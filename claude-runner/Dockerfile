FROM node:24-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV ASTRO_TELEMETRY_DISABLED=1
ENV DISABLE_OPENCOLLECTIVE=1
ENV ADBLOCK=1
ENV NEXT_TELEMETRY_DISABLED=1
ENV NPM_CONFIG_STORE_DIR=/pnpm-store

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    chromium \
    coreutils \
    curl \
    fd-find \
    findutils \
    fzf \
    g++ \
    gcc \
    git \
    grep \
    jq \
    less \
    lsof \
    make \
    nano \
    openssh-client \
    procps \
    psmisc \
    python3 \
    python3-pip \
    ripgrep \
    rsync \
    sed \
    tar \
    tree \
    unzip \
    vim \
    wget \
    xz-utils \
    zip \
  && rm -rf /var/lib/apt/lists/* \
  && ln -sf /usr/bin/fdfind /usr/local/bin/fd

RUN npm install -g @anthropic-ai/claude-code pnpm figma-developer-mcp

ARG RALPHEX_VERSION=0.26.3
RUN ARCH="$(dpkg --print-architecture)" && \
    curl -sL "https://github.com/umputun/ralphex/releases/download/v${RALPHEX_VERSION}/ralphex_${RALPHEX_VERSION}_linux_${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin ralphex && \
    chmod +x /usr/local/bin/ralphex

COPY run-all-plans.sh /usr/local/bin/run-all-plans
RUN chmod +x /usr/local/bin/run-all-plans

# Create a user matching host UID/GID so files written to /workspace
# and the container home have correct ownership.
ARG CLAUDE_UID=1001
ARG CLAUDE_GID=1001
RUN if ! getent group "${CLAUDE_GID}" >/dev/null; then \
      groupadd -g "${CLAUDE_GID}" claude; \
    fi && \
    useradd -m -u "${CLAUDE_UID}" -g "${CLAUDE_GID}" -s /bin/bash claude && \
    chmod 0755 /home/claude
USER claude

WORKDIR /workspace

ENTRYPOINT ["claude"]
