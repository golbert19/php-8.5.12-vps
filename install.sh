#!/usr/bin/env bash
# ==============================================================================
# Script de Instalación y Cambio a PHP 8.5.12 para VPS
# Repositorio: https://github.com/golbert19/php-8.5.12-vps
# ==============================================================================

set -e

TARGET_VERSION="8.5"
EXPECTED_PATCH="8.5.12"

echo "===================================================="
echo " Iniciando actualización a PHP ${EXPECTED_PATCH}..."
echo "===================================================="

# Verificar permisos de superusuario
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root o usando sudo."
  exit 1
fi

# Detectar sistema operativo
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "No se pudo detectar el sistema operativo del VPS."
  exit 1
fi

install_debian_ubuntu() {
  echo "[1/4] Configurando repositorio PPA (ondrej/php) en ${OS}..."
  apt-get update -y
  apt-get install -y software-properties-common ca-certificates lsb-release apt-transport-https curl

  if [ "$OS" = "ubuntu" ]; then
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
  elif [ "$OS" = "debian" ]; then
    curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
    dpkg -i /tmp/debsuryorg-archive-keyring.deb
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
  fi

  apt-get update -y

  echo "[2/4] Instalando PHP ${TARGET_VERSION} (${EXPECTED_PATCH}) y extensiones comunes..."
  apt-get install -y \
    php${TARGET_VERSION} \
    php${TARGET_VERSION}-cli \
    php${TARGET_VERSION}-fpm \
    php${TARGET_VERSION}-common \
    php${TARGET_VERSION}-mysql \
    php${TARGET_VERSION}-xml \
    php${TARGET_VERSION}-curl \
    php${TARGET_VERSION}-gd \
    php${TARGET_VERSION}-mbstring \
    php${TARGET_VERSION}-zip \
    php${TARGET_VERSION}-bcmath \
    (php${TARGET_VERSION}-intl)

  echo "[3/4] Estableciendo PHP ${TARGET_VERSION} como versión predeterminada en CLI..."
  update-alternatives --set php /usr/bin/php${TARGET_VERSION} || true
  update-alternatives --set phar /usr/bin/phar${TARGET_VERSION} || true
  update-alternatives --set phar.phar /usr/bin/phar.phar${TARGET_VERSION} || true

  echo "[4/4] Reiniciando servicio PHP-FPM..."
  systemctl enable php${TARGET_VERSION}-fpm
  systemctl restart php${TARGET_VERSION}-fpm
}

install_rhel_alma_rocky() {
  echo "[1/4] Configurando repositorio Remi en ${OS}..."
  dnf install -y epel-release
  dnf install -y https://rpms.remirepo.net/enterprise/remi-release-${VERSION_ID%%.*}.rpm || true

  echo "[2/4] Activando módulo PHP ${TARGET_VERSION}..."
  dnf module reset php -y
  dnf module enable php:remi-${TARGET_VERSION} -y

  echo "[3/4] Instalando PHP ${EXPECTED_PATCH} y extensiones..."
  dnf update -y
  dnf install -y php php-cli php-fpm php-common php-mysqlnd php-xml php-curl php-gd php-mbstring php-zip php-bcmath php-intl php-opcache

  echo "[4/4] Reiniciando servicio PHP-FPM..."
  systemctl enable php-fpm
  systemctl restart php-fpm
}

case "$OS" in
  ubuntu|debian)
    install_debian_ubuntu
    ;;
  almalinux|rocky|rhel|centos|fedora)
    install_rhel_alma_rocky
    ;;
  *)
    echo "Sistema operativo (${OS}) no soportado automáticamente por este script."
    exit 1
    ;;
esac

echo "===================================================="
echo " Instalación completada. Versión activa actual:"
php -v
echo "===================================================="
