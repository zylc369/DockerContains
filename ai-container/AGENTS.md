# AI Container - OpenCode Development Environment

**Generated:** 2026-03-12
**Location:** `./ai-container/`

**Purpose:** Containerized AI coding assistant with Ubuntu 22.04, Node.js, Bun, OpenCode (zylc369 fork), and oh-my-opencode

---

## Overview

Containerized development environment running OpenCode web interface (port 4097→4096) with serve on port 4173.

---

## WHERE TO LOOK

**Entry Points:**
- `start.sh` — Start/restart container, prompts for GITHUB_TOKEN and API key
- `rebuild.sh` — Full container rebuild with cache clear
- `docker_log_search.sh` — View recent container logs

**Configuration:**
- `Dockerfile` — Base image setup, user creation, package installation
- `docker-compose.yml` — Service definition, port mappings, volume mounts
- `entrypoint.sh` — Git authentication, sparse checkout, auto-clone repos
- `.env` — GitHub token storage (created by start.sh)
- `data/home/.config/repos/repos.json` — Auto-clone repository config

**Data Persistence:**
- `./data/home/data/ai-doctor-notes` — Notes directory
- `./data/home/Codes/buwai-ai-extension` — Extensions (sparse checkout)
- `./data/home/Codes/DockerContains` — DockerContains repo (auto-pull)
- `./data/home/.cache/opencode` — OpenCode cache
- `./data/home/.config/opencode` — OpenCode configuration
- `./data/home/.local/share/opencode` — OpenCode data (auth.json here)
- `./data/home/.local/state/opencode` — OpenCode state

---

## UNIQUE STYLES

- **zylc369 fork** — Uses custom OpenCode fork, not official release
- **Dual-process startup** — opencode web (4096) + serve (4173)
- **Sparse checkout** — buwai-ai-extension only pulls `/extensions/` and install scripts
- **repos.json config** — Auto-clones repos defined in `~/.config/repos/repos.json`
- **DockerContains auto-pull** — Clones/updates parent repo on container startup
- **Interactive setup** — start.sh prompts for GITHUB_TOKEN and API key if missing

---

## COMMANDS
```bash
cd ai-container

# Start container (prompts for token/api key if needed)
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

## ANTI-PATTERNS

- DO NOT hardcode GITHUB_TOKEN in Dockerfile or scripts
- DO NOT run container as root user (aiuser only)
- DO NOT forget to create data volume directories before starting
- DO NOT use official OpenCode — use zylc369 fork (see Dockerfile)
- WARNING: Default password in Dockerfile line 50 (change for production)

---

## repos.json FORMAT

```json
{
  "repos": [
    {
      "url": "https://github.com/owner/repo",
      "branch": "main",
      "directory": "/home/aiuser/Codes/repo"
    }
  ]
}
```
