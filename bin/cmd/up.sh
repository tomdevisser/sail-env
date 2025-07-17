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
docker compose up -d > /dev/null 2>&1

# Wait for containers to be ready
log_info "Waiting for containers to start..."
sleep 5

# Get container name for this site
container_name="wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g')"

# Check if WordPress is installed
log_info "Checking WordPress installation status..."
if ! docker compose exec "$container_name" wp core is-installed --allow-root > /dev/null 2&>1; then
	log_info "WordPress not installed. Installing with default values..."
	
	# Install WordPress with default values
	docker compose exec "$container_name" wp core install \
		--url="https://$DOMAIN" \
		--title="$DOMAIN - Development Site" \
		--admin_user="admin" \
		--admin_password="admin" \
		--admin_email="admin@$DOMAIN" \
		--allow-root \
		> /dev/null 2>&1
	
	log_success "WordPress installed with default credentials (admin/admin)."
	log_info "Note: These credentials will be overwritten when you run 'sail sync --db'."
else
	log_info "WordPress is already installed."
fi

# Restart the main nginx proxy to reload configurations
log_info "Restarting nginx proxy to reload configurations..."
docker restart sail_proxy > /dev/null 2>&1

echo ""

log_success "Site $DOMAIN is now running at https://$DOMAIN!"
log_success "phpMyAdmin is now running at https://pma.$DOMAIN!"

echo ""
log_info "To synchronize your website with your staging environment, use 'sail sync'."
