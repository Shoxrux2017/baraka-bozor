# Production runtime: PHP 8.4 FPM, built from backend/ with docker/ as the
# additional build context `runtime`:
#
#   docker build -f docker/app.prod.Dockerfile --build-context runtime=docker \
#       -t barakabozor-app:<release> backend
#
# The development image (docker/app.Dockerfile) stays separate: it carries
# Composer, git and the -dev packages and bind-mounts the source. This one holds
# no dev dependency and no tooling (DL-104 (3), DL-107).

FROM php:8.4-fpm AS base

# pcntl is what `queue:work` needs for its timeout and a graceful stop.
# opcache is compiled in but not loaded until docker-php-ext-install enables it.
# The -dev packages are build-only: the official images' apt-mark pattern keeps
# the packages that were installed before, then marks the runtime libraries the
# built extensions link against, and purges the rest.
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends libpq-dev libicu-dev; \
    docker-php-ext-install pdo_pgsql intl opcache pcntl; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    find /usr/local -type f -executable -exec ldd '{}' ';' \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
        | sort -u \
        | xargs -r dpkg-query --search \
        # Only "package: path" lines name a package; Debian 13 usrmerge diversions print "diversion by ..." lines.
        | awk 'sub(":$", "", $1) { print $1 }' \
        | sort -u \
        | xargs -r apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

FROM base AS vendor

# Composer needs git and unzip to extract packages; they stay in this stage.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# The manifests alone first, so the dependency layer is rebuilt only when they
# change. No artisan runs at build time: the production boot check would refuse
# it, and Laravel writes the package manifest at the first boot.
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction

COPY . .
RUN composer dump-autoload --no-dev --optimize --no-scripts

FROM base

# The shared file is the same one the development image uses, so a value set
# there reaches production unchanged. conf.d/ is read in byte order and zzz-
# sorts after the shared zz- file, so the production values win.
# See docker/README.md for why conf.d/ and the zz- prefix.
COPY --from=runtime php.ini /usr/local/etc/php/conf.d/zz-baraka-bozor.ini
COPY --from=runtime php.prod.ini /usr/local/etc/php/conf.d/zzz-baraka-bozor-prod.ini
COPY --from=runtime php-fpm.prod.conf /usr/local/etc/php-fpm.d/zz-baraka-bozor.conf
COPY --from=runtime entrypoint.prod.sh /usr/local/bin/entrypoint.prod.sh

WORKDIR /app
# Root-owned: the unprivileged user that runs FPM cannot rewrite its own code.
COPY --from=vendor /app /app

# .dockerignore keeps the runtime directories' contents out of the image, so
# they are recreated here, writable by the unprivileged user that runs FPM.
# bootstrap/cache stays writable for `php artisan optimize` at start.
RUN chmod +x /usr/local/bin/entrypoint.prod.sh \
    && mkdir -p storage/framework/cache/data storage/framework/sessions \
        storage/framework/views storage/logs storage/app/public bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache

USER www-data

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.prod.sh"]
CMD ["php-fpm"]
