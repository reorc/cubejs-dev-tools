#!/bin/bash

# Colors for better readability
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[0;33m'
export RED='\033[0;31m'
export NC='\033[0m' # No Color

# Function to print status messages
print_status() {
  echo -e "${BLUE}$1${NC}"
}

print_warning() {
  echo -e "${YELLOW}$1${NC}"
}

print_success() {
  echo -e "${GREEN}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check if a package is installed (for Debian-based systems)
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii" &> /dev/null
}

# Function to install system packages
install_system_packages() {
    print_status "Checking and installing system dependencies..."
    sudo apt-get update

    # Check and install each package individually
    for pkg in "$@"; do
        if package_installed "$pkg"; then
            print_warning "$pkg is already installed, skipping..."
        else
            print_status "Installing $pkg..."
            sudo apt-get install -y "$pkg"
        fi
    done
}

# Function to install Node.js
install_nodejs() {
    local version="${1:-20.x}"
    
    # Check if Node.js with specified version is installed
    if command_exists node && [[ $(node -v) == v${version%.*}* ]]; then
        print_warning "Node.js ${version%.*}.x is already installed, skipping..."
    else
        print_status "Installing Node.js ${version}..."
        curl -fsSL "https://deb.nodesource.com/setup_${version}" | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
}

# Function to install Yarn
install_yarn() {
    # Check if Yarn is installed
    if command_exists yarn; then
        print_warning "Yarn is already installed, skipping..."
    else
        print_status "Installing Yarn..."
        sudo npm install -g yarn
    fi
}

# Function to install Rust
install_rust() {
    # Check if Rust is installed
    if command_exists rustc; then
        print_warning "Rust is already installed, skipping..."
    else
        print_status "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi
    
    # Make sure Rust is in the PATH
    source "$HOME/.cargo/env"
}

# Function to install Docker
install_docker() {
    # Check if Docker is installed
    if command_exists docker; then
        print_warning "Docker is already installed, skipping..."
    else
        print_status "Installing Docker..."
        
        # Install required packages
        sudo apt-get update
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Set up the Docker repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Start and enable Docker service
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add current user to docker group
        sudo usermod -aG docker $USER
        print_warning "You may need to log out and log back in for Docker group changes to take effect"
    fi
    
    # Install Docker Compose if not already installed
    if ! command_exists docker-compose; then
        print_status "Installing Docker Compose..."
        sudo apt-get install -y docker-compose
        print_success "Docker Compose has been installed successfully"
    else
        print_warning "Docker Compose is already installed"
    fi
    
    # Verify Docker is running
    if ! sudo docker info >/dev/null 2>&1; then
        print_warning "Docker service is not running. Attempting to start..."
        sudo systemctl start docker
        
        # Wait for Docker to be ready
        print_status "Waiting for Docker to be ready..."
        timeout 30 sh -c 'until sudo docker info >/dev/null 2>&1; do echo "Waiting for Docker to be available..."; sleep 2; done' || {
            print_error "Docker failed to start within the timeout period"
            return 1
        }
    fi
    
    print_success "Docker is installed and running"
    return 0
}

# Function to build CubeSQL
build_cubesql() {
    local repo_dir="$1"
    local cubesql_bin="$repo_dir/rust/cubesql/target/debug/cubesql"
    
    if [ ! -f "$cubesql_bin" ] || [ -n "$(find $repo_dir/rust/cubesql/src -name "*.rs" -newer "$cubesql_bin" 2>/dev/null)" ]; then
        print_status "Building CubeSQL..."
        cd "$repo_dir/rust/cubesql"
        cargo build
        cd "$repo_dir"
        return 0
    else
        print_status "CubeSQL is already built"
        return 1
    fi
}

# Function to install/update Cube.js dependencies
install_cube_dependencies() {
    local repo_dir="$1"
    
    cd "$repo_dir"
    
    # Check if dependencies are already installed
    if [ -d "node_modules" ]; then
        print_status "Dependencies appear to be installed. Checking if update is needed..."
        
        # Check if yarn.lock has changed since last install
        if [ -f ".yarn_install_timestamp" ] && [ yarn.lock -ot ".yarn_install_timestamp" ]; then
            print_status "Dependencies are up to date"
            return 1
        else
            print_status "Installing/updating Cube.js dependencies..."
            yarn install
            touch .yarn_install_timestamp
            return 0
        fi
    else
        print_status "Installing Cube.js dependencies..."
        yarn install
        touch .yarn_install_timestamp
        return 0
    fi
}

# Function to build Cube.js frontend packages
build_cube_frontend() {
    local repo_dir="$1"
    
    cd "$repo_dir"
    
    # Check if frontend packages are already built
    if [ ! -f "packages/cubejs-playground/build/index.html" ] || [ -n "$(find packages -name "*.tsx" -newer "packages/cubejs-playground/build/index.html" 2>/dev/null)" ]; then
        print_status "Building frontend packages..."
        yarn build
        
        print_status "Building playground..."
        cd packages/cubejs-playground
        yarn build
        cd ../..
        return 0
    else
        print_status "Frontend packages and playground already built"
        return 1
    fi
}

# Function to start TypeScript compiler in watch mode
start_typescript_watch() {
    local repo_dir="$1"
    
    cd "$repo_dir"
    
    # Start TypeScript compiler in watch mode if not already running
    if ! pgrep -f "yarn tsc:watch" > /dev/null; then
        print_status "Starting TypeScript compiler in watch mode..."
        yarn tsc:watch > typescript-watch.log 2>&1 &
        local typescript_pid=$!
        print_warning "TypeScript compiler started with PID: $typescript_pid"
        return 0
    else
        print_status "TypeScript compiler is already running"
        return 1
    fi
} 