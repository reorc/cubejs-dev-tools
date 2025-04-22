#!/bin/bash

# Source common utilities
source "$(dirname "$0")/../common/utils.sh"

# Exit on any error
set -e

# Function to build and push the Docker image
build_and_push_image() {
    local base_image="$1"
    local new_image_name="$2"
    local new_image_tag="$3"
    local remote_image_name="${4:-$new_image_name}"  # Use local image name if remote not specified
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
    sudo docker build -t "${new_image_name}:${new_image_tag}" -f "$dockerfile" . --no-cache
    
    # Tag the image with latest if it's not already the tag
    if [ "$new_image_tag" != "latest" ]; then
        print_status "Tagging image as ${new_image_name}:latest"
        sudo docker tag "${new_image_name}:${new_image_tag}" "${new_image_name}:latest"
    fi
    
    print_status "Logging in to Docker Hub"
    # Check if DOCKER_USERNAME and DOCKER_PASSWORD environment variables are set
    if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
        print_warning "Docker Hub credentials not found in environment variables"
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
    
    # Tag for remote push if remote_image_name is different
    if [ "$remote_image_name" != "$new_image_name" ]; then
        print_status "Tagging for remote: ${remote_image_name}:${new_image_tag}"
        sudo docker tag "${new_image_name}:${new_image_tag}" "${remote_image_name}:${new_image_tag}"
        if [ "$new_image_tag" != "latest" ]; then
            sudo docker tag "${new_image_name}:latest" "${remote_image_name}:latest"
        fi
    fi
    
    print_status "Pushing image ${remote_image_name}:${new_image_tag} to Docker Hub"
    sudo docker push "${remote_image_name}:${new_image_tag}"
    
    if [ "$new_image_tag" != "latest" ]; then
        print_status "Pushing image ${remote_image_name}:latest to Docker Hub"
        sudo docker push "${remote_image_name}:latest"
    fi
    
    print_status "Cleaning up"
    rm -f "$dockerfile"
    
    print_success "Docker image built and pushed successfully!"
}

# Main execution
main() {
    print_status "Starting Docker image build process for Cube.js with Doris driver..."
    
    # Check if Docker is installed
    install_docker
    
    # Default values
    local base_image="recurvedata/recurve-cube-base:latest"
    local new_image_name="reorc/cube-official"
    local new_image_tag="latest"
    local remote_image_name="docker.tool.recurvedata.com/recurve-cube"
    
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
            --remote-image)
                remote_image_name="$2"
                shift 2
                ;;
            --help)
                print_status "Usage: $0 [options]"
                print_status "Options:"
                print_status "  --base-image IMAGE    Set base Docker image (default: $base_image)"
                print_status "  --image-name NAME     Set local Docker image name (default: $new_image_name)"
                print_status "  --image-tag TAG       Set Docker image tag (default: $new_image_tag)"
                print_status "  --remote-image NAME   Set remote Docker Hub image name (optional)"
                print_status "  --help                Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_status "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    print_status "Using base image: $base_image"
    print_status "Local image will be: ${new_image_name}:${new_image_tag}"
    if [ -n "$remote_image_name" ]; then
        print_status "Remote image will be: ${remote_image_name}:${new_image_tag}"
    fi
    
    # Build and push the Docker image
    build_and_push_image "$base_image" "$new_image_name" "$new_image_tag" "$remote_image_name"
}

# Run main function with all arguments passed to the script
main "$@" 