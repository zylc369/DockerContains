# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-12
**Commit:** HEAD
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

## CONVENTIONS
- All services use docker-compose.yml for orchestration
- Shell scripts for container lifecycle management
- No CI/CD workflows or Makefile (manual Docker-based)
- No test infrastructure present
- Configuration via .env files and docker-compose environment variables

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT hardcode GITHUB_TOKEN in Dockerfile or scripts (ai-container)
- DO NOT run containers as root user (ai-container uses 'aiuser')
- DO NOT forget to create data volume directories before starting containers

## UNIQUE STYLES
- Custom OpenCode installation with zylc369 fork (ai-container)
- Dual-process startup (opencode web + serve)
- AI user management with sudo access
- Custom entrypoint script for Git authentication

## COMMANDS
```bash
# AI container
cd ai-container
./start.sh          # Start/restart container
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
- Port conflicts: OpenCode (4096), Gitea (3000), OpenList (5244)
- All containers use non-root users where applicable
- Environment variables required: GITHUB_TOKEN, OPLISTDX_* vars
- No standard development/testing setup - pure infrastructure as code
