# PHP runtime for local development and tests.
#
# The host PHP is Herd-lite, which has no loadable extension directory and
# cannot provide pdo_pgsql. This image supplies it, and keeps local runs on the
# same Linux PHP that CI and production use.
#
# Matches docs/07-architecture.md Section 2: PHP 8.3+.
FROM php:8.4-cli

# libpq-dev is the PostgreSQL client library pdo_pgsql builds against.
# libicu-dev backs intl, which Laravel's own `db:show` requires to format its
# output; without it that command prints the connection and then throws.
# git and unzip are what Composer needs to resolve and extract packages.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq-dev \
        libicu-dev \
        git \
        unzip \
    && docker-php-ext-install pdo_pgsql intl \
    && rm -rf /var/lib/apt/lists/*

# The -dev packages stay installed on purpose. The official images' trick for
# dropping them needs the matching apt-mark pair around the build; half of it
# alone removes nothing, and this is a development image where a smaller layer
# buys nothing.

# Without this the image runs with no php.ini at all: the base image ships
# php.ini-development and php.ini-production but activates neither, so PHP falls
# back to its compiled-in defaults. conf.d/ is read alphabetically after the
# main php.ini, and the zz- prefix puts this file after the extension files
# docker-php-ext-install writes there, so its precedence is deliberate rather
# than accidental.
COPY php.ini /usr/local/etc/php/conf.d/zz-baraka-bozor.ini

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# No application code is copied in. backend/ is bind-mounted by Compose so that
# an edit on the host is visible immediately, which is what a development
# runtime needs. A deployable image is out of scope for Wave 0.
