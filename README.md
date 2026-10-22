# 🚀 Despliegue Automatizado de PHP 8.5.12 para VPS

![PHP Version](https://img.shields.io/badge/PHP-8.5.12-777BB4?style=for-the-badge&logo=php&logoColor=white)
![Bash Script](https://img.shields.io/badge/Bash-Scripting-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux Support](https://img.shields.io/badge/Linux-Ubuntu%20%7C%20Debian%20%7C%20RHEL-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Termius Ready](https://img.shields.io/badge/Termius-Snippets%20Ready-000000?style=for-the-badge&logo=termius&logoColor=white)

Colección de scripts en Bash diseñados para instalar, compilar y activar **PHP 8.5.12** (`CLI` y `PHP-FPM`) de forma desatendida en servidores VPS Linux, optimizados para ejecutarse en una sola línea desde clientes SSH como **Termius**.

---

## ⚖️ ¿Qué script elegir?

El repositorio incluye dos métodos de instalación según las necesidades de tu infraestructura:

| Característica | `install.sh` (Repositorios PPA / Remi) | `compile-php-8.5.12.sh` (Código Fuente) |
| :--- | :--- | :--- |
| **Origen de paquetes** | Repositorios de Ondřej Surý (Debian/Ubuntu) o Remi (RHEL) | Paquete oficial `php-8.5.12.tar.gz` desde `php.net` |
| **Versión instalada** | Última versión menor disponible en la rama `8.5.x` | **Exactamente `8.5.12`** (fijada e inmutable) |
| **Tiempo estimado** | ⚡ 1 a 2 minutos | ⚙️ 5 a 15 minutos (según núcleos de CPU del VPS) |
| **Ruta de instalación** | Rutas estándar del sistema (`/usr/bin/php`, `/etc/php/8.5/`) | Directorio aislado (`/opt/php-8.5.12/`) + enlaces en `PATH` |
| **Caso de uso ideal** | Entornos estándar con actualizaciones vía `apt` o `dnf` | Entornos que exigen fijar exactamente el parche `8.5.12` |

---

## 🖥️ Sistemas Operativos y Extensiones Incluidas

### Distribuciones Soportadas
* **Familia Debian:** Ubuntu (20.04, 22.04, 24.04+) y Debian (11, 12+).
* **Familia Enterprise Linux:** AlmaLinux, Rocky Linux, RHEL, CentOS Stream (8, 9+) y Fedora.

### Extensiones Configuradas por Defecto
Ambos scripts instalan y activan los módulos esenciales para aplicaciones modernas (Laravel, Symfony, WordPress, APIs REST):
* `cli`, `fpm`, `common`, `opcache`
* `mysqlnd` (`mysqli`, `pdo_mysql`)
* `curl`, `mbstring`, `xml`, `xsl`, `soap`
* `gd` (con soporte `jpeg` y `webp`), `zip`, `zlib`
* `intl`, `bcmath`, `sodium`, `pcntl`, `sockets`

---

## ⚡ Instalación Rápida (One-Liner)

Conéctate a tu VPS con un usuario con privilegios `sudo` o como `root` y ejecuta el comando correspondiente al método que prefieras.

### Opción A: Instalación rápida mediante Gestor de Paquetes (`install.sh`)

```bash
curl -sSL [https://raw.githubusercontent.com/golbert19/php-8.5.12-vps/main/install.sh](https://raw.githubusercontent.com/golbert19/php-8.5.12-vps/main/install.sh) | sudo bash
```

### Opción B: Compilación exacta desde el Código Fuente (`compile-php-8.5.12.sh`)

```bash
curl -sSL [https://raw.githubusercontent.com/golbert19/php-8.5.12-vps/main/compile-php-8.5.12.sh](https://raw.githubusercontent.com/golbert19/php-8.5.12-vps/main/compile-php-8.5.12.sh) | sudo bash
```

### Opción C: Clonar el repositorio manualmente (Auditoría previa)

Si prefieres inspeccionar o personalizar los scripts antes de ejecutarlos:

```bash
git clone [https://github.com/golbert19/php-8.5.12-vps.git](https://github.com/golbert19/php-8.5.12-vps.git)
cd php-8.5.12-vps
chmod +x install.sh compile-php-8.5.12.sh

# Ejecutar versión por repositorio:
sudo ./install.sh

# O ejecutar versión compilada desde fuente:
sudo ./compile-php-8.5.12.sh
```

---

## 📱 Guía de Uso desde Termius

### 1. Guardar como Snippet para ejecución en un toque
Para automatizar el despliegue en múltiples servidores desde la aplicación móvil o de escritorio de **Termius**:

1. Abre **Termius** y dirígete a la sección **Snippets** en el menú lateral.
2. Haz clic en **New Snippet** (`+`).
3. Asigna un nombre descriptivo (ej. `Deploy PHP 8.5.12 - Fuente`).
4. En el bloque **Script**, pega el comando `curl` de la opción que utilices habitualmente:
   ```bash
   curl -sSL [https://raw.githubusercontent.com/golbert19/php-8.5.12-vps/main/compile-php-8.5.12.sh](https://raw.githubusercontent.com/golbert19/php-8.5.12-vps/main/compile-php-8.5.12.sh) | sudo bash
   ```
5. Guarda los cambios. Al abrir cualquier conexión SSH hacia tu VPS, selecciona el ícono de **Snippets** para lanzar la instalación automáticamente.

### 2. Proteger la sesión con `tmux` (Recomendado al compilar)
Si ejecutas `compile-php-8.5.12.sh` desde Termius en un dispositivo móvil, utiliza `tmux` para evitar que una desconexión de red interrumpa la compilación:

```bash
# 1. Instalar tmux y crear una sesión en segundo plano
sudo apt-get install -y tmux || sudo dnf install -y tmux
tmux new -s php-build

# 2. Lanzar la compilación dentro de la sesión
curl -sSL [https://raw.githubusercontent.com/golbert19/php-8.5.12-vps/main/compile-php-8.5.12.sh](https://raw.githubusercontent.com/golbert19/php-8.5.12-vps/main/compile-php-8.5.12.sh) | sudo bash
```

> **Nota:** Si la app de Termius se cierra o cambias de red durante el proceso, reconéctate al VPS y ejecuta `tmux attach -t php-build` para retomar la terminal exactamente donde quedó.

---

## 📂 Rutas Clave y Gestión del Servicio

Una vez finalizado cualquiera de los dos scripts, puedes verificar la versión activa en consola ejecutando:

```bash
php -v
```

### Ubicación de archivos según el método utilizado

| Componente | Método Repositorio (`install.sh`) | Método Compilado (`compile-php-8.5.12.sh`) |
| :--- | :--- | :--- |
| **Binario CLI** | `/usr/bin/php8.5` | `/opt/php-8.5.12/bin/php` |
| **Archivo `php.ini`** | `/etc/php/8.5/fpm/php.ini` (Debian/Ubuntu)<br>`/etc/php.ini` (RHEL/Alma/Rocky) | `/opt/php-8.5.12/etc/php.ini` |
| **Configuración FPM Pool** | `/etc/php/8.5/fpm/pool.d/www.conf` | `/opt/php-8.5.12/etc/php-fpm.d/www.conf` |
| **Directorio `conf.d`** | `/etc/php/8.5/fpm/conf.d/` | `/opt/php-8.5.12/etc/conf.d/` |
| **Socket Unix FPM** | `/run/php/php8.5-fpm.sock` | `/run/php/php8.5-fpm.sock` |

### Comandos de administración de `PHP-FPM`

```bash
# Verificar estado del servicio
sudo systemctl status php8.5-fpm

# Reiniciar PHP-FPM tras cambios en php.ini
sudo systemctl restart php8.5-fpm

# Recargar configuración sin cortar conexiones activas
sudo systemctl reload php8.5-fpm
```

---

## 🌐 Configuración del Servidor Web

### Nginx
En el bloque `server` de tu archivo de configuración (`/etc/nginx/sites-available/tu-sitio.conf` o `/etc/nginx/conf.d/default.conf`), apunta la directiva `fastcgi_pass` al nuevo socket de PHP 8.5:

```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.5-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
}
```

Verifica la sintaxis y recarga Nginx:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Apache (Ubuntu / Debian)
Habilita los módulos de proxy FastCGI y la configuración de `php8.5-fpm`:

```bash
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php8.5-fpm
sudo systemctl reload apache2
```

---

## 📄 Licencia

Este proyecto se distribuye bajo la licencia **MIT**. Eres libre de clonar, modificar y adaptar los scripts para tus propios servidores.

*Desarrollado y mantenido por [golbert19](https://github.com/golbert19).*
