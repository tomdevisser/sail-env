#!/bin/bash

# Terminate the script immediately if a command exits with an error
set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../.." && pwd)"

source "$root_dir/bin/lib/common.sh"

cert_dir="$root_dir/certs"
log_dir="$root_dir/logs/nginx"
nginx_sites_dir="$root_dir/nginx_sites"
docker_compose_file="$root_dir/docker-compose.yml"
network_name="sailnet"
domain_wildcard="*.sail"

# Ensure required folders exist
log_info "Checking folder structure..."
mkdir -p "$cert_dir" "$log_dir" "$nginx_sites_dir"

# Ensure mkcert is installed
if ! command -v mkcert >/dev/null 2>&1; then
  log_info "mkcert not found. Installing via Homebrew..."
  brew install mkcert
fi

ca_file="$HOME/Library/Application Support/mkcert/rootCA.pem"
if [[ ! -f "$ca_file" ]]; then
  log_info "mkcert CA not found. Running mkcert -install..."
  mkcert -install
fi

log_success "mkcert is ready and root CA is trusted."

# Ensure Docker network
if ! docker network inspect "$network_name" >/dev/null 2>&1; then
	log_info "Creating Docker network '$network_name'"
	docker network create "$network_name" >/dev/null 2>&1
else
	log_success "Docker network '$network_name' already exists."
fi

# Start reverse proxy
log_info "Starting reverse proxy via Docker Compose..."
docker compose -f "$docker_compose_file" up -d

log_success "Sail system initialized. Ready to create and run sites."
