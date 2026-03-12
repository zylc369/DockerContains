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
    echo "https://${GITHUB_TOKEN}@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    echo "Git configured successfully."
    echo "- Public repos: clone without authentication"
    echo "- Private repos with token access: will use token automatically"
    echo "- Private repos without token access: will fail (expected)"
else
    echo "Warning: GITHUB_TOKEN not set. Git operations may fail for private repos."
fi

# Clone with retry and cleanup
clone_with_retry() {
    local max_attempts=5
    local attempt=1
    local delay=5
    while [ $attempt -le $max_attempts ]; do
        rm -rf "${REPO_DIR:?}/"* "${REPO_DIR:?}/".* 2>/dev/null || true
        echo "Clone attempt $attempt/$max_attempts..."
        if git clone --depth 1 --single-branch --branch "$BRANCH" "$REPO_URL" "$REPO_DIR" 2>&1; then
            return 0
        else
            exit_code=$?
            if [ $attempt -lt $max_attempts ]; then
                echo "Clone failed (attempt $attempt/$max_attempts), retrying in ${delay}s..."
                sleep $delay
                attempt=$((attempt + 1))
                delay=$((delay * 2))
            else
                return $exit_code
            fi
        fi
    done
}

# Clone or pull buwai-ai-extension repository
if [ -n "$GITHUB_TOKEN" ]; then
    REPO_URL="https://${GITHUB_TOKEN}@github.com/zylc369/buwai-ai-extension"
else
    REPO_URL="https://github.com/zylc369/buwai-ai-extension"
fi
REPO_DIR="/home/aiuser/Codes/buwai-ai-extension"
BRANCH="main"

echo ""
echo "Setting up buwai-ai-extension repository..."

# Check if it's a valid git repository
if [ -d "$REPO_DIR/.git" ] && git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Repository exists, updating..."
    cd "$REPO_DIR"
    git fetch origin "$BRANCH" 2>&1 || true
    git reset --hard origin/"$BRANCH" 2>&1 || true
    echo "Repository updated."
else
    echo "Cloning repository..."
    clone_with_retry
    echo "Repository cloned."
fi

# Replace remote URL to remove token
if [ -d "$REPO_DIR/.git" ]; then
    cd "$REPO_DIR"
    git remote set-url origin "https://github.com/zylc369/buwai-ai-extension"
    
    # Install AI extensions
    if [ -f install-ai-extensions.sh ]; then
        echo "Installing AI extensions..."
        chmod +x install-ai-extensions.sh
        ./install-ai-extensions.sh
    else
        echo "Warning: install-ai-extensions.sh not found."
    fi
fi

# Execute the passed command
exec "$@"
