FROM node:9.5.0-alpine as builder

ENV NODE_ENV production

WORKDIR /kubebox

COPY lib lib/
COPY package.json package-lock.json index.js ./

RUN npm install
RUN npm install -g browserify
RUN npm run bundle

FROM alpine:3.7

ENV TERM xterm-256color
ENV LANG C.UTF-8

# kubernetes tools

# Note: Latest version of kubectl may be found at:
# https://aur.archlinux.org/packages/kubectl-bin/
ENV KUBE_LATEST_VERSION="v1.10.2"
# Note: Latest version of helm may be found at:
# https://github.com/kubernetes/helm/releases
ENV HELM_VERSION="v2.9.1"

RUN apk add --no-cache ca-certificates bash git curl gnupg \
    && wget -q https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && wget -q http://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && helm init --client-only \
    && helm plugin install https://github.com/futuresimple/helm-secrets

# Node.js
COPY --from=builder /usr/local/bin/node /usr/local/bin/
COPY --from=builder /usr/lib/libgcc* /usr/lib/libstdc* /usr/lib/

# Kubebox
COPY --from=builder /kubebox/bundle.js /kubebox/client.js

RUN addgroup -g 1000 node && \
    adduser -u 1000 -G node -s /bin/sh -D node && \
    chown node:node /kubebox

WORKDIR /kubebox

USER node

ENTRYPOINT ["node", "client.js"]
