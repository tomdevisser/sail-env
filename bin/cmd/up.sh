#!/bin/bash

# Terminate the script immediately if a command exits with an error
set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
root_dir="$(cd "$script_dir/../.." && pwd)"

source "$root_dir/bin/lib/common.sh"

# Check if we're inside a valid site folder
if [[ ! -f "./sail.conf" ]]; then
	log_error "No sail.conf found. Are you in a site folder?"
	exit 1
fi

# Load site configuration
source ./sail.conf

if [[ -z "$DOMAIN" ]]; then
	log_error "DOMAIN not set in sail.conf."
	exit 1
fi

# Start the site's containers
log_info "Starting site for $DOMAIN..."
docker compose up -d

# Restart the main nginx proxy to reload configurations
log_info "Restarting nginx proxy to reload configurations..."
docker restart sail_proxy > /dev/null 2>&1

log_success "Site $DOMAIN is now running at https://$DOMAIN"
log_info "phpMyAdmin: https://pma.$DOMAIN"
