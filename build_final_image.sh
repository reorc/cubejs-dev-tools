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

# Check if Docker is installed
check_docker() {
    if ! command_exists docker; then
        print_status "Docker is not installed. Installing Docker..."
        
        # Update package list
        sudo apt-get update
        
        # Install prerequisites
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Set up the stable repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Add current user to docker group to avoid using sudo
        sudo usermod -aG docker $USER
        
        print_status "Docker installed successfully. You may need to log out and back in for group changes to take effect."
        print_status "For now, we'll continue using sudo for docker commands."
    else
        print_status "Docker is already installed"
    fi
}

# Function to build and push the Docker image
build_and_push_image() {
    local base_image="$1"
    local new_image_name="$2"
    local new_image_tag="$3"
    local dockerfile="Dockerfile.doris"
    
    print_status "Creating Dockerfile for Doris driver image"
    
    # Create Dockerfile
    cat > "$dockerfile" << EOF
FROM ${base_image}

# Install the Doris driver and clean up npm cache in the same layer
RUN npm install --save doris-cubejs-driver && \\
    npm cache clean --force && \\
    rm -rf /root/.npm/* /tmp/*

CMD ["cubejs", "server"]
EOF
    
    print_status "Building Docker image: ${new_image_name}:${new_image_tag}"
    sudo docker build -t "${new_image_name}:${new_image_tag}" -f "$dockerfile" .
    
    # Tag the image with latest if it's not already the tag
    if [ "$new_image_tag" != "latest" ]; then
        print_status "Tagging image as ${new_image_name}:latest"
        sudo docker tag "${new_image_name}:${new_image_tag}" "${new_image_name}:latest"
    fi
    
    print_status "Logging in to Docker Hub"
    # Check if DOCKER_USERNAME and DOCKER_PASSWORD environment variables are set
    if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
        print_status "Docker Hub credentials not found in environment variables"
        print_status "Please enter your Docker Hub credentials"
        
        # Prompt for Docker Hub credentials
        read -p "Docker Hub Username: " docker_username
        read -s -p "Docker Hub Password: " docker_password
        echo
        
        # Login to Docker Hub
        echo "$docker_password" | sudo docker login --username "$docker_username" --password-stdin
    else
        # Login using environment variables
        echo "$DOCKER_PASSWORD" | sudo docker login --username "$DOCKER_USERNAME" --password-stdin
    fi
    
    print_status "Pushing image ${new_image_name}:${new_image_tag} to Docker Hub"
    sudo docker push "${new_image_name}:${new_image_tag}"
    
    if [ "$new_image_tag" != "latest" ]; then
        print_status "Pushing image ${new_image_name}:latest to Docker Hub"
        sudo docker push "${new_image_name}:latest"
    fi
    
    print_status "Cleaning up"
    rm -f "$dockerfile"
    
    print_status "Docker image built and pushed successfully!"
}

# Main execution
main() {
    print_status "Starting Docker image build process for Cube.js with Doris driver..."
    
    # Check if Docker is installed
    check_docker
    
    # Default values
    local base_image="reorc/cube:latest"
    local new_image_name="reorc/cubejs-official"
    local new_image_tag="latest"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --base-image)
                base_image="$2"
                shift 2
                ;;
            --image-name)
                new_image_name="$2"
                shift 2
                ;;
            --image-tag)
                new_image_tag="$2"
                shift 2
                ;;
            *)
                print_status "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    print_status "Using base image: $base_image"
    print_status "New image will be: ${new_image_name}:${new_image_tag}"
    
    # Build and push the Docker image
    build_and_push_image "$base_image" "$new_image_name" "$new_image_tag"
}

# Run main function with all arguments passed to the script
main "$@" 