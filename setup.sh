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
    error "Config file not found. Copy config.env.example to config.env and customize it."
fi

source "$CONFIG_FILE"

# Validate required vars
required_vars=(DOMAIN SSL_EMAIL WP_PORT MYSQL_PORT CONTAINER_PREFIX WP_DB_NAME WP_DB_USER WP_DB_PASSWORD MYSQL_ROOT_PASSWORD SSH_HOST)
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        error "Missing required variable: $var"
    fi
done

# Check for placeholder passwords
if [[ "$WP_DB_PASSWORD" == "CHANGE_ME"* ]] || [[ "$MYSQL_ROOT_PASSWORD" == "CHANGE_ME"* ]]; then
    error "Please change the default passwords in config.env"
fi

log "Starting WordPress deployment for ${DOMAIN}"

# Create remote directory
REMOTE_DIR="/opt/wp-deployments/${CONTAINER_PREFIX}"
log "Creating remote directory: ${REMOTE_DIR}"
ssh "$SSH_HOST" "mkdir -p ${REMOTE_DIR}"

# Generate nginx config from template
log "Generating nginx config"
NGINX_CONF=$(sed \
    -e "s/{{DOMAIN}}/${DOMAIN}/g" \
    -e "s/{{WP_PORT}}/${WP_PORT}/g" \
    "${SCRIPT_DIR}/templates/nginx.conf.template")

# Copy docker-compose.yml
log "Copying docker-compose.yml to remote"
scp "${SCRIPT_DIR}/docker-compose.yml" "${SSH_HOST}:${REMOTE_DIR}/"

# Copy config.env for docker-compose
log "Copying config.env to remote"
scp "${CONFIG_FILE}" "${SSH_HOST}:${REMOTE_DIR}/.env"

# Setup nginx config
NGINX_CONF_NAME="${DOMAIN//./-}.conf"
log "Setting up nginx config: ${NGINX_CONF_NAME}"
echo "$NGINX_CONF" | ssh "$SSH_HOST" "sudo tee ${NGINX_SITES_AVAILABLE}/${NGINX_CONF_NAME} > /dev/null"
ssh "$SSH_HOST" "sudo ln -sf ${NGINX_SITES_AVAILABLE}/${NGINX_CONF_NAME} ${NGINX_SITES_ENABLED}/"

# Test and reload nginx
log "Testing nginx config"
ssh "$SSH_HOST" "sudo nginx -t"
ssh "$SSH_HOST" "sudo systemctl reload nginx"

# Check if SSL cert already exists
log "Checking SSL certificate"
CERT_EXISTS=$(ssh "$SSH_HOST" "sudo test -f /etc/letsencrypt/live/${DOMAIN}/fullchain.pem && echo 'yes' || echo 'no'")

if [[ "$CERT_EXISTS" == "no" ]]; then
    log "Obtaining SSL certificate via Let's Encrypt"
    ssh "$SSH_HOST" "sudo certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email ${SSL_EMAIL}"
else
    warn "SSL certificate already exists for ${DOMAIN}, skipping certbot"
fi

# Start containers
log "Starting Docker containers"
ssh "$SSH_HOST" "cd ${REMOTE_DIR} && docker compose up -d"

# Wait for containers to be healthy
log "Waiting for containers to start..."
sleep 10

# Check container status
log "Container status:"
ssh "$SSH_HOST" "docker ps --filter name=${CONTAINER_PREFIX}"

# Test HTTPS
log "Testing HTTPS endpoint"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
    log "WordPress is accessible at https://${DOMAIN}"
elif [[ "$HTTP_CODE" == "502" ]]; then
    warn "Got 502 - containers may still be starting. Check: docker logs ${CONTAINER_PREFIX}_wordpress"
else
    warn "Got HTTP ${HTTP_CODE} - check configuration"
fi

echo ""
log "========================================="
log "Deployment complete!"
log "URL: https://${DOMAIN}"
log "Remote dir: ${REMOTE_DIR}"
log "========================================="
