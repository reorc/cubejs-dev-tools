#!/bin/bash

# Set up base directories
BASE_DIR=~/projects/cube
BRANCHES_DIR=$BASE_DIR/branches
RELEASE_BRANCH="release"

# Default Docker image settings
DEFAULT_IMAGE_NAME="reorc/cube"
DEFAULT_IMAGE_TAG="latest"
IMAGE_NAME=$DEFAULT_IMAGE_NAME
IMAGE_TAG=$DEFAULT_IMAGE_TAG

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --image-name NAME    Set custom Docker image name (default: $DEFAULT_IMAGE_NAME)"
            echo "  --image-tag TAG      Set custom Docker image tag (default: $DEFAULT_IMAGE_TAG)"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check and install dependencies
setup_dependencies() {
    echo "Checking and installing dependencies..."
    
    # Update package lists
    sudo apt-get update
    
    # Install build essentials and required tools
    echo "Installing build tools and compilers..."
    sudo apt-get install -y build-essential python3 make gcc g++ default-jdk

    # Install Node.js and npm if not present
    if ! command -v node &> /dev/null; then
        echo "Installing Node.js and npm..."
        # First remove any existing installations
        sudo apt-get remove -y nodejs npm
        sudo apt-get autoremove -y
        
        # Install Node.js from NodeSource
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        
        # Verify installation
        node --version
        npm --version
    fi
    
    # Install yarn if not present
    if ! command -v yarn &> /dev/null; then
        echo "Installing yarn..."
        # Install yarn from their official repository
        curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
        echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
        sudo apt-get update
        sudo apt-get install -y yarn
        
        # Verify installation
        yarn --version
    fi
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

    # Ensure Docker permissions are set correctly
    echo "Setting up Docker permissions..."
    sudo usermod -aG docker $USER
    # Start Docker service if not running
    sudo systemctl start docker || true
    # Wait for Docker to be ready
    echo "Waiting for Docker to be ready..."
    timeout 30 sh -c 'until sudo docker info >/dev/null 2>&1; do echo "Waiting for Docker to be available..."; sleep 2; done'
}

# Change to master branch directory
cd "$BRANCHES_DIR/master" || {
    echo "Error: Master branch directory not found!"
    exit 1
}

# Remove existing release branch and worktree if they exist
if [ -d "$BRANCHES_DIR/$RELEASE_BRANCH" ]; then
    echo "Removing existing release branch and worktree..."
    git worktree remove -f "$BRANCHES_DIR/$RELEASE_BRANCH"
    git branch -D "$RELEASE_BRANCH" || true
fi

# Create new release branch from master
echo "Creating new release branch: $RELEASE_BRANCH"
git worktree add "$BRANCHES_DIR/$RELEASE_BRANCH" -b "$RELEASE_BRANCH"

# Change to release branch directory
cd "$BRANCHES_DIR/$RELEASE_BRANCH" || {
    echo "Error: Failed to change to release branch directory!"
    exit 1
}

# Show changes from reorc branch before merging
echo "========================================================"
echo "Showing changes from reorc branch compared to master..."
echo "========================================================"
git fetch origin reorc
echo "Files changed in reorc branch:"
git diff --name-status origin/master origin/reorc

echo "Detailed changes (showing diff):"
git diff --color=always origin/master origin/reorc | less -R

# Prompt for confirmation before merging
read -p "Do you want to proceed with merging the reorc branch? (y/n): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo "Merge aborted by user."
    exit 0
fi

# Merge code from reorc branch
echo "Merging code from reorc branch..."
git merge origin/reorc

echo "Release branch setup complete!"
echo "Release branch is at: $BRANCHES_DIR/$RELEASE_BRANCH"

# Setup dependencies (Node.js, Yarn, Docker)
setup_dependencies

# Install dependencies in packages/cubejs-docker
echo "Installing dependencies in cubejs-docker..."
cd "$BRANCHES_DIR/$RELEASE_BRANCH/packages/cubejs-docker" || {
    echo "Error: Failed to change to cubejs-docker directory!"
    exit 1
}
yarn install

# Copy yarn.lock to docker build directory
echo "Copying yarn.lock for Docker build..."
cp "$BRANCHES_DIR/$RELEASE_BRANCH/yarn.lock" .

# Build the image using sudo to ensure permissions
echo "Building Cube.js Docker image as $IMAGE_NAME:$IMAGE_TAG..."
sudo docker build -t "$IMAGE_NAME:$IMAGE_TAG" -f latest.Dockerfile .

echo "Build complete! The image is tagged as $IMAGE_NAME:$IMAGE_TAG" 