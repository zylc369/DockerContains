#!/bin/bash
set -e

docker logs ai-container 2>&1 | head -50