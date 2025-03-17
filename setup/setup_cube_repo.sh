#!/bin/bash

# Function to print status messages
print_status() {
  echo "===> $1"
}

# Function to convert branch name to directory name
convert_branch_to_dirname() {
    echo "${1//\//--}"
}

# Function to setup a repository with specified branches
setup_repository() {
    local repo_url=$1
    local repo_name=$2
    shift 2
    local branches=("$@")  # Rest of the arguments are branches
    
    if [ ${#branches[@]} -eq 0 ]; then
        print_status "Error: At least one branch must be specified for $repo_name"
        return 1
    fi
    
    local base_dir=~/projects/$repo_name
    local branches_dir=$base_dir/branches
    local git_dir=$base_dir/git
    local base_branch=${branches[0]}  # First branch is considered the base branch
    local base_branch_dirname=$(convert_branch_to_dirname "$base_branch")  # Convert base branch name to directory name
    
    # Check if setup is already complete
    local all_branches_exist=true
    local existing_branches=()
    for branch in "${branches[@]}"; do
        local branch_dirname=$(convert_branch_to_dirname "$branch")
        if [ ! -d "$branches_dir/$branch_dirname" ]; then
            all_branches_exist=false
        else
            existing_branches+=("$branch")
        fi
    done
    
    if $all_branches_exist && [ -d "$git_dir" ] && [ -d "$git_dir/refs" ]; then
        print_status "Setup already complete for $repo_name."
        for branch in "${branches[@]}"; do
            print_status "Branch $branch is at: $branches_dir/$branch_dirname"
        done
        
        # Optionally update the repository
        read -p "Do you want to update $repo_name repository? (y/n): " update_repo
        if [[ "$update_repo" == "y" || "$update_repo" == "Y" ]]; then
            for branch in "${branches[@]}"; do
                print_status "Updating $branch branch at $branches_dir/$branch_dirname..."
                (cd "$branches_dir/$branch_dirname" && git pull origin $branch)
            done
        fi
        
        return 0
    fi
    
    # Create necessary directories
    print_status "Creating directories for $repo_name..."
    mkdir -p "$branches_dir"
    
    # Handle existing git directory
    if [ -d "$git_dir" ]; then
        if [ -d "$git_dir/refs" ]; then
            print_status "Found existing git directory at $git_dir"
        else
            print_status "Found incomplete git directory at $git_dir, moving it to backup..."
            mv "$git_dir" "${git_dir}_backup_$(date +%Y%m%d_%H%M%S)"
        fi
    fi
    
    # Clone or reinitialize the repository
    if [ ! -d "$branches_dir/$base_branch_dirname" ]; then
        if [ -d "$git_dir/refs" ]; then
            print_status "Reusing existing git directory..."
            git clone --separate-git-dir="$git_dir" "$repo_url" "$branches_dir/$base_branch_dirname" || {
                print_status "Failed to clone with existing git directory. Trying to reinitialize..."
                mv "$git_dir" "${git_dir}_backup_$(date +%Y%m%d_%H%M%S)"
                git clone --separate-git-dir="$git_dir" "$repo_url" "$branches_dir/$base_branch_dirname" || {
                    print_status "Failed to clone $repo_name repository"
                    return 1
                }
            }
        else
            print_status "Cloning $repo_name repository..."
            git clone --separate-git-dir="$git_dir" "$repo_url" "$branches_dir/$base_branch_dirname" || {
                print_status "Failed to clone $repo_name repository"
                return 1
            }
        fi
    else
        print_status "Repository $repo_name already cloned at $branches_dir/$base_branch_dirname"
        
        # Verify git directory is properly set up
        if [ ! -d "$git_dir/refs" ]; then
            print_status "Git directory not properly initialized for $repo_name. Reinitializing..."
            if [ -d "$git_dir" ]; then
                mv "$git_dir" "${git_dir}_backup_$(date +%Y%m%d_%H%M%S)"
            fi
            (cd "$branches_dir/$base_branch_dirname" && git init --separate-git-dir="$git_dir")
        fi
    fi
    
    # Change to the base branch directory
    cd "$branches_dir/$base_branch_dirname" || {
        print_status "Failed to change to $base_branch directory"
        return 1
    }
    
    # Ensure we have the latest changes and the remote is set correctly
    print_status "Updating $base_branch branch..."
    git remote set-url origin "$repo_url" 2>/dev/null || git remote add origin "$repo_url"
    git fetch origin
    
    # Create worktrees for additional branches
    for branch in "${branches[@]:1}"; do  # Skip the first (base) branch
        local branch_dirname=$(convert_branch_to_dirname "$branch")
        if [ ! -d "$branches_dir/$branch_dirname" ]; then
            print_status "Creating worktree for $branch branch..."
            
            # Check if branch exists locally
            if git show-ref --verify --quiet refs/heads/$branch; then
                print_status "Using existing local $branch branch..."
            else
                print_status "Fetching $branch branch from remote..."
                git fetch origin $branch:$branch || {
                    print_status "Failed to fetch $branch branch from remote. Creating it locally..."
                    # Create the branch locally based on the current branch
                    git branch $branch || {
                        print_status "Failed to create $branch branch locally"
                        return 1
                    }
                }
            fi
            
            git worktree add "$branches_dir/$branch_dirname" $branch || {
                print_status "Failed to create worktree for $branch branch"
                return 1
            }
        else
            print_status "$branch branch worktree already exists at $branches_dir/$branch_dirname"
        fi
    done
    
    print_status "Repository $repo_name setup complete!"
    for branch in "${branches[@]}"; do
        print_status "Branch $branch is at: $branches_dir/$branch_dirname"
    done
    
    return 0
}

# Parse command line arguments
CUBE_DEVELOP_BRANCH=""
DORIS_DEVELOP_BRANCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --cube-develop)
            CUBE_DEVELOP_BRANCH="$2"
            shift 2
            ;;
        --doris-develop)
            DORIS_DEVELOP_BRANCH="$2"
            shift 2
            ;;
        *)
            print_status "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Setup cube repository
print_status "Setting up cube repository..."
if [ -n "$CUBE_DEVELOP_BRANCH" ]; then
    setup_repository "git@github.com:reorc/cube.git" "cube" "master" "reorc" "$CUBE_DEVELOP_BRANCH"
else
    setup_repository "git@github.com:reorc/cube.git" "cube" "master" "reorc" "develop"
fi

# Setup cubejs-doris-driver repository
print_status "Setting up cubejs-doris-driver repository..."
if [ -n "$DORIS_DEVELOP_BRANCH" ]; then
    setup_repository "git@github.com:reorc/cubejs-doris-driver.git" "cubejs-doris-driver" "main" "$DORIS_DEVELOP_BRANCH"
else
    setup_repository "git@github.com:reorc/cubejs-doris-driver.git" "cubejs-doris-driver" "main" "develop"
fi

# Example usage:
# ./setup_cube_repo.sh --cube-develop feature/new-feature --doris-develop feature/doris-update

# Example of how to use with different number of branches:
# Single branch:
# setup_repository "git@github.com:user/repo.git" "repo-name" "main"
# Three branches:
# setup_repository "git@github.com:user/repo.git" "repo-name" "main" "develop" "feature"
# Four branches:
# setup_repository "git@github.com:user/repo.git" "repo-name" "main" "develop" "staging" "production" 