#!/bin/bash

# setup_mysql.sh
# Script to set up MySQL using Docker Compose on Ubuntu 24.04 LTS
# This script is idempotent and can be run multiple times safely

# Source common utilities
source "$(dirname "$0")/../../common/utils.sh"

set -e

# Configuration
MYSQL_VERSION="8.0"
# Use user-specific directories instead of system directories
MYSQL_DATA_DIR="$HOME/.local/mysql/data"
MYSQL_COMPOSE_DIR="$HOME/.local/mysql/compose"
MYSQL_ADMIN_USER="root"
MYSQL_PASSWORD="mysql"  # Password for the root user
MYSQL_DATABASE="mysql"  # Default database name
MYSQL_PORT=3306

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

# Install MySQL client if not already installed
if ! command_exists mysql; then
    print_status "Installing MySQL client..."
    install_system_packages mysql-client
fi

# Clean up any existing data to ensure a fresh start
print_section "Cleaning up existing data"
if [ -d "$MYSQL_COMPOSE_DIR" ]; then
    cd $MYSQL_COMPOSE_DIR 2>/dev/null && docker-compose down -v 2>/dev/null || true
fi
rm -rf $MYSQL_DATA_DIR

# Create directories if they don't exist
print_section "Setting up directories"
mkdir -p $MYSQL_DATA_DIR
mkdir -p $MYSQL_COMPOSE_DIR
chmod -R 755 $MYSQL_DATA_DIR
chmod -R 755 $MYSQL_COMPOSE_DIR

# Create Docker Compose file
print_section "Creating Docker Compose file"
cat > $MYSQL_COMPOSE_DIR/docker-compose.yml << EOF
version: "3"
services:
  mysql:
    image: mysql:${MYSQL_VERSION}
    container_name: mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
    volumes:
      - ${MYSQL_DATA_DIR}:/var/lib/mysql
    ports:
      - "${MYSQL_PORT}:3306"
    restart: always
    command: --default-authentication-plugin=mysql_native_password
EOF

print_success "Docker Compose file created at $MYSQL_COMPOSE_DIR/docker-compose.yml"

# Start MySQL using Docker Compose
print_section "Starting MySQL"
cd $MYSQL_COMPOSE_DIR
docker-compose down 2>/dev/null || true
docker-compose up -d

print_success "MySQL has been started using Docker Compose"

# Wait for MySQL to start up
print_status "Waiting for MySQL to start up (this may take a few moments)..."

# Check if MySQL container is running
if docker ps | grep -q "mysql"; then
    print_success "MySQL container is running"
else
    print_error "MySQL failed to start"
    docker-compose logs
    exit 1
fi

# Wait for MySQL port to be available
MAX_RETRIES=15
RETRY_COUNT=0
PORT_AVAILABLE=false

print_status "Waiting for MySQL port $MYSQL_PORT to be available..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$PORT_AVAILABLE" = false ]; do
    if nc -z localhost $MYSQL_PORT 2>/dev/null; then
        print_success "MySQL port $MYSQL_PORT is now available"
        PORT_AVAILABLE=true
    else
        print_status "Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES: MySQL port not available yet, waiting..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 5
    fi
done

if [ "$PORT_AVAILABLE" = false ]; then
    print_error "MySQL port $MYSQL_PORT is not available after $MAX_RETRIES attempts."
    print_error "MySQL may not be fully initialized. Check the logs for more information:"
    print_warning "docker-compose -f $MYSQL_COMPOSE_DIR/docker-compose.yml logs"
    exit 1
fi

# Wait for MySQL to be ready to accept connections
MAX_RETRIES=10
RETRY_COUNT=0
DB_READY=false

print_status "Checking if MySQL is ready to accept connections..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DB_READY" = false ]; do
    if docker exec mysql mysqladmin -u$MYSQL_ADMIN_USER -p$MYSQL_PASSWORD ping 2>/dev/null; then
        print_success "MySQL is ready to accept connections"
        DB_READY=true
    else
        print_status "Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES: MySQL not ready yet, waiting..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 5
    fi
done

if [ "$DB_READY" = false ]; then
    print_error "MySQL is not ready to accept connections after $MAX_RETRIES attempts."
    print_error "Check the logs for more information:"
    print_warning "docker-compose -f $MYSQL_COMPOSE_DIR/docker-compose.yml logs"
    exit 1
fi

# Add a small delay to ensure MySQL is fully initialized
print_status "Waiting for MySQL to fully initialize..."
sleep 5

# Create a test database to verify everything is working
print_section "Creating a test database"
if docker exec mysql mysql -u$MYSQL_ADMIN_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS test_db;" 2>/dev/null; then
    print_success "Test database 'test_db' created successfully"
else
    print_warning "Warning: Could not create test database. MySQL might not be fully initialized yet."
    print_status "You can try creating it manually with:"
    print_warning "docker exec mysql mysql -u$MYSQL_ADMIN_USER -p$MYSQL_PASSWORD -e \"CREATE DATABASE test_db;\""
fi

# Print connection information
print_section "MySQL Connection Information"
print_success "MySQL has been successfully set up!"
print_status "MySQL Port: $MYSQL_PORT"
print_status "Admin Username: $MYSQL_ADMIN_USER"
print_status "Admin Password: $MYSQL_PASSWORD"
print_status "Default Database: $MYSQL_DATABASE"
print_status ""
print_status "To connect to MySQL using the mysql client:"
print_warning "mysql -h127.0.0.1 -P$MYSQL_PORT -u$MYSQL_ADMIN_USER -p$MYSQL_PASSWORD"
print_status ""
print_status "To check the MySQL container status:"
print_warning "docker ps | grep mysql"
print_status ""
print_status "To view MySQL logs:"
print_warning "docker-compose -f $MYSQL_COMPOSE_DIR/docker-compose.yml logs"
print_status ""
print_status "To stop MySQL:"
print_warning "docker-compose -f $MYSQL_COMPOSE_DIR/docker-compose.yml down"
print_status ""
print_status "Important Note: You can create additional databases and users as needed."
print_status "Example to create a new database and user:"
print_warning "docker exec mysql mysql -u$MYSQL_ADMIN_USER -p$MYSQL_PASSWORD -e \"CREATE DATABASE mydb;\""
print_warning "docker exec mysql mysql -u$MYSQL_ADMIN_USER -p$MYSQL_PASSWORD -e \"CREATE USER 'myuser'@'%' IDENTIFIED BY 'mypassword';\""
print_warning "docker exec mysql mysql -u$MYSQL_ADMIN_USER -p$MYSQL_PASSWORD -e \"GRANT ALL PRIVILEGES ON mydb.* TO 'myuser'@'%';\""
print_warning "docker exec mysql mysql -u$MYSQL_ADMIN_USER -p$MYSQL_PASSWORD -e \"FLUSH PRIVILEGES;\"" 