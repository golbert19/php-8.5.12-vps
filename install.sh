#!/usr/bin/env bash
set -Eeuo pipefail

# PHP 8.5.12 isolated source installer for Debian/Ubuntu.
# Does not replace /usr/bin/php or change web-server configuration.

VERSION="8.5.12"
SHA256="08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209"
ARCHIVE="php-${VERSION}.tar.xz"
URL="https://www.php.net/distributions/${ARCHIVE}"
PREFIX="/opt/php/${VERSION}"
CONFIG_DIR="/etc/opt/php/${VERSION}"
SERVICE="php85.12-fpm.service"
FPM_LOG="/var/log/php85.12-fpm.log"
PHP_ERROR_LOG="/var/log/php85.12-php-errors.log"
JOBS="${JOBS:-2}"

info() { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[AVISO] %s\n' "$*" >&2; }
die()  { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

if [[ "${EUID}" -ne 0 ]]; then
  die "Ejecuta este script como root: sudo bash install.sh"
fi
[[ -r /etc/os-release ]] || die "No se puede identificar el sistema operativo (falta /etc/os-release)."
# shellcheck disable=SC1091
. /etc/os-release
OS_FAMILY=" ${ID:-} ${ID_LIKE:-} "
if [[ "$OS_FAMILY" != *debian* && "$OS_FAMILY" != *ubuntu* ]]; then
  die "Este instalador está preparado para Debian/Ubuntu. Sistema detectado: ${PRETTY_NAME:-desconocido}"
fi
command -v apt-get >/dev/null 2>&1 || die "No se encontró apt-get."
command -v systemctl >/dev/null 2>&1 || die "Se necesita systemd/systemctl para configurar PHP-FPM."
getent passwd www-data >/dev/null 2>&1 || die "No existe el usuario www-data, necesario para PHP-FPM en Debian/Ubuntu."
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || die "JOBS debe ser un número entero positivo, por ejemplo JOBS=1."

SKIP_BUILD=0
if [[ -x "$PREFIX/bin/php" ]]; then
  installed_version="$("$PREFIX/bin/php" -r 'echo PHP_VERSION;' 2>/dev/null || true)"
  [[ "$installed_version" == "$VERSION" ]] || die "Ya existe $PREFIX con una versión distinta o inválida. Revísala antes de continuar."
  info "PHP ${VERSION} ya está compilado en $PREFIX; se comprobará/configurará PHP-FPM."
  SKIP_BUILD=1
elif [[ -e "$PREFIX" ]]; then
  die "Existe $PREFIX pero no contiene un PHP ejecutable. No se sobrescribió para evitar pérdida de datos; revisa esa ruta primero."
fi

check_link() {
  local link="$1" expected="$2" resolved=""
  if [[ -e "$link" || -L "$link" ]]; then
    resolved="$(readlink -f "$link" 2>/dev/null || true)"
    [[ "$resolved" == "$expected" ]] || die "Ya existe $link y no pertenece a este instalador. No se sobrescribió nada."
  fi
}
check_link /usr/local/bin/php85 "$PREFIX/bin/php"
check_link /usr/local/bin/phpize85 "$PREFIX/bin/phpize"
check_link /usr/local/bin/php-config85 "$PREFIX/bin/php-config"
check_link /usr/local/sbin/php-fpm85 "$PREFIX/sbin/php-fpm"

BUILD_DIR=""
if [[ "$SKIP_BUILD" -eq 0 ]]; then
  info "Instalando dependencias de compilación..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    build-essential autoconf bison re2c pkg-config ca-certificates curl xz-utils \
    libxml2-dev libsqlite3-dev libcurl4-openssl-dev libssl-dev zlib1g-dev \
    libonig-dev libzip-dev libreadline-dev libjpeg-dev libpng-dev libwebp-dev \
    libfreetype6-dev libicu-dev libxslt1-dev libsodium-dev libbz2-dev

  BUILD_DIR="$(mktemp -d /tmp/php-${VERSION}-build.XXXXXX)"
  trap '[[ -z "${BUILD_DIR:-}" ]] || rm -rf -- "$BUILD_DIR"' EXIT

  info "Descargando PHP ${VERSION} desde php.net..."
  curl --fail --location --retry 3 --retry-delay 2 "$URL" --output "$BUILD_DIR/$ARCHIVE"
  info "Verificando SHA-256 del archivo oficial..."
  printf '%s  %s\n' "$SHA256" "$BUILD_DIR/$ARCHIVE" | sha256sum --check --status \
    || die "La verificación SHA-256 falló. El archivo se rechazó y no se instalará."

  info "Extrayendo el código fuente..."
  tar -xJf "$BUILD_DIR/$ARCHIVE" -C "$BUILD_DIR"
  cd "$BUILD_DIR/php-${VERSION}"

  info "Configurando PHP ${VERSION}. Esto puede tardar varios minutos..."
  ./configure \
    --prefix="$PREFIX" \
    --sysconfdir="$CONFIG_DIR" \
    --localstatedir=/var \
    --with-config-file-path="$CONFIG_DIR" \
    --with-config-file-scan-dir="$CONFIG_DIR/conf.d" \
    --enable-fpm \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
    --enable-opcache \
    --enable-mbstring \
    --enable-bcmath \
    --enable-calendar \
    --enable-exif \
    --enable-ftp \
    --enable-intl \
    --enable-soap \
    --enable-sockets \
    --enable-pcntl \
    --with-openssl \
    --with-curl \
    --with-zlib \
    --with-zip \
    --with-bz2 \
    --with-readline \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-pdo-sqlite \
    --with-sqlite3 \
    --enable-gd \
    --with-jpeg \
    --with-webp \
    --with-freetype \
    --with-xsl \
    --with-sodium

  info "Compilando con ${JOBS} proceso(s) paralelo(s)..."
  make -j"$JOBS"
  info "Instalando en $PREFIX..."
  make install
fi

info "Preparando configuración aislada..."
install -d -m 0755 "$CONFIG_DIR" "$CONFIG_DIR/conf.d" "$CONFIG_DIR/php-fpm.d"
if [[ ! -e "$CONFIG_DIR/php.ini" ]]; then
  if [[ -n "$BUILD_DIR" && -f "$BUILD_DIR/php-${VERSION}/php.ini-production" ]]; then
    install -m 0644 "$BUILD_DIR/php-${VERSION}/php.ini-production" "$CONFIG_DIR/php.ini"
  else
    # Recovery path when PHP binaries were already compiled but php.ini is missing.
    TEMPLATE_DIR="$(mktemp -d /tmp/php-${VERSION}-ini.XXXXXX)"
    trap '[[ -z "${TEMPLATE_DIR:-}" ]] || rm -rf -- "$TEMPLATE_DIR"' EXIT
    curl --fail --location --retry 3 "$URL" --output "$TEMPLATE_DIR/$ARCHIVE"
    printf '%s  %s\n' "$SHA256" "$TEMPLATE_DIR/$ARCHIVE" | sha256sum --check --status \
      || die "Falló la verificación SHA-256 del código fuente."
    tar -xJf "$TEMPLATE_DIR/$ARCHIVE" -C "$TEMPLATE_DIR" "php-${VERSION}/php.ini-production"
    install -m 0644 "$TEMPLATE_DIR/php-${VERSION}/php.ini-production" "$CONFIG_DIR/php.ini"
    rm -rf -- "$TEMPLATE_DIR"
    TEMPLATE_DIR=""
  fi
fi

# This file is managed by this installer. User settings in php.ini are preserved.
cat > "$CONFIG_DIR/conf.d/90-vps-defaults.ini" <<'INI'
; Defaults created by php-8.5.12-vps. Edit as needed.
date.timezone = America/Lima
expose_php = Off
cgi.fix_pathinfo = 0
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 60
error_log = /var/log/php85.12-php-errors.log
log_errors = On
INI

cat > "$CONFIG_DIR/conf.d/10-opcache.ini" <<'INI'
; OPcache built with PHP 8.5.12
zend_extension=opcache
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
INI

cat > "$CONFIG_DIR/php-fpm.conf" <<FPMCONF
[global]
pid = /run/php85.12-fpm/php-fpm.pid
error_log = ${FPM_LOG}
daemonize = no
include = ${CONFIG_DIR}/php-fpm.d/*.conf
FPMCONF

cat > "$CONFIG_DIR/php-fpm.d/www.conf" <<POOLCONF
[www]
user = www-data
group = www-data
listen = /run/php85.12-fpm/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
clear_env = yes
security.limit_extensions = .php
php_admin_flag[log_errors] = on
POOLCONF

install -d -m 0755 /var/log
: >> "$FPM_LOG"
: >> "$PHP_ERROR_LOG"
chown www-data:www-data "$PHP_ERROR_LOG"
chmod 0640 "$PHP_ERROR_LOG"

cat > "/etc/systemd/system/$SERVICE" <<UNITFILE
[Unit]
Description=PHP ${VERSION} FastCGI Process Manager (isolated)
After=network.target

[Service]
Type=simple
RuntimeDirectory=php85.12-fpm
RuntimeDirectoryMode=0755
ExecStartPre=${PREFIX}/sbin/php-fpm --test --fpm-config ${CONFIG_DIR}/php-fpm.conf
ExecStart=${PREFIX}/sbin/php-fpm --nodaemonize --fpm-config ${CONFIG_DIR}/php-fpm.conf
ExecReload=/bin/kill -USR2 \$MAINPID
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNITFILE

link_checked() {
  local target="$1" link="$2"
  if [[ -L "$link" ]] && [[ "$(readlink -f "$link" 2>/dev/null || true)" == "$target" ]]; then
    return
  fi
  [[ ! -e "$link" && ! -L "$link" ]] || die "No se puede crear $link: ya existe y no apunta a $target."
  ln -s "$target" "$link"
}
link_checked "$PREFIX/bin/php" /usr/local/bin/php85
link_checked "$PREFIX/bin/phpize" /usr/local/bin/phpize85
link_checked "$PREFIX/bin/php-config" /usr/local/bin/php-config85
link_checked "$PREFIX/sbin/php-fpm" /usr/local/sbin/php-fpm85

info "Validando configuración y habilitando PHP-FPM..."
"$PREFIX/sbin/php-fpm" --test --fpm-config "$CONFIG_DIR/php-fpm.conf"
systemctl daemon-reload
systemctl enable --now "$SERVICE"

info "Instalación terminada."
printf '\nPHP CLI instalado: '
"$PREFIX/bin/php" -v | head -n 1
printf 'Ejecutables: php85, phpize85, php-config85, php-fpm85\n'
printf 'Socket FPM: /run/php85.12-fpm/php-fpm.sock\n'
printf 'Servicio: systemctl status %s\n' "$SERVICE"
printf '\nIMPORTANTE: no se ha cambiado el comando global php ni la configuración de Nginx/Apache.\n'
printf 'Consulta README.md para conectar tu servidor web a PHP-FPM.\n'
