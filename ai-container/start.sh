#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="ai-container"

# Function to print colored messages
info_msg() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success_msg() {
    echo -e "${GREEN}✓${NC} $1"
}

warning_msg() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error_exit() {
    echo -e "${RED}✗ Error: $1${NC}" >&2
    exit 1
}

# Function to trim whitespace
trim() {
    local var="$1"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Function to check if container is running
is_container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Function to check if container exists (running or stopped)
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Parse arguments
FORCE_RESTART=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--restart)
            FORCE_RESTART=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -r, --restart    Restart the container if it's already running"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "This script will:"
            echo "  1. Check for .env file and GITHUB_TOKEN"
            echo "  2. Prompt for token if not found"
            echo "  3. Check for auth.json and API key"
            echo "  4. Start or restart the Docker container"
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1\nUse -h or --help for usage information"
            ;;
    esac
done

cd "$SCRIPT_DIR"

# Step 1: Check and create .env file with GITHUB_TOKEN
info_msg "Checking environment configuration..."

ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    info_msg ".env file not found, will create one"
    TOUCH_ENV=true
else
    # Check if GITHUB_TOKEN exists in .env
    if grep -q "^GITHUB_TOKEN=" "$ENV_FILE" 2>/dev/null; then
        EXISTING_TOKEN=$(grep "^GITHUB_TOKEN=" "$ENV_FILE" | cut -d'=' -f2-)
        EXISTING_TOKEN=$(trim "$EXISTING_TOKEN")
        
        if [ -n "$EXISTING_TOKEN" ] && [ "$EXISTING_TOKEN" != "your_github_token_here" ]; then
            success_msg "GITHUB_TOKEN found in .env"
            TOUCH_ENV=false
        else
            TOUCH_ENV=true
        fi
    else
        TOUCH_ENV=true
    fi
fi

# Prompt for token if needed
if [ "$TOUCH_ENV" = true ]; then
    echo ""
    warning_msg "请输入 GitHub Token，用以访问特定代码仓库"
    info_msg "Create token at: https://github.com/settings/tokens"
    echo ""
    
    while true; do
        read -p "GitHub Token: " INPUT_TOKEN
        
        # Trim whitespace
        INPUT_TOKEN=$(trim "$INPUT_TOKEN")
        
        if [ -z "$INPUT_TOKEN" ]; then
            warning_msg "Token cannot be empty. Please try again."
            continue
        fi
        
        # Save to .env file
        if [ ! -f "$ENV_FILE" ]; then
            echo "# GitHub Personal Access Token (Fine-grained)" > "$ENV_FILE"
            echo "# Required permissions: Contents (Read and write)" >> "$ENV_FILE"
            echo "# Create token at: https://github.com/settings/tokens" >> "$ENV_FILE"
            echo "" >> "$ENV_FILE"
        fi
        
        # Remove existing GITHUB_TOKEN line if exists
        if grep -q "^GITHUB_TOKEN=" "$ENV_FILE" 2>/dev/null; then
            # Create temp file without GITHUB_TOKEN line
            grep -v "^GITHUB_TOKEN=" "$ENV_FILE" > "${ENV_FILE}.tmp" || true
            mv "${ENV_FILE}.tmp" "$ENV_FILE"
        fi
        
        # Add new GITHUB_TOKEN
        echo "GITHUB_TOKEN=${INPUT_TOKEN}" >> "$ENV_FILE"
        success_msg "Token saved to .env"
        break
    done
fi

# Step 1.5: Check and create auth.json with API key
AUTH_DIR="$SCRIPT_DIR/data/home/.local/share/opencode"
AUTH_FILE="$AUTH_DIR/auth.json"
NEED_API_KEY=false

info_msg "Checking API key configuration..."

# Create directory if not exists
mkdir -p "$AUTH_DIR"

# Check if auth.json exists and has valid keys
if [ ! -f "$AUTH_FILE" ]; then
    NEED_API_KEY=true
    info_msg "auth.json not found"
else
    # Check if file contains valid keys for both providers
    if ! grep -q '"zai-coding-plan"' "$AUTH_FILE" 2>/dev/null; then
        NEED_API_KEY=true
        info_msg "zai-coding-plan not found in auth.json"
    elif ! grep -q '"zhipuai-coding-plan"' "$AUTH_FILE" 2>/dev/null; then
        NEED_API_KEY=true
        info_msg "zhipuai-coding-plan not found in auth.json"
    else
        # Check if keys are non-empty
        ZAI_KEY=$(grep -A 3 '"zai-coding-plan"' "$AUTH_FILE" | grep '"key"' | sed 's/.*"key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
        ZHIPU_KEY=$(grep -A 3 '"zhipuai-coding-plan"' "$AUTH_FILE" | grep '"key"' | sed 's/.*"key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
        
        if [ -z "$ZAI_KEY" ] || [ -z "$ZHIPU_KEY" ]; then
            NEED_API_KEY=true
            info_msg "API key is empty in auth.json"
        else
            success_msg "API key found in auth.json"
        fi
    fi
fi

# Prompt for API key if needed
if [ "$NEED_API_KEY" = true ]; then
    echo ""
    warning_msg "请输入 API Key，用于 zai-coding-plan 和 zhipuai-coding-plan"
    info_msg "同一个 key 可同时用于两个服务"
    echo ""
    
    while true; do
        read -p "API Key: " INPUT_API_KEY
        
        # Trim whitespace
        INPUT_API_KEY=$(trim "$INPUT_API_KEY")
        
        if [ -z "$INPUT_API_KEY" ]; then
            echo ""
            error_exit "未输入 API Key，脚本终止。请重新运行脚本并输入有效的 API Key。"
        fi
        
        # Create auth.json with the key
        cat > "$AUTH_FILE" << EOF
{
  "zai-coding-plan": {
    "type": "api",
    "key": "${INPUT_API_KEY}"
  },
  "zhipuai-coding-plan": {
    "type": "api",
    "key": "${INPUT_API_KEY}"
  }
}
EOF
        chmod 600 "$AUTH_FILE"
        success_msg "API Key saved to auth.json"
        break
    done
fi

# Step 2: Handle container start/restart
info_msg "Checking container status..."

if is_container_running; then
    if [ "$FORCE_RESTART" = true ]; then
        info_msg "Restarting container..."
        docker-compose restart
        success_msg "Container restarted successfully"
    else
        echo ""
        warning_msg "Container '$CONTAINER_NAME' is already running"
        read -p "Do you want to restart it? [y/N]: " RESTART_CHOICE
        
        case "$RESTART_CHOICE" in
            y|Y|yes|YES)
                info_msg "Restarting container..."
                docker-compose restart
                success_msg "Container restarted successfully"
                ;;
            *)
                info_msg "Keeping container running"
                success_msg "Container is running at http://localhost:4097"
                ;;
        esac
    fi
else
    # Container is not running
    if container_exists; then
        info_msg "Container exists but is not running, starting..."
    else
        info_msg "Building and starting container..."
    fi
    
    docker-compose up -d --build
    success_msg "Container started successfully"
fi

# Step 3: Show status
echo ""
info_msg "Container status:"
docker-compose ps

echo ""
success_msg "Access OpenCode at: http://localhost:4097"
info_msg "To enter container: docker exec -it $CONTAINER_NAME bash"
info_msg "To view logs: docker-compose logs -f"
