#!/bin/bash
set -e

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
  echo -e "${BLUE}$1${NC}"
}

# Function to convert branch name to directory name (same as in setup_cube_repo.sh)
convert_branch_to_dirname() {
    echo "${1//\//--}"
}

# Source the common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$PROJECT_ROOT/common/utils.sh"

# Parse command line arguments
DEVELOP_BRANCH="develop"  # Default value

while [[ $# -gt 0 ]]; do
    case $1 in
        --develop)
            DEVELOP_BRANCH="$2"
            shift 2
            ;;
        *)
            print_warning "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Convert branch name to directory name
DEVELOP_DIR_NAME=$(convert_branch_to_dirname "$DEVELOP_BRANCH")

# Make sure Rust is installed and in the PATH
install_rust

# Define paths
CUBE_BASE_DIR=~/projects/cube
CUBE_BRANCHES_DIR=$CUBE_BASE_DIR/branches
DEVELOP_BRANCH_DIR=$CUBE_BRANCHES_DIR/${DEVELOP_DIR_NAME}

# Check if the repository structure exists
if [ ! -d "$DEVELOP_BRANCH_DIR" ]; then
    print_status "Error: Cube.js branch directory not found at $DEVELOP_BRANCH_DIR"
    print_status "Please run setup_cube_repo.sh first to set up the repository structure"
    exit 1
fi

print_status "Using existing Cube.js repository at $DEVELOP_BRANCH_DIR"
cd "$DEVELOP_BRANCH_DIR"

# Install/update dependencies
install_cube_dependencies "$DEVELOP_BRANCH_DIR"

# Build frontend packages
build_cube_frontend "$DEVELOP_BRANCH_DIR"

# Start TypeScript compiler in watch mode
start_typescript_watch "$DEVELOP_BRANCH_DIR"

# Build CubeSQL
build_cubesql "$DEVELOP_BRANCH_DIR"

print_success "Cube.js playground setup completed successfully!"
print_success "You can now start developing with Cube.js in the develop branch at:"
print_success "$DEVELOP_BRANCH_DIR" 