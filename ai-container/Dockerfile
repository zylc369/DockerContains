FROM ubuntu:22.04

# Set non-interactive mode
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages (using Aliyun mirror for ARM compatibility)
RUN sed -i 's|ports.ubuntu.com|mirrors.aliyun.com|g' /etc/apt/sources.list && \
    sed -i 's|archive.ubuntu.com|mirrors.aliyun.com|g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y \
    curl \
    lsof \
    git \
    ca-certificates \
    sudo \
    unzip \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (NodeSource) for serve package
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install serve globally
RUN npm install -g serve


# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Install OpenCode (will be replaced later)
# RUN curl -fsSL https://opencode.ai/install | bash
RUN curl -fsSL https://raw.githubusercontent.com/zylc369/opencode/refs/heads/feature/optimization_v1_1/install-zylc369 | bash

# Create user 'aiuser' with sudo access
RUN useradd -m -s /bin/bash aiuser && \
    echo "aiuser:Lcnihao2010" | chpasswd && \
    echo "aiuser ALL=(ALL) ALL" >> /etc/sudoers

# Copy opencode and bun from root to aiuser's home
# Reason: Install scripts run as root, installing to /root/.opencode and /root/.bun
# But the container runs as 'aiuser' (see USER aiuser below), who cannot access /root
# So we copy these tools to /home/aiuser so aiuser can use them at runtime
RUN mkdir -p /home/aiuser/.opencode && \
    mkdir -p /home/aiuser/.config/opencode && \
    mkdir -p /home/aiuser/Codes/ai-doctor/notes && \
    cp -r /root/.opencode/* /home/aiuser/.opencode/ && \
    mkdir -p /home/aiuser/.bun && \
    (cp -r /root/.bun/* /home/aiuser/.bun/ 2>/dev/null || true) && \
    # Configure npm to use user directory for global packages (avoids sudo requirement)
    mkdir -p /home/aiuser/.npm-global && \
    echo "prefix=/home/aiuser/.npm-global" > /home/aiuser/.npmrc

# Switch to user directory
WORKDIR /home/aiuser

# Install oh-my-opencode (with OpenCode Zen for free models)
RUN cd /home/aiuser && \
    /home/aiuser/.bun/bin/bunx oh-my-opencode install --no-tui --claude=no --openai=no --gemini=no --copilot=no --opencode-zen=yes

# Restore opencode binary after oh-my-opencode install
# Reason: oh-my-opencode may replace the opencode binary with a different version
# We need to restore the original binary that supports --unmatched-request-proxy
RUN cp /root/.opencode/bin/opencode /home/aiuser/.opencode/bin/opencode
# Configure ll command as global executable
RUN printf '#!/bin/sh\nexec ls -ahl "$@"' > /usr/local/bin/ll && chmod +x /usr/local/bin/ll
# Ensure proper ownership
RUN chown -R aiuser:aiuser /home/aiuser

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set PATH environment variable for runtime
ENV PATH="/home/aiuser/.npm-global/bin:/home/aiuser/.opencode/bin:/home/aiuser/.bun/bin:$PATH"

# Switch to non-root user
USER aiuser

# Use entrypoint to configure Git with GitHub Token
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Expose ports (4096 for opencode web, 4173 for serve)
EXPOSE 4096 4173
