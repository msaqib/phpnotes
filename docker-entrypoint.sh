#!/bin/bash
set -e

cd /var/www/html

# Ensure environment file exists
if [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    cp .env.example .env
  else
    cat <<'EOF' > .env
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=pgsql
DB_DATABASE=
EOF
  fi
fi

# If APP_KEY is provided via environment variable, ensure .env reflects it
if [ -n "${APP_KEY:-}" ]; then
  escaped_app_key=${APP_KEY//\\/\\\\}
  escaped_app_key=${escaped_app_key//\//\\/}
  if grep -q '^APP_KEY=' .env; then
    sed -i "s/^APP_KEY=.*/APP_KEY=${escaped_app_key}/" .env
  else
    printf "\nAPP_KEY=%s\n" "$APP_KEY" >> .env
  fi
fi

# Ensure application key exists
KEY_VALUE=$(php -r 'echo preg_match("/^APP_KEY=\s*$/m", file_get_contents(".env")) ? "" : "exists";')

if [ -z "$KEY_VALUE" ]; then
  if ! php artisan key:generate --force --no-interaction; then
    echo "Failed to generate APP_KEY. Inserting placeholder value."
    sed -i 's/^APP_KEY=.*$/APP_KEY=base64:FAKEKEYFORDEV==/' .env || echo "APP_KEY=base64:FAKEKEYFORDEV==" >> .env
  fi
fi

# Ensure storage directories exist with correct permissions
mkdir -p storage/framework/{cache,views,sessions} \
  storage/logs \
  bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache || true
chmod -R 775 storage bootstrap/cache || true

# Run migrations
php artisan migrate --force --no-interaction

# Start Apache
exec apache2-foreground

