#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="8.5.12"
PREFIX="/opt/php/${VERSION}"
CONFIG_DIR="/etc/opt/php/${VERSION}"
SERVICE="php85.12-fpm.service"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta como root: sudo bash uninstall.sh" >&2
  exit 1
fi

cat <<MSG
Este desinstalador quitará únicamente la instalación aislada PHP ${VERSION} creada por este proyecto:
  - Binarios: ${PREFIX}
  - Servicio systemd: ${SERVICE}
  - Enlaces php85/phpize85/php-config85/php-fpm85, si pertenecen a esta instalación

No cambiará /usr/bin/php, no quitará paquetes de Debian/Ubuntu y no modificará Nginx/Apache.
Se conservará ${CONFIG_DIR} y los logs para proteger la configuración personalizada.
MSG
read -r -p "Escribe ELIMINAR para continuar: " answer
[[ "$answer" == "ELIMINAR" ]] || { echo "Cancelado."; exit 0; }

systemctl disable --now "$SERVICE" 2>/dev/null || true
rm -f "/etc/systemd/system/$SERVICE"
systemctl daemon-reload
systemctl reset-failed "$SERVICE" 2>/dev/null || true

remove_link_if_owned() {
  local link="$1" expected="$2"
  if [[ -L "$link" ]] && [[ "$(readlink -f "$link" 2>/dev/null || true)" == "$expected" ]]; then
    rm -f "$link"
  fi
}
remove_link_if_owned /usr/local/bin/php85 "$PREFIX/bin/php"
remove_link_if_owned /usr/local/bin/phpize85 "$PREFIX/bin/phpize"
remove_link_if_owned /usr/local/bin/php-config85 "$PREFIX/bin/php-config"
remove_link_if_owned /usr/local/sbin/php-fpm85 "$PREFIX/sbin/php-fpm"

rm -rf -- "$PREFIX"
echo "PHP ${VERSION} aislado y su servicio fueron eliminados."
echo "Configuración conservada en: ${CONFIG_DIR}"
echo "Los paquetes de compilación y los logs no se eliminaron."
