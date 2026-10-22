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
| **Versión instalada** | Última versión menor disponible en la rama `8.5.x` | **Exactamente
