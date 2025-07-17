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
cert_pem="$cert_dir/cert.pem"
key_pem="$cert_dir/key.pem"
network_name="sailnet"
domain_wildcard="*.sail"

# Ensure required folders exist
log_info "Checking folder structure..."
mkdir -p "$cert_dir" "$log_dir" "$nginx_sites_dir"

# Ensure mkcert is installed
if ! command -v mkcert >/dev/null 2>&1; then
  log_info "mkcert(nohlsearch) not found. Installing via Homebrew..."
  brew install mkcert
fi

ca_file="$HOME/Library/Application Support/mkcert/rootCA.pem"
if [[ ! -f "$ca_file" ]]; then
  log_info "mkcert CA not found. Running mkcert -install..."
  mkcert -install
fi

log_success "mkcert is ready and root CA is trusted."

# Generate certs with mkcert if missing
if [[ ! -f "$cert_pem" || ! -f "$key_pem" ]]; then
	log_info "Generating trusted certificate with mkcert for *.sail..."
	pushd "$cert_dir" >/dev/null
	mkcert "$domain_wildcard" "sail" >/dev/null 2>&1
	generated_cert=$(ls -t *.pem | grep -v 'key' | head -n1)
	generated_key=$(ls -t *-key.pem | head -n1)
	mv "$generated_cert" "$cert_pem"
	mv "$generated_key" "$key_pem"
	popd >/dev/null
	log_success "Trusted certificate generated successfully."
else
	log_success "Certificate already exists. Skipping generation."
fi

# Ensure Docker network
if ! docker network inspect "$network_name" >/dev/null 2>&1; then
	log_info "Creating Docker network '$network_name'"
	docker network create "$network_name" >/dev/null 2>&1
else
	log_success "Docker network '$network_name' already exists."
fi

# Start reverse proxy
log_info "Starting reverse proxy via Docker Compose..."
docker compose -f "$docker_compose_file" up -d >/dev/null 2>&1

log_success "Sail system initialized. Ready to create and run sites."
