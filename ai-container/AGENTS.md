# Docker/Container Agent Guide

**Location:** `containers/ai-container/`

**Purpose:** Development environment for AI coding assistant with Ubuntu 22.04, Node.js, Bun, OpenCode, and oh-my-opencode.

---

## Overview

Containerized development environment running OpenCode web interface (port 4096) with serve on port 4173.

---

## Where to Look

**Entry Points:**
- `start.sh` — Start/restart container, prompts for GITHUB_TOKEN
- `rebuild.sh` — Full container rebuild with cache clear
- `docker_log_search.sh` — View recent container logs

**Configuration:**
- `Dockerfile` — Base image setup, user creation, package installation
- `docker-compose.yml` — Service definition, port mappings, volume mounts
- `entrypoint.sh` — Git authentication setup with GITHUB_TOKEN
- `.env` — GitHub token storage (created by start.sh)

**Data Persistence:**
- `./data/home/data/ai-doctor-notes` — Notes directory
- `./data/home/.cache/opencode` — OpenCode cache
- `./data/home/.config/opencode` — OpenCode configuration
- `./data/home/.local/share/opencode` — OpenCode data
- `./data/home/.local/state/opencode` — OpenCode state

---

## Common Commands

```bash
cd containers/ai-container

# Start container (prompts for token if needed)
./start.sh

# Restart container if running
./start.sh --restart

# Full rebuild
./rebuild.sh

# View logs
docker-compose logs -f

# Enter container
docker exec -it ai-container bash
```

---

## Anti-Patterns

- DO NOT hardcode GITHUB_TOKEN in Dockerfile or scripts
- DO NOT run container as root user (aiuser only)
- DO NOT forget to create data volume directories before starting
