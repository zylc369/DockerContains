#!/bin/bash
set -e

PUID=${PUID:-1000}
PGID=${PGID:-1000}

CURRENT_UID=$(id -u aiuser)
CURRENT_GID=$(id -g aiuser)

if [ "$PUID" != "$CURRENT_UID" ] || [ "$PGID" != "$CURRENT_GID" ]; then
    echo "Configuring aiuser with UID=$PUID, GID=$PGID..."
    
    groupmod -o -g "$PGID" aiuser 2>/dev/null || true
    usermod -o -u "$PUID" aiuser 2>/dev/null || true
    
    chown -R "$PUID:$PGID" /home/aiuser
    
    for dir in \
        /home/aiuser/Codes/ai-doctor/notes \
        /home/aiuser/Codes/buwai-ai-extension \
        /home/aiuser/Codes/buwai-claude-assistant \
        /home/aiuser/.cache/opencode \
        /home/aiuser/.config/opencode \
        /home/aiuser/.config/repos \
        /home/aiuser/.local/share/opencode \
        /home/aiuser/.local/state/opencode
    do
        if [ -d "$dir" ]; then
            chown -R "$PUID:$PGID" "$dir" 2>/dev/null || true
        fi
    done
    
    echo "User configuration complete."
fi

git config --global --add safe.directory '*' 2>/dev/null || true

if [ -n "$GITHUB_TOKEN" ]; then
    echo "Configuring Git to use GitHub Token..."
    git config --global credential.helper store
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    git config --global http.postBuffer 524288000
    git config --global core.compression 0
    git config --global pack.windowMemory 512m
    git config --global pack.packSizeLimit 512m
    echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    git config --global --add safe.directory '*' 2>/dev/null || true
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

mkdir -p /home/aiuser
git config --global --file /home/aiuser/.gitconfig --add safe.directory '*' 2>/dev/null || true
chown "$PUID:$PGID" /home/aiuser/.gitconfig 2>/dev/null || true
if [ -f /root/.gitconfig ]; then
    cp /root/.gitconfig /home/aiuser/.gitconfig 2>/dev/null || true
    chown "$PUID:$PGID" /home/aiuser/.gitconfig 2>/dev/null || true
fi
if [ -f /root/.git-credentials ]; then
    cp /root/.git-credentials /home/aiuser/.git-credentials 2>/dev/null || true
    chown "$PUID:$PGID" /home/aiuser/.git-credentials 2>/dev/null || true
    chmod 600 /home/aiuser/.git-credentials 2>/dev/null || true
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
    
    local max_attempts=5
    local attempt=1
    local delay=5
    
    while [ $attempt -le $max_attempts ]; do
        if [ -d "$directory/.git" ] && git -C "$directory" rev-parse --git-dir >/dev/null 2>&1; then
            echo "Repository exists, updating..."
            cd "$directory"
            if git fetch origin && git checkout "$branch" 2>/dev/null && git pull origin "$branch" 2>/dev/null; then
                echo "Repository updated."
                break
            else
                echo "Update failed, re-cloning..."
                rm -rf "${directory:?}" 2>/dev/null || find "${directory:?}" -mindepth 1 -delete 2>/dev/null || true
                git clone -b "$branch" "$clone_url" "$directory" && break
            fi
        else
            if [ -d "$directory" ]; then
                echo "Directory exists but is not a valid git repo, cleaning..."
                rm -rf "${directory:?}" 2>/dev/null || find "${directory:?}" -mindepth 1 -delete 2>/dev/null || true
            fi
            echo "Cloning (attempt $attempt/$max_attempts)..."
            if git clone --depth 1 --single-branch -b "$branch" "$clone_url" "$directory"; then
                break
            fi
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "Clone failed, retrying in ${delay}s..."
            sleep $delay
            attempt=$((attempt + 1))
            delay=$((delay * 2))
        else
            echo "Clone failed after $max_attempts attempts."
            return 1
        fi
    done
    
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

# Setup buwai-claude-assistant dependencies
BUWAI_DIR="/home/aiuser/Codes/buwai-claude-assistant"
if [ -d "$BUWAI_DIR" ]; then
    echo ""
    echo "Setting up buwai-claude-assistant dependencies..."
    
    # Setup Python backend (server/.venv)
    SERVER_DIR="$BUWAI_DIR/server"
    if [ -d "$SERVER_DIR" ]; then
        if [ ! -d "$SERVER_DIR/.venv" ]; then
            echo "Creating Python virtual environment for server..."
            cd "$SERVER_DIR"
            python3 -m venv .venv
            echo "Installing Python dependencies..."
            .venv/bin/pip install --upgrade pip
            if [ -f "requirements.txt" ]; then
                .venv/bin/pip install -r requirements.txt
            fi
            echo "Python virtual environment setup completed."
        else
            echo "Python virtual environment already exists at server/.venv"
        fi
    fi
    
    # Setup frontend (web/ bun install)
    WEB_DIR="$BUWAI_DIR/web"
    if [ -d "$WEB_DIR" ]; then
        echo "Installing frontend dependencies with bun..."
        cd "$WEB_DIR"
        /home/aiuser/.bun/bin/bun install
        echo "Frontend dependencies installed."
    fi
    
    # Fix ownership for newly created files
    chown -R "$PUID:$PGID" "$BUWAI_DIR" 2>/dev/null || true
    
    echo "buwai-claude-assistant setup completed."
fi

exec gosu aiuser "$@"
