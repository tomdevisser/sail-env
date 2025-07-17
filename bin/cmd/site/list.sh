#!/bin/bash

# Terminate the script immediately if a command exits with an error
set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../../.." && pwd)"

source "$root_dir/bin/lib/common.sh"

sites_dir="$root_dir/sites"

# Check if sites directory exists
if [[ ! -d "$sites_dir" ]]; then
    log_error "Sites directory not found at $sites_dir"
    exit 1
fi

# Get all site directories
sites=($(find "$sites_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))

if [[ ${#sites[@]} -eq 0 ]]; then
    log_info "No sites found. Use 'sail site add <name>' to create a new site."
    exit 0
fi

echo "Sites:"
echo "------"

for site in "${sites[@]}"; do
    site_dir="$sites_dir/$site"
    conf_file="$site_dir/sail.conf"
    
    # Skip if no sail.conf file (not a valid site)
    if [[ ! -f "$conf_file" ]]; then
        continue
    fi
    
    # Load site configuration to get domain
    source "$conf_file"
    
    # Check if site is running by looking for the container
    container_name="wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g')"
    
    # Check if container exists and is running
    if docker ps --format "table {{.Names}}" | grep -q "^$container_name$" 2>/dev/null; then
        status="UP"
        color="\033[0;32m"  # green
    else
        status="DOWN"
        color="\033[0;31m"  # red
    fi
    
    nc="\033[0m"  # no color
    
    printf "  %-20s ${color}%-6s${nc} https://%s\n" "$site" "$status" "$DOMAIN"
done

echo ""
