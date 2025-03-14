#!/bin/bash

# Source common utilities
source "$(dirname "$0")/../../common/utils.sh"

# Exit on any error
set -e

# Default configuration
DB_TYPE="postgres"
CUBEJS_IMAGE="reorc/cubejs-official:latest"
PROJECT_NAME="cubejs-test-project"
PROJECT_DIR="$HOME/projects/$PROJECT_NAME"
SCHEMAS_DIR="$(dirname "$0")/../../development/cube/setup_project/schemas"
MODELS_DIR="$PROJECT_DIR/model"

# Database credentials (matching setup scripts)
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_NAME="postgres"
DB_PORT=5432
DB_HOST="localhost"

# Default ports
REST_API_PORT=4000
SQL_API_PORT=15432

# Operation mode
OPERATION_MODE="setup"  # Default operation is setup, alternative is cleanup

# Function to print section headers
print_section() {
    print_status "=== $1 ==="
}

# Function to find an available port
find_available_port() {
    local base_port=$1
    local port=$base_port
    
    while netstat -tuln | grep -q ":$port "; do
        port=$((port + 1))
    done
    
    echo $port
}

# Function to create Cube.js data model files
create_cube_models() {
    print_section "Creating Cube.js data models"
    
    # Create the models directory if it doesn't exist
    mkdir -p "$MODELS_DIR"
    
    # Create Products cube
    cat > "$MODELS_DIR/Products.yml" << EOF
cubes:
  - name: Products
    sql_table: products
    
    dimensions:
      - name: id
        sql: id
        type: number
        primary_key: true
      
      - name: name
        sql: name
        type: string
      
      - name: category
        sql: category
        type: string
      
      - name: added_date
        sql: added_date
        type: time
    
    measures:
      - name: count
        type: count
      
      - name: avg_price
        sql: base_price
        type: avg
EOF
    
    # Create Orders cube
    cat > "$MODELS_DIR/Orders.yml" << EOF
cubes:
  - name: Orders
    sql_table: orders
    
    dimensions:
      - name: id
        sql: id
        type: number
        primary_key: true
      
      - name: status
        sql: status
        type: string
      
      - name: created_at
        sql: created_at
        type: time
    
    measures:
      - name: count
        type: count
      
      - name: total_amount
        sql: amount
        type: sum
EOF
    
    # Create OrderItems cube
    cat > "$MODELS_DIR/OrderItems.yml" << EOF
cubes:
  - name: OrderItems
    sql_table: order_items
    
    dimensions:
      - name: id
        sql: id
        type: number
        primary_key: true
      
      - name: order_id
        sql: order_id
        type: number
      
      - name: product_id
        sql: product_id
        type: number
      
      - name: quantity
        sql: quantity
        type: number
    
    measures:
      - name: count
        type: count
      
      - name: total_quantity
        sql: quantity
        type: sum
      
      - name: total_price
        sql: price * quantity
        type: sum
    
    joins:
      - name: Orders
        relationship: many_to_one
        sql_on: "{OrderItems.order_id} = {Orders.id}"
      
      - name: Products
        relationship: one_to_one
        sql_on: "{OrderItems.product_id} = {Products.id}"
EOF
    
    print_success "Cube.js data models created successfully"
}

# Function to setup the database
setup_database() {
    local db_type="$1"
    local force_reinstall="${2:-false}"  # New parameter with default value false
    
    print_section "Setting up $db_type database"
    
    # Check if the database setup script exists
    local db_setup_script="$HOME/projects/cubejs-dev-tools/branches/main/testing/db_setup/setup_${db_type}.sh"
    
    if [ ! -f "$db_setup_script" ]; then
        print_error "Database setup script not found: $db_setup_script"
        exit 1
    fi

    # Function to check if database is running and accessible
    check_database_connection() {
        local db_type="$1"
        local host="$2"
        local port="$3"
        local user="$4"
        local password="$5"
        local dbname="$6"

        case "$db_type" in
            postgres)
                PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$dbname" -c "SELECT 1" &>/dev/null
                return $?
                ;;
            mysql)
                mysql -h "$host" -P "$port" -u "$user" -p"$password" -e "SELECT 1" &>/dev/null
                return $?
                ;;
            doris)
                mysql -h "$host" -P "$port" -u "$user" -p"$password" -e "SELECT 1" &>/dev/null
                return $?
                ;;
            *)
                return 1
                ;;
        esac
    }

    # Set default connection parameters based on database type
    case "$db_type" in
        postgres)
            DB_USER="postgres"
            DB_PASSWORD="postgres"
            DB_NAME="test"
            DB_PORT=5432
            ;;
        mysql)
            DB_USER="root"
            DB_PASSWORD="password"
            DB_NAME="test"
            DB_PORT=3306
            ;;
        doris)
            DB_USER="root"
            DB_PASSWORD="root"
            DB_NAME="test"
            DB_PORT=9030
            ;;
        *)
            print_error "Unsupported database type: $db_type"
            exit 1
            ;;
    esac

    # Check if database exists and is working
    if [ "$force_reinstall" != "true" ]; then
        print_status "Checking if $db_type database is already running and accessible..."
        if check_database_connection "$db_type" "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"; then
            print_success "$db_type database is already running and accessible"
            return 0
        else
            print_status "$db_type database is not accessible, proceeding with setup"
        fi
    else
        print_status "Force reinstall option enabled - will delete existing database if present"
    fi
    
    # Run the database setup script with force_reinstall parameter
    print_status "Running database setup script: $db_setup_script"
    if [ "$force_reinstall" = "true" ]; then
        bash "$db_setup_script" --force
    else
        bash "$db_setup_script"
    fi
    
    # After database is set up, populate it with data
    populate_database "$db_type"
}

# Function to populate the database with sample data
populate_database() {
    local db_type="$1"
    local schemas_dir="$HOME/projects/cubejs-dev-tools/branches/main/testing/db_setup/${db_type}_schemas"
    
    print_section "Populating $db_type database with sample data"
    
    # Check if schemas directory exists
    if [ ! -d "$schemas_dir" ]; then
        print_error "Schemas directory not found: $schemas_dir"
        exit 1
    fi
    
    # Create a temporary .env file with database connection details
    cat > "$schemas_dir/.env" << EOF
CUBEJS_DB_HOST=$DB_HOST
CUBEJS_DB_PORT=$DB_PORT
CUBEJS_DB_NAME=$DB_NAME
CUBEJS_DB_USER=$DB_USER
CUBEJS_DB_PASS=$DB_PASSWORD
EOF
    
    # Run the setup_database.sh script
    print_status "Running database population script"
    (cd "$schemas_dir" && bash setup_database.sh)
    
    # Clean up the temporary .env file
    rm -f "$schemas_dir/.env"
    
    print_success "Database populated successfully"
}

# Function to create .env file
create_env_file() {
    local db_type="$1"
    
    print_section "Creating .env file with database configuration"
    
    cat > "$PROJECT_DIR/.env" << EOL
# Cube environment variables: https://cube.dev/docs/reference/environment-variables
CUBEJS_DEV_MODE=true
CUBEJS_DB_TYPE=${db_type}
CUBEJS_API_SECRET=34fb4f35211d33723ab9ee5763af62e9f148edd2dda181e5e7904286db405f9aae589698900b9c35eeec7333d5c25ce1cb7dd05282b77c35457030a0c1e5d272
CUBEJS_EXTERNAL_DEFAULT=true
CUBEJS_SCHEDULED_REFRESH_DEFAULT=true
CUBEJS_SCHEMA_PATH=model
CUBEJS_WEB_SOCKETS=true

# SQL API configuration
CUBEJS_SQL_PORT=5432
CUBEJS_SQL_USER=cubesql
CUBEJS_SQL_PASSWORD=cubesql

# Database connection details
CUBEJS_DB_HOST=${DB_HOST}
CUBEJS_DB_PORT=${DB_PORT}
CUBEJS_DB_NAME=${DB_NAME}
CUBEJS_DB_USER=${DB_USER}
CUBEJS_DB_PASS=${DB_PASSWORD}
EOL
    
    print_success ".env file created with $db_type configuration"
}

# Function to launch Cube.js using Docker
launch_cubejs() {
    print_section "Launching Cube.js using Docker"
    
    # Create docker-compose.yml file
    cat > "$PROJECT_DIR/docker-compose.yml" << EOL
version: '3'
services:
  cubejs-${PROJECT_NAME}:
    image: ${CUBEJS_IMAGE}
    container_name: cubejs-${PROJECT_NAME}
    ports:
      - "${REST_API_PORT}:4000"
      - "${SQL_API_PORT}:15432"
    volumes:
      - .:/cube/conf
    environment:
      - CUBEJS_DEV_MODE=true
      - CUBEJS_DB_TYPE=${DB_TYPE}
      - CUBEJS_API_SECRET=34fb4f35211d33723ab9ee5763af62e9f148edd2dda181e5e7904286db405f9aae589698900b9c35eeec7333d5c25ce1cb7dd05282b77c35457030a0c1e5d272
      - CUBEJS_EXTERNAL_DEFAULT=true
      - CUBEJS_SCHEDULED_REFRESH_DEFAULT=true
      - CUBEJS_SCHEMA_PATH=model
      - CUBEJS_WEB_SOCKETS=true
      - CUBEJS_SQL_USER=cubesql
      - CUBEJS_SQL_PASSWORD=cubesql
      - CUBEJS_DB_HOST=${DB_HOST}
      - CUBEJS_DB_PORT=${DB_PORT}
      - CUBEJS_DB_NAME=${DB_NAME}
      - CUBEJS_DB_USER=${DB_USER}
      - CUBEJS_DB_PASS=${DB_PASSWORD}
EOL
    
    # Start Cube.js using Docker Compose
    cd "$PROJECT_DIR"
    docker-compose up -d
    
    print_success "Cube.js is now running at http://localhost:${REST_API_PORT}"
    print_status "You can access the Cube.js Playground at http://localhost:${REST_API_PORT}"
    print_status "SQL API is available at localhost:${SQL_API_PORT}"
    print_status "SQL API credentials: cubesql / cubesql"
    print_status "To stop Cube.js, run: cd $PROJECT_DIR && docker-compose down"
}

# Function to create a sample query script
create_sample_query() {
    print_section "Creating a sample query script"
    
    cat > "$PROJECT_DIR/sample_query.js" << EOL
const fetch = require('node-fetch');

async function runQuery() {
  const query = {
    measures: ['OrderItems.total_price'],
    dimensions: ['Products.category'],
    timeDimensions: [
      {
        dimension: 'Orders.created_at',
        granularity: 'month'
      }
    ]
  };

  try {
    const response = await fetch('http://localhost:${REST_API_PORT}/cubejs-api/v1/load', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE2MzQ2NDUxNDR9.rPyPd1AOBGt7TDX7Fq5dVKwUQVWBCN5FCy_WDSYo3IY'
      },
      body: JSON.stringify({ query })
    });
    
    const result = await response.json();
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error('Error running query:', error);
  }
}

runQuery();
EOL
    
    # Create a sample SQL query file
    cat > "$PROJECT_DIR/sample_sql_query.txt" << EOL
-- Sample SQL query for CubeSQL
-- Connect using: psql -h localhost -p ${SQL_API_PORT} -U cubesql

SELECT 
  p.category, 
  SUM(oi.price * oi.quantity) as total_price,
  DATE_TRUNC('month', o.created_at) as month
FROM order_items oi
GROSS JOIN products p
GROSS JOIN orders o
GROUP BY p.category, DATE_TRUNC('month', o.created_at)
ORDER BY month, total_price DESC;
EOL
    
    print_success "Sample query script created at $PROJECT_DIR/sample_query.js"
    print_status "To run the sample REST API query, execute: cd $PROJECT_DIR && node sample_query.js"
    print_status "Sample SQL query is available at $PROJECT_DIR/sample_sql_query.txt"
    print_status "To connect to SQL API: psql -h localhost -p ${SQL_API_PORT} -U cubesql"
}

# Function to clean up the project
cleanup_project() {
    print_section "Cleaning up Cube.js project: $PROJECT_NAME"
    
    # Check if project directory exists
    if [ ! -d "$PROJECT_DIR" ]; then
        print_warning "Project directory does not exist: $PROJECT_DIR"
        print_warning "Nothing to clean up."
        return
    fi
    
    # Stop and remove Docker container if it exists
    if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        print_status "Stopping and removing Docker container..."
        cd "$PROJECT_DIR"
        docker-compose down -v || true
    else
        # Try to find and remove the container directly
        print_status "Looking for Docker container: cubejs-${PROJECT_NAME}"
        if docker ps -a | grep -q "cubejs-${PROJECT_NAME}"; then
            print_status "Stopping and removing Docker container: cubejs-${PROJECT_NAME}"
            docker stop "cubejs-${PROJECT_NAME}" || true
            docker rm "cubejs-${PROJECT_NAME}" || true
        else
            print_warning "Docker container not found: cubejs-${PROJECT_NAME}"
        fi
    fi
    
    # Remove project directory
    print_status "Removing project directory: $PROJECT_DIR"
    rm -rf "$PROJECT_DIR"
    
    print_success "Cube.js project cleaned up successfully!"
    print_status "Project name: $PROJECT_NAME"
    print_status "Project directory removed: $PROJECT_DIR"
    print_status "Docker container removed: cubejs-${PROJECT_NAME}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --db-type)
            DB_TYPE="$2"
            shift 2
            ;;
        --image)
            CUBEJS_IMAGE="$2"
            shift 2
            ;;
        --project-name)
            PROJECT_NAME="$2"
            PROJECT_DIR="$HOME/projects/$PROJECT_NAME"
            MODELS_DIR="$PROJECT_DIR/model"
            shift 2
            ;;
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --rest-port)
            REST_API_PORT="$2"
            shift 2
            ;;
        --sql-port)
            SQL_API_PORT="$2"
            shift 2
            ;;
        --force-reinstall-db)
            FORCE_REINSTALL_DB="true"
            shift
            ;;
        --cleanup)
            OPERATION_MODE="cleanup"
            shift
            ;;
        --help)
            print_status "Usage: $0 [options]"
            print_status "Options:"
            print_status "  --db-type TYPE       Set database type (postgres, mysql, doris) (default: postgres)"
            print_status "  --image IMAGE        Set Cube.js Docker image (default: $CUBEJS_IMAGE)"
            print_status "  --project-name NAME  Set project name (default: $PROJECT_NAME)"
            print_status "  --project-dir DIR    Set project directory (default: $HOME/projects/[project-name])"
            print_status "  --rest-port PORT     Set REST API port (default: auto-detected starting from 4000)"
            print_status "  --sql-port PORT      Set SQL API port (default: auto-detected starting from 15432)"
            print_status "  --force-reinstall-db Force delete and reinstall database if it exists"
            print_status "  --cleanup            Clean up the project (remove container and project directory)"
            print_status "  --help               Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_status "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    if [ "$OPERATION_MODE" == "cleanup" ]; then
        # Clean up mode
        cleanup_project
    else
        # Setup mode
        print_status "Starting Cube.js project setup with $DB_TYPE database..."
        print_status "Project name: $PROJECT_NAME"
        print_status "Project directory: $PROJECT_DIR"        

        # Check if Docker is installed
        install_docker
        
        # Install Node.js and npm if not already installed
        install_nodejs 20.x
        
        # Create project directory if it doesn't exist
        if [ ! -d "$PROJECT_DIR" ]; then
            print_status "Creating project directory: $PROJECT_DIR"
            mkdir -p "$PROJECT_DIR"
        else
            print_warning "Project directory already exists: $PROJECT_DIR"
        fi
        
        # Find available ports if not specified
        if [[ "$REST_API_PORT" == "4000" ]]; then
            REST_API_PORT=$(find_available_port 4000)
            print_status "Using REST API port: $REST_API_PORT"
        fi
        
        if [[ "$SQL_API_PORT" == "15432" ]]; then
            SQL_API_PORT=$(find_available_port 15432)
            print_status "Using SQL API port: $SQL_API_PORT"
        fi
        
        # Save port information for future reference
        mkdir -p "$PROJECT_DIR"
        echo "${REST_API_PORT}" > "$PROJECT_DIR/.cubejs_port"
        echo "${SQL_API_PORT}" > "$PROJECT_DIR/.cubesql_port"
        
        # Setup the database with force_reinstall option if specified
        setup_database "$DB_TYPE" "${FORCE_REINSTALL_DB:-false}"
        
        # Create Cube.js data model files
        create_cube_models
        
        # Create .env file
        create_env_file "$DB_TYPE"
        
        # Install node-fetch for sample query
        print_status "Installing node-fetch for sample queries..."
        cd "$PROJECT_DIR"
        npm init -y
        npm install node-fetch
        
        # Launch Cube.js
        launch_cubejs
        
        # Create a sample query script
        create_sample_query
        
        print_success "Cube.js project setup completed successfully!"
        print_status "Project name: $PROJECT_NAME"
        print_status "Project directory: $PROJECT_DIR"
        print_status "Cube.js REST API is running at http://localhost:${REST_API_PORT}"
        print_status "Cube.js SQL API is available at localhost:${SQL_API_PORT}"
        print_status "SQL API credentials: cubesql / cubesql"
        print_status ""
        print_status "To clean up this project later, run:"
        print_status "$0 --project-name $PROJECT_NAME --cleanup"
    fi
}

# Run main function
main 