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
    jq \
    software-properties-common \
    gpg \
    wget \
    sqlite3 \
    ripgrep \
    fd-find \
    bat \
    fzf \
    net-tools \
    iputils-ping \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Configure git globally (system-level, applies to all users)
RUN git config --system user.email "buwai.bw@qq.com" && \
    git config --system user.name "buwai"

# Install gosu for privilege dropping
RUN curl -fsSL https://github.com/tianon/gosu/releases/download/1.17/gosu-$(dpkg --print-architecture) -o /usr/local/bin/gosu && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true

# Install Python 3.14 from Deadsnakes PPA
RUN curl --retry 5 --retry-delay 3 -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" | gpg --dearmor -o /usr/share/keyrings/deadsnakes.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/deadsnakes.gpg] http://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu jammy main" > /etc/apt/sources.list.d/deadsnakes-ppa.list && \
    apt-get update && apt-get install -y \
    python3.14 \
    python3.14-venv \
    python3.14-dev \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3.14 /usr/bin/python3 && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3 && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

# Install basedpyright globally
RUN pip3 install --break-system-packages basedpyright && pip3 show basedpyright

# Install Node.js (NodeSource) for serve package
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install serve globally
RUN npm install -g serve && npm install -g bash-language-server typescript-language-server


# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Install OpenCode (will be replaced later)
# RUN curl -fsSL https://opencode.ai/install | bash
RUN curl -fsSL https://raw.githubusercontent.com/anomalyco/opencode/refs/heads/dev/install | bash

# Create user 'aiuser' with sudo access
RUN useradd -m -s /bin/bash aiuser && \
    echo "aiuser:Lcnihao2010" | chpasswd && \
    echo "aiuser ALL=(ALL) ALL" >> /etc/sudoers

# Copy opencode and bun from root to aiuser's home
# Install scripts run as root, installing to /root/.opencode and /root/.bun
# Container starts as root at runtime, entrypoint drops privileges via gosu
# So we copy these tools to /home/aiuser for aiuser to use after privilege drop
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
    /home/aiuser/.bun/bin/bunx oh-my-opencode install --no-tui --claude=no --gemini=no --copilot=no --openai=no --opencode-zen=no --zai-coding-plan=yes

# Restore opencode binary after oh-my-opencode install
# Reason: oh-my-opencode may replace the opencode binary with a different version
# We need to restore the original binary that supports --unmatched-request-proxy
RUN cp /root/.opencode/bin/opencode /home/aiuser/.opencode/bin/opencode && \
    rm -rf /root/.opencode
# Configure ll command as global executable
RUN printf '#!/bin/sh\nexec ls -ahl "$@"' > /usr/local/bin/ll && chmod +x /usr/local/bin/ll
# Ensure proper ownership
RUN chown -R aiuser:aiuser /home/aiuser

# Add PATH to aiuser's .profile for login shells (gosu su - aiuser)
# Note: .bashrc has early return for non-interactive shells, so we use .profile
RUN echo '# Custom PATH for aiuser (bun, opencode, npm-global)' >> /home/aiuser/.profile && \
    echo 'export PATH="/home/aiuser/.npm-global/bin:/home/aiuser/.opencode/bin:/home/aiuser/.bun/bin:$PATH"' >> /home/aiuser/.profile && \
    # Fix bunx symlink (points to /root/.bun/bin/bun by default, aiuser can't access)
    rm -f /home/aiuser/.bun/bin/bunx && \
    ln -s /home/aiuser/.bun/bin/bun /home/aiuser/.bun/bin/bunx

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 lib/ /usr/local/lib/
COPY --chmod=755 opencode-run.sh /usr/local/bin/opencode-run.sh


# Set PATH environment variable for runtime
ENV PATH="/home/aiuser/.npm-global/bin:/home/aiuser/.opencode/bin:/home/aiuser/.bun/bin:$PATH"

# Use entrypoint to configure Git with GitHub Token
# Container starts as root, entrypoint drops privileges via gosu
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Expose ports (4096 for opencode web, 4173 for serve)
EXPOSE 4096 4173
