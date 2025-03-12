#!/bin/bash

# Exit on any error
set -e

# Function to print status messages
print_status() {
    echo "===> $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install system dependencies
install_system_dependencies() {
    print_status "Updating system package list..."
    sudo apt-get update

    print_status "Installing system dependencies..."
    sudo apt-get install -y \
        curl \
        git \
        build-essential \
        python3
}

# Function to install Node.js and npm
install_node() {
    if ! command_exists node; then
        print_status "Installing Node.js and npm..."
        # Install Node.js 18.x (LTS)
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs

        # Verify installation
        node --version
        npm --version
    else
        print_status "Node.js is already installed"
        node --version
    fi
}

# Function to install Yarn
install_yarn() {
    if ! command_exists yarn; then
        print_status "Installing Yarn package manager..."
        # Install Yarn using npm
        npm install -g yarn
        
        # Verify installation
        yarn --version
    else
        print_status "Yarn is already installed"
        yarn --version
    fi
}

# Function to check if version exists on npm
version_exists_on_npm() {
    local package_name="$1"
    local version="$2"
    
    # Use npm view to check if the version exists
    if npm view "${package_name}@${version}" version &>/dev/null; then
        return 0 # Version exists
    else
        return 1 # Version doesn't exist
    fi
}

# Function to get package version from package.json
get_package_version() {
    local package_dir="$1"
    if [ ! -f "$package_dir/package.json" ]; then
        echo "Error: package.json not found in $package_dir"
        exit 1
    fi
    
    # Extract version from package.json using node
    node -p "require('$package_dir/package.json').version"
}

# Function to get package name from package.json
get_package_name() {
    local package_dir="$1"
    if [ ! -f "$package_dir/package.json" ]; then
        echo "Error: package.json not found in $package_dir"
        exit 1
    fi
    
    # Extract name from package.json using node
    node -p "require('$package_dir/package.json').name"
}

# Function to check if package has tests
has_tests() {
    local package_dir="$1"
    
    # Check if there's a test script in package.json
    local test_script=$(node -p "require('$package_dir/package.json').scripts && require('$package_dir/package.json').scripts.test || ''")
    
    # Check if there's a test directory
    if [ -n "$test_script" ] && [ "$test_script" != "echo \"Error: no test specified\" && exit 1" ]; then
        return 0 # Has tests
    elif [ -d "$package_dir/test" ] || [ -d "$package_dir/tests" ]; then
        return 0 # Has tests
    else
        return 1 # No tests
    fi
}

# Function to increment version number
increment_version() {
    local version="$1"
    local position="${2:-patch}"  # Default to incrementing patch version
    
    # Split version into components
    IFS='.' read -r -a version_parts <<< "$version"
    local major="${version_parts[0]}"
    local minor="${version_parts[1]}"
    local patch="${version_parts[2]}"
    
    case "$position" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch|*)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Function to update version in package.json
update_package_version() {
    local package_dir="$1"
    local new_version="$2"
    
    print_status "Updating package.json version to $new_version"
    
    # Use node to update the version in package.json
    node -e "
        const fs = require('fs');
        const path = require('path');
        const packagePath = path.join('$package_dir', 'package.json');
        const package = require(packagePath);
        package.version = '$new_version';
        fs.writeFileSync(packagePath, JSON.stringify(package, null, 2) + '\n');
    "
    
    # Verify the update
    local updated_version=$(get_package_version "$package_dir")
    if [ "$updated_version" != "$new_version" ]; then
        print_status "Error: Failed to update version in package.json"
        exit 1
    fi
    
    print_status "Successfully updated version to $new_version"
}

# Function to clean up after build and publish
cleanup() {
    local package_dir="$1"
    
    print_status "Performing cleanup..."
    
    # Restore package.json using git
    print_status "Restoring package.json using git"
    git -C "$package_dir" checkout -- package.json
    
    # Remove node_modules directory if desired
    # Uncomment the following line if you want to remove node_modules
    # print_status "Removing node_modules directory"
    # rm -rf "$package_dir/node_modules"
    
    print_status "Cleanup completed"
}

# Function to build and publish the package
build_and_publish() {
    local package_dir="$1"
    local was_updated=false
    
    print_status "Navigating to package directory: $package_dir"
    cd "$package_dir"

    # Get package details
    local package_name=$(get_package_name "$package_dir")
    local package_version=$(get_package_version "$package_dir")
    
    print_status "Package: $package_name"
    print_status "Current version: $package_version"
    
    # Check if version already exists
    if version_exists_on_npm "$package_name" "$package_version"; then
        print_status "Version $package_version already exists on npm. Incrementing version..."
        local new_version=$(increment_version "$package_version")
        print_status "New version will be: $new_version"
        
        # Update package.json with new version
        update_package_version "$package_dir" "$new_version"
        
        # Update package_version variable with new version
        package_version="$new_version"
        was_updated=true
    fi

    print_status "Installing dependencies with Yarn..."
    yarn install

    print_status "Running build..."
    yarn build

    # Run tests only if they exist
    if has_tests "$package_dir"; then
        print_status "Running tests..."
        if ! yarn test --passWithNoTests; then
            print_status "Tests failed. Please fix the issues before publishing."
            
            # Clean up before exiting
            if [ "$was_updated" = true ]; then
                cleanup "$package_dir"
            fi
            
            exit 1
        fi
    else
        print_status "No tests found. Skipping test step."
    fi

    print_status "Publishing package version $package_version..."
    print_status "Note: You may be prompted to login if not already authenticated"
    yarn publish --new-version "$package_version" --access public
    
    # Clean up after successful publish
    cleanup "$package_dir"
}

# Function to handle cleanup on script exit
handle_exit() {
    local exit_code=$?
    local package_dir="$HOME/projects/cubejs-doris-driver/branches/main"
    
    if [ $exit_code -ne 0 ]; then
        print_status "Script exited with error code $exit_code"
        # Attempt cleanup if package_dir exists
        if [ -d "$package_dir" ]; then
            cleanup "$package_dir"
        fi
    fi
    
    exit $exit_code
}

# Set up trap to handle script exit
trap handle_exit EXIT INT TERM

# Main execution
main() {
    print_status "Starting build and publish process for doris-cubejs-driver..."

    # Install basic system dependencies
    install_system_dependencies

    # Install Node.js and npm
    install_node
    
    # Install Yarn
    install_yarn

    # Assuming we're in the repository root directory
    local package_dir="$HOME/projects/cubejs-doris-driver/branches/main"

    # Check if directory exists
    if [ ! -d "$package_dir" ]; then
        print_status "Error: Package directory not found at $package_dir"
        print_status "Please run setup_cube_repo.sh first to clone the repository"
        exit 1
    fi

    # Build and publish
    build_and_publish "$package_dir"

    print_status "Build and publish process completed successfully!"
}

# Run main function
main 