#!/bin/bash

# Terminate the script immediately if a command exits with an error
set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../../.." && pwd)"

source "$root_dir/bin/lib/common.sh"

site_name=$1

if [[ -z "$site_name" ]]; then
	log_error "No site name provided. Usage: sail site add <name>"
	exit 1
fi

site_name_clean=$(echo "$site_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

site_dir="$root_dir/sites/$site_name_clean"
site_domain="$site_name_clean.sail"
conf_file="$site_dir/sail.conf"
nginx_conf_file="$root_dir/nginx_sites/$site_domain.conf"
template_conf="$root_dir/config/sail.template.conf"
nginx_template="$root_dir/config/nginx/default.template.conf"
phpmyadmin_template="$root_dir/config/nginx/phpmyadmin.template.conf"
nginx_pma_conf="$root_dir/nginx_sites/pma.$site_domain.conf"
docker_template="$root_dir/config/docker/site.template.yml"
site_compose_file="$site_dir/docker-compose.yml"
xdebug_template="$root_dir/config/php/xdebug.template.ini"
xdebug_dest="$site_dir/xdebug.ini"

# Check if the site already exists
if [[ -d "$site_dir" ]]; then
	log_error "Site '$site_name_clean' already exists."
	exit 1
fi

# Create folder structure
log_info "Creating site structure in $site_dir..."
mkdir -p "$site_dir/plugins" "$site_dir/theme" "$site_dir/uploads" "$site_dir/database" "$site_dir/.vscode"

# Copy VSCode launch template
log_info "Configuring VSCode launch settings..."
cp "$root_dir/config/.vscode/launch.template.json" "$site_dir/.vscode/launch.json"

# Create sail.conf from template
log_info "Generating sail.conf..."
sed "s/^DOMAIN=.*/DOMAIN=$site_domain/" "$template_conf" > "$conf_file"

# Generate nginx config
log_info "Generating nginx config for $site_domain..."
sed \
	-e "s/\$domain/$site_domain/g" \
	-e "s/\$site_name_clean/$site_name_clean/g" \
	"$nginx_template" > "$nginx_conf_file"

# Generate phpMyAdmin config
log_info "Generating nginx config for phpMyAdmin at pma.$site_domain..."
sed "s/\$domain/$site_domain/g" "$phpmyadmin_template" > "$nginx_pma_conf"

# Generate site nginx config
log_info "Generating site nginx config..."
sed "s/\$site_name_clean/$site_name_clean/g" "$root_dir/config/nginx/site.template.conf" > "$site_dir/nginx.conf"

# Generate Docker Compose
log_info "Generating docker-compose.yml..."
sed "s/\$domain/$site_name_clean/g" "$docker_template" > "$site_compose_file"

# Generate xdebug.ini
if [[ -f "$xdebug_template" ]]; then
	log_info "Copying xdebug.ini..."
	cp "$xdebug_template" "$xdebug_dest"
fi

# Generate certificate for site
log_info "Adding $site_domain to trusted certificate via mkcert..."
cert_dir="$root_dir/certs"

pushd "$cert_dir" >/dev/null

mkcert "$site_domain" > /dev/null 2>&1
cert_file=$(ls -t "$site_domain"*.pem | grep -v 'key' | head -n1)
key_file=$(ls -t "$site_domain"*-key.pem | head -n1)

if [[ -f "$cert_file" && -f "$key_file" ]]; then
	log_success "Certificate generated for $site_domain."
else
	log_error "Failed to generate certificate for $site_domain."
	exit 1
fi

# Generate certificate for pma.$site_domain
log_info "Adding pma.$site_domain to trusted certificate via mkcert..."
mkcert "pma.$site_domain" > /dev/null 2>&1
cert_file=$(ls -t "pma.$site_domain"*.pem | grep -v 'key' | head -n1)
key_file=$(ls -t "pma.$site_domain"*-key.pem | head -n1)

if [[ -f "$cert_file" && -f "$key_file" ]]; then
	log_success "Certificate generated for pma.$site_domain."
else
	log_error "Failed to generate certificate for pma.$site_domain."
	exit 1
fi

popd >/dev/null

# Add domain to /etc/hosts if not already present
if ! grep -q "$site_domain" /etc/hosts; then
	echo "127.0.0.1 $site_domain pma.$site_domain" | sudo tee -a /etc/hosts > /dev/null
	log_success "$site_domain added to /etc/hosts."
else
	log_info "$site_domain already exists in /etc/hosts."
fi

log_success "Site '$site_name_clean' added. You can now start the site by running 'sail up' from within the site's directory."
log_info "cd sites/$site_name_clean && sail up"
