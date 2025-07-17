# Sail - WordPress Development Environment

A containerized WordPress development environment using nginx + PHP-FPM architecture that matches production server setups. Perfect for managing multiple WordPress sites locally with SSL certificates and phpMyAdmin.

## Features

- **Docker-based**: Isolated containers for each WordPress site
- **SSL Certificates**: Automatic SSL setup with trusted certificates using mkcert
- **Multi-site Support**: Easily manage multiple WordPress projects
- **nginx + PHP-FPM**: Production-ready architecture
- **phpMyAdmin**: Database management for each site
- **Simple Commands**: Easy-to-use CLI for site management
- **Reverse Proxy**: Centralized SSL termination and routing

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

- **sail_proxy**: Main nginx reverse proxy handling SSL and routing
- **nginx\_[site]**: Per-site nginx for static files and PHP-FPM communication
- **wp\_[site]**: WordPress with PHP-FPM
- **db\_[site]**: MySQL database for each site
- **sail_phpmyadmin**: Shared phpMyAdmin instance

## Directory Structure

```
sail/
├── bin/                    # CLI commands
│   ├── sail               # Main CLI entry point
│   └── cmd/               # Command implementations
├── config/                # Configuration templates
│   ├── nginx/             # nginx templates
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
├── sail.conf             # Site configuration
├── xdebug.ini           # XDebug configuration
├── theme/               # Custom theme files
├── plugins/             # Custom plugins
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
