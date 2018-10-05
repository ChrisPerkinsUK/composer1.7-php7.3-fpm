FROM php:7.3-rc-fpm-alpine3.8

## Install the composer package dependencies
RUN apk --no-cache add git subversion openssh mercurial tini bash patch libzip-dev

## Remove php memory limit and set timezone to UTC
RUN echo "memory_limit=-1" > "$PHP_INI_DIR/conf.d/memory-limit.ini" \
 && echo "date.timezone=${PHP_TIMEZONE:-UTC}" > "$PHP_INI_DIR/conf.d/date_timezone.ini"

# Install PHP dependencies
RUN apk add --no-cache --virtual .build-deps zlib-dev \
 && docker-php-ext-install zip \
 && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
 && apk add --virtual .composer-phpext-rundeps $runDeps \
 && apk del .build-deps

## Set Environment variables to allow composer to
## be configured, set up and used correctly

# Allow composer to be run as super user
ENV COMPOSER_ALLOW_SUPERUSER 1
# Set the composer home directory
ENV COMPOSER_HOME /tmp
# Set the composer version
ENV COMPOSER_VERSION 1.7.2

## Install shortcut take advantage of multistage 
## build feature and copy the composer executable
## from the official image
COPY --from=composer:1.7 /usr/bin/composer /usr/bin/composer

## Copy in the entry point script
COPY ./entrypoint/docker-entrypoint.sh /docker-entrypoint.sh

## Use this directory for all the composing
WORKDIR /app

## Run the entry point script to set up all the commands
ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]

## Set PHP running to allow persistent containers
## execute commands on persistent containers with
## docker exec container_name command flag1 flag2 value1 value2 ...
CMD ["php-fpm"]
