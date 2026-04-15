FROM ghcr.io/openclaw/openclaw:slim

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ca-certificates \
  chromium \
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
ARG KUBECTL_VERSION=1.32.3
ARG OP_VERSION=2.30.0

RUN ARCH="$(dpkg --print-architecture)" \
  && case "$ARCH" in \
  amd64) GH_ARCH='amd64'; HELM_ARCH='amd64'; OP_ARCH='amd64' ;; \
  arm64) GH_ARCH='arm64'; HELM_ARCH='arm64'; OP_ARCH='arm64' ;; \
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
  esac \
  && curl -fsSL -o /tmp/gh.deb "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.deb" \
  && dpkg -i /tmp/gh.deb \
  && rm -f /tmp/gh.deb \
  && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz" -o /tmp/helm.tgz \
  && tar -xzf /tmp/helm.tgz -C /tmp \
  && install -m 0755 "/tmp/linux-${HELM_ARCH}/helm" /usr/local/bin/helm \
  && rm -rf /tmp/helm.tgz "/tmp/linux-${HELM_ARCH}" \
  && curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" -o /tmp/kubectl \
  && install -m 0755 /tmp/kubectl /usr/local/bin/kubectl \
  && rm -f /tmp/kubectl \
  && curl -fsSL "https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_VERSION}/op_linux_${OP_ARCH}_v${OP_VERSION}.zip" -o /tmp/op.zip \
  && unzip -j /tmp/op.zip op -d /usr/local/bin \
  && chmod 0755 /usr/local/bin/op \
  && rm -f /tmp/op.zip

USER node

