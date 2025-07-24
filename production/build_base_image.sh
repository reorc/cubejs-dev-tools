#!/bin/bash

# Source common utilities
source "$(dirname "$0")/../common/utils.sh"

# Get absolute path of the script directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Set up base directories
BASE_DIR=~/projects/cube
BRANCHES_DIR=$BASE_DIR/branches
RELEASE_BRANCH="release"
MASTER_BRANCH="master" # official 
REORC_BRANCH="reorc" # our changes here

# Default Docker image settings
DEFAULT_IMAGE_NAME="reorc/cube"
DEFAULT_IMAGE_TAG="latest"
IMAGE_NAME=$DEFAULT_IMAGE_NAME
IMAGE_TAG=$DEFAULT_IMAGE_TAG
REMOTE_IMAGE_NAME="recurvedata/recurve-cube-base"
# REMOTE_IMAGE_TAG=$(date +"%Y%m%d-%H%M%S")
REMOTE_IMAGE_TAG="v1.3.42_reorc_$(date +"%Y%m%d_%H%M%S")"
BUILD_IMAGE=true
PUSH_IMAGE=true
PUSH_SEMVER=false  # Whether to push with semantic version tag

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
        --remote-image-name)
            REMOTE_IMAGE_NAME="$2"
            shift 2
            ;;
        --remote-image-tag)
            REMOTE_IMAGE_TAG="$2"
            shift 2
            ;;
        --build-only)
            BUILD_IMAGE=true
            PUSH_IMAGE=false
            PUSH_SEMVER=false
            shift
            ;;
        --push-only)
            BUILD_IMAGE=false
            PUSH_IMAGE=true
            shift
            ;;
        --no-semver)
            PUSH_SEMVER=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --image-name NAME         Set custom Docker image name for local build (default: $DEFAULT_IMAGE_NAME)"
            echo "  --image-tag TAG           Set custom Docker image tag for local build (default: $DEFAULT_IMAGE_TAG)"
            echo "  --remote-image-name NAME  Set different image name for pushing to Docker Hub"
            echo "  --remote-image-tag TAG    Set different image tag for pushing to Docker Hub"
            echo "  --build-only              Only build the Docker image, don't push"
            echo "  --push-only               Only push the Docker image, don't build"
            echo "  --no-semver               Don't push with semantic version tag"
            echo "  --help                    Show this help message"
            echo
            echo "If neither --build-only nor --push-only is specified, both build and push will be performed."
            echo "If remote image name/tag are not specified, local image name/tag will be used for pushing."
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_status "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set remote image details to local ones if not specified
if [ -z "$REMOTE_IMAGE_NAME" ]; then
    REMOTE_IMAGE_NAME=$IMAGE_NAME
fi
if [ -z "$REMOTE_IMAGE_TAG" ]; then
    REMOTE_IMAGE_TAG=$IMAGE_TAG
fi

# Function to get the latest semantic version from Docker Hub and increment it
get_next_semver() {
    local image_name=$1
    local current_version="0.0.0"
    
    print_status "Fetching latest semantic version for $image_name..." >&2
    
    # Get all tags from Docker Hub
    local tags_json=$(curl -s "https://hub.docker.com/v2/repositories/${image_name}/tags/?page_size=100")
    
    # Parse tags that match semantic versioning pattern (x.y.z)
    local semver_tags=$(echo "$tags_json" | grep -o '"name":"[0-9]\+\.[0-9]\+\.[0-9]\+"' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | sort -t. -k1,1n -k2,2n -k3,3n)
    
    # If we found any semantic version tags, get the latest one
    if [ -n "$semver_tags" ]; then
        current_version=$(echo "$semver_tags" | tail -n 1)
        print_status "Current latest version: $current_version" >&2
    else
        print_status "No existing semantic versions found, starting with 0.0.1" >&2
        current_version="0.0.0"
    fi
    
    # Split the version into components
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Increment the patch version
    patch=$((patch + 1))
    
    # Return the new version
    echo "$major.$minor.$patch"
}

# Handle push-only operation early to skip build process
if [ "$BUILD_IMAGE" = false ] && [ "$PUSH_IMAGE" = true ]; then
    print_status "Push-only operation requested. Skipping build process..."
    
    # Check if user is logged into Docker Hub
    print_status "Checking Docker Hub authentication..."
    if ! docker info 2>/dev/null | grep -q "Username"; then
        print_warning "Not logged into Docker Hub. Please login first."
        docker login
    fi

    # Check if the image exists locally
    if ! docker image inspect "$IMAGE_NAME:$IMAGE_TAG" >/dev/null 2>&1; then
        print_error "Image $IMAGE_NAME:$IMAGE_TAG not found locally. Please build the image first or ensure the image name and tag are correct."
        exit 1
    fi

    # If using different remote name/tag, create a new tag
    if [ "$IMAGE_NAME:$IMAGE_TAG" != "$REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG" ]; then
        print_status "Creating remote tag $REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG..."
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG"
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REMOTE_IMAGE_NAME:latest"
    fi

    # Push the image to Docker Hub with latest tag
    print_status "Pushing image to Docker Hub as $REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG..."
    docker push "$REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG"
    docker push "$REMOTE_IMAGE_NAME:latest"
    
    # Push with semantic version tag if enabled
    if [ "$PUSH_SEMVER" = true ]; then
        # Get next semantic version
        SEMVER_TAG=$(get_next_semver "${REMOTE_IMAGE_NAME}")
        
        print_status "Creating semantic version tag $REMOTE_IMAGE_NAME:$SEMVER_TAG..."
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REMOTE_IMAGE_NAME:$SEMVER_TAG"
        
        print_status "Pushing image to Docker Hub as $REMOTE_IMAGE_NAME:$SEMVER_TAG..."
        docker push "$REMOTE_IMAGE_NAME:$SEMVER_TAG"
        print_success "Pushed semantic version: $SEMVER_TAG"
    fi
    
    print_success "Push complete! The image is available at $REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG"
    exit 0
fi

# Function to setup all dependencies using common utilities
setup_dependencies() {
    print_status "Setting up dependencies..."
    
    # Install system packages
    install_system_packages build-essential python3 make gcc g++ default-jdk
    
    # Install Node.js
    install_nodejs 20.x
    
    # Install Yarn
    install_yarn
    
    # Install Docker
    install_docker
}



# Change to master branch directory
cd "$BRANCHES_DIR/$MASTER_BRANCH" || {
    print_error "Error: Master branch directory not found!"
    exit 1
}
git pull

# Remove existing release branch and worktree if they exist
print_status "Checking for existing release branch and worktree..."
if [ -d "$BRANCHES_DIR/$RELEASE_BRANCH" ]; then
    print_status "Removing existing release worktree..."
    git worktree remove -f "$BRANCHES_DIR/$RELEASE_BRANCH" || true
fi

# Check if the branch exists regardless of worktree status
if git branch --list "$RELEASE_BRANCH" | grep -q "$RELEASE_BRANCH"; then
    print_status "Removing existing release branch..."
    git branch -D "$RELEASE_BRANCH"
fi

# Create new release branch from master
print_status "Creating new release branch: $RELEASE_BRANCH"
git worktree add "$BRANCHES_DIR/$RELEASE_BRANCH" -b "$RELEASE_BRANCH"

# Change to release branch directory
cd "$BRANCHES_DIR/$RELEASE_BRANCH" || {
    print_error "Error: Failed to change to release branch directory!"
    exit 1
}

# Show changes from reorc branch before merging
print_status "========================================================"
print_status "Showing changes from $REORC_BRANCH branch compared to $MASTER_BRANCH..."
print_status "========================================================"
git fetch origin $MASTER_BRANCH
git fetch origin $REORC_BRANCH

# Capture changed packages into a variable
print_status "Analyzing changed packages..."
CHANGED_PACKAGES=$(git diff --name-only origin/$MASTER_BRANCH...origin/$REORC_BRANCH | grep "^packages/" | cut -d'/' -f2 | sort -u)
print_status "Changed packages:"
echo "$CHANGED_PACKAGES"

print_status "Files changed in $REORC_BRANCH branch:"
git diff --name-status origin/$MASTER_BRANCH...origin/$REORC_BRANCH

print_status "Detailed changes (showing diff):"
git diff --color=always origin/$MASTER_BRANCH...origin/$REORC_BRANCH | less -R

# Prompt for confirmation before merging
read -p "Do you want to proceed with merging the $REORC_BRANCH branch? (y/n): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    print_warning "Merge aborted by user."
    exit 0
fi

# Merge code from reorc branch
print_status "Merging code from $REORC_BRANCH branch..."
if ! git merge origin/$REORC_BRANCH --no-commit; then
    print_warning "Merge conflicts detected!"
    print_status "Please resolve the conflicts manually, then continue with the build process."
    print_status "You can use 'git status' to see the conflicting files."
    print_status "After resolving conflicts, commit the changes with 'git commit -m \"Resolve merge conflicts\"'"
    read -p "Have you resolved all conflicts? (y/n): " conflicts_resolved
    if [[ $conflicts_resolved != [yY] && $conflicts_resolved != [yY][eE][sS] ]]; then
        print_warning "Build process aborted. Please resolve conflicts before running this script again."
        exit 1
    fi
    # Complete the merge with the resolved conflicts
    git commit -m "Merge origin/$REORC_BRANCH with conflicts resolved"
else
    # No conflicts, commit the merge
    git commit -m "Merge origin/$REORC_BRANCH into release branch"
fi

print_success "Release branch setup complete!"
print_status "Release branch is at: $BRANCHES_DIR/$RELEASE_BRANCH"

# Setup dependencies (Node.js, Yarn, Docker)
setup_dependencies

# Build steps in the root directory
print_status "Installing dependencies and building packages in root directory..."
cd "$BRANCHES_DIR/$RELEASE_BRANCH" || {
    print_error "Error: Failed to change to release branch root directory!"
    exit 1
}

print_status "Running yarn install..."
yarn install

print_status "Running yarn build..."
yarn build

print_status "Running yarn lerna run build..."
yarn lerna run build

# Ensure cubejs-docker/packages directory exists
print_status "Setting up cubejs-docker packages directory..."
mkdir -p "$BRANCHES_DIR/$RELEASE_BRANCH/packages/cubejs-docker/packages"

# Copy updated packages
print_status "Copying updated packages to cubejs-docker/packages..."
for package in $CHANGED_PACKAGES; do
    if [ -d "$BRANCHES_DIR/$RELEASE_BRANCH/packages/$package" ]; then
        print_status "Copying package: $package"
        cp -r "$BRANCHES_DIR/$RELEASE_BRANCH/packages/$package" "$BRANCHES_DIR/$RELEASE_BRANCH/packages/cubejs-docker/packages/"
    fi
done
# Although cubejs-backend-native does not change
# It contains compiled rust code that is changed by ReOrc
cp -r "$BRANCHES_DIR/$RELEASE_BRANCH/packages/cubejs-backend-native" "$BRANCHES_DIR/$RELEASE_BRANCH/packages/cubejs-docker/packages/"


# Install dependencies in packages/cubejs-docker
print_status "Installing dependencies in cubejs-docker..."
cd "$BRANCHES_DIR/$RELEASE_BRANCH/packages/cubejs-docker" || {
    print_error "Error: Failed to change to cubejs-docker directory!"
    exit 1
}
yarn install

# Copy yarn.lock to docker build directory
print_status "Copying yarn.lock for Docker build..."
cp "$BRANCHES_DIR/$RELEASE_BRANCH/yarn.lock" .

# Copy updated.Dockerfile from production directory
print_status "Copying updated.Dockerfile for Docker build..."
cp "$SCRIPT_DIR/updated.Dockerfile" .

# Docker build and push section
if [ "$BUILD_IMAGE" = true ]; then
    # Build the image using sudo to ensure permissions
    print_status "Building Cube.js Docker image as $IMAGE_NAME:$IMAGE_TAG..."
    docker build -t "$IMAGE_NAME:$IMAGE_TAG" -f updated.Dockerfile . --no-cache
    print_success "Build complete! The image is tagged as $IMAGE_NAME:$IMAGE_TAG"
fi

if [ "$PUSH_IMAGE" = true ]; then
    # Check if user is logged into Docker Hub
    print_status "Checking Docker Hub authentication..."
    if ! docker info 2>/dev/null | grep -q "Username"; then
        print_warning "Not logged into Docker Hub. Please login first."
        docker login
    fi

    # If using different remote name/tag, create a new tag
    if [ "$IMAGE_NAME:$IMAGE_TAG" != "$REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG" ]; then
        print_status "Creating remote tag $REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG..."
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG"
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REMOTE_IMAGE_NAME:latest"
    fi

    # Push the image to Docker Hub with latest tag
    print_status "Pushing image to Docker Hub as $REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG..."
    docker push "$REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG"
    docker push "$REMOTE_IMAGE_NAME:latest"
    # Push with semantic version tag if enabled
    if [ "$PUSH_SEMVER" = true ]; then
        # Get next semantic version
        SEMVER_TAG=$(get_next_semver "${REMOTE_IMAGE_NAME}")
        
        print_status "Creating semantic version tag $REMOTE_IMAGE_NAME:$SEMVER_TAG..."
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REMOTE_IMAGE_NAME:$SEMVER_TAG"
        
        print_status "Pushing image to Docker Hub as $REMOTE_IMAGE_NAME:$SEMVER_TAG..."
        docker push "$REMOTE_IMAGE_NAME:$SEMVER_TAG"
        print_success "Pushed semantic version: $SEMVER_TAG"
    fi
    
    print_success "Push complete! The image is available at $REMOTE_IMAGE_NAME:$REMOTE_IMAGE_TAG"
fi

if [ "$BUILD_IMAGE" = true ] && [ "$PUSH_IMAGE" = true ]; then
    print_success "Build and push operations completed successfully!"
fi 