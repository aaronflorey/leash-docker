FROM public.ecr.aws/s5i7k8t3/strongdm/coder:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV MISE_DATA_DIR=/opt/leash/mise/data
ENV MISE_CONFIG_DIR=/opt/leash/mise/config
ENV MISE_CACHE_DIR=/opt/leash/mise/cache
ENV PATH="/opt/leash/mise/data/shims:/usr/local/bin:${PATH}"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash \
        git \
        xz-utils; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /opt/leash/mise/data /opt/leash/mise/config /opt/leash/mise/cache; \
    chmod -R 0777 /opt/leash; \
    curl https://mise.run | sh; \
    ln -sf /root/.local/bin/mise /usr/local/bin/mise; \
    mise --version; \
    curl -fsSL https://raw.githubusercontent.com/aaronflorey/bin/master/install.sh | sh; \
    /usr/local/bin/bin install --force github.com/cli/cli /usr/local/bin/gh; \
    gh --version

COPY entrypoint.sh /etc/profile.d/leash-mise.sh

RUN chmod 0644 /etc/profile.d/leash-mise.sh
