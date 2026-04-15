FROM ghcr.io/openclaw/openclaw:slim

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  jq \
  less \
  procps \
  ripgrep \
  sqlite3 \
  tar \
  gzip \
  unzip \
  openssh-client \
  && rm -rf /var/lib/apt/lists/*

ARG GH_VERSION=2.74.2
ARG HELM_VERSION=3.18.4

RUN ARCH="$(dpkg --print-architecture)" \
  && case "$ARCH" in \
  amd64) GH_ARCH='amd64'; HELM_ARCH='amd64' ;; \
  arm64) GH_ARCH='arm64'; HELM_ARCH='arm64' ;; \
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
  esac \
  && curl -fsSL -o /tmp/gh.deb "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.deb" \
  && dpkg -i /tmp/gh.deb \
  && rm -f /tmp/gh.deb \
  && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz" -o /tmp/helm.tgz \
  && tar -xzf /tmp/helm.tgz -C /tmp \
  && install -m 0755 "/tmp/linux-${HELM_ARCH}/helm" /usr/local/bin/helm \
  && rm -rf /tmp/helm.tgz "/tmp/linux-${HELM_ARCH}"

USER node

