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

# Get container name for this site
container_name="wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g')"

# Check if container is running
if ! docker ps --format "table {{.Names}}" | grep -q "^$container_name$" 2>/dev/null; then
	log_error "Site container '$container_name' is not running. Please run 'sail up' first."
	exit 1
fi

# If no arguments provided, show wp help
if [[ $# -eq 0 ]]; then
	log_info "Running WP-CLI help for site $DOMAIN..."
	docker compose exec "$container_name" wp --help --allow-root
	exit 0
fi

# Run wp command with all arguments passed through
log_info "Running WP-CLI command for site $DOMAIN..."
docker compose exec "$container_name" wp "$@" --allow-root
