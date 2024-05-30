FROM php:7.4-fpm
WORKDIR /var/www

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential libpng-dev libzip-dev \
    libjpeg62-turbo-dev libfreetype6-dev \
    locales zip unzip \
    jpegoptim optipng pngquant gifsicle \
    vim git curl \
    nodejs npm supervisor cron nginx

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install extensions
# Install PHP extensions
RUN docker-php-ext-install pdo_mysql zip exif pcntl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && docker-php-ext-install mysqli

# Configure nginx
COPY prod/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY prod/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY prod/php.ini /etc/php7/conf.d/custom.ini

# Configure supervisord
COPY prod/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup document root
RUN mkdir -p /var/www/html

# Make sure files/folders needed by the processes are accessable when they run under the nobody user


# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
#RUN composer self-update 1.10.18
RUN composer clear-cache
COPY --from=composer:2.7.6 /usr/bin/composer /usr/bin/composer


# Switch to use a non-root user from here on
# USER nobody

# Add application
WORKDIR /var/www/html
COPY . /var/www/html/

RUN rm -rf /var/www/html/composer.lock
RUN chmod 0777 -R /var/www/html/bootstrap
RUN chmod 0777 -R /var/www/html/storage
#RUN rm -rf /var/www/html/.env
#RUN cd /var/www/html && mv .env.prod .env
RUN cd /var/www/html && COMPOSER_MEMORY_LIMIT=-1 composer install --prefer-dist --no-scripts

USER root
RUN rm -rf /root/.composer
#SER nobody

# Finish composer install
#RUN cd /var/www/html && composer dump-autoload --no-scripts --no-dev --optimize

#RUN cd /var/www/html && php artisan cache:clear
#RUN cd /var/www/html && php artisan config:clear
#RUN cd /var/www/html && php artisan migrate
RUN cd /var/www/html && php artisan vendor:publish --tag=public --force
RUN cd /var/www/html && php artisan cms:theme:activate news; exit 0

RUN chown -R www-data:www-data /var/www/html
RUN chmod 0777 -R /var/www/html/storage
RUN chmod 0777 -R /var/www/html/bootstrap
RUN chmod 0777 -R /var/www/html/public

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping