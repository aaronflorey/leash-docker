# syntax=docker/dockerfile:1.7

FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG VERSION=dev
ARG COMMIT=dev
ARG BUILD_DATE=unknown
ARG CHANNEL=main
ARG GIT_REMOTE_URL=unknown

ENV MISE_DATA_DIR=/opt/leash/mise/data
ENV MISE_CONFIG_DIR=/opt/leash/mise/config
ENV MISE_CACHE_DIR=/opt/leash/mise/cache
ENV BUN_INSTALL=/opt/leash/bun
ENV BUN_INSTALL_CACHE_DIR=/opt/leash/bun/cache
ENV PATH="/opt/leash/mise/data/shims:/opt/leash/bun/bin:/usr/local/bin:${PATH}"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash \
        bubblewrap \
        ca-certificates \
        curl \
        git \
        less \
        unzip \
        wget \
        xz-utils; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p \
        /opt/leash/mise/data \
        /opt/leash/mise/config \
        /opt/leash/mise/cache \
        /opt/leash/bun/cache; \
    chmod -R 0777 /opt/leash; \
    curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh; \
    curl -fsSL https://bun.sh/install | bash; \
    ln -sf /opt/leash/bun/bin/bun /usr/local/bin/bun; \
    mise --version; \
    bun --version; \
    rm -rf /root/.cache /tmp/*

COPY entrypoint.sh /etc/profile.d/leash-mise.sh
COPY iterm-title.sh /etc/profile.d/leash-iterm-title.sh
COPY scripts/runtime-entrypoint.sh /usr/local/bin/leash-runtime-entrypoint

RUN chmod 0644 /etc/profile.d/leash-mise.sh /etc/profile.d/leash-iterm-title.sh \
    && chmod 0755 /usr/local/bin/leash-runtime-entrypoint

LABEL org.opencontainers.image.version="v${VERSION}" \
      org.opencontainers.image.revision="${COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="${GIT_REMOTE_URL}" \
      org.opencontainers.image.ref.name="${CHANNEL}"

ENTRYPOINT ["/usr/local/bin/leash-runtime-entrypoint"]
CMD ["bash"]
