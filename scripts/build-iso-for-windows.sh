#!/usr/bin/env bash
# Build NixOS installer ISO and copy to Windows-accessible location
set -euo pipefail

# Configuration
WINDOWS_USER="${WINDOWS_USER:-SchausbergerF}"
WINDOWS_ISO_DIR="/mnt/c/Users/${WINDOWS_USER}/ISOs"
DEFAULT_VARIANT="minimal"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_usage() {
    cat << EOF
Build NixOS installer ISO and copy to Windows path.

Usage: $(basename "$0") [OPTIONS] [VARIANT]

VARIANT:
    minimal    Build minimal installer ISO (default)
    full       Build full installer ISO with recovery tools
    both       Build both variants

OPTIONS:
    -h, --help              Show this help message
    -d, --destination DIR   Windows destination directory (default: ${WINDOWS_ISO_DIR})
    -k, --keep-result       Keep Nix result symlink after copying
    -n, --no-copy           Build only, don't copy to Windows
    -v, --verbose           Show detailed build output

Examples:
    $(basename "$0")                    # Build minimal ISO and copy to Windows
    $(basename "$0") full               # Build full ISO and copy to Windows
    $(basename "$0") both               # Build both ISOs
    $(basename "$0") -d /mnt/d/ISOs     # Copy to custom Windows location
    $(basename "$0") -n minimal         # Build only, don't copy
EOF
}

# Parse arguments
VARIANT="${DEFAULT_VARIANT}"
DESTINATION="${WINDOWS_ISO_DIR}"
KEEP_RESULT=false
NO_COPY=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -k|--keep-result)
            KEEP_RESULT=true
            shift
            ;;
        -n|--no-copy)
            NO_COPY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        minimal|full|both)
            VARIANT="$1"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Validate destination is a Windows mount
if [[ ! "${DESTINATION}" =~ ^/mnt/[a-z] ]] && [[ "${NO_COPY}" == false ]]; then
    echo -e "${YELLOW}Warning: Destination ${DESTINATION} doesn't look like a Windows mount point${NC}"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create destination directory if it doesn't exist
if [[ "${NO_COPY}" == false ]]; then
    mkdir -p "${DESTINATION}"
    echo -e "${GREEN}Using destination: ${DESTINATION}${NC}"
fi

build_and_copy() {
    local variant=$1
    local flake_attr="installer-iso-${variant}"
    local iso_filename="nixos-installer-${variant}.iso"

    echo -e "\n${GREEN}Building ${variant} ISO...${NC}"

    # Build the ISO
    if [[ "${VERBOSE}" == true ]]; then
        nix build ".#${flake_attr}" --print-build-logs
    else
        nix build ".#${flake_attr}"
    fi

    # Find the built ISO
    local iso_path
    iso_path=$(find result/iso -name "*.iso" -type f | head -1)

    if [[ -z "${iso_path}" ]]; then
        echo -e "${RED}Error: ISO not found in result/iso/${NC}" >&2
        return 1
    fi

    local iso_size
    iso_size=$(du -h "${iso_path}" | cut -f1)
    echo -e "${GREEN}Built: ${iso_path} (${iso_size})${NC}"

    # Copy to Windows if requested
    if [[ "${NO_COPY}" == false ]]; then
        local dest_path="${DESTINATION}/${iso_filename}"
        echo -e "${GREEN}Copying to: ${dest_path}${NC}"
        cp "${iso_path}" "${dest_path}"
        echo -e "${GREEN}Done! ISO available at: ${dest_path}${NC}"

        # Print Windows path
        local windows_path
        windows_path=$(echo "${dest_path}" | sed 's|/mnt/\([a-z]\)|\U\1:|')
        echo -e "${YELLOW}Windows path: ${windows_path}${NC}"
    fi

    # Clean up result symlink unless requested to keep
    if [[ "${KEEP_RESULT}" == false ]]; then
        rm -f result
    fi
}

# Main execution
cd /per/etc/nixos

case "${VARIANT}" in
    minimal)
        build_and_copy "minimal"
        ;;
    full)
        build_and_copy "full"
        ;;
    both)
        build_and_copy "minimal"
        build_and_copy "full"
        ;;
    *)
        echo -e "${RED}Error: Unknown variant: ${VARIANT}${NC}" >&2
        print_usage
        exit 1
        ;;
esac

echo -e "\n${GREEN}All done!${NC}"
