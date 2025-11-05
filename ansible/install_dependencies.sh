#!/bin/sh

# Parse command line arguments
LOCAL_COLLECTION_PATH=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --local-collection)
            LOCAL_COLLECTION_PATH="$2"
            shift 2
            ;;
        --local-collection=*)
            LOCAL_COLLECTION_PATH="${1#*=}"
            shift 1
            ;;
        -h|--help)
            echo "Usage: $0 [--local-collection PATH]"
            echo ""
            echo "Options:"
            echo "  --local-collection PATH    Use a local symlinked ansible collection instead of installing from GitHub"
            echo "  -h, --help                Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

ansible-galaxy install -r requirements.yaml --force

# Handle local collection symlinking if requested
if [ -n "$LOCAL_COLLECTION_PATH" ]; then
    COLLECTION_VENDOR_PATH="vendor/collections/ansible_collections/ethpandaops/general"

    if [ ! -d "$LOCAL_COLLECTION_PATH" ]; then
        echo "Error: Local collection path does not exist: $LOCAL_COLLECTION_PATH"
        exit 1
    fi

    echo "Replacing ethpandaops.general collection with symlink to local version..."
    echo "  Local path: $LOCAL_COLLECTION_PATH"

    # Remove the installed collection
    rm -rf "$COLLECTION_VENDOR_PATH"

    # Create symlink to local collection
    ln -s "$(cd "$LOCAL_COLLECTION_PATH" && pwd)" "$COLLECTION_VENDOR_PATH"

    if [ -L "$COLLECTION_VENDOR_PATH" ]; then
        echo "Successfully symlinked local collection"
        echo "  Symlink: $COLLECTION_VENDOR_PATH -> $(readlink "$COLLECTION_VENDOR_PATH")"
    else
        echo "Error: Failed to create symlink"
        exit 1
    fi
fi

# Install Mitogen for Ansible performance optimization
# Following official installation instructions from https://mitogen.networkgenomics.com/ansible_detailed.html
MITOGEN_VERSION="0.3.27"

MITOGEN_DIR="vendor/mitogen-${MITOGEN_VERSION}"
MITOGEN_URL="https://files.pythonhosted.org/packages/source/m/mitogen/mitogen-${MITOGEN_VERSION}.tar.gz"

echo "Installing Mitogen v${MITOGEN_VERSION} from official PyPI source..."

# Create vendor directory if it doesn't exist
mkdir -p vendor

# Remove old Mitogen installation if it exists
if [ -d "${MITOGEN_DIR}" ]; then
    echo "Removing existing Mitogen installation..."
    rm -rf "${MITOGEN_DIR}"
fi

# Download and extract Mitogen from official PyPI source
if command -v wget >/dev/null 2>&1; then
    wget -q -O - "${MITOGEN_URL}" | tar -xz -C vendor
elif command -v curl >/dev/null 2>&1; then
    curl -sL "${MITOGEN_URL}" | tar -xz -C vendor
else
    echo "Error: Neither wget nor curl is available. Please install one of them."
    exit 1
fi

if [ -d "${MITOGEN_DIR}/ansible_mitogen" ]; then
    echo "Mitogen ${MITOGEN_VERSION} installed successfully in ${MITOGEN_DIR}"
    echo "Ansible configuration has been updated to use this installation."
else
    echo "Error: Mitogen installation failed"
    exit 1
fi