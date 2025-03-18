#!/bin/bash
set -e

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
  echo -e "${BLUE}$1${NC}"
}

print_success() {
  echo -e "${GREEN}$1${NC}"
}

print_warning() {
  echo -e "${YELLOW}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# Function to convert branch name to directory name (same as in setup_cube_repo.sh)
convert_branch_to_dirname() {
    echo "${1//\//--}"
}

# Parse command line arguments
DEVELOP_BRANCH="develop"  # Default value
TEST_PROJECT_NAME="cubejs-test-project"  # Default project name

while [[ $# -gt 0 ]]; do
    case $1 in
        --develop)
            DEVELOP_BRANCH="$2"
            shift 2
            ;;
        --project-name)
            TEST_PROJECT_NAME="$2"
            shift 2
            ;;
        *)
            print_warning "Unknown option: $1"
            print_warning "Usage: $0 [--develop <branch>] [--project-name <name>]"
            exit 1
            ;;
    esac
done

# Convert branch name to directory name
DEVELOP_DIR_NAME=$(convert_branch_to_dirname "$DEVELOP_BRANCH")

# Define paths
CUBE_DEV_TOOLS_DIR="$HOME/projects/cubejs-dev-tools/branches/main"
CUBE_REPO_DIR="$HOME/projects/cube/branches/${DEVELOP_DIR_NAME}"
TEST_PROJECT_DIR="$HOME/projects/${TEST_PROJECT_NAME}"
POSTGRES_SCHEMAS_DIR="$CUBE_DEV_TOOLS_DIR/testing/db_setup/postgres_schemas"

# PostgreSQL credentials (matching testing/db_setup/setup_postgres.sh)
POSTGRES_ADMIN_USER="postgres"
POSTGRES_PASSWORD="postgres"
POSTGRES_DB="postgres"
POSTGRES_PORT=5432

# Check and setup PostgreSQL if needed
print_status "Checking PostgreSQL setup..."
POSTGRES_SETUP_SCRIPT="$CUBE_DEV_TOOLS_DIR/testing/db_setup/setup_postgres.sh"

check_postgres() {
    if ! docker ps | grep -q "postgres"; then
        return 1
    fi
    
    # Try to connect to verify the instance is working
    if ! docker exec postgres pg_isready -U $POSTGRES_ADMIN_USER &>/dev/null; then
        return 1
    fi
    
    return 0
}

if ! check_postgres; then
    print_status "Valid PostgreSQL instance not found. Setting up PostgreSQL..."
    if [ -f "$POSTGRES_SETUP_SCRIPT" ]; then
        chmod +x "$POSTGRES_SETUP_SCRIPT"
        "$POSTGRES_SETUP_SCRIPT"
        
        # Wait a bit for PostgreSQL to be fully ready
        print_status "Waiting for PostgreSQL to be fully ready..."
        sleep 10
        
        if ! check_postgres; then
            print_error "Failed to set up PostgreSQL. Please check the logs and try again."
            exit 1
        fi
        print_success "PostgreSQL setup completed successfully!"
    else
        print_error "PostgreSQL setup script not found at: $POSTGRES_SETUP_SCRIPT"
        exit 1
    fi
else
    print_success "Valid PostgreSQL instance found and running."
fi

# Check if Cube.js CLI is installed
if ! command -v cubejs &> /dev/null; then
    print_status "Installing Cube.js CLI..."
    sudo npm install -g cubejs-cli
else
    print_status "Cube.js CLI is already installed."
fi

# Create test project if it doesn't exist
print_status "Setting up test project..."
if [ ! -d "$TEST_PROJECT_DIR" ]; then
    print_status "Creating a new test project..."
    mkdir -p "$HOME/projects"
    cd "$HOME/projects"
    cubejs create "$TEST_PROJECT_NAME"
else
    print_status "Test project already exists at $TEST_PROJECT_DIR"
fi

# Navigate to test project
cd "$TEST_PROJECT_DIR"

# Link server-core package from the develop branch
print_status "Linking server-core package from develop branch..."
if [ -d "$CUBE_REPO_DIR" ]; then
    cd "$CUBE_REPO_DIR/packages/cubejs-server-core"
    yarn link
    cd "$TEST_PROJECT_DIR"
    yarn link @cubejs-backend/server-core
    print_success "Successfully linked @cubejs-backend/server-core from develop branch"
else
    print_warning "Cube.js repository not found at $CUBE_REPO_DIR. Skipping package linking."
fi

# Install node-fetch if not already installed
if ! grep -q "node-fetch" "$TEST_PROJECT_DIR/package.json"; then
    print_status "Installing node-fetch for sample queries..."
    npm install node-fetch
else
    print_status "node-fetch is already installed."
fi

# Create .env file with database configuration
print_status "Creating .env file with database configuration..."
cat > "$TEST_PROJECT_DIR/.env" << EOL
# Cube environment variables: https://cube.dev/docs/reference/environment-variables
CUBEJS_DEV_MODE=true
CUBEJS_DB_TYPE=postgres
CUBEJS_API_SECRET=34fb4f35211d33723ab9ee5763af62e9f148edd2dda181e5e7904286db405f9aae589698900b9c35eeec7333d5c25ce1cb7dd05282b77c35457030a0c1e5d272
CUBEJS_EXTERNAL_DEFAULT=true
CUBEJS_SCHEDULED_REFRESH_DEFAULT=true
CUBEJS_SCHEMA_PATH=model
CUBEJS_WEB_SOCKETS=true

# PostgreSQL connection details (matching setup_postgres.sh)
CUBEJS_DB_HOST=localhost
CUBEJS_DB_PORT=$POSTGRES_PORT
CUBEJS_DB_NAME=$POSTGRES_DB
CUBEJS_DB_USER=$POSTGRES_ADMIN_USER
CUBEJS_DB_PASS=$POSTGRES_PASSWORD
EOL

# Create schema directory if it doesn't exist
print_status "Creating schema directory..."
mkdir -p "$TEST_PROJECT_DIR/model/schema"

# Copy SQL schema files from testing/db_setup/postgres_schemas
print_status "Copying SQL schema files..."
cp "$POSTGRES_SCHEMAS_DIR/create_tables.sql" "$TEST_PROJECT_DIR/model/schema/"
cp "$POSTGRES_SCHEMAS_DIR/insert_products.sql" "$TEST_PROJECT_DIR/model/schema/"
cp "$POSTGRES_SCHEMAS_DIR/insert_orders.sql" "$TEST_PROJECT_DIR/model/schema/"
cp "$POSTGRES_SCHEMAS_DIR/insert_order_items.sql" "$TEST_PROJECT_DIR/model/schema/"

# Copy setup_database.sh script
print_status "Copying setup_database.sh script..."
cp "$POSTGRES_SCHEMAS_DIR/setup_database.sh" "$TEST_PROJECT_DIR/model/schema/"

# Set up the database
print_status "Setting up the database..."
chmod +x "$TEST_PROJECT_DIR/model/schema/setup_database.sh"
cd "$TEST_PROJECT_DIR/model/schema"
./setup_database.sh

print_success "Test project setup completed successfully!"
print_status "Test project is located at: $TEST_PROJECT_DIR"
print_status "You can start the development server by running: cd $TEST_PROJECT_DIR && npm run dev" 