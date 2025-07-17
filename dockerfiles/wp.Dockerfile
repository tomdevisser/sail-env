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

# Optional: install and enable Xdebug
ARG INSTALL_XDEBUG=true
RUN if [ "$INSTALL_XDEBUG" = "true" ]; then \
      pecl install xdebug && docker-php-ext-enable xdebug ; \
    fi

# Copy optional config (e.g., xdebug.ini)
COPY ./xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini
