#!/bin/bash
set -e

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
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

# Define paths
CUBE_DEV_TOOLS_DIR="$HOME/projects/cubejs-dev-tools/branches/main"
CUBE_REPO_DIR="$HOME/projects/cube/branches/develop"
TEST_PROJECT_DIR="$HOME/projects/cubejs-test-project"
SCHEMAS_DIR="$CUBE_DEV_TOOLS_DIR/development/cube/setup_project/schemas"

# PostgreSQL credentials (matching setup_postgres.sh)
POSTGRES_ADMIN_USER="postgres"
POSTGRES_PASSWORD="postgres"
POSTGRES_DB="postgres"
POSTGRES_PORT=5432

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
    cubejs create cubejs-test-project
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

# Check if PostgreSQL is running via Docker
print_status "Checking PostgreSQL status..."
if docker ps | grep -q "postgres"; then
    print_status "PostgreSQL container is already running"
else
    print_warning "PostgreSQL container is not running. Please run setup_postgres.sh first."
    print_warning "You can find it at: testing/db_setup/setup_postgres.sh"
    
    # Ask if user wants to continue anyway
    read -p "Do you want to continue anyway? (y/n): " continue_anyway
    if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
        print_warning "Exiting. Please run setup_postgres.sh first."
        exit 1
    fi
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

# Copy SQL schema files
print_status "Copying SQL schema files..."
cp "$SCHEMAS_DIR/create_tables.sql" "$TEST_PROJECT_DIR/model/schema/"
cp "$SCHEMAS_DIR/insert_products.sql" "$TEST_PROJECT_DIR/model/schema/"
cp "$SCHEMAS_DIR/insert_orders.sql" "$TEST_PROJECT_DIR/model/schema/"
cp "$SCHEMAS_DIR/insert_order_items.sql" "$TEST_PROJECT_DIR/model/schema/"

# Copy setup_database.sh script
print_status "Copying setup_database.sh script..."
cp "$SCHEMAS_DIR/setup_database.sh" "$TEST_PROJECT_DIR/"

# Set up the database
print_status "Setting up the database..."
chmod +x "$TEST_PROJECT_DIR/setup_database.sh"
cd "$TEST_PROJECT_DIR"
./setup_database.sh

print_success "Test project setup completed successfully!"
print_status "Test project is located at: $TEST_PROJECT_DIR"
print_status "You can start the development server by running: cd $TEST_PROJECT_DIR && npm run dev" 