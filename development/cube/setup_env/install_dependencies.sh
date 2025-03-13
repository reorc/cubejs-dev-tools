#!/bin/bash
set -e

# Source the common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$PROJECT_ROOT/common/utils.sh"

# Install common system packages
install_system_packages curl git build-essential gdb lldb lsof

# Install Node.js 20.x
install_nodejs "20.x"

# Install Yarn
install_yarn

# Install Rust
install_rust

# Install Java 17
install_java "17"

# Install VSCode extensions (if VSCode is installed)
if command_exists code; then
    print_status "Checking VSCode extensions..."
    
    # Check and install each extension individually
    for ext in "vadimcn.vscode-lldb" "ms-vscode.js-debug"; do
        if code --list-extensions | grep -q "$ext"; then
            print_warning "VSCode extension $ext is already installed, skipping..."
        else
            print_status "Installing VSCode extension $ext..."
            code --install-extension "$ext"
        fi
    done
fi

print_success "Dependencies installation completed successfully!" 