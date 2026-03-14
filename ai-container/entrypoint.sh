#!/bin/bash
set -e

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

basic_clone() {
    local url="$1"
    local branch="$2"
    local directory="$3"
    
    local clone_url="$url"
    if [ -n "$GITHUB_TOKEN" ] && [[ "$url" == *"github.com"* ]]; then
        clone_url="${url/github.com/${GITHUB_TOKEN}@github.com}"
    fi
    
    if [ -d "$directory/.git" ] && git -C "$directory" rev-parse --git-dir >/dev/null 2>&1; then
        echo "Repository exists, updating..."
        cd "$directory"
        if git fetch origin && git checkout "$branch" 2>/dev/null && git pull origin "$branch" 2>/dev/null; then
            echo "Repository updated."
        else
            echo "Update failed, re-cloning..."
            rm -rf "${directory:?}"
            git clone -b "$branch" "$clone_url" "$directory"
        fi
    else
        echo "Cloning..."
        git clone -b "$branch" "$clone_url" "$directory"
    fi
    
    if [ -d "$directory/.git" ]; then
        cd "$directory"
        git remote set-url origin "$url"
    fi
}

if [ ! -f "$REPOS_CONFIG" ]; then
    echo ""
    echo "No repos.json config found at $REPOS_CONFIG"
    echo "To auto-clone repositories, create the config file with format:"
    cat << 'EOF'
{
  "repos": [
    {
      "url": "https://github.com/owner/repo",
      "branch": "main",
      "directory": "/home/aiuser/Codes/repo",
      "sparse_checkout": ["/dir/", "/file.sh"],
      "post_clone": "./install.sh"
    }
  ]
}
EOF
else
    echo ""
    echo "Reading repositories configuration from $REPOS_CONFIG..."
    
    repo_count=$(jq '.repos | length' "$REPOS_CONFIG" 2>/dev/null)
    current=0
    
    while IFS= read -r repo_json; do
        current=$((current + 1))
        url=$(echo "$repo_json" | jq -r '.url // empty')
        branch=$(echo "$repo_json" | jq -r '.branch // "main"')
        directory=$(echo "$repo_json" | jq -r '.directory // empty')
        sparse_checkout=$(echo "$repo_json" | jq -c '.sparse_checkout // empty')
        post_clone=$(echo "$repo_json" | jq -r '.post_clone // empty')
        
        if [ -z "$url" ] || [ -z "$directory" ]; then
            continue
        fi
        
        echo ""
        echo "[$current/$repo_count] $url"
        
        if [ -x "$SPARSE_CLONE_LIB" ] && [ -n "$sparse_checkout" ] && [ "$sparse_checkout" != "null" ]; then
            "$SPARSE_CLONE_LIB" --url "$url" --branch "$branch" --dir "$directory" --sparse "$sparse_checkout"
        else
            basic_clone "$url" "$branch" "$directory"
        fi
        
        if [ -n "$post_clone" ] && [ "$post_clone" != "null" ] && [ -d "$directory" ]; then
            echo "Running post-clone: $post_clone"
            cd "$directory"
            eval "$post_clone"
        fi
    done < <(jq -c '.repos[]' "$REPOS_CONFIG" 2>/dev/null)
    
    echo ""
    echo "Repository sync completed."
fi

exec "$@"
