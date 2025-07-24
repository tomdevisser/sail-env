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

# Function to prompt for missing variables
prompt_for_missing_config() {
	local config_updated=false
	
	if [[ -z "$REMOTE_HOST" ]]; then
		read -p "Remote Host: " REMOTE_HOST
		echo "REMOTE_HOST=\"$REMOTE_HOST\"" >> ./sail.conf
		config_updated=true
	fi
	
	if [[ -z "$REMOTE_USER" ]]; then
		read -p "Remote User: " REMOTE_USER
		echo "REMOTE_USER=\"$REMOTE_USER\"" >> ./sail.conf
		config_updated=true
	fi
	
	if [[ -z "$REMOTE_PASS" ]]; then
		read -s -p "Remote Password: " REMOTE_PASS
		echo
		echo "REMOTE_PASS=\"$REMOTE_PASS\"" >> ./sail.conf
		config_updated=true
	fi
	
	if [[ -z "$REMOTE_PORT" ]]; then
		read -p "Remote Port (default 22): " REMOTE_PORT
		REMOTE_PORT=${REMOTE_PORT:-22}
		echo "REMOTE_PORT=\"$REMOTE_PORT\"" >> ./sail.conf
		config_updated=true
	fi
	
	if [[ -z "$REMOTE_PATH" ]]; then
		read -p "Remote WordPress Path (e.g., /var/www/html): " REMOTE_PATH
		echo "REMOTE_PATH=\"$REMOTE_PATH\"" >> ./sail.conf
		config_updated=true
	fi
	
	if [[ "$config_updated" == true ]]; then
		log_info "Configuration saved to sail.conf. You can edit this file manually to update these settings."
		# Reload configuration
		source ./sail.conf
	fi
}

# Check for missing configuration and prompt if needed
if [[ -z "$REMOTE_HOST" || -z "$REMOTE_USER" || -z "$REMOTE_PASS" || -z "$REMOTE_PORT" || -z "$REMOTE_PATH" ]]; then
	log_info "Some remote configuration is missing. Please provide the required information:"
	prompt_for_missing_config
fi

# Parse command line arguments
sync_all=false
sync_db=false
sync_plugins=false
sync_media=false
sync_core=false

if [[ $# -eq 0 ]]; then
	sync_all=true
else
	while [[ $# -gt 0 ]]; do
		case $1 in
			--all)
				sync_all=true
				shift
				;;
			--db)
				sync_db=true
				shift
				;;
			--plugins)
				sync_plugins=true
				shift
				;;
			--media)
				sync_media=true
				shift
				;;
			--core)
				sync_core=true
				shift
				;;
			*)
				log_error "Unknown option: $1"
				echo "Usage: sail sync [--all] [--db] [--plugins] [--media] [--core]"
				exit 1
				;;
		esac
	done
fi

# If --all is specified, sync everything
if [[ "$sync_all" == true ]]; then
	sync_db=true
	sync_plugins=true
	sync_media=true
	sync_core=true
fi

log_info "Starting sync for $DOMAIN..."
log_info "Note: Make sure the site is running with 'sail up' before syncing"

# Create temporary directory for sync operations
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Get remote domain for search/replace
log_info "Getting remote domain..."
remote_domain=$(sshpass -p "$REMOTE_PASS" ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_PATH && wp option get siteurl --allow-root 2>/dev/null | sed 's|https\\?://||' | sed 's|/.*||'")

if [[ -z "$remote_domain" ]]; then
	log_error "Could not get remote domain. Make sure WP-CLI is installed on the remote server."
	exit 1
fi

log_info "Remote domain: $remote_domain"
log_info "Local domain: $DOMAIN"

# Sync WordPress core
if [[ "$sync_core" == true ]]; then
	log_info "Syncing WordPress core..."
	
	# Get remote WordPress version
	remote_version=$(sshpass -p "$REMOTE_PASS" ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_PATH && wp core version --allow-root" 2>/dev/null)
	
	if [[ -n "$remote_version" ]]; then
		log_info "Remote WordPress version: $remote_version"
		
		# Update local WordPress to match remote version
		docker compose exec wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g') wp core update --version="$remote_version" --allow-root
		
		log_success "WordPress core synced to version $remote_version"
	else
		log_error "Could not get remote WordPress version"
	fi
fi

# Sync database
if [[ "$sync_db" == true ]]; then
	log_info "Syncing database..."
	
	# Generate unique filename for the export
	remote_db_file="sail_export_$(date +%s).sql"
	
	# Export database on remote server
	log_info "Creating database export on remote server..."
	sshpass -p "$REMOTE_PASS" ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_PATH && wp db export $remote_db_file --allow-root"
	
	# Download the exported database
	log_info "Downloading database export..."
	sshpass -p "$REMOTE_PASS" scp -P "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/$remote_db_file" "$temp_dir/remote_db.sql"
	
	# Remove the export file from remote server
	log_info "Cleaning up remote export file..."
	sshpass -p "$REMOTE_PASS" ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "rm -f $REMOTE_PATH/$remote_db_file" || log_info "Remote file already cleaned up"
	
	if [[ -f "$temp_dir/remote_db.sql" ]]; then
		# Import database to local
		log_info "Importing database locally..."
		docker compose exec -T wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g') wp db import - --allow-root < "$temp_dir/remote_db.sql"
		
		# Search and replace domain
		log_info "Updating URLs for local domain..."
		docker compose exec wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g') wp search-replace "https://$remote_domain" "https://$DOMAIN" --allow-root
		docker compose exec wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g') wp search-replace "http://$remote_domain" "https://$DOMAIN" --allow-root
		docker compose exec wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g') wp search-replace "$remote_domain" "$DOMAIN" --allow-root
		
		# Flush rewrite rules
		docker compose exec wp_$(echo $DOMAIN | sed 's/\.sail$//' | sed 's/[^a-z0-9]/-/g') wp rewrite flush --allow-root
		
		# Clean up local temporary file
		rm -f "$temp_dir/remote_db.sql"
		
		log_success "Database synced and domain replaced"
	else
		log_error "Failed to download remote database export"
	fi
fi

# Sync plugins
if [[ "$sync_plugins" == true ]]; then
	log_info "Syncing plugins..."
	
	# Create plugins directory if it doesn't exist
	mkdir -p ./plugins
	
	# Sync plugins using rsync
	sshpass -p "$REMOTE_PASS" rsync -avz --delete -e "ssh -p $REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/plugins/" "./plugins/"
	
	log_success "Plugins synced"
fi

# Sync media/uploads
if [[ "$sync_media" == true ]]; then
	log_info "Syncing media..."
	
	# Create uploads directory if it doesn't exist
	mkdir -p ./uploads
	
	# Sync uploads using rsync
	sshpass -p "$REMOTE_PASS" rsync -avz --delete -e "ssh -p $REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/wp-content/uploads/" "./uploads/"
	
	log_success "Media synced"
fi

log_success "Sync completed for $DOMAIN!"
log_info "You can edit the remote configuration in: ./sail.conf"
