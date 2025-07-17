# Sail - WordPress Development Environment

A containerized WordPress development environment using nginx + PHP-FPM architecture that matches production server setups. Perfect for managing multiple WordPress sites locally with SSL certificates and phpMyAdmin.

## Features

- **Docker-based**: Isolated containers for each WordPress site
- **SSL Certificates**: Automatic SSL setup with trusted certificates using mkcert
- **Multi-site Support**: Easily manage multiple WordPress projects
- **nginx + PHP-FPM**: Production-ready architecture
- **phpMyAdmin**: Database management for each site
- **Simple Commands**: Easy-to-use CLI for site management
- **Resilient Reverse Proxy**: Centralized SSL termination and routing with graceful handling of down sites
- **Offline Page**: Beautiful offline page when sites are down instead of browser errors
- **Remote Sync**: Sync WordPress core, database, plugins, and media from remote servers

## Requirements

- **Docker & Docker Compose**: For containerization
- **mkcert**: For SSL certificate generation
- **macOS/Linux**: Tested on macOS, should work on Linux

## Installation

1. **Clone the repository**:

   ```bash
   git clone <repository-url> sail
   cd sail
   ```

2. **Make the sail command executable**:

   ```bash
   chmod +x bin/sail
   ```

3. **Initialize the system**:

   ```bash
   ./bin/sail init
   ```

   This will:

   - Install mkcert if not present
   - Set up the mkcert CA certificate
   - Create necessary directories
   - Start the nginx reverse proxy

## Usage

### Available Commands

```bash
./bin/sail <command>
```

| Command              | Description                                     |
| -------------------- | ----------------------------------------------- |
| `init`               | Set up the reverse proxy and certificates       |
| `up`                 | Start site containers (run from site directory) |
| `down`               | Stop site containers (run from site directory)  |
| `sync [options]`     | Sync data from remote server (run from site directory) |
| `site add <name>`    | Create a new WordPress site                     |
| `site remove <name>` | Remove an existing site                         |

### Creating a New Site

```bash
./bin/sail site add mysite
```

This creates:

- Site directory structure in `sites/mysite/`
- SSL certificates for `mysite.sail` and `pma.mysite.sail`
- nginx configuration files
- Docker Compose setup
- Database containers
- Entry in `/etc/hosts`

### Starting a Site

```bash
cd sites/mysite
../../bin/sail up
```

This will:
- Start all containers (nginx, WordPress, database)
- Automatically install WordPress with default credentials if not installed
- Default login: `admin` / `admin`

Your site will be available at:
- **WordPress**: https://mysite.sail
- **phpMyAdmin**: https://pma.mysite.sail

### Stopping a Site

```bash
cd sites/mysite
../../bin/sail down
```

**Note**: The `down` command now checks if containers are running and will show an error if no containers are currently running for the site.

### Offline Sites

When a site is down, visiting its URL will show a beautiful offline page instead of browser errors. This means:

- **No more proxy crashes** when some sites are down
- **User-friendly offline page** with instructions to start the site
- **Seamless experience** when sites come back online

### Remote Sync

Sync your local development site with a remote server:

```bash
cd sites/mysite
../../bin/sail sync [options]
```

Sync options:
- `--all` or no options: Sync everything (database, plugins, media, core)
- `--db`: Sync database only
- `--plugins`: Sync plugins only
- `--media`: Sync media/uploads only
- `--core`: Sync WordPress core only

Combine options: `../../bin/sail sync --db --plugins`

The sync command will:
- Prompt for remote server credentials on first use
- Save configuration to `sail.conf` for future use
- Download and import remote database with URL replacements
- Sync files using rsync over SSH
- Update local WordPress core to match remote version

### Removing a Site

```bash
./bin/sail site remove mysite
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    sail_proxy (nginx)                      │
│                  SSL Termination + Routing                 │
│                       Port 443                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Per-Site Stack                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │  nginx_site     │  │   wp_site       │  │   db_site   │ │
│  │  Static Files   │  │   PHP-FPM       │  │   MySQL     │ │
│  │  Port 80        │  │   Port 9000     │  │   Port 3306 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Container Details

- **sail_proxy**: Main nginx reverse proxy handling SSL and routing with resilient upstream handling
- **nginx\_[site]**: Per-site nginx for static files and PHP-FPM communication
- **wp\_[site]**: WordPress with PHP-FPM
- **db\_[site]**: MySQL database for each site
- **sail_phpmyadmin**: Shared phpMyAdmin instance

### Proxy Resilience

The nginx proxy is designed to handle sites being up or down gracefully:

- **Dynamic DNS resolution**: Uses Docker's internal DNS resolver
- **Graceful error handling**: Shows custom offline page when sites are down
- **No startup failures**: Proxy starts even if some sites are offline
- **Automatic recovery**: Sites work immediately when brought back online

## Directory Structure

```
sail/
├── bin/                    # CLI commands
│   ├── sail               # Main CLI entry point
│   └── cmd/               # Command implementations
├── config/                # Configuration templates
│   ├── nginx/             # nginx templates
│   │   ├── html/          # Static files (offline page)
│   │   └── *.template.conf # nginx configuration templates
│   ├── docker/            # Docker Compose templates
│   └── php/               # PHP configuration
├── dockerfiles/           # Custom Docker images
├── sites/                 # WordPress sites (gitignored)
├── nginx_sites/           # Generated nginx configs (gitignored)
├── certs/                 # SSL certificates (gitignored)
├── logs/                  # nginx logs (gitignored)
└── docker-compose.yml     # Main reverse proxy setup
```

## Site Directory Structure

Each site in `sites/[sitename]/` contains:

```
sites/mysite/
├── docker-compose.yml     # Site-specific containers
├── nginx.conf            # Site nginx configuration
├── sail.conf             # Site configuration (includes remote sync settings)
├── xdebug.ini           # XDebug configuration
├── theme/               # Custom theme files
├── plugins/             # Custom plugins
├── uploads/             # WordPress uploads/media
└── database/            # MySQL data files
```

## SSL Certificates

Sail uses [mkcert](https://github.com/FiloSottile/mkcert) to generate locally trusted SSL certificates:

- Certificates are automatically generated for each site
- Both main domain and phpMyAdmin subdomain get certificates
- Certificates are valid for 2+ years
- No browser warnings when properly set up

### Troubleshooting SSL

If you see "Not Secure" warnings:

1. **Clear browser cache** for the site
2. **Hard refresh**: `Cmd + Shift + R` (macOS)
3. **Test in incognito mode**
4. **Reinstall mkcert CA**: `mkcert -install`

## WordPress Setup

1. Visit your site: `https://mysite.sail`
2. Follow the WordPress installation wizard
3. Database details:
   - **Host**: `db:3306`
   - **Database**: `wordpress`
   - **Username**: `wordpress`
   - **Password**: `wordpress`

## phpMyAdmin Access

- **URL**: `https://pma.mysite.sail`
- **Server**: `db_mysite`
- **Username**: `wordpress`
- **Password**: `wordpress`

## Development Features

### Xdebug Support

Xdebug is available and can be enabled by setting `XDEBUG_ENABLED=true` in your environment.

### File Syncing

- **Themes**: `sites/mysite/theme/` → `/var/www/html/wp-content/themes/custom`
- **Plugins**: `sites/mysite/plugins/` → `/var/www/html/wp-content/plugins/`

### Database Persistence

Database files are stored in `sites/mysite/database/` and persist between container restarts.

## Customization

### Adding Custom nginx Configuration

Edit `config/nginx/site.template.conf` to modify the per-site nginx setup.

### PHP Configuration

Modify `config/php/xdebug.template.ini` for PHP settings.

### Docker Customization

Edit `config/docker/site.template.yml` to modify the Docker Compose setup.

## Production Alignment

This setup mirrors production environments using:

- nginx as reverse proxy
- nginx + PHP-FPM per site
- Separate databases per site
- SSL termination at the proxy level

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - feel free to use and modify as needed.
