#!/bin/bash

# setup_postgres.sh
# Script to set up PostgreSQL using Docker Compose on Ubuntu 24.04 LTS
# This script is idempotent and can be run multiple times safely

# Source common utilities
source "$(dirname "$0")/../../common/utils.sh"

set -e

# Configuration
POSTGRES_VERSION="16.1"
# Use user-specific directories instead of system directories
POSTGRES_DATA_DIR="$HOME/.local/postgres/data"
POSTGRES_COMPOSE_DIR="$HOME/.local/postgres/compose"
POSTGRES_ADMIN_USER="postgres"
POSTGRES_PASSWORD="postgres"  # Password for the postgres user
POSTGRES_DB="postgres"  # Default database name
POSTGRES_PORT=5432

# Function to print section headers
print_section() {
    print_status "=== $1 ==="
}

# Check if user is in docker group
check_docker_permissions() {
    if ! groups | grep -q docker; then
        print_warning "Your user is not in the docker group. Some commands may require sudo."
        print_warning "To add your user to the docker group (recommended), run:"
        print_warning "sudo usermod -aG docker $USER"
        print_warning "Then log out and log back in for the changes to take effect."
        return 1
    fi
    return 0
}

# Install dependencies if not already installed
print_section "Checking and installing dependencies"

# Install required packages using the utility function
# Note: install_system_packages in utils.sh already uses sudo internally
install_system_packages curl apt-transport-https ca-certificates gnupg lsb-release

# Install Docker if not already installed
if ! command_exists docker; then
    print_section "Installing Docker"
    # Note: install_docker in utils.sh already uses sudo internally
    install_docker
else
    print_warning "Docker is already installed"
    # Check if user has docker permissions
    check_docker_permissions
fi

# Install Docker Compose if not already installed
if ! command_exists docker-compose; then
    print_section "Installing Docker Compose"
    install_system_packages docker-compose
    print_success "Docker Compose has been installed successfully"
else
    print_warning "Docker Compose is already installed"
fi

# Install PostgreSQL client if not already installed
if ! command_exists psql; then
    print_status "Installing PostgreSQL client..."
    install_system_packages postgresql-client
fi

# Clean up any existing data to ensure a fresh start
print_section "Cleaning up existing data"
if [ -d "$POSTGRES_COMPOSE_DIR" ]; then
    cd $POSTGRES_COMPOSE_DIR 2>/dev/null && docker-compose down -v 2>/dev/null || true
fi
rm -rf $POSTGRES_DATA_DIR

# Create directories if they don't exist
print_section "Setting up directories"
mkdir -p $POSTGRES_DATA_DIR
mkdir -p $POSTGRES_COMPOSE_DIR
chmod -R 755 $POSTGRES_DATA_DIR
chmod -R 755 $POSTGRES_COMPOSE_DIR

# Create Docker Compose file
print_section "Creating Docker Compose file"
cat > $POSTGRES_COMPOSE_DIR/docker-compose.yml << EOF
version: "3"
services:
  postgres:
    image: postgres:${POSTGRES_VERSION}
    container_name: postgres
    environment:
      - POSTGRES_USER=${POSTGRES_ADMIN_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - ${POSTGRES_DATA_DIR}:/var/lib/postgresql/data
    ports:
      - "${POSTGRES_PORT}:5432"
    restart: always
EOF

print_success "Docker Compose file created at $POSTGRES_COMPOSE_DIR/docker-compose.yml"

# Start PostgreSQL using Docker Compose
print_section "Starting PostgreSQL"
cd $POSTGRES_COMPOSE_DIR
docker-compose down 2>/dev/null || true
docker-compose up -d

print_success "PostgreSQL has been started using Docker Compose"

# Wait for PostgreSQL to start up
print_status "Waiting for PostgreSQL to start up (this may take a few moments)..."

# Check if PostgreSQL container is running
if docker ps | grep -q "postgres"; then
    print_success "PostgreSQL container is running"
else
    print_error "PostgreSQL failed to start"
    docker-compose logs
    exit 1
fi

# Wait for PostgreSQL port to be available
MAX_RETRIES=15
RETRY_COUNT=0
PORT_AVAILABLE=false

print_status "Waiting for PostgreSQL port $POSTGRES_PORT to be available..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$PORT_AVAILABLE" = false ]; do
    if nc -z localhost $POSTGRES_PORT 2>/dev/null; then
        print_success "PostgreSQL port $POSTGRES_PORT is now available"
        PORT_AVAILABLE=true
    else
        print_status "Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES: PostgreSQL port not available yet, waiting..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 5
    fi
done

if [ "$PORT_AVAILABLE" = false ]; then
    print_error "PostgreSQL port $POSTGRES_PORT is not available after $MAX_RETRIES attempts."
    print_error "PostgreSQL may not be fully initialized. Check the logs for more information:"
    print_warning "docker-compose -f $POSTGRES_COMPOSE_DIR/docker-compose.yml logs"
    exit 1
fi

# Wait for PostgreSQL to be ready to accept connections
MAX_RETRIES=10
RETRY_COUNT=0
DB_READY=false

print_status "Checking if PostgreSQL is ready to accept connections..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DB_READY" = false ]; do
    if docker exec postgres pg_isready -U $POSTGRES_ADMIN_USER 2>/dev/null; then
        print_success "PostgreSQL is ready to accept connections"
        DB_READY=true
    else
        print_status "Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES: PostgreSQL not ready yet, waiting..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 5
    fi
done

if [ "$DB_READY" = false ]; then
    print_error "PostgreSQL is not ready to accept connections after $MAX_RETRIES attempts."
    print_error "Check the logs for more information:"
    print_warning "docker-compose -f $POSTGRES_COMPOSE_DIR/docker-compose.yml logs"
    exit 1
fi

# Create a test database to verify everything is working
print_section "Creating a test database"
if docker exec postgres psql -U $POSTGRES_ADMIN_USER -c "CREATE DATABASE test_db;" 2>/dev/null; then
    print_success "Test database 'test_db' created successfully"
else
    print_warning "Warning: Could not create test database. PostgreSQL might not be fully initialized yet."
fi

# Print connection information
print_section "PostgreSQL Connection Information"
print_success "PostgreSQL has been successfully set up!"
print_status "PostgreSQL Port: $POSTGRES_PORT"
print_status "Admin Username: $POSTGRES_ADMIN_USER"
print_status "Admin Password: $POSTGRES_PASSWORD"
print_status "Default Database: $POSTGRES_DB"
print_status ""
print_status "To connect to PostgreSQL using psql client:"
print_warning "psql -h localhost -p $POSTGRES_PORT -U $POSTGRES_ADMIN_USER -d $POSTGRES_DB"
print_status ""
print_status "To check the PostgreSQL container status:"
print_warning "docker ps | grep postgres"
print_status ""
print_status "To view PostgreSQL logs:"
print_warning "docker-compose -f $POSTGRES_COMPOSE_DIR/docker-compose.yml logs"
print_status ""
print_status "To stop PostgreSQL:"
print_warning "docker-compose -f $POSTGRES_COMPOSE_DIR/docker-compose.yml down"
print_status ""
print_status "Important Note: You can create additional databases and users as needed."
print_status "Example to create a new database and user:"
print_warning "docker exec postgres psql -U $POSTGRES_ADMIN_USER -c \"CREATE DATABASE mydb;\""
print_warning "docker exec postgres psql -U $POSTGRES_ADMIN_USER -c \"CREATE USER myuser WITH ENCRYPTED PASSWORD 'mypassword';\""
print_warning "docker exec postgres psql -U $POSTGRES_ADMIN_USER -c \"GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;\"" 