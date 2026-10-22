# PHP 8.5.12 aislado para Ubuntu 22.04 + Nginx

Instalador para VPS que permite utilizar PHP 8.5.12 en sitios web mediante PHP-FPM **sin reemplazar la versión de PHP administrada por Ubuntu**. Diseñado para ejecutar desde Termius por SSH.

PHP 8.5.12 fue publicado por el proyecto PHP el 21 de octubre de 2026. El paquete se descarga de php.net y el instalador verifica el SHA-256 oficial antes de compilar.

## Qué hace

- Instala PHP 8.5.12 desde el código fuente oficial en `/opt/php/8.5.12`.
- Instala configuración aislada en `/etc/opt/php/8.5.12`.
- Crea el servicio `php85.12-fpm.service`.
- Crea el socket FastCGI `/run/php85.12-fpm/php-fpm.sock`.
- Proporciona el comando `/usr/local/bin/php85`.
- **No** cambia `/usr/bin/php`, `update-alternatives` ni modifica automáticamente los sitios Nginx.
- El desinstalador solo elimina los binarios aislados y el servicio del proyecto; conserva la configuración y los logs.

## Requisitos

- Ubuntu 22.04 LTS con systemd.
- Acceso SSH mediante Termius y permisos `sudo`.
- Conexión a Internet.
- Recomendado: 2 GB de RAM como mínimo; si la VPS es pequeña, compilar con `JOBS=1`.
- Espacio libre suficiente para descargar y compilar PHP (varios GB).
- Copia de seguridad de los archivos de configuración de Nginx antes de editarlos.

## 1. Subir a GitHub

1. Descarga y descomprime el ZIP del proyecto en tu computadora.
2. En GitHub crea un repositorio nuevo llamado `php-8.5.12-vps`. Si ya tienes los archivos localmente, no marques la opción de inicializar con README para evitar conflictos.
3. Sube el contenido completo de la carpeta, incluida la carpeta `nginx/`.

Si usas Git en tu computadora:

```bash
cd php-8.5.12-vps
git init
git add .
git commit -m "Instalador aislado PHP 8.5.12 para Ubuntu 22.04 y Nginx"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/php-8.5.12-vps.git
git push -u origin main
```

Cambia `TU_USUARIO` por tu usuario real de GitHub. Si Git pide autenticación, usa el método recomendado por GitHub; no guardes tokens dentro del repositorio.

## 2. Descargar y revisar desde Termius

Reemplaza `TU_USUARIO` por tu usuario de GitHub:

```bash
sudo apt-get update
sudo apt-get install -y git ca-certificates
git clone https://github.com/TU_USUARIO/php-8.5.12-vps.git
cd php-8.5.12-vps

# Confirma el sistema operativo y revisa los scripts antes de ejecutarlos.
cat /etc/os-release
less install.sh
less uninstall.sh
```

Pulsa `q` para salir de `less`.

## 3. Instalar PHP 8.5.12

En una VPS con poca memoria, utiliza un solo proceso de compilación:

```bash
sudo env JOBS=1 bash install.sh
```

En una VPS con suficiente RAM, puedes utilizar dos procesos:

```bash
sudo env JOBS=2 bash install.sh
```

La compilación puede tardar varios minutos. No cierres la sesión mientras esté trabajando. Si se interrumpe, revisa el error antes de volver a ejecutar el instalador.

## 4. Verificar sin afectar la versión anterior

```bash
/usr/local/bin/php85 -v
/usr/local/bin/php85 --ini
/usr/local/bin/php85 -m
sudo systemctl status php85.12-fpm --no-pager
sudo journalctl -u php85.12-fpm.service --no-pager -n 60
sudo bash check-php85.sh
```

Comprueba que la versión global anterior se conserva:

```bash
php -v
command -v php
```

Es normal que `php -v` muestre la versión anterior. Usa `php85` para ejecutar la versión nueva desde la terminal.

## 5. Conectar un sitio Nginx a PHP 8.5.12

El instalador **no cambia Nginx automáticamente**. Así se evita interrumpir sitios existentes.

Primero identifica el archivo del sitio. En Ubuntu, las configuraciones suelen estar en `/etc/nginx/sites-available/` y enlazarse desde `/etc/nginx/sites-enabled/`. Inspecciona la configuración activa:

```bash
sudo nginx -T 2>&1 | less
```

Busca el bloque `server` del dominio correcto y su bloque PHP existente (`location ~ \.php$` o similar). Haz una copia del archivo antes de editarlo. Por ejemplo, si el archivo real fuera `/etc/nginx/sites-available/ejemplo`:

```bash
sudo cp -a /etc/nginx/sites-available/ejemplo \
  /etc/nginx/sites-available/ejemplo.bak-antes-php85
sudo nano /etc/nginx/sites-available/ejemplo
```

**No añadas un segundo `location ~ \.php$` si ya existe uno.** En el bloque PHP existente, conserva las demás directivas y cambia únicamente la línea `fastcgi_pass` para que apunte a este socket:

```nginx
fastcgi_pass unix:/run/php85.12-fpm/php-fpm.sock;
```

Si el sitio no tiene todavía un bloque PHP, `nginx/php85-location.example.conf` contiene un ejemplo, que debe colocarse dentro del bloque `server { ... }` correcto. La configuración exacta puede variar según el sitio y el panel de hosting.

Antes de aplicar el cambio, comprueba que PHP-FPM esté activo y que el socket exista:

```bash
sudo systemctl is-active php85.12-fpm
sudo test -S /run/php85.12-fpm/php-fpm.sock && echo "Socket OK"
```

Valida la sintaxis y solo después recarga Nginx:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

No reinicies Nginx ni recargues su configuración si `nginx -t` falla. Revierte la copia de seguridad si la web deja de funcionar.

### Prueba de PHP en el sitio

Es preferible comprobar primero una página de prueba con acceso restringido. No dejes `phpinfo()` público: revela información sensible del servidor. Si creas un archivo de prueba, elimínalo inmediatamente después de verificar la versión.

## 6. Desinstalar

```bash
cd php-8.5.12-vps
sudo bash uninstall.sh
```

El desinstalador requiere escribir `ELIMINAR`. No elimina paquetes de PHP del sistema ni cambia Nginx. Antes de desinstalar, cambia los sitios que usen el socket nuevo a un socket PHP-FPM que siga activo; de lo contrario, esos sitios dejarán de procesar PHP.

## Rutas

- Binarios: `/opt/php/8.5.12`
- Configuración: `/etc/opt/php/8.5.12`
- Socket: `/run/php85.12-fpm/php-fpm.sock`
- Servicio: `php85.12-fpm.service`
- Logs: `/var/log/php85.12-fpm.log` y `/var/log/php85.12-php-errors.log`

## Fuente y verificación

- Anuncio oficial: https://www.php.net/releases/8_5_12.php
- Descarga: https://www.php.net/distributions/php-8.5.12.tar.xz
- SHA-256 oficial del archivo `.tar.xz`: `08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209`

El instalador compara esa huella antes de extraer y compilar.

## Licencia

MIT. Consulta `LICENSE`.
