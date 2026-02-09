#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Config file not found: $CONFIG_FILE"
fi

source "$CONFIG_FILE"

REMOTE_DIR="/opt/wp-deployments/${CONTAINER_PREFIX}"
NGINX_CONF_NAME="${DOMAIN//./-}.conf"

# Confirm destruction
echo ""
warn "This will DESTROY the following:"
echo "  - Docker containers: ${CONTAINER_PREFIX}_wordpress, ${CONTAINER_PREFIX}_mysql"
echo "  - Docker volumes: ${CONTAINER_PREFIX}_wordpress_data, ${CONTAINER_PREFIX}_mysql_data"
echo "  - Nginx config: ${NGINX_CONF_NAME}"
echo "  - Remote directory: ${REMOTE_DIR}"
echo ""

if [[ "$1" != "--force" ]]; then
    read -p "Are you sure? Type 'yes' to confirm: " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        log "Aborted."
        exit 0
    fi
fi

log "Starting teardown for ${DOMAIN}"

# Stop and remove containers + volumes
log "Stopping Docker containers"
ssh "$SSH_HOST" "cd ${REMOTE_DIR} && docker compose down -v 2>/dev/null || true"

# Remove any orphan containers
log "Removing orphan containers"
ssh "$SSH_HOST" "docker rm -f ${CONTAINER_PREFIX}_wordpress ${CONTAINER_PREFIX}_mysql 2>/dev/null || true"

# Remove volumes
log "Removing Docker volumes"
ssh "$SSH_HOST" "docker volume rm ${CONTAINER_PREFIX}_wordpress_data ${CONTAINER_PREFIX}_mysql_data 2>/dev/null || true"

# Remove nginx config
log "Removing nginx config"
ssh "$SSH_HOST" "sudo rm -f ${NGINX_SITES_ENABLED}/${NGINX_CONF_NAME}"
ssh "$SSH_HOST" "sudo rm -f ${NGINX_SITES_AVAILABLE}/${NGINX_CONF_NAME}"

# Reload nginx
log "Reloading nginx"
ssh "$SSH_HOST" "sudo nginx -t && sudo systemctl reload nginx"

# Optionally remove SSL cert (commented out by default - certs are free to keep)
# log "Removing SSL certificate"
# ssh "$SSH_HOST" "sudo certbot delete --cert-name ${DOMAIN} --non-interactive || true"

# Remove remote directory
log "Removing remote directory"
ssh "$SSH_HOST" "rm -rf ${REMOTE_DIR}"

echo ""
log "========================================="
log "Teardown complete!"
log "Note: SSL cert kept (run 'certbot delete --cert-name ${DOMAIN}' to remove)"
log "========================================="
