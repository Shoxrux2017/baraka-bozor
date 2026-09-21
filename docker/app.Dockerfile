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
    && apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# No application code is copied in. backend/ is bind-mounted by Compose so that
# an edit on the host is visible immediately, which is what a development
# runtime needs. A deployable image is out of scope for Wave 0.
