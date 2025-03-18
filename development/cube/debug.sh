#!/bin/bash

# debug.sh
# Script to set up a Cube.js debugging environment

# Source common utilities
source "$(dirname "$0")/../../common/utils.sh"

# Function to print section headers
print_section() {
    print_status "=== $1 ==="
}

# Function to convert branch name to directory name (same as in setup_cube_repo.sh)
convert_branch_to_dirname() {
    echo "${1//\//--}"
}

# Function to unlink packages
unlink_packages() {
    local yarn_link_dir="$HOME/.config/yarn/link/@cubejs-backend"
    
    # Check if the Cube.js link directory exists
    if [[ ! -d "$yarn_link_dir" ]]; then
        print_success "No Cube.js packages are globally linked."
        return 0
    fi
    
    print_warning "Found linked packages:"
    
    # Get list of actually linked packages
    for link in "$yarn_link_dir"/*; do
        if [[ -L "$link" ]]; then  # Check if it's a symbolic link
            local package_name="@cubejs-backend/$(basename "$link")"
            local target_path=$(readlink -f "$link")
            print_warning "  $package_name -> $target_path"
            
            # Remove the global link
            print_warning "Removing global link for $package_name"
            rm -f "$link"
        fi
    done
    
    # Check if @cubejs-backend directory is empty and remove it if it is
    if [[ -d "$yarn_link_dir" ]] && [[ ! "$(ls -A "$yarn_link_dir")" ]]; then
        rmdir "$yarn_link_dir"
    fi
    
    print_success "Global package links removed!"
}

# Function to link a package
link_package() {
    local package_path=$1
    local package_name=$2
    
    print_warning "Linking package: ${package_name}"
    
    # Register the package globally
    cd ${package_path}
    yarn link 2>/dev/null || true
    
    # Link the package in the test project
    cd ${TEST_PROJECT_PATH}
    yarn link ${package_name} 2>/dev/null || true
}

# Function to update launch configuration
update_launch_config() {
    local launch_config_file="${CUBE_REPO_PATH}/.vscode/launch.json"
    
    if [[ -f "$launch_config_file" ]]; then
        print_warning "Updating launch.json with test project path: ${TEST_PROJECT_PATH}"
        # Use sed to update the placeholder in launch.json
        sed -i.bak "s|\"cwd\": \"{{TEST_PROJECT_PATH}}\"|\"cwd\": \"${TEST_PROJECT_PATH}\"|g" "$launch_config_file"
        rm -f "${launch_config_file}.bak"
        print_success "Launch configuration updated!"
    else
        print_error "launch.json not found at $launch_config_file"
        print_error "Please run setup_debugger.sh first"
        exit 1
    fi
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

# Function to kill processes by port
kill_process_by_port() {
  local port=$1
  local pid=$(lsof -i :$port | grep LISTEN | awk '{print $2}')
  if [ ! -z "$pid" ]; then
    print_error "Killing process on port $port (PID: $pid)"
    kill -9 $pid 2>/dev/null || true
  else
    print_success "No process found on port $port"
  fi
}

# Function to kill processes by name
kill_process_by_name() {
  local name=$1
  local pids=$(pgrep -f "$name" || true)
  if [ ! -z "$pids" ]; then
    print_error "Killing processes matching '$name' (PIDs: $pids)"
    pkill -f "$name" 2>/dev/null || true
  else
    print_success "No processes found matching '$name'"
  fi
}

# Define paths
CUBE_REPO_PATH=~/projects/cube/branches/${DEVELOP_DIR_NAME}
CUBESQL_PATH=${CUBE_REPO_PATH}/rust/cubesql
TEST_PROJECT_PATH=~/projects/${TEST_PROJECT_NAME}
CUBESQL_EXECUTABLE=${CUBESQL_PATH}/target/debug/cubesqld

print_section "Starting Cube.js Debugging Environment"

print_section "Cleaning up existing processes"

# Kill any existing Node.js processes on port 9229 (debugger)
kill_process_by_port 9229

# Kill any existing Cube.js server processes on port 4000
kill_process_by_port 4000

# Kill any existing CubeSQL processes on port 15432
kill_process_by_port 15432

# Kill any existing TypeScript compiler processes
kill_process_by_name "yarn tsc:watch"

# Kill any existing CubeSQL processes
kill_process_by_name "cubesql"
kill_process_by_name "cubesqld"

# Additional cleanup for any stray processes
kill_process_by_name "cubejs-server"

# Wait a moment to ensure all processes are terminated
print_status "Waiting for processes to terminate..."
sleep 2

print_section "Cleaning up existing yarn links"
unlink_packages

print_section "Building TypeScript packages"
cd ${CUBE_REPO_PATH}
yarn build

print_section "Updating VSCode launch configuration"
update_launch_config

print_section "Ensuring packages are properly linked from ${CUBE_REPO_PATH} to ${TEST_PROJECT_PATH}"

# Core packages for API and query processing
link_package "${CUBE_REPO_PATH}/packages/cubejs-api-gateway" "@cubejs-backend/api-gateway"
link_package "${CUBE_REPO_PATH}/packages/cubejs-schema-compiler" "@cubejs-backend/schema-compiler"
link_package "${CUBE_REPO_PATH}/packages/cubejs-query-orchestrator" "@cubejs-backend/query-orchestrator"
link_package "${CUBE_REPO_PATH}/packages/cubejs-server-core" "@cubejs-backend/server-core"

# Additional packages that might be involved in rolling window functionality
link_package "${CUBE_REPO_PATH}/packages/cubejs-backend-shared" "@cubejs-backend/shared"
link_package "${CUBE_REPO_PATH}/packages/cubejs-base-driver" "@cubejs-backend/base-driver"

print_success "Package linking complete!"

# Check if we can use the utility function for TypeScript watch
if command_exists start_typescript_watch; then
  start_typescript_watch ${CUBE_REPO_PATH}
  TSC_PID=$!
else
  # Start TypeScript compiler in watch mode
  print_section "Starting TypeScript compiler in watch mode"
  cd ${CUBE_REPO_PATH}
  yarn tsc:watch > typescript-watch.log 2>&1 &
  TSC_PID=$!
  print_success "TypeScript compiler started with PID: $TSC_PID"
fi

# Wait for TypeScript compiler to initialize
print_status "Waiting for TypeScript compiler to initialize..."
sleep 5

print_section "Building CubeSQL with debug symbols"
cd ${CUBESQL_PATH}
cargo build

# Verify the CubeSQL executable exists
if [ ! -f "${CUBESQL_EXECUTABLE}" ]; then
  print_error "CubeSQL executable not found at ${CUBESQL_EXECUTABLE}"
  print_error "Please check the path and build process"
  exit 1
fi

print_section "Starting CubeSQL in the background"
cd ${CUBESQL_PATH}
RUST_BACKTRACE=1 RUST_LOG=trace ${CUBESQL_EXECUTABLE} &
CUBESQL_PID=$!
print_success "CubeSQL started with PID: $CUBESQL_PID"

print_section "Starting Cube.js with debugging enabled"
cd ${TEST_PROJECT_PATH}
print_success "Attaching debugger to port 9229. Please set your breakpoints now."
print_success "Recommended breakpoints:"
print_success "1. ${CUBE_REPO_PATH}/packages/cubejs-api-gateway/src/gateway.ts - Look for the load() method around line 1785"
print_success "2. ${CUBE_REPO_PATH}/packages/cubejs-schema-compiler/src/adapter/BaseQuery.js - Look for methods with 'rollingWindow' in their name"
print_success "3. ${CUBE_REPO_PATH}/packages/cubejs-schema-compiler/src/adapter/BaseTimeDimension.ts - Contains time dimension handling logic"
print_success "4. ${CUBE_REPO_PATH}/packages/cubejs-query-orchestrator/src/orchestrator/QueryOrchestrator.ts - For query execution"

print_section "Debugging Instructions"
print_warning "1. Open VSCode and go to the Run and Debug view (Ctrl+Shift+D)"
print_warning "2. Select 'Attach to Cube.js Server' from the dropdown"
print_warning "3. Click the green play button to attach the debugger"
print_warning "4. Set breakpoints in the files mentioned above"
print_warning "5. Run a query using the debug-rolling-window.sh script in another terminal"
print_warning "6. The debugger will pause at your breakpoints"

NODE_OPTIONS="--inspect-brk=0.0.0.0:9229" CUBEJS_DEV_MODE=true CUBEJS_LOG_LEVEL=trace yarn dev

# Cleanup on exit
trap "echo -e '${RED}Cleaning up processes...${NC}'; kill $CUBESQL_PID $TSC_PID 2>/dev/null || true" EXIT 