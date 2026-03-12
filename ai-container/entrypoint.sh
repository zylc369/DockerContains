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

# Clone with retry, sparse checkout, and cleanup
clone_sparse_with_retry() {
    local max_attempts=5
    local attempt=1
    local delay=5
    while [ $attempt -le $max_attempts ]; do
        rm -rf "${REPO_DIR:?}/"* "${REPO_DIR:?}/".* 2>/dev/null || true
        echo "Clone attempt $attempt/$max_attempts with sparse checkout..."
        if git clone --depth 1 --no-checkout --single-branch --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"; then
            cd "$REPO_DIR"
            if git sparse-checkout init --no-cone && \
               printf '%s\n' "$SPARSE_CHECKOUT_CONTENT" | git sparse-checkout set --stdin && \
               git checkout "$BRANCH"; then
                return 0
            else
                echo "Sparse checkout configuration failed."
                return 1
            fi
        else
            if [ $attempt -lt $max_attempts ]; then
                echo "Clone failed (attempt $attempt/$max_attempts), retrying in ${delay}s..."
                sleep $delay
                attempt=$((attempt + 1))
                delay=$((delay * 2))
            else
                return 1
            fi
        fi
    done
}

# Clone or pull buwai-ai-extension repository with sparse checkout
if [ -n "$GITHUB_TOKEN" ]; then
    REPO_URL="https://${GITHUB_TOKEN}@github.com/zylc369/buwai-ai-extension"
else
    REPO_URL="https://github.com/zylc369/buwai-ai-extension"
fi
REPO_DIR="/home/aiuser/Codes/buwai-ai-extension"
BRANCH="main"

# Generate sparse-checkout file content (non-cone mode format)
SPARSE_CHECKOUT_CONTENT="/*
!/*
!/*/
/extensions/
/install-ai-extensions.sh
/init-ai-tools.sh
/uninstall-extensions.sh
/.gitignore"

echo ""
echo "Setting up buwai-ai-extension repository (sparse checkout)..."

# Check if it's a valid git repository (not just a directory with .git folder)
if [ -d "$REPO_DIR/.git" ] && git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Repository exists, updating..."
    cd "$REPO_DIR"
    
    # Ensure sparse checkout is configured
    if [ ! -f "$REPO_DIR/.git/info/sparse-checkout" ] || ! grep -q "^/extensions/$" "$REPO_DIR/.git/info/sparse-checkout" 2>/dev/null; then
        echo "Configuring sparse checkout..."
        find "$REPO_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
        git sparse-checkout init --no-cone
        printf '%s\n' "$SPARSE_CHECKOUT_CONTENT" | git sparse-checkout set --stdin
        git checkout "$BRANCH"
    fi
    
    # Fetch and checkout - only fetches files needed for sparse checkout
    echo "Fetching latest changes..."
    if git fetch origin "$BRANCH" --depth 1 && git checkout "$BRANCH" && git sparse-checkout reapply; then
        echo "Repository updated to latest $BRANCH branch."
    else
        echo "Update failed, attempting to re-clone..."
        rm -rf "${REPO_DIR:?}"
        clone_sparse_with_retry
    fi
else
    echo "Cloning repository with sparse checkout..."
    clone_sparse_with_retry
    echo "Repository cloned with sparse checkout."
fi

# Replace remote URL to remove token (credential.helper will handle auth)
if [ -d "$REPO_DIR/.git" ]; then
    cd "$REPO_DIR"
    git remote set-url origin "https://github.com/zylc369/buwai-ai-extension"
    
    # Install AI extensions
    echo "Installing AI extensions..."
    if [ -f install-ai-extensions.sh ]; then
        chmod +x install-ai-extensions.sh
        ./install-ai-extensions.sh
    else
        echo "Warning: install-ai-extensions.sh not found."
    fi
fi

# Execute the passed command
exec "$@"
