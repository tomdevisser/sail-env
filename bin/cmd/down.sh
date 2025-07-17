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

# Check if containers are running
running_containers=$(docker compose ps -q 2>/dev/null)

if [[ -z "$running_containers" ]]; then
	log_error "No containers are currently running for site $DOMAIN."
	exit 1
fi

# Stop the site's containers
log_info "Stopping site containers for $DOMAIN..."
docker compose down > /dev/null 2>&1
log_success "Site $DOMAIN containers have been stopped."
