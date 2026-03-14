#!/bin/bash
set -e

# Configure Git to use GitHub Token for authentication
if [ -n "$GITHUB_TOKEN" ]; then
    echo "Configuring Git to use GitHub Token..."
    git config --global credential.helper store
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    git config --global http.postBuffer 524288000
    git config --global core.compression 0
    git config --global pack.windowMemory 512m
    git config --global pack.packSizeLimit 512m
    echo "https://${GITHUB_TOKEN}@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    echo "Git configured successfully."
    echo "- Public repos: clone without authentication"
    echo "- Private repos with token access: will use token automatically"
    echo "- Private repos without token access: will fail (expected)"
else
    echo "Warning: GITHUB_TOKEN not set. Git operations may fail for private repos."
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    git config --global http.postBuffer 524288000
    git config --global core.compression 0
    git config --global pack.windowMemory 512m
    git config --global pack.packSizeLimit 512m
fi

REPOS_CONFIG="/home/aiuser/.config/repos/repos.json"
SPARSE_CLONE_LIB="/usr/local/lib/sparse-clone.sh"

process_repos_config() {
    if [ ! -f "$REPOS_CONFIG" ]; then
        echo ""
        echo "No repos.json config found at $REPOS_CONFIG"
        echo "To auto-clone repositories, create the config file with format:"
        echo '{
  "repos": [
    {
      "url": "https://github.com/owner/repo",
      "branch": "main",
      "directory": "/home/aiuser/Codes/repo",
      "sparse_checkout": ["/dir/", "/file.sh"],
      "post_clone": "./install.sh"
    }
  ]
}'
        return
    fi
    
    echo ""
    echo "Reading repositories configuration from $REPOS_CONFIG..."
    
    local repo_count=$(jq '.repos | length' "$REPOS_CONFIG" 2>/dev/null)
    local current=0
    
    jq -c '.repos[]' "$REPOS_CONFIG" 2>/dev/null | while IFS= read -r repo_json; do
        current=$((current + 1))
        echo ""
        echo "[$current/$repo_count] Processing repository..."
        
        if [ -x "$SPARSE_CLONE_LIB" ]; then
            "$SPARSE_CLONE_LIB" "$repo_json"
        else
            echo "Warning: sparse-clone.sh not found at $SPARSE_CLONE_LIB"
            echo "Falling back to basic clone..."
            basic_clone "$repo_json"
        fi
    done
    
    echo ""
    echo "Repository sync completed."
}

basic_clone() {
    local json="$1"
    local url=$(echo "$json" | jq -r '.url // empty')
    local branch=$(echo "$json" | jq -r '.branch // "main"')
    local directory=$(echo "$json" | jq -r '.directory // empty')
    
    if [ -z "$url" ] || [ -z "$directory" ]; then
        echo "Invalid config: missing url or directory"
        return 1
    fi
    
    local clone_url="$url"
    if [ -n "$GITHUB_TOKEN" ] && [[ "$url" == *"github.com"* ]]; then
        clone_url="${url/github.com/${GITHUB_TOKEN}@github.com}"
    fi
    
    if [ -d "$directory/.git" ] && git -C "$directory" rev-parse --git-dir >/dev/null 2>&1; then
        echo "Repository exists at $directory, updating..."
        cd "$directory"
        if git fetch origin && git checkout "$branch" 2>/dev/null && git pull origin "$branch" 2>/dev/null; then
            echo "Repository updated."
        else
            echo "Update failed, re-cloning..."
            rm -rf "${directory:?}"
            git clone -b "$branch" "$clone_url" "$directory"
        fi
    else
        echo "Cloning $url to $directory..."
        git clone -b "$branch" "$clone_url" "$directory"
    fi
    
    if [ -d "$directory/.git" ]; then
        cd "$directory"
        git remote set-url origin "$url"
    fi
}

process_repos_config

exec "$@"
