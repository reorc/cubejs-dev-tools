#!/bin/bash

# debug.sh
# Script to set up a Cube.js debugging environment

# Source common utilities
source "$(dirname "$0")/../../common/utils.sh"

# Function to print section headers
print_section() {
    print_status "=== $1 ==="
}

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

# Define paths
CUBE_REPO_PATH=~/projects/cube/branches/develop
CUBESQL_PATH=${CUBE_REPO_PATH}/rust/cubesql
TEST_PROJECT_PATH=~/projects/cubejs-test-project
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

print_section "Ensuring packages are properly linked"

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