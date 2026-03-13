# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-12
**Commit:** 9d6ab9c
**Branch:** main

## OVERVIEW
Docker containers repository with 3 services: AI development environment, Gitea Git hosting, and OpenList file management.

## STRUCTURE
```
./
├── ai-container/    # AI coding assistant dev environment (custom)
├── Gitea/          # Git hosting (standard Docker image)
└── OpenListNew/    # File management (standard Docker image)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| AI dev env | `ai-container/start.sh` | Entry point for AI container |
| Git hosting | `Gitea/docker-compose.yml` | Standard Gitea + PostgreSQL |
| File manager | `OpenListNew/docker-compose.yml` | OpenList + downloaders |
| Auto-clone repos | `ai-container/entrypoint.sh` | Reads ~/.config/repos/repos.json |

## CONVENTIONS
- All services use docker-compose.yml for orchestration
- Shell scripts for container lifecycle management
- No CI/CD workflows or Makefile (manual Docker-based)
- No test infrastructure present
- Configuration via .env files and docker-compose environment variables
- Environment variables: `GITHUB_TOKEN`, `OPLISTDX_*` prefix for OpenList
- Volume mount pattern: `./data/home/*` → `/home/aiuser/*`

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT hardcode GITHUB_TOKEN in Dockerfile or scripts (ai-container)
- DO NOT run containers as root user (ai-container uses 'aiuser')
- DO NOT forget to create data volume directories before starting containers
- DO NOT use official OpenCode — use zylc369 fork (see Dockerfile)
- WARNING: Default password in Dockerfile line 50 (should be changed for production)

## UNIQUE STYLES
- Custom OpenCode installation with zylc369 fork (ai-container)
- Dual-process startup (opencode web + serve)
- AI user management with sudo access
- Custom entrypoint script for Git authentication
- Sparse checkout for buwai-ai-extension repository
- Auto-clone repositories via repos.json config
- DockerContains auto-pull on container startup

## COMMANDS
```bash
# AI container
cd ai-container
./start.sh          # Start/restart container (interactive)
./start.sh --restart # Force restart
./rebuild.sh        # Full rebuild with cache clear
docker-compose logs -f
docker exec -it ai-container bash

# Gitea
cd Gitea
docker-compose up -d

# OpenList
cd OpenListNew
docker-compose up -d
```

## NOTES
- Port mappings: AI container (4097→4096), Gitea (3000, 222), OpenList (5244)
- All containers use non-root users where applicable
- Environment variables required: GITHUB_TOKEN, OPLISTDX_* vars
- No standard development/testing setup - pure infrastructure as code
- ai-container only custom service; Gitea/OpenList use pre-built images
