#!/bin/bash

# setup_dorisdb.sh
# Script to set up DorisDB using Docker Compose on Ubuntu 24.04 LTS
# This script is idempotent and can be run multiple times safely

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root or with sudo privileges${NC}"
    exit 1
fi

# Install dependencies if not already installed
print_section "Checking and installing dependencies"

# Update package lists
apt-get update

# Install required packages if not already installed
for pkg in curl apt-transport-https ca-certificates gnupg lsb-release; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        echo "Installing $pkg..."
        apt-get install -y $pkg
    else
        echo "$pkg is already installed"
    fi
done

# Install Docker if not already installed
if ! command_exists docker; then
    print_section "Installing Docker"
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    echo -e "${GREEN}Docker has been installed successfully${NC}"
else
    echo "Docker is already installed"
fi

# Install Docker Compose if not already installed
if ! command_exists docker-compose; then
    print_section "Installing Docker Compose"
    
    # Install Docker Compose
    apt-get install -y docker-compose
    
    echo -e "${GREEN}Docker Compose has been installed successfully${NC}"
else
    echo "Docker Compose is already installed"
fi

# Install MySQL client if not already installed
if ! command_exists mysql; then
    echo "Installing MySQL client..."
    apt-get install -y mysql-client-core-8.0
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

echo -e "${GREEN}Docker Compose file created at $DORISDB_COMPOSE_DIR/docker-compose.yml${NC}"

# Set environment variable for Docker Compose
export DORIS_QUICK_START_VERSION=$DORISDB_VERSION

# Start DorisDB using Docker Compose
print_section "Starting DorisDB"
cd $DORISDB_COMPOSE_DIR
docker-compose down 2>/dev/null || true
docker-compose up -d

echo -e "${GREEN}DorisDB has been started using Docker Compose${NC}"

# Wait for DorisDB to start up
echo "Waiting for DorisDB to start up (this may take a few minutes)..."

# Check if DorisDB containers are running
if docker ps | grep -q "doris.*fe"; then
    echo -e "${GREEN}DorisDB Frontend container is running${NC}"
else
    echo -e "${RED}DorisDB Frontend failed to start${NC}"
    docker-compose logs fe
    exit 1
fi

if docker ps | grep -q "doris.*be"; then
    echo -e "${GREEN}DorisDB Backend container is running${NC}"
else
    echo -e "${RED}DorisDB Backend failed to start${NC}"
    docker-compose logs be
    exit 1
fi

# Wait for MySQL port to be available
MAX_RETRIES=30
RETRY_COUNT=0
PORT_AVAILABLE=false

echo "Waiting for MySQL port $DORISDB_MYSQL_PORT to be available..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$PORT_AVAILABLE" = false ]; do
    if nc -z localhost $DORISDB_MYSQL_PORT 2>/dev/null; then
        echo -e "${GREEN}MySQL port $DORISDB_MYSQL_PORT is now available${NC}"
        PORT_AVAILABLE=true
    else
        echo "Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES: MySQL port not available yet, waiting..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 10
    fi
done

if [ "$PORT_AVAILABLE" = false ]; then
    echo -e "${RED}MySQL port $DORISDB_MYSQL_PORT is not available after $MAX_RETRIES attempts.${NC}"
    echo -e "${RED}DorisDB may not be fully initialized. Check the logs for more information:${NC}"
    echo -e "${YELLOW}docker-compose -f $DORISDB_COMPOSE_DIR/docker-compose.yml logs${NC}"
    exit 1
fi

# Try to set the root password
print_section "Setting up root password"
MAX_RETRIES=5
RETRY_COUNT=0
PASSWORD_SET=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$PASSWORD_SET" = false ]; do
    echo "Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES: Setting root password..."
    if mysql -h127.0.0.1 -P$DORISDB_MYSQL_PORT -u$DORISDB_ADMIN_USER -e "ALTER USER '$DORISDB_ADMIN_USER' IDENTIFIED BY '$DORISDB_NEW_PASSWORD'" 2>/dev/null; then
        echo -e "${GREEN}Root password has been set successfully${NC}"
        PASSWORD_SET=true
    else
        echo "Failed to set password, waiting and retrying..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 5
    fi
done

if [ "$PASSWORD_SET" = false ]; then
    echo -e "${YELLOW}Warning: Could not set root password after $MAX_RETRIES attempts.${NC}"
    echo -e "${YELLOW}You may need to set it manually once DorisDB is fully initialized:${NC}"
    echo -e "${YELLOW}mysql -h127.0.0.1 -P$DORISDB_MYSQL_PORT -u$DORISDB_ADMIN_USER -e \"ALTER USER '$DORISDB_ADMIN_USER' IDENTIFIED BY '$DORISDB_NEW_PASSWORD'\"${NC}"
fi

# Print connection information
print_section "DorisDB Connection Information"
echo -e "${GREEN}DorisDB has been successfully set up!${NC}"
echo -e "Frontend Port: ${GREEN}$DORISDB_FE_PORT${NC}"
echo -e "HTTP Port: ${GREEN}$DORISDB_HTTP_PORT${NC}"
echo -e "MySQL Port: ${GREEN}$DORISDB_MYSQL_PORT${NC}"
echo -e "Admin Username: ${GREEN}$DORISDB_ADMIN_USER${NC}"
echo -e "Admin Password: ${GREEN}$DORISDB_NEW_PASSWORD${NC} (if password setting was successful)"
echo
echo -e "To connect to DorisDB using MySQL client:"
echo -e "${YELLOW}mysql -h127.0.0.1 -P$DORISDB_MYSQL_PORT -u$DORISDB_ADMIN_USER -p$DORISDB_NEW_PASSWORD${NC}"
echo
echo -e "To access the DorisDB web UI (note: the web UI may not be available in this version):"
echo -e "${YELLOW}http://localhost:$DORISDB_HTTP_PORT${NC}"
echo
echo -e "To check the DorisDB container status:"
echo -e "${YELLOW}docker ps | grep doris${NC}"
echo
echo -e "To view DorisDB logs:"
echo -e "${YELLOW}docker-compose -f $DORISDB_COMPOSE_DIR/docker-compose.yml logs${NC}"
echo
echo -e "To stop DorisDB:"
echo -e "${YELLOW}docker-compose -f $DORISDB_COMPOSE_DIR/docker-compose.yml down${NC}"
echo
echo -e "${GREEN}Important Note:${NC} When creating tables, you must set the replication factor to 1 since there is only one backend node."
echo -e "Example:"
echo -e "${YELLOW}CREATE TABLE example_table (id INT, name VARCHAR(50)) ENGINE=OLAP DISTRIBUTED BY HASH(id) PROPERTIES('replication_num' = '1');${NC}" 