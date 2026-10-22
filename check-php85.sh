#!/usr/bin/env bash
# ==============================================================================
# Compilación e Instalación de PHP 8.5.12 desde el código fuente oficial
# Repositorio: https://github.com/golbert19/php-8.5.12-vps
# Fuente: https://www.php.net/distributions/php-8.5.12.tar.gz
# ==============================================================================

set -e

PHP_VERSION="8.5.12"
INSTALL_PREFIX="/opt/php-${PHP_VERSION}"
SRC_DIR="/usr/local/src/php-${PHP_VERSION}-build"
DOWNLOAD_URL="https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz"

echo "========================================================"
echo " Iniciando compilación de PHP ${PHP_VERSION} desde fuente"
echo "========================================================"

if [ "$EUID" -ne 0 ]; then
  echo "Error: Ejecuta este script como root o usando sudo."
  exit 1
fi

if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "Error: No se pudo detectar el sistema operativo."
  exit 1
fi

# 1. Instalar dependencias de compilación y usuario web
echo "[1/6] Instalando dependencias de compilación para ${OS}..."
case "$OS" in
  ubuntu|debian)
    apt-get update -y
    apt-get install -y \
      build-essential autoconf bison re2c pkg-config curl wget ca-certificates \
      libxml2-dev libsqlite3-dev libssl-dev libcurl4-openssl-dev \
      libpng-dev libjpeg-dev libwebp-dev libonig-dev libzip-dev \
      libicu-dev libxslt1-dev libsodium-dev zlib1g-dev
    FPM_USER="www-data"
    FPM_GROUP="www-data"
    ;;
  almalinux|rocky|rhel|centos|fedora)
    dnf install -y epel-release || true
    dnf config-manager --set-enabled crb || dnf config-manager --set-enabled powertools || true
    dnf install -y \
      gcc gcc-c++ make autoconf bison re2c pkgconfig curl wget ca-certificates \
      libxml2-devel sqlite-devel openssl-devel libcurl-devel \
      libpng-devel libjpeg-turbo-devel libwebp-devel oniguruma-devel \
      libzip-devel libicu-devel libxslt-devel libsodium-devel zlib-devel
    FPM_USER="nginx"
    FPM_GROUP="nginx"
    id -u $FPM_USER &>/dev/null || useradd -r -s /sbin/nologin $FPM_USER
    ;;
  *)
    echo "Sistema operativo (${OS}) no soportado por este script."
    exit 1
    ;;
esac

# 2. Descargar y extraer el código fuente oficial
echo "[2/6] Descargando php-${PHP_VERSION}.tar.gz desde php.net..."
rm -rf "${SRC_DIR}"
mkdir -p "${SRC_DIR}"
cd "${SRC_DIR}"

curl -fSL "${DOWNLOAD_URL}" -o "php-${PHP_VERSION}.tar.gz"
tar -xzf "php-${PHP_VERSION}.tar.gz"
cd "php-${PHP_VERSION}"

# 3. Configurar parámetros de compilación
echo "[3/6] Configurando la compilación de PHP ${PHP_VERSION}..."
./configure \
  --prefix="${INSTALL_PREFIX}" \
  --with-config-file-path="${INSTALL_PREFIX}/etc" \
  --with-config-file-scan-dir="${INSTALL_PREFIX}/etc/conf.d" \
  --enable-fpm \
  --with-fpm-user="${FPM_USER}" \
  --with-fpm-group="${FPM_GROUP}" \
  --enable-mbstring \
  --enable-bcmath \
  --enable-intl \
  --enable-soap \
  --enable-pcntl \
  --enable-sockets \
  --enable-gd \
  --with-jpeg \
  --with-webp \
  --with-openssl \
  --with-curl \
  --with-zip \
  --with-zlib \
  --with-sodium \
  --with-xsl \
  --with-mysqli=mysqlnd \
  --with-pdo-mysql=mysqlnd

# 4. Compilar usando todos los núcleos de CPU disponibles
CORES=$(nproc)
echo "[4/6] Compilando con ${CORES} núcleos de CPU (esto tomará varios minutos)..."
make -j"${CORES}"
make install

# 5. Configurar php.ini y PHP-FPM
echo "[5/6] Configurando archivos php.ini y servicio PHP-FPM..."
mkdir -p "${INSTALL_PREFIX}/etc/conf.d"
mkdir -p /run/php

cp php.ini-production "${INSTALL_PREFIX}/etc/php.ini"
cp "${INSTALL_PREFIX}/etc/php-fpm.conf.default" "${INSTALL_PREFIX}/etc/php-fpm.conf"
cp "${INSTALL_PREFIX}/etc/php-fpm.d/www.conf.default" "${INSTALL_PREFIX}/etc/php-fpm.d/www.conf"

# Ajustar el socket para que escuche en /run/php/php8.5-fpm.sock
sed -i 's|^listen = .*|listen = /run/php/php8.5-fpm.sock|' "${INSTALL_PREFIX}/etc/php-fpm.d/www.conf"
sed -i "s|^;listen.owner = .*|listen.owner = ${FPM_USER}|" "${INSTALL_PREFIX}/etc/php-fpm.d/www.conf"
sed -i "s|^;listen.group = .*|listen.group = ${FPM_GROUP}|" "${INSTALL_PREFIX}/etc/php-fpm.d/www.conf"
sed -i 's|^;listen.mode = .*|listen.mode = 0660|' "${INSTALL_PREFIX}/etc/php-fpm.d/www.conf"

# Crear unidad de systemd para php8.5-fpm
cat <<EOF > /etc/systemd/system/php8.5-fpm.service
[Unit]
Description=The PHP ${PHP_VERSION} FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=/run/php/php8.5-fpm.pid
RuntimeDirectory=php
RuntimeDirectoryMode=0755
ExecStart=${INSTALL_PREFIX}/sbin/php-fpm --nodaemonize --fpm-config ${INSTALL_PREFIX}/etc/php-fpm.conf --pid /run/php/php8.5-fpm.pid
ExecReload=/bin/kill -USR2 \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable php8.5-fpm
systemctl restart php8.5-fpm

# 6. Vincular PHP 8.5.12 como versión predeterminada del sistema
echo "[6/6] Activando PHP ${PHP_VERSION} en el PATH del sistema..."
ln -sf "${INSTALL_PREFIX}/bin/php" /usr/local/bin/php
ln -sf "${INSTALL_PREFIX}/bin/phpize" /usr/local/bin/phpize
ln -sf "${INSTALL_PREFIX}/bin/php-config" /usr/local/bin/php-config

if command -v update-alternatives &>/dev/null; then
  update-alternatives --install /usr/bin/php php "${INSTALL_PREFIX}/bin/php" 8512
  update-alternatives --set php "${INSTALL_PREFIX}/bin/php"
fi

# Limpiar archivos temporales de compilación
rm -rf "${SRC_DIR}"

echo "========================================================"
echo " Compilación finalizada con éxito. Versión instalada:"
php -v
echo "========================================================"
