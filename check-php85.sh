#!/usr/bin/env bash
set -Eeuo pipefail

PHP="/usr/local/bin/php85"
SERVICE="php85.12-fpm.service"
SOCKET="/run/php85.12-fpm/php-fpm.sock"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta con sudo: sudo bash check-php85.sh" >&2
  exit 1
fi

echo "== Sistema =="
. /etc/os-release
printf '%s\n' "${PRETTY_NAME:-desconocido}"

echo
echo "== Versión PHP aislada =="
if [[ -x "$PHP" ]]; then
  "$PHP" -v
else
  echo "No se encuentra $PHP. ¿Se ejecutó install.sh?" >&2
  exit 1
fi

echo
echo "== Servicio PHP-FPM =="
systemctl --no-pager --full status "$SERVICE" || true

echo
echo "== Socket FastCGI =="
if [[ -S "$SOCKET" ]]; then
  ls -l "$SOCKET"
  echo "Socket encontrado."
else
  echo "No se encuentra el socket: $SOCKET" >&2
  echo "Consulta: sudo journalctl -u $SERVICE -n 80 --no-pager" >&2
  exit 1
fi

echo
echo "== Validación Nginx =="
if command -v nginx >/dev/null 2>&1; then
  nginx -t
else
  echo "Nginx no está instalado o no se encuentra en PATH."
fi

echo
echo "No se cambió la versión global de PHP ni se modificó la configuración de Nginx."
