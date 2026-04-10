use anyhow::{Context, Result};
use clap::Parser;
use log::{debug, error, info, warn};

/// A CLI tool template for NixOS system management
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,

    /// Configuration file path
    #[arg(short, long, default_value = "/etc/myconfig.conf")]
    config: String,

    /// Dry run mode - show what would be done without executing
    #[arg(short, long)]
    dry_run: bool,

    /// The command to execute
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Parser, Debug)]
enum Commands {
    /// Initialize the tool
    Init {
        /// Target directory
        #[arg(short, long, default_value = ".")]
        target: String,
    },
    /// Run the main operation
    Run {
        /// Input parameter
        input: String,
        /// Optional output parameter
        #[arg(short, long)]
        output: Option<String>,
    },
    /// Show system status
    Status,
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Initialize logging
    let log_level = if args.verbose { "debug" } else { "info" };
    env_logger::init_from_env(env_logger::Env::new().default_filter_or(log_level));

    info!("Starting my-rust-tool v{}", env!("CARGO_PKG_VERSION"));
    debug!("Arguments: {:?}", args);

    // Load configuration
    let _config = load_config(&args.config)?;

    // Execute command
    match &args.command {
        Some(Commands::Init { target }) => {
            info!("Initializing in directory: {}", target);
            init_command(target, args.dry_run)?;
        }
        Some(Commands::Run { input, output }) => {
            info!("Running with input: {}", input);
            run_command(input, output.as_deref(), args.dry_run)?;
        }
        Some(Commands::Status) => {
            info!("Checking status");
            status_command()?;
        }
        None => {
            warn!("No command specified, showing status");
            status_command()?;
        }
    }

    info!("Operation completed successfully");
    Ok(())
}

fn load_config(config_path: &str) -> Result<()> {
    debug!("Loading configuration from: {}", config_path);

    // TODO: Implement configuration loading
    // This might involve reading YAML, TOML, or JSON files
    // Example with serde_yaml:
    // let config_str = std::fs::read_to_string(config_path)
    //     .with_context(|| format!("Failed to read config file: {}", config_path))?;
    // let config: MyConfig = serde_yaml::from_str(&config_str)
    //     .context("Failed to parse configuration")?;

    Ok(())
}

fn init_command(target: &str, dry_run: bool) -> Result<()> {
    if dry_run {
        info!("DRY RUN: Would initialize in {}", target);
        return Ok(());
    }

    // Create target directory if it doesn't exist
    std::fs::create_dir_all(target)
        .with_context(|| format!("Failed to create directory: {}", target))?;

    info!("Initialized successfully in {}", target);
    Ok(())
}

fn run_command(input: &str, output: Option<&str>, dry_run: bool) -> Result<()> {
    if dry_run {
        info!("DRY RUN: Would process input '{}' to output '{:?}'", input, output);
        return Ok(());
    }

    // TODO: Implement your main logic here
    debug!("Processing input: {}", input);

    // Example of using system commands
    let output_result = std::process::Command::new("echo")
        .arg(format!("Processing: {}", input))
        .output()
        .context("Failed to execute echo command")?;

    if !output_result.status.success() {
        error!("Command failed with status: {}", output_result.status);
        return Err(anyhow::anyhow!("Command execution failed"));
    }

    let result = String::from_utf8_lossy(&output_result.stdout);
    info!("Command result: {}", result.trim());

    // Handle output
    if let Some(output_path) = output {
        std::fs::write(output_path, result.as_bytes())
            .with_context(|| format!("Failed to write output to: {}", output_path))?;
        info!("Output written to: {}", output_path);
    }

    Ok(())
}

fn status_command() -> Result<()> {
    info!("System status:");

    // Example system checks
    let hostname = std::process::Command::new("hostname")
        .output()
        .context("Failed to get hostname")?;

    if hostname.status.success() {
        let hostname_str = String::from_utf8_lossy(&hostname.stdout).trim().to_string();
        info!("  Hostname: {}", hostname_str);
    } else {
        warn!("  Could not determine hostname");
    }

    // Add more status checks as needed
    info!("  Tool version: {}", env!("CARGO_PKG_VERSION"));
    info!("  Status: OK");

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_init_command() {
        let temp_dir = tempdir().unwrap();
        let target_path = temp_dir.path().join("test_init");
        let target_str = target_path.to_str().unwrap();

        // Test dry run
        assert!(init_command(target_str, true).is_ok());
        assert!(!target_path.exists(), "Directory should not be created in dry run");

        // Test actual initialization
        assert!(init_command(target_str, false).is_ok());
        assert!(target_path.exists(), "Directory should be created");
    }

    #[test]
    fn test_load_config_missing_file() {
        let result = load_config("/nonexistent/config.yaml");
        // With the current implementation, this should succeed
        // In a real implementation, it might fail if file doesn't exist
        assert!(result.is_ok());
    }
}
