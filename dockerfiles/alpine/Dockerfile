# Rootless Caddy - OpenShift Compatible Container Image
#
# IMPORTANT: This Dockerfile only provides rootless container configuration.
# All Caddy code, binaries, and functionality are created and maintained by:
#   - The Caddy Project: https://caddyserver.com/
#   - Caddy GitHub: https://github.com/caddyserver/caddy
#   - Official Caddy Docker: https://github.com/caddyserver/caddy-docker
#
# This file adds minimal modifications (~40 lines) to enable:
#   - Rootless operation (non-root user)
#   - OpenShift compatibility (arbitrary UID support)
#   - Security best practices (non-privileged ports)
#
# All credit for Caddy's amazing functionality goes to the Caddy development team.
# This repository only provides container deployment configurations.

FROM caddy:2-alpine

LABEL maintainer="Caddy Rootless Project"
LABEL org.opencontainers.image.source="https://github.com/i5okie/caddy-rootless"
LABEL org.opencontainers.image.description="Rootless Caddy image compatible with OpenShift and Kubernetes"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="Caddy Rootless"
LABEL org.opencontainers.image.url="https://github.com/i5okie/caddy-rootless"
LABEL org.opencontainers.image.base.name="docker.io/library/caddy:2-alpine"

# Create non-root user with UID 1001 and root group (GID 0)
# OpenShift will override the UID but keep GID=0
# The -D flag creates a system user without password
# The -H flag prevents creating a home directory
RUN adduser -D -u 1001 -g 0 -H -h /data caddy

# Set ownership to 1001:0 (user:root-group) for OpenShift compatibility
# OpenShift assigns arbitrary UIDs but always uses GID=0 (root group)
# The root group has no special privileges despite the name
RUN chown -R 1001:0 /data /config /etc/caddy /usr/share/caddy /srv && \
    chmod -R ug+rwX /data /config /etc/caddy /usr/share/caddy /srv

# Ensure Caddy binary is executable by user and group
RUN chmod ug+x /usr/bin/caddy

# Remove file capabilities set by base image (incompatible with OpenShift)
# OpenShift's Security Context Constraints don't allow capabilities on binaries
# This prevents "operation not permitted" errors in OpenShift
RUN setcap -r /usr/bin/caddy || true

# Create additional directories that may be needed for logging and state
RUN mkdir -p /var/log/caddy /var/lib/caddy && \
    chown -R 1001:0 /var/log/caddy /var/lib/caddy && \
    chmod -R ug+rwX /var/log/caddy /var/lib/caddy

# Copy default Caddyfile configured for non-privileged ports
# Users can override this by mounting their own Caddyfile at /etc/caddy/Caddyfile
COPY --chown=1001:0 --chmod=664 config/Caddyfile /etc/caddy/Caddyfile

# Expose non-privileged ports (rootless containers cannot bind to ports < 1024)
# Configure these ports in your Caddyfile with http_port and https_port directives
# 8080: HTTP, 8443: HTTPS (TCP), 8443/udp: HTTP/3 (QUIC), 2019: Admin API
EXPOSE 8080 8443 8443/udp 2019

# Switch to non-root user
# OpenShift will override this UID with an arbitrary one, but keep GID=0
USER 1001

# Inherit CMD from base image: caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
# No need to redefine unless you want to change the default behavior
