#!/bin/bash

# setup_doris.sh
# Script to set up DorisDB using Docker Compose on Ubuntu 24.04 LTS
# This script is idempotent and can be run multiple times safely

# Source common utilities
source "$(dirname "$0")/../../common/utils.sh"

set -e

# Configuration
DORISDB_VERSION="3.0.4"
DORISDB_DATA_DIR="/opt/dorisdb/data"
DORISDB_LOG_DIR="/opt/dorisdb/log"
DORISDB_COMPOSE_DIR="/opt/dorisdb/compose"
DORISDB_ADMIN_USER="root"
DORISDB_ADMIN_PASSWORD=""  # Empty password for initial login
DORISDB_NEW_PASSWORD="root"  # Password to set after login
DORISDB_FE_PORT=8030
DORISDB_HTTP_PORT=8040
DORISDB_MYSQL_PORT=9030

# Function to print section headers
print_section() {
    print_status "=== $1 ==="
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root or with sudo privileges"
    exit 1
fi

# Install dependencies if not already installed
print_section "Checking and installing dependencies"

# Install required packages using the utility function
install_system_packages curl apt-transport-https ca-certificates gnupg lsb-release

# Install Docker if not already installed
if ! command_exists docker; then
    print_section "Installing Docker"
    install_docker
else
    print_warning "Docker is already installed"
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
    install_system_packages mysql-client-core-8.0
fi

# Clean up any existing data to ensure a fresh start
print_section "Cleaning up existing data"
cd $DORISDB_COMPOSE_DIR 2>/dev/null && docker-compose down -v 2>/dev/null || true
rm -rf $DORISDB_DATA_DIR
rm -rf $DORISDB_LOG_DIR

# Create directories if they don't exist
print_section "Setting up directories"
mkdir -p $DORISDB_DATA_DIR/fe
mkdir -p $DORISDB_DATA_DIR/be
mkdir -p $DORISDB_LOG_DIR/fe
mkdir -p $DORISDB_LOG_DIR/be
mkdir -p $DORISDB_COMPOSE_DIR
chmod -R 777 $DORISDB_DATA_DIR
chmod -R 777 $DORISDB_LOG_DIR
chmod -R 777 $DORISDB_COMPOSE_DIR

# Create Docker Compose file
print_section "Creating Docker Compose file"
cat > $DORISDB_COMPOSE_DIR/docker-compose.yml << EOF
version: "3"
services:
  fe:
    image: apache/doris:fe-${DORISDB_VERSION}
    hostname: fe
    environment:
      - FE_SERVERS=fe1:127.0.0.1:9010
      - FE_ID=1
    volumes:
      - ${DORISDB_DATA_DIR}/fe:/opt/apache-doris/fe/doris-meta
      - ${DORISDB_LOG_DIR}/fe:/opt/apache-doris/fe/log
    network_mode: host
    restart: always
  be:
    image: apache/doris:be-${DORISDB_VERSION}
    hostname: be
    environment:
      - FE_SERVERS=fe1:127.0.0.1:9010
      - BE_ADDR=127.0.0.1:9050
    volumes:
      - ${DORISDB_DATA_DIR}/be:/opt/apache-doris/be/storage
      - ${DORISDB_LOG_DIR}/be:/opt/apache-doris/be/log
    depends_on:
      - fe
    network_mode: host
    restart: always
EOF

print_success "Docker Compose file created at $DORISDB_COMPOSE_DIR/docker-compose.yml"

# Set environment variable for Docker Compose
export DORIS_QUICK_START_VERSION=$DORISDB_VERSION

# Start DorisDB using Docker Compose
print_section "Starting DorisDB"
cd $DORISDB_COMPOSE_DIR
docker-compose down 2>/dev/null || true
docker-compose up -d

print_success "DorisDB has been started using Docker Compose"

# Wait for DorisDB to start up
print_status "Waiting for DorisDB to start up (this may take a few minutes)..."

# Check if DorisDB containers are running
if docker ps | grep -q "doris.*fe"; then
    print_success "DorisDB Frontend container is running"
else
    print_error "DorisDB Frontend failed to start"
    docker-compose logs fe
    exit 1
fi

if docker ps | grep -q "doris.*be"; then
    print_success "DorisDB Backend container is running"
else
    print_error "DorisDB Backend failed to start"
    docker-compose logs be
    exit 1
fi

# Wait for MySQL port to be available
MAX_RETRIES=30
RETRY_COUNT=0
PORT_AVAILABLE=false

print_status "Waiting for MySQL port $DORISDB_MYSQL_PORT to be available..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$PORT_AVAILABLE" = false ]; do
    if nc -z localhost $DORISDB_MYSQL_PORT 2>/dev/null; then
        print_success "MySQL port $DORISDB_MYSQL_PORT is now available"
        PORT_AVAILABLE=true
    else
        print_status "Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES: MySQL port not available yet, waiting..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 10
    fi
done

if [ "$PORT_AVAILABLE" = false ]; then
    print_error "MySQL port $DORISDB_MYSQL_PORT is not available after $MAX_RETRIES attempts."
    print_error "DorisDB may not be fully initialized. Check the logs for more information:"
    print_warning "docker-compose -f $DORISDB_COMPOSE_DIR/docker-compose.yml logs"
    exit 1
fi

# Try to set the root password
print_section "Setting up root password"
MAX_RETRIES=5
RETRY_COUNT=0
PASSWORD_SET=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$PASSWORD_SET" = false ]; do
    print_status "Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES: Setting root password..."
    if mysql -h127.0.0.1 -P$DORISDB_MYSQL_PORT -u$DORISDB_ADMIN_USER -e "ALTER USER '$DORISDB_ADMIN_USER' IDENTIFIED BY '$DORISDB_NEW_PASSWORD'" 2>/dev/null; then
        print_success "Root password has been set successfully"
        PASSWORD_SET=true
    else
        print_warning "Failed to set password, waiting and retrying..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 5
    fi
done

if [ "$PASSWORD_SET" = false ]; then
    print_warning "Warning: Could not set root password after $MAX_RETRIES attempts."
    print_warning "You may need to set it manually once DorisDB is fully initialized:"
    print_warning "mysql -h127.0.0.1 -P$DORISDB_MYSQL_PORT -u$DORISDB_ADMIN_USER -e \"ALTER USER '$DORISDB_ADMIN_USER' IDENTIFIED BY '$DORISDB_NEW_PASSWORD'\""
fi

# Print connection information
print_section "DorisDB Connection Information"
print_success "DorisDB has been successfully set up!"
print_status "Frontend Port: ${DORISDB_FE_PORT}"
print_status "HTTP Port: ${DORISDB_HTTP_PORT}"
print_status "MySQL Port: ${DORISDB_MYSQL_PORT}"
print_status "Admin Username: ${DORISDB_ADMIN_USER}"
print_status "Admin Password: ${DORISDB_NEW_PASSWORD} (if password setting was successful)"
print_status ""
print_status "To connect to DorisDB using MySQL client:"
print_warning "mysql -h127.0.0.1 -P$DORISDB_MYSQL_PORT -u$DORISDB_ADMIN_USER -p$DORISDB_NEW_PASSWORD"
print_status ""
print_status "To access the DorisDB web UI (note: the web UI may not be available in this version):"
print_warning "http://localhost:$DORISDB_HTTP_PORT"
print_status ""
print_status "To check the DorisDB container status:"
print_warning "docker ps | grep doris"
print_status ""
print_status "To view DorisDB logs:"
print_warning "docker-compose -f $DORISDB_COMPOSE_DIR/docker-compose.yml logs"
print_status ""
print_status "To stop DorisDB:"
print_warning "docker-compose -f $DORISDB_COMPOSE_DIR/docker-compose.yml down"
print_status ""
print_status "Important Note: When creating tables, you must set the replication factor to 1 since there is only one backend node."
print_status "Example:"
print_warning "CREATE TABLE example_table (id INT, name VARCHAR(50)) ENGINE=OLAP DISTRIBUTED BY HASH(id) PROPERTIES('replication_num' = '1');" 