// src/main.rs
use anyhow::{anyhow, Context, Result};
use clap::Parser;
use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::process::{Command, Stdio};
use uuid::Uuid;

fn get_hostname() -> Result<String> {
    let output = Command::new("hostname").output()?;
    let hostname = String::from_utf8_lossy(&output.stdout).trim().to_string();

    // Convert to lowercase first
    let hostname_lower = hostname.to_lowercase();

    // Sanitize: Remove any characters that are not alphanumeric or hyphens
    let sanitized = hostname_lower
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == '-')
        .collect::<String>();

    Ok(sanitized)
}

fn get_disk_serial(disk: &str) -> Result<String> {
    let output = Command::new("lsblk")
        .args(&["-d", "-n", "-o", "SERIAL", disk])
        .output()?;

    let serial = String::from_utf8_lossy(&output.stdout).trim().to_string();

    if serial.is_empty() {
        // Fallback: Use disk ID or part of the UUID
        let disk_id = Command::new("lsblk")
            .args(&["-d", "-n", "-o", "UUID", disk])
            .output()?;
        let disk_id = String::from_utf8_lossy(&disk_id.stdout)
            .trim()
            .chars()
            .take(8)
            .collect::<String>();
        Ok(format!("DISK-{}", disk_id))
    } else {
        Ok(serial.replace(" ", "_"))
    }
}

fn generate_pool_name(disk: &str) -> Result<String> {
    let hostname = get_hostname().unwrap_or_else(|_| "unknown".to_string());
    let serial = get_disk_serial(disk).unwrap_or_else(|_| "unknown".to_string());
    Ok(format!("rpool-{}-{}", hostname, serial))
}

fn cleanup_existing_setup(disk: &str) -> Result<()> {
    println!("Cleaning up any existing setup...");

    // 1. Destroy ZFS pool first (if exists)
    let pool_name = generate_pool_name(disk)?;
    let _ = Command::new("sudo")
        .args(&["zpool", "destroy", "-f", &pool_name])
        .status();

    // 2. Deactivate all swap partitions on the disk
    let swap_partitions = Command::new("lsblk")
        .args(&["-nlpo", "NAME,TYPE", disk])
        .output()?;

    for line in String::from_utf8_lossy(&swap_partitions.stdout).lines() {
        if line.contains("part") && line.contains("swap") {
            let part = line.split_whitespace().next().unwrap_or_default();
            let _ = Command::new("sudo").args(&["swapoff", "-v", part]).status();
        }
    }

    // 3. Unmount all partitions aggressively
    let _ = Command::new("sudo")
        .args(&["umount", "-A", "--recursive", &format!("{}*", disk)])
        .status();

    // 4. Wipe signatures with force (even if busy)
    println!("Clearing all signatures on {}...", disk);
    let _ = Command::new("sudo")
        .args(&["wipefs", "-a", "-f", disk])
        .status();

    // 5. Refresh partition table with retries
    for _ in 0..3 {
        let _ = Command::new("sudo")
            .args(&["blockdev", "--rereadpt", disk])
            .status();
        std::thread::sleep(std::time::Duration::from_secs(1));
    }

    Ok(())
}

#[derive(Parser, Debug)]
#[command(author, version, about = "ZFS NixOS setup tool")]
struct Args {
    /// Disk to use
    #[arg(short, long, required = true)]
    disk: String,

    /// Hostname to use
    #[arg(short = 'n', long, default_value = "nixos")]
    hostname: String,

    /// Username to use
    #[arg(short, long)]
    username: Option<String>,

    /// Swap size in GB
    #[arg(short, long, default_value_t = 4)]
    swap: u32,

    /// EFI partition size in GB
    #[arg(short = 'e', long, default_value_t = 1)]
    efi: u32,

    /// Reserve space at end of disk in GB
    #[arg(short, long, default_value_t = 1)]
    reserve: u32,

    /// Enable LUKS encryption
    #[arg(long)]
    encrypt: bool,

    /// Don't create swap partition
    #[arg(long)]
    no_swap: bool,

    /// Disable trim/discard (for non-SSD)
    #[arg(long)]
    no_trim: bool,

    /// Flake source path (location of your flake.nix)
    #[arg(short, long, default_value = "/per/etc/nixos")]
    flake_source: String,

    /// Host profile to use from flake (desktop, portable, surface, thinkpad, etc.)
    #[arg(short = 'p', long)]
    profile: Option<String>,

    /// Skip NixOS installation, only prepare the disk
    #[arg(long)]
    prepare_only: bool,
}

fn main() -> Result<()> {
    env_logger::init();
    let args = Args::parse();

    // Clean up any existing setup
    cleanup_existing_setup(&args.disk)?;

    // Get current username if not specified
    let username = match args.username {
        Some(name) => name,
        None => whoami::username(),
    };

    let use_swap = !args.no_swap;
    let allow_discard = !args.no_trim;

    // Check if disk exists
    if !Path::new(&args.disk).exists() {
        return Err(anyhow!(
            "Disk {} does not exist or is not a block device",
            args.disk
        ));
    }

    // Determine host profile
    let profile = match &args.profile {
        Some(p) => p.clone(),
        None => {
            // Attempt to auto-detect system type
            let laptop_markers = Command::new("dmidecode")
                .args(&["-s", "chassis-type"])
                .output()
                .map(|out| {
                    let chassis = String::from_utf8_lossy(&out.stdout).to_lowercase();
                    chassis.contains("laptop") || chassis.contains("notebook")
                })
                .unwrap_or(false);

            if laptop_markers {
                // Check if it's a Surface or ThinkPad
                let system_vendor = Command::new("dmidecode")
                    .args(&["-s", "system-manufacturer"])
                    .output()
                    .map(|out| String::from_utf8_lossy(&out.stdout).to_lowercase())
                    .unwrap_or_default();

                let system_product = Command::new("dmidecode")
                    .args(&["-s", "system-product-name"])
                    .output()
                    .map(|out| String::from_utf8_lossy(&out.stdout).to_lowercase())
                    .unwrap_or_default();

                if system_vendor.contains("microsoft") || system_product.contains("surface") {
                    "surface".to_string()
                } else if system_vendor.contains("lenovo") {
                    "thinkpad".to_string()
                } else {
                    "portable".to_string()
                }
            } else {
                "desktop".to_string()
            }
        }
    };

    // Show disk details
    println!("================= Disk Information =================");
    run_command("lsblk", &["-dpo", "name,size,model,serial", &args.disk])?;
    println!("===================================================");

    println!("WARNING: This will destroy all data on {}", args.disk);
    println!("Setup details:");
    println!("  - Hostname: {}", args.hostname);
    println!("  - Username: {}", username);
    println!("  - Host profile: {}", profile);
    println!("  - Flake source: {}", args.flake_source);
    println!("  - EFI size: {}GB", args.efi);
    if use_swap {
        println!("  - Swap size: {}GB", args.swap);
    } else {
        println!("  - Swap: disabled");
    }
    println!("  - Reserved space: {}GB", args.reserve);
    if args.encrypt {
        println!("  - Encryption: enabled");
    } else {
        println!("  - Encryption: disabled");
    }
    if allow_discard {
        println!("  - Trim/discard: enabled (for SSD)");
    } else {
        println!("  - Trim/discard: disabled");
    }
    if args.prepare_only {
        println!("  - Mode: Prepare disk only (no NixOS installation)");
    } else {
        println!("  - Mode: Full installation");
    }
    println!();

    print!("Type YES to continue: ");
    io::stdout().flush()?;
    let mut confirm = String::new();
    io::stdin().read_line(&mut confirm)?;
    if confirm.trim() != "YES" {
        println!("Aborted.");
        return Ok(());
    }

    // Calculate disk layout
    println!("Calculating disk layout...");
    let disk_size = get_disk_size(&args.disk)?;
    let sector_size = get_sector_size(&args.disk)?;
    let disk_size_gb = (disk_size * sector_size) as f64 / 1024.0 / 1024.0 / 1024.0;

    // Calculate partition boundaries
    let rpool_end_gb = if use_swap {
        disk_size_gb - args.swap as f64 - args.reserve as f64
    } else {
        disk_size_gb - args.reserve as f64
    };

    let swap_end_gb = disk_size_gb - args.reserve as f64;

    // Create partition table
    println!("Creating partition table...");
    create_partition_table(&args.disk, args.efi, rpool_end_gb, swap_end_gb, use_swap)?;

    // Update partition table
    println!("Updating partition table...");
    run_command("partprobe", &[&args.disk])?;
    std::thread::sleep(std::time::Duration::from_secs(2));

    // Get partition names
    let efi_part = format!("{}1", args.disk);
    let zfs_part = format!("{}2", args.disk);
    let swap_part = if use_swap {
        Some(format!("{}3", args.disk))
    } else {
        None
    };

    // Format EFI partition
    println!("Formatting EFI partition...");
    run_command("mkfs.vfat", &["-F32", &efi_part])?;

    // Set up encryption if requested
    let zfs_dev = if args.encrypt {
        println!("Setting up LUKS encryption...");
        setup_luks_encryption(&zfs_part, "luks-rpool")?;
        String::from("/dev/mapper/luks-rpool")
    } else {
        zfs_part
    };

    // Format swap if requested
    // NOTE: We use dedicated encrypted partitions for swap, NOT ZFS zvols.
    // ZFS swap can cause deadlocks due to memory allocation loops during low-memory
    // situations when ZFS needs memory to process swap writes (COW operations).
    if let Some(swap) = &swap_part {
        println!("Formatting swap partition...");
        if args.encrypt {
            setup_luks_encryption(swap, "luks-swap")?;
            run_command("mkswap", &["/dev/mapper/luks-swap"])?;
            run_command("swapon", &["/dev/mapper/luks-swap"])?;
        } else {
            run_command("mkswap", &[swap])?;
            run_command("swapon", &[swap])?;
        }
    }

    // Create ZFS pool
    println!("Creating ZFS pool with 'erase your darlings' layout...");
    let pool_name = generate_pool_name(&args.disk)?;
    create_zfs_pool(&zfs_dev)?;

    // Create datasets for erase-your-darlings setup
    println!("Creating datasets...");
    create_zfs_datasets(&pool_name)?;

    // Create a blank snapshot for "erase your darlings"
    println!("Creating blank snapshot...");
    run_command(
        "zfs",
        &["snapshot", &format!("{}/eyd/root@blank", pool_name)],
    )?;

    // Mount filesystems for NixOS installation
    println!("Mounting filesystems...");
    mount_filesystems(&efi_part, &pool_name)?;

    // Display disk-by-id information
    println!("\nDisk by-id paths (useful for configuration):");
    show_disk_by_id(&efi_part, &format!("{}2", args.disk))?;

    // Set up persistent directory structure
    println!("\nSetting up persistent directory structure...");
    setup_persist_directories(&username)?;

    // Create basic flake configuration for bootstrapping if needed
    println!("\nSetting up NixOS configuration...");

    let flake_source_path = Path::new(&args.flake_source);

    if !flake_source_path.exists() {
        return Err(anyhow!(
            "Flake source path {} does not exist",
            args.flake_source
        ));
    }

    // Create /mnt/per/etc/nixos directory
    fs::create_dir_all("/mnt/per/etc/nixos")
        .context("Failed to create /mnt/per/etc/nixos")?;

    // Check for existing flake and copy it if it exists
    println!("Copying flake configuration from {}...", args.flake_source);

    // Use rsync to copy the flake files to the new system
    let status = Command::new("rsync")
        .args(&[
            "-av",
            "--exclude='.git'",
            "--exclude='result'",
            &format!("{}/", args.flake_source),
            "/mnt/per/etc/nixos/",
        ])
        .status()
        .context("Failed to copy flake configuration")?;

    if !status.success() {
        return Err(anyhow!("Failed to copy flake configuration"));
    }

    // Create symlink for /mnt/etc/nixos to /mnt/per/etc/nixos
    fs::create_dir_all("/mnt/etc").context("Failed to create /mnt/etc")?;
    std::os::unix::fs::symlink("/per/etc/nixos", "/mnt/etc/nixos")
        .context("Failed to create symlink for /mnt/etc/nixos")?;

    // Update host-id in hardware configuration for the target host
    let host_config_dir = format!("/mnt/per/etc/nixos/hosts/{}", profile);

    if !Path::new(&host_config_dir).exists() {
        fs::create_dir_all(&host_config_dir)
            .context("Failed to create host configuration directory")?;
    }

    // Generate machine-id (hostId for ZFS)
    let machine_id = Uuid::new_v4()
        .to_string()
        .chars()
        .take(8)
        .collect::<String>();

    // Check if we need to create/update hardware configuration
    let hw_config_path = format!("{}/hardware-configuration.nix", host_config_dir);

    // Create or update hardware configuration
    update_hardware_configuration(
        &hw_config_path,
        &machine_id,
        &args.hostname,
        &pool_name,
        args.encrypt,
        use_swap,
        allow_discard,
        swap_part.as_deref(),
    )?;

    // Update hostname in flake.nix if needed
    update_flake_hostname(&args.hostname, &profile, "/mnt/per/etc/nixos/flake.nix")?;

    // Create a basic script to bootstrap the system after reboot
    create_bootstrap_script(&args.hostname, &profile, &username)?;

    // If we're not just preparing, install NixOS now
    if !args.prepare_only {
        println!("\nInstalling NixOS...");

        // Make sure /mnt/per/etc/nixos/flake.nix exists
        if !Path::new("/mnt/per/etc/nixos/flake.nix").exists() {
            return Err(anyhow!(
                "Flake configuration not found at /mnt/per/etc/nixos/flake.nix"
            ));
        }

        // Create a longer-lived string for the flake path
        let flake_path = format!("/mnt/per/etc/nixos#{}", args.hostname);

        // Install NixOS using the flake
        let nixos_install_args = vec![
            "--option",
            "pure-eval",
            "no",
            "--flake",
            &flake_path,
            "/mnt",
        ];

        println!("Running: nixos-install {}", nixos_install_args.join(" "));

        let status = Command::new("nixos-install")
            .args(&nixos_install_args)
            .status()
            .context("Failed to run nixos-install")?;

        if !status.success() {
            return Err(anyhow!("nixos-install failed"));
        }
    }

    println!("\n==================== SUCCESS ====================");
    println!("ZFS setup and NixOS installation complete!");
    println!("\nYour ZFS layout:");
    run_command("zfs", &["list"])?;
    println!("\nNext steps:");

    if args.prepare_only {
        println!(
            "1. Complete the installation: nixos-install --flake /mnt/per/etc/nixos#{}",
            args.hostname
        );
    } else {
        println!("1. Reboot into your new system");
        println!("2. Run the bootstrap script: /per/bootstrap.sh");
    }

    println!("\nSee /mnt/per/bootstrap.sh for more details");
    println!("=================================================");

    Ok(())
}

fn get_disk_size(disk: &str) -> Result<u64> {
    // Try using lsblk to get the size in bytes first (more reliable)
    let output = Command::new("lsblk")
        .args(&[
            "--bytes",
            "--nodeps",
            "--noheadings",
            "--output",
            "SIZE",
            disk,
        ])
        .output();

    if let Ok(output) = output {
        let size_str = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !size_str.is_empty() {
            // Convert bytes to sectors (assuming 512-byte sectors as default)
            let sector_size = get_sector_size(disk).unwrap_or(512);
            let bytes = size_str
                .parse::<u64>()
                .context("Failed to parse disk size")?;
            return Ok(bytes / sector_size);
        }
    }

    // Fall back to blockdev if lsblk failed
    let output = Command::new("blockdev")
        .args(&["--getsz", disk])
        .output()
        .context("Failed to get disk size")?;

    let size_str = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if size_str.is_empty() {
        return Err(anyhow!(
            "Could not determine disk size: empty output from blockdev"
        ));
    }

    let size = size_str
        .parse::<u64>()
        .context("Failed to parse disk size")?;
    Ok(size)
}

fn get_sector_size(disk: &str) -> Result<u64> {
    // Try blockdev first
    let output = Command::new("blockdev").args(&["--getss", disk]).output();

    if let Ok(output) = output {
        let size_str = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !size_str.is_empty() {
            return size_str
                .parse::<u64>()
                .context("Failed to parse sector size");
        }
    }

    // If blockdev fails, use a standard sector size of 512 bytes
    println!("Warning: Couldn't determine sector size, using default of 512 bytes");
    Ok(512)
}

fn run_command(cmd: &str, args: &[&str]) -> Result<()> {
    let status = Command::new(cmd)
        .args(args)
        .status()
        .with_context(|| format!("Failed to execute '{}' with args: {:?}", cmd, args))?;

    if !status.success() {
        return Err(anyhow!("Command '{}' with args {:?} failed", cmd, args));
    }

    Ok(())
}

fn create_partition_table(
    disk: &str,
    efi_size: u32,
    rpool_end_gb: f64,
    swap_end_gb: f64,
    use_swap: bool,
) -> Result<()> {
    // Create GPT partition table
    run_command(
        "parted",
        &["--script", "-s", "--align=optimal", disk, "mklabel", "gpt"],
    )?;

    // Create EFI partition
    run_command(
        "parted",
        &[
            "--script",
            "--align=optimal",
            disk,
            "mkpart",
            "efi",
            "fat32",
            "1MiB",
            &format!("{}GiB", efi_size),
        ],
    )?;

    // Set ESP flag
    run_command(
        "parted",
        &["--script", "--align=optimal", disk, "set", "1", "esp", "on"],
    )?;

    // Create ZFS partition
    run_command(
        "parted",
        &[
            "--script",
            "--align=optimal",
            disk,
            "mkpart",
            "rpool",
            &format!("{}GiB", efi_size),
            &format!("{}GiB", rpool_end_gb),
        ],
    )?;

    // Create swap partition if needed
    if use_swap {
        run_command(
            "parted",
            &[
                "--script",
                "--align=optimal",
                disk,
                "mkpart",
                "swap",
                &format!("{}GiB", rpool_end_gb),
                &format!("{}GiB", swap_end_gb),
            ],
        )?;
    }

    Ok(())
}

fn setup_luks_encryption(device: &str, name: &str) -> Result<()> {
    // Create a command with both stdin and stdout piped
    let mut child = Command::new("cryptsetup")
        .args(&["luksFormat", "--type", "luks2", device])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .context("Failed to spawn cryptsetup")?;

    // User needs to confirm and enter password
    println!(
        "Please confirm and enter a password for LUKS encryption on {}",
        device
    );

    // Let cryptsetup handle the interaction directly
    let status = child.wait().context("Failed to wait for cryptsetup")?;
    if !status.success() {
        return Err(anyhow!("cryptsetup luksFormat failed"));
    }

    // Open the encrypted device
    let mut child = Command::new("cryptsetup")
        .args(&["luksOpen", device, name])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .context("Failed to spawn cryptsetup luksOpen")?;

    println!("Please enter the password to open the encrypted device");

    let status = child
        .wait()
        .context("Failed to wait for cryptsetup luksOpen")?;
    if !status.success() {
        return Err(anyhow!("cryptsetup luksOpen failed"));
    }

    Ok(())
}

fn create_zfs_pool(device: &str) -> Result<()> {
    let pool_name = generate_pool_name(device)?;

    // Create the pool
    let status = Command::new("zpool")
        .args(&["create", "-f", "-o", "ashift=12", &pool_name, device])
        .status()?;

    if !status.success() {
        return Err(anyhow!("Failed to create ZFS pool"));
    }

    // Create a root dataset with immutable properties set upfront
    let root_dataset = format!("{}/root", pool_name);
    run_command(
        "zfs",
        &[
            "create",
            "-o",
            "compression=lz4",      // Fast compression with good ratio
            "-o",
            "acltype=posixacl",     // POSIX ACLs for proper permissions
            "-o",
            "xattr=sa",             // System attribute-based extended attributes (faster)
            "-o",
            "atime=off",            // Disable access time updates (major performance boost)
            "-o",
            "normalization=formD",  // Unicode normalization for consistent filename handling
            "-o",
            "mountpoint=none",      // This dataset is just a container, not mounted directly
            &root_dataset,
        ],
    )?;

    // Set mutable properties on the POOL
    run_command("zpool", &["set", "autotrim=on", &pool_name])?;  // Automatic TRIM for SSDs (maintains performance)

    Ok(())
}

fn create_zfs_datasets(pool_name: &str) -> Result<()> {
    // Root dataset
    run_command(
        "zfs",
        &[
            "create",
            "-o",
            "mountpoint=none",
            &format!("{}/eyd", pool_name),
        ],
    )?;
    run_command(
        "zfs",
        &[
            "create",
            "-o",
            "mountpoint=/",
            &format!("{}/eyd/root", pool_name),
        ],
    )?;

    // Persistent datasets
    run_command(
        "zfs",
        &[
            "create",
            "-o",
            "mountpoint=/nix",
            &format!("{}/eyd/nix", pool_name),
        ],
    )?;
    run_command(
        "zfs",
        &[
            "create",
            "-o",
            "mountpoint=/home",
            &format!("{}/eyd/home", pool_name),
        ],
    )?;
    run_command(
        "zfs",
        &[
            "create",
            "-o",
            "mountpoint=/per",
            &format!("{}/eyd/per", pool_name),
        ],
    )?;

    Ok(())
}

fn mount_filesystems(efi_part: &str, pool_name: &str) -> Result<()> {
    // Create mount directories
    fs::create_dir_all("/mnt").context("Failed to create /mnt")?;

    // Mount ZFS root
    run_command(
        "mount",
        &["-t", "zfs", &format!("{}/eyd/root", pool_name), "/mnt"],
    )?;

    // Create other mount points
    for dir in &["/mnt/boot", "/mnt/nix", "/mnt/home", "/mnt/per"] {
        fs::create_dir_all(dir).with_context(|| format!("Failed to create {}", dir))?;
    }

    // Mount other filesystems
    run_command("mount", &[efi_part, "/mnt/boot"])?;
    run_command(
        "mount",
        &["-t", "zfs", &format!("{}/eyd/nix", pool_name), "/mnt/nix"],
    )?;
    run_command(
        "mount",
        &["-t", "zfs", &format!("{}/eyd/home", pool_name), "/mnt/home"],
    )?;
    run_command(
        "mount",
        &[
            "-t",
            "zfs",
            &format!("{}/eyd/per", pool_name),
            "/mnt/per",
        ],
    )?;

    Ok(())
}

fn show_disk_by_id(efi_part: &str, zfs_part: &str) -> Result<()> {
    for part in &[efi_part, zfs_part] {
        let output = Command::new("readlink")
            .args(&["-f", part])
            .output()
            .context("Failed to readlink")?;

        let real_path = String::from_utf8(output.stdout)?.trim().to_string();
        let filename = Path::new(&real_path)
            .file_name()
            .ok_or_else(|| anyhow!("Failed to get filename from {}", real_path))?
            .to_string_lossy()
            .to_string();

        // Find disk-by-id symlinks
        let output = Command::new("ls")
            .args(&["-l", "/dev/disk/by-id"])
            .output()
            .context("Failed to list disk-by-id")?;

        let ls_output = String::from_utf8(output.stdout)?;

        for line in ls_output.lines() {
            if line.contains(&filename) {
                println!("{} -> {}", part, line);
                break;
            }
        }
    }

    Ok(())
}

fn setup_persist_directories(username: &str) -> Result<()> {
    // Create essential directories in /per
    for dir in &[
        "/mnt/per/etc",
        "/mnt/per/etc/nixos",
        "/mnt/per/var/lib",
        "/mnt/per/var/log",
        "/mnt/per/etc/ssh",
        "/mnt/per/etc/NetworkManager/system-connections",
    ] {
        fs::create_dir_all(dir).with_context(|| format!("Failed to create {}", dir))?;
    }

    // Create user-specific directories
    let user_dirs = [
        format!("/mnt/home/{}", username),
        format!("/mnt/home/{}/.ssh", username),
        format!("/mnt/home/{}/.gnupg", username),
        format!("/mnt/home/{}/.config", username),
    ];

    for dir in &user_dirs {
        fs::create_dir_all(dir).with_context(|| format!("Failed to create {}", dir))?;
    }

    // Ensure correct permissions
    run_command(
        "chown",
        &["-R", &format!("{}:{}", username, username), &user_dirs[0]],
    )?;

    Ok(())
}

fn update_hardware_configuration(
    hw_config_path: &str,
    machine_id: &str,
    hostname: &str,
    pool_name: &str,
    encryption: bool,
    use_swap: bool,
    allow_discard: bool,
    swap_part: Option<&str>,
) -> Result<()> {
    // Get disk UUIDs for boot device and swap
    let boot_uuid = get_partition_uuid("/dev/disk/by-partlabel/efi")?;
    let rpool_uuid = get_partition_uuid("/dev/disk/by-partlabel/rpool")?;
    let swap_uuid = if use_swap {
        get_partition_uuid("/dev/disk/by-partlabel/swap").ok()
    } else {
        None
    };

    // Create hardware-configuration.nix
    let hardware_config = format!(
        r#"{{ config, lib, pkgs, modulesPath, ... }}:

{{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Host specific configuration
  networking.hostName = "{}";
  networking.hostId = "{}"; # Required for ZFS

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # File systems
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = true;

  fileSystems."/" = {{
    device = "{}/eyd/root";
    fsType = "zfs";
  }};

  fileSystems."/nix" = {{
    device = "{}/eyd/nix";
    fsType = "zfs";
  }};

  fileSystems."/home" = {{
    device = "{}/eyd/home";
    fsType = "zfs";
  }};

  fileSystems."/per" = {{
    device = "{}/eyd/per";
    fsType = "zfs";
  }};

  fileSystems."/boot" = {{
    device = "{}";
    fsType = "vfat";
  }};

  # Ensure persistent directories are properly linked
  environment.persistence."/per" = {{
    directories = [
      "/etc/nixos"
      "/etc/ssh"
      "/var/lib"
      "/var/log"
      "/etc/NetworkManager/system-connections"
    ];
  }};

  # Make /etc/nixos point to /per/etc/nixos
  boot.initrd.postMountCommands = ''
    mkdir -p /mnt-root/etc
    ln -s /per/etc/nixos /mnt-root/etc/nixos
  '';
"#,
        hostname, machine_id, pool_name, pool_name, pool_name, pool_name, boot_uuid
    );

    // Add encryption configuration if enabled
    let mut config = hardware_config;

    if encryption {
        let encryption_config = format!(
            r#"
  # LUKS configuration
  boot.initrd.luks.devices."luks-rpool" = {{
    device = "{}";
    preLVM = true;
    allowDiscards = {};
  }};
"#,
            rpool_uuid, allow_discard
        );
        config.push_str(&encryption_config);
    }

    // Add swap configuration if enabled
    if use_swap && swap_uuid.is_some() {
        let swap_config = format!(
            r#"
  swapDevices = [
    {{ device = "{}"; }}
  ];
"#,
            swap_uuid.unwrap()
        );
        config.push_str(&swap_config);
    }

    // Close the module
    config.push_str("\n}\n");

    // Create the directory if it doesn't exist
    if let Some(parent) = Path::new(hw_config_path).parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("Failed to create directory {}", parent.display()))?;
    }

    // Write the hardware configuration
    fs::write(hw_config_path, config).with_context(|| {
        format!(
            "Failed to write hardware configuration to {}",
            hw_config_path
        )
    })?;

    Ok(())
}

fn get_partition_uuid(dev_path: &str) -> Result<String> {
    // Try to get the UUID using blkid
    let output = Command::new("blkid")
        .args(&["-s", "UUID", "-o", "value", dev_path])
        .output()
        .context("Failed to run blkid")?;

    let uuid = String::from_utf8(output.stdout)?.trim().to_string();

    if uuid.is_empty() {
        return Err(anyhow!("Failed to get UUID for {}", dev_path));
    }

    Ok(format!("/dev/disk/by-uuid/{}", uuid))
}

fn update_flake_hostname(hostname: &str, profile: &str, flake_path: &str) -> Result<()> {
    // Read the flake.nix file
    let flake_content = match fs::read_to_string(flake_path) {
        Ok(content) => content,
        Err(e) => {
            println!(
                "Warning: Could not read flake.nix: {}. Will not update hostname.",
                e
            );
            return Ok(());
        }
    };

    // Update profile to use the current hostname if needed
    // This is more complex and would require parsing the flake.nix structure properly
    // For simplicity, we'll just provide a helpful message
    println!("NOTE: You may need to update your flake.nix to use the hostname '{}' with the '{}' profile.", hostname, profile);
    println!("      Typically this would involve adding an entry for this host in your flake outputs section.");

    Ok(())
}

fn create_bootstrap_script(hostname: &str, profile: &str, username: &str) -> Result<()> {
    let bootstrap_script = format!(
        r#"#!/bin/sh
# Bootstrap script for new NixOS installation
# Generated by zfs-nixos-setup

echo "Setting up persistent directories..."

# Create system directories if they don't exist
mkdir -p /per/etc/nixos
mkdir -p /per/etc/ssh
mkdir -p /per/var/lib
mkdir -p /per/var/log
mkdir -p /per/etc/NetworkManager/system-connections

# Create user directories if they don't exist
mkdir -p /home/{}/.ssh
mkdir -p /home/{}/.gnupg
mkdir -p /home/{}/.config

# Set proper permissions
chown -R {}:{} /home/{}

# Create symlinks for persistence
if [ ! -L /etc/nixos ]; then
  ln -sf /per/etc/nixos /etc/nixos
fi

if [ ! -L /etc/ssh ]; then
  ln -sf /per/etc/ssh /etc/ssh
fi

# Rebuild the system
echo "Rebuilding NixOS..."
nixos-rebuild --flake /per/etc/nixos#{} switch

echo "Setup complete! Your system is now ready."
echo "Remember to change your password with 'passwd'"
"#,
        username, username, username, username, username, username, hostname
    );

    fs::write("/mnt/per/bootstrap.sh", bootstrap_script)
        .context("Failed to write bootstrap script")?;

    // Make the script executable
    run_command("chmod", &["+x", "/mnt/per/bootstrap.sh"])?;

    Ok(())
}
