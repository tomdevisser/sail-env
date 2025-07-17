#!/bin/bash

# Terminate the script immediately if a command exits with an error
set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../../.." && pwd)"

source "$root_dir/bin/lib/common.sh"

site_name=$1

if [[ -z "$site_name" ]]; then
	log_error "No site name provided. Usage: sail site remove <name>"
	exit 1
fi

site_name_clean=$(echo "$site_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

site_dir="$root_dir/sites/$site_name_clean"
site_domain="$site_name_clean.sail"
nginx_conf_file="$root_dir/nginx_sites/$site_domain.conf"
nginx_pma_conf="$root_dir/nginx_sites/pma.$site_domain.conf"
cert_dir="$root_dir/certs"

# Check if the site exists
if [[ ! -d "$site_dir" ]]; then
	log_error "Site '$site_name_clean' does not exist."
	exit 1
fi

# Confirmation prompt
log_info "This will remove the site '$site_name_clean' and all its data."
read -p "Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	log_info "Operation cancelled."
	exit 0
fi

# Stop and remove containers
log_info "Stopping and removing containers for $site_domain..."
if [[ -f "$site_dir/docker-compose.yml" ]]; then
	pushd "$site_dir" > /dev/null
	docker compose down -v
	popd > /dev/null
else
	log_info "No docker-compose.yml found, skipping container removal."
fi

# Remove nginx configurations
log_info "Removing nginx configurations..."
rm -f "$nginx_conf_file"
rm -f "$nginx_pma_conf"

# Remove certificates
log_info "Removing certificates..."
rm -f "$cert_dir/$site_domain.pem"
rm -f "$cert_dir/$site_domain-key.pem"
rm -f "$cert_dir/pma.$site_domain.pem"
rm -f "$cert_dir/pma.$site_domain-key.pem"

# Remove from /etc/hosts
log_info "Removing from /etc/hosts..."
if grep -q "$site_domain" /etc/hosts; then
	sudo sed -i '' "/$site_domain/d" /etc/hosts
	log_success "$site_domain removed from /etc/hosts."
else
	log_info "$site_domain not found in /etc/hosts."
fi

# Remove site directory
log_info "Removing site directory..."
rm -rf "$site_dir"

# Restart nginx proxy
log_info "Restarting nginx proxy..."
docker restart sail_proxy > /dev/null 2>&1

log_success "Site '$site_name_clean' has been completely removed."
