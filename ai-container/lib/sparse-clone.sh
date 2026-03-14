#!/bin/bash
# sparse-clone.sh - Clone git repository with optional sparse checkout
#
# Usage:
#   sparse-clone.sh <config_json>
#   sparse-clone.sh --url <url> --branch <branch> --dir <directory> [--sparse <patterns>]
#
# Environment variables (used when not provided in args):
#   GITHUB_TOKEN - GitHub personal access token for private repos
#
# Config JSON format:
# {
#   "url": "https://github.com/owner/repo",
#   "branch": "main",
#   "directory": "/path/to/clone",
#   "sparse_checkout": ["dir/", "file.sh"]  // optional, enables sparse checkout
# }
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Clone failed after retries
#   3 - Sparse checkout configuration failed

set -e

# Default values
MAX_ATTEMPTS=5
INITIAL_DELAY=5

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Generate sparse-checkout content from patterns array
# Input: patterns as arguments (e.g., "dir/" "file.sh")
# Output: sparse-checkout file content (non-cone mode format)
generate_sparse_checkout_content() {
    local patterns=("$@")
    
    echo "/*"
    echo "!/*"
    echo "!/*/"
    
    for pattern in "${patterns[@]}"; do
        if [[ "$pattern" != /* ]]; then
            echo "/$pattern"
        else
            echo "$pattern"
        fi
    done
}

# Clone with retry logic and sparse checkout support
# Arguments:
#   $1 - repo_url (with token if needed)
#   $2 - branch
#   $3 - target directory
#   $4 - sparse checkout content (optional, "-" for full clone)
clone_with_retry() {
    local repo_url="$1"
    local branch="$2"
    local target_dir="$3"
    local sparse_content="$4"
    
    local attempt=1
    local delay=$INITIAL_DELAY
    
    while [ $attempt -le $MAX_ATTEMPTS ]; do
        rm -rf "${target_dir:?}/"* "${target_dir:?}/".* 2>/dev/null || true
        
        log_info "Clone attempt $attempt/$MAX_ATTEMPTS..."
        
        if [ "$sparse_content" = "-" ]; then
            if git clone --depth 1 --single-branch --branch "$branch" "$repo_url" "$target_dir"; then
                return 0
            fi
        else
            if git clone --depth 1 --no-checkout --single-branch --branch "$branch" "$repo_url" "$target_dir"; then
                cd "$target_dir"
                if git sparse-checkout init --no-cone && \
                   printf '%s\n' "$sparse_content" | git sparse-checkout set --stdin && \
                   git checkout "$branch"; then
                    return 0
                else
                    log_error "Sparse checkout configuration failed."
                    return 3
                fi
            fi
        fi
        
        if [ $attempt -lt $MAX_ATTEMPTS ]; then
            log_warn "Clone failed (attempt $attempt/$MAX_ATTEMPTS), retrying in ${delay}s..."
            sleep $delay
            attempt=$((attempt + 1))
            delay=$((delay * 2))
        else
            log_error "Clone failed after $MAX_ATTEMPTS attempts."
            return 2
        fi
    done
    
    return 2
}

# Update existing repository with sparse checkout
# Arguments:
#   $1 - repo_url (without token)
#   $2 - branch
#   $3 - target directory
#   $4 - sparse checkout content (optional, "-" for full clone)
update_repository() {
    local repo_url="$1"
    local branch="$2"
    local target_dir="$3"
    local sparse_content="$4"
    
    cd "$target_dir"
    
    if [ "$sparse_content" != "-" ]; then
        local needs_reconfigure=false
        
        if [ ! -f "$target_dir/.git/info/sparse-checkout" ]; then
            needs_reconfigure=true
        else
            for pattern in $sparse_content; do
                if ! grep -qF "$pattern" "$target_dir/.git/info/sparse-checkout" 2>/dev/null; then
                    needs_reconfigure=true
                    break
                fi
            done
        fi
        
        if [ "$needs_reconfigure" = true ]; then
            log_info "Configuring sparse checkout..."
            find "$target_dir" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
            git sparse-checkout init --no-cone
            printf '%s\n' "$sparse_content" | git sparse-checkout set --stdin
            git checkout "$branch"
        fi
    fi
    
    log_info "Fetching latest changes..."
    if git fetch origin "$branch" --depth 1 && \
       git checkout "$branch" && \
       { [ "$sparse_content" = "-" ] || git sparse-checkout reapply; }; then
        log_info "Repository updated to latest $branch branch."
        return 0
    else
        log_warn "Update failed, re-clone required."
        return 1
    fi
}

# Main clone/update function
# Arguments (from JSON config):
#   url - repository URL
#   branch - branch name (default: main)
#   directory - target directory
#   sparse_checkout - array of patterns (optional)
clone_or_update_repo() {
    local url="$1"
    local branch="$2"
    local directory="$3"
    local sparse_patterns="$4"
    
    branch="${branch:-main}"
    
    if [ -z "$url" ] || [ -z "$directory" ]; then
        log_error "Missing required parameters: url and directory"
        return 1
    fi
    
    log_info "Setting up repository: $url"
    log_info "  Branch: $branch"
    log_info "  Directory: $directory"
    
    local clone_url="$url"
    if [ -n "$GITHUB_TOKEN" ] && [[ "$url" == *"github.com"* ]]; then
        clone_url="${url/github.com/${GITHUB_TOKEN}@github.com}"
    fi
    
    local sparse_content="-"
    if [ -n "$sparse_patterns" ] && [ "$sparse_patterns" != "null" ]; then
        local patterns_array=()
        while IFS= read -r pattern; do
            [ -n "$pattern" ] && patterns_array+=("$pattern")
        done < <(echo "$sparse_patterns" | jq -r '.[] // empty' 2>/dev/null)
        
        if [ ${#patterns_array[@]} -gt 0 ]; then
            sparse_content=$(generate_sparse_checkout_content "${patterns_array[@]}")
            log_info "  Sparse checkout: ${patterns_array[*]}"
        fi
    fi
    
    if [ -d "$directory/.git" ] && git -C "$directory" rev-parse --git-dir >/dev/null 2>&1; then
        log_info "Repository exists, updating..."
        if update_repository "$url" "$branch" "$directory" "$sparse_content"; then
            cd "$directory"
            git remote set-url origin "$url"
            return 0
        else
            rm -rf "${directory:?}"
        fi
    fi
    
    log_info "Cloning repository..."
    if clone_with_retry "$clone_url" "$branch" "$directory" "$sparse_content"; then
        cd "$directory"
        git remote set-url origin "$url"
        log_info "Repository ready at $directory"
        return 0
    else
        return $?
    fi
}

# Parse JSON config and execute
process_json_config() {
    local json="$1"
    
    local url=$(echo "$json" | jq -r '.url // empty')
    local branch=$(echo "$json" | jq -r '.branch // "main"')
    local directory=$(echo "$json" | jq -r '.directory // empty')
    local sparse_checkout=$(echo "$json" | jq -c '.sparse_checkout // empty')
    local post_clone=$(echo "$json" | jq -r '.post_clone // empty')
    
    if [ -z "$url" ] || [ -z "$directory" ]; then
        log_error "Invalid config: missing url or directory"
        return 1
    fi
    
    if clone_or_update_repo "$url" "$branch" "$directory" "$sparse_checkout"; then
        if [ -n "$post_clone" ] && [ "$post_clone" != "null" ]; then
            log_info "Running post-clone command: $post_clone"
            cd "$directory"
            eval "$post_clone"
        fi
        return 0
    else
        return $?
    fi
}

# Main entry point
main() {
    local config=""
    local url=""
    local branch=""
    local directory=""
    local sparse=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --url)
                url="$2"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            --dir)
                directory="$2"
                shift 2
                ;;
            --sparse)
                sparse="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Usage: sparse-clone.sh <config_json>"
                echo "       sparse-clone.sh --url <url> --branch <branch> --dir <directory> [--sparse <json_array>]"
                exit 1
                ;;
            *)
                config="$1"
                shift
                ;;
        esac
    done
    
    if [ -n "$config" ]; then
        process_json_config "$config"
    elif [ -n "$url" ] && [ -n "$directory" ]; then
        branch="${branch:-main}"
        clone_or_update_repo "$url" "$branch" "$directory" "$sparse"
    else
        log_error "Missing required arguments"
        echo "Usage: sparse-clone.sh <config_json>"
        echo "       sparse-clone.sh --url <url> --branch <branch> --dir <directory> [--sparse <json_array>]"
        exit 1
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
