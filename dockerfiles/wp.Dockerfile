FROM wordpress:6.5-php8.3-fpm

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  && chmod +x wp-cli.phar \
  && mv wp-cli.phar /usr/local/bin/wp

# Install MySQL client (needed for wp db commands)
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    less \
  && rm -rf /var/lib/apt/lists/*

# Always install Xdebug (but don't enable it - let xdebug.ini handle it)
RUN pecl install xdebug

# Note: xdebug.ini is mounted as a volume at runtime
