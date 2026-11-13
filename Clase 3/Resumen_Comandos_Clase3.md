# Resumen Práctico de Comandos - Clase 3

> **Asignatura:** Temas Selectos de Ingeniería en Computación - DevOps  
> **Tema:** Comandos ejecutados en la sesión (Paquetería DNF/RPM, Apache httpd, SELinux, firewalld y Lynis).  
> **Objetivo de este documento:** Guía rápida y detallada de consulta donde cada comando incluye su función, explicación de banderas y efecto en el sistema operativo.

---

## Índice Rápido de Etapas

1. [Restauración de Repositorios Oficiales](#etapa-1-restauración-de-repositorios-oficiales)
2. [Gestión e Inspección de Paquetes (`dnf` vs `rpm`)](#etapa-2-gestión-e-inspección-de-paquetes-dnf-vs-rpm)
3. [Instalación de Apache y Herramientas de SELinux](#etapa-3-instalación-de-apache-y-herramientas-de-selinux)
4. [Inspección de Contextos de Seguridad SELinux](#etapa-4-inspección-de-contextos-de-seguridad-selinux)
5. [El Laboratorio de Cambio de Puerto y Solución con `semanage`](#etapa-5-el-laboratorio-de-cambio-de-puerto-y-solución-con-semanage)
6. [Demostración de Contención contra Intrusiones (`runcon`)](#etapa-6-demostración-de-contención-contra-intrusiones-runcon)
7. [Configuración del Cortafuegos Perimetral (`firewalld`)](#etapa-7-configuración-del-cortafuegos-perimetral-firewalld)
8. [Auditoría de Seguridad y Medición con Lynis](#etapa-8-auditoría-de-seguridad-y-medición-con-lynis)

---

## Etapa 1: Restauración de Repositorios Oficiales

En la clase 2 se desactivaron los repositorios remotos para trabajar offline con el CD-ROM. Al inicio de la clase 3 se reactivó la salida a internet.

### 1.1 Localizar archivos de repositorio
```bash
find / -name '*.repo'
```
* **¿Qué hace?** Busca recursivamente en toda la raíz del disco (`/`) cualquier archivo con extensión `.repo`.
* **Argumentos:**
  - `/`: Directorio de inicio de búsqueda (raíz del sistema).
  - `-name '*.repo'`: Filtro para buscar coincidencias por nombre exacto.
* **Efecto:** Nos mostró que los repositorios originales estaban respaldados en `/root/`.

---

### 1.2 Mover repositorios a la carpeta activa de DNF
```bash
mv /root/rocky*.repo /etc/yum.repos.d/
```
* **¿Qué hace?** Mueve los archivos de repositorios oficiales de Rocky Linux desde `/root/` al directorio oficial donde DNF/YUM lee los orígenes de descarga (`/etc/yum.repos.d/`).
* **Argumentos:**
  - `rocky*.repo`: Comodín que selecciona todos los archivos que inicien con "rocky" y terminen en ".repo" (`rocky.repo`, `rocky-addons.repo`, `rocky-extras.repo`, etc.).

---

### 1.3 Desactivar el repositorio del CD-ROM
```bash
mv /etc/yum.repos.d/cdrom.repo /root/
```
* **¿Qué hace?** Saca el archivo de configuración del CD-ROM de `/etc/yum.repos.d/` para que DNF no intente buscar paquetes en el lector de discos inexistente o desconectado.

---

### 1.4 Limpiar metadatos en caché y verificar repositorios
```bash
dnf clean all
dnf repolist
```
* **¿Qué hace?**
  - `clean all`: Elimina paquetes en caché, encabezados XML y metadatos viejos descargados en disco.
  - `repolist`: Consulta y muestra en pantalla la lista de repositorios activos (`baseos`, `appstream`, `extras`).

---

## Etapa 2: Gestión e Inspección de Paquetes (`dnf` vs `rpm`)

### 2.1 Identificar qué paquete provee un comando
```bash
dnf whatprovides nc
```
* **¿Qué hace?** Escanea la base de datos de repositorios para determinar qué paquete RPM contiene el binario ejecutable `nc` (Netcat).
* **Resultado:** Indica que `nmap-ncat` provee dicho comando.

---

### 2.2 Consultar versión exacta y arquitectura del sistema
```bash
cat /etc/os-release
```
* **¿Qué hace?** Lee el archivo estándar del sistema operativo para conocer la versión exacta de la distribución.
* **Datos observados:**
  - `VERSION_ID="10.2"`
  - `PLATFORM_ID="platform:el10"` *(Indica que solo son compatibles paquetes con sufijo `.el10`)*.

---

### 2.3 Prueba de instalación con RPM (Bajo Nivel)
```bash
rpm -ivh nmap-ncat-7.92-5.el10.x86_64.rpm
```
* **¿Qué hace?** Instala un archivo `.rpm` local directamente sin consultar repositorios en internet.
* **Banderas:**
  - `-i` (*install*): Ordena instalar el paquete en el sistema.
  - `-v` (*verbose*): Imprime mensajes detallados de cada fase.
  - `-h` (*hash*): Dibuja una barra de progreso en terminal usando el carácter `#`.
* **Comportamiento clave:** Si el paquete ya existe en el sistema, `rpm` aborta con error (no es idempotente). Si faltan librerías, falla sin resolverlas.

---

### 2.4 Prueba de incompatibilidad de plataforma
```bash
rpm -ivh nmap-ncat-7.92-5.el9.x86_64.rpm
```
* **¿Qué hace?** Intenta instalar un binario compilado para Rocky Linux 9 (`el9`) en Rocky Linux 10 (`el10`).
* **Efecto didáctico:** Provoca fallos por dependencias de librerías compartidas (`glibc`), demostrando por qué no deben mezclarse versiones de Enterprise Linux.

---

## Etapa 3: Instalación de Apache y Herramientas de SELinux

### 3.1 Instalar paquetes necesarios
```bash
dnf install -y policycoreutils-python-utils setroubleshoot-server httpd
```
* **¿Qué hace?** Descarga e instala el servidor web Apache y las herramientas administrativas de SELinux resolviendo todas sus dependencias automáticamente.
* **Banderas:**
  - `-y` (*assume-yes*): Responde "sí" automáticamente a la confirmación de descarga y claves GPG.
* **Paquetes instalados:**
  - `httpd`: Servidor Web Apache.
  - `policycoreutils-python-utils`: Proporciona la herramienta imprescindible `semanage` (para gestionar puertos y contextos).
  - `setroubleshoot-server`: Analizador de denegaciones de SELinux que traduce logs criptográficos a diagnósticos comprensibles (`audit2why`, `sealert`).

---

### 3.2 Iniciar y habilitar el servicio Apache
```bash
systemctl enable --now httpd
```
* **¿Qué hace?** Realiza dos acciones en un solo comando:
  1. `enable`: Crea los enlaces simbólicos en systemd para que Apache arranque automáticamente cada vez que se encienda la máquina.
  2. `--now`: Inicia el servicio en ese mismo instante en la memoria RAM.

---

### 3.3 Validar respuesta del servidor web
```bash
curl -I localhost
```
* **¿Qué hace?** Realiza una petición HTTP local al puerto estándar 80.
* **Banderas:**
  - `-I` (*head*): Solicita únicamente las cabeceras HTTP de respuesta (código de estado, versión del servidor `Server: Apache/2.4.63 (Rocky Linux)`), sin descargar todo el HTML.

---

## Etapa 4: Inspección de Contextos de Seguridad SELinux

### 4.1 Inspeccionar contextos de directorios y archivos
```bash
ls -ldZ /var/www/html
ls -lZ /etc/httpd/
```
* **¿Qué hace?** Muestra el listado de archivos y carpetas agregando la etiqueta de seguridad obligatoria de SELinux.
* **Banderas:**
  - `-l`: Formato largo (permisos, propietario, tamaño, fecha).
  - `-d`: Muestra la carpeta en sí misma, no su contenido interior.
  - **`-Z`**: Bandera clave que imprime el contexto de SELinux (`usuario:rol:tipo:nivel`).
* **Contextos observados:**
  - `/var/www/html`: `system_u:object_r:httpd_sys_content_t:s0`
  - `/etc/httpd/`: `system_u:object_r:httpd_config_t:s0`

---

### 4.2 Consultar y fijar el modo de SELinux
```bash
getenforce
setenforce 1
```
* **¿Qué hace?**
  - `getenforce`: Imprime el modo actual (`Enforcing`, `Permissive` o `Disabled`).
  - `setenforce 1`: Establece el modo en **Enforcing** (estricto, donde el kernel intercepta y bloquea toda acción fuera de política).

---

### 4.3 Inspeccionar interruptores booleanos de Apache
```bash
getsebool -a | grep httpd
```
* **¿Qué hace?** Consulta la lista completa de "booleanos" (interruptores binarios on/off) de SELinux y filtra solo los relacionados con el servicio web Apache (ej. si Apache tiene permiso de conectar a bases de datos o leer carpetas `/home/`).
* **Banderas:**
  - `-a`: Muestra todos los booleanos del sistema.

---

## Etapa 5: El Laboratorio de Cambio de Puerto y Solución con `semanage`

Este fue el ejercicio central de la clase: provocar un bloqueo de SELinux al cambiar el puerto de Apache y solucionarlo sin desactivar la seguridad.

### 5.1 Cambiar puerto de Apache al 8088
```bash
sed -i 's/^Listen 80/Listen 8088/' /etc/httpd/conf/httpd.conf
```
* **¿Qué hace?** Modifica directamente el archivo principal de configuración de Apache, cambiando la directiva de escucha del puerto 80 al puerto 8088.
* **Banderas:**
  - `-i` (*in-place*): Guarda los cambios directamente sobre el archivo original.

---

### 5.2 Reiniciar el servicio y observar el fallo
```bash
systemctl restart httpd
systemctl status httpd --no-pager
```
* **¿Qué hace?** Intenta reiniciar Apache con la nueva configuración.
* **Efecto observado:** **El comando falla.** Al revisar el estado se observa:
  ```text
  (13)Permission denied: AH00072: make_sock: could not bind to address [::]:8088
  (13)Permission denied: AH00072: make_sock: could not bind to address 0.0.0.0:8088
  ```
  *Explicación:* Aunque systemd corre como `root`, el proceso de Apache pertenece al dominio `httpd_t`, y SELinux le impide abrir sockets en puertos no registrados.

---

### 5.3 Consultar puertos autorizados para Apache en SELinux
```bash
semanage port -l | grep http_port_t
```
* **¿Qué hace?** Lista (`-l`) todos los puertos registrados en la base de datos de SELinux y filtra el tipo `http_port_t`.
* **Resultado:** Muestra `80, 81, 443, 488, 8008, 8009, 8443, 9000`. El puerto `8088` no forma parte de la lista.

---

### 5.4 Registrar el nuevo puerto en la política de SELinux
```bash
semanage port -a -t http_port_t -p tcp 8088
```
* **¿Qué hace?** Registra formalmente y de forma permanente el puerto `8088/tcp` dentro de los puertos permitidos para servidores web en SELinux.
* **Banderas:**
  - `-a` (*add*): Agrega una nueva regla.
  - `-t http_port_t` (*type*): Especifica el tipo de puerto de la política.
  - `-p tcp` (*protocol*): Protocolo de transporte.
  - `8088`: Número de puerto a autorizar.

---

### 5.5 Reiniciar Apache y validar funcionamiento
```bash
systemctl restart httpd
systemctl is-active httpd
curl -I localhost:8088
```
* **¿Qué hace?** Reinicia Apache (ahora arranca con éxito `active`) y comprueba la respuesta HTTP correcta por el nuevo puerto 8088.

---

## Etapa 6: Demostración de Contención contra Intrusiones (`runcon`)

### 6.1 Simulación de ataque dentro del dominio `httpd_t`
```bash
runcon -u system_u -r system_r -t httpd_t cat /etc/shadow
```
* **¿Qué hace?** Ejecuta el comando `cat /etc/shadow` obligándolo a correr bajo la identidad y contexto de un proceso Apache comprometido.
* **Banderas:**
  - `-u system_u`: Usuario de SELinux.
  - `-r system_r`: Rol de sistema.
  - `-t httpd_t`: Tipo/Dominio confinado de Apache.
* **Resultado:** `runcon: «cat»: Permiso denegado`.
* **Importancia para examen/evaluación:** Demuestra que **incluso si un atacante obtiene privilegios de root dentro de Apache, SELinux le prohíbe tocar archivos confidenciales del sistema**.

---

## Etapa 7: Configuración del Cortafuegos Perimetral (`firewalld`)

### 7.1 Abrir el puerto 8088 en el cortafuegos
```bash
firewall-cmd --permanent --zone=public --add-port=8088/tcp
```
* **¿Qué hace?** Autoriza el tráfico entrante al puerto `8088/tcp` en la zona pública del firewall.
* **Banderas:**
  - `--permanent`: Escribe la regla en el archivo XML de disco (`/etc/firewalld/zones/public.xml`) para que persista al reiniciar.
  - `--zone=public`: Aplica la regla a la zona pública.
  - `--add-port=8088/tcp`: Abre el puerto y protocolo especificados.

---

### 7.2 Habilitar registro de paquetes denegados
```bash
firewall-cmd --set-log-denied=all
```
* **¿Qué hace?** Ordena a `firewalld` escribir en los registros del sistema (`syslog` / `journalctl`) cada paquete que sea rechazado o descartado por el firewall, convirtiéndolo en un sensor de intrusión.

---

### 7.3 Recargar y consultar configuración activa
```bash
firewall-cmd --reload
firewall-cmd --zone=public --list-all
```
* **¿Qué hace?**
  - `--reload`: Compila las reglas permanentes en el kernel (`nftables`) en caliente sin interrumpir sesiones SSH activas.
  - `--list-all`: Imprime en pantalla todos los servicios, puertos, interfaces y reglas activas en la zona.

---

## Etapa 8: Auditoría de Seguridad y Medición con Lynis

Lynis es la herramienta oficial utilizada para evaluar el endurecimiento del servidor y competir por el punto extra.

### 8.1 Habilitar repositorio EPEL y CodeReady Builder (CRB)
```bash
dnf install -y epel-release
/usr/bin/crb enable
```
* **¿Qué hace?** Activa los repositorios comunitarios empresariales oficiales (Extra Packages for Enterprise Linux) y CRB para permitir la instalación de herramientas avanzadas de auditoría como Lynis.

---

### 8.2 Instalar Lynis
```bash
dnf install -y lynis
```
* **¿Qué hace?** Instala la suite de auditoría técnica Lynis en el sistema.

---

### 8.3 Ejecutar auditoría completa del sistema
```bash
lynis audit system -Q
```
* **¿Qué hace?** Ejecuta más de 240 pruebas de seguridad automatizadas sobre el sistema operativo (autenticación, firewall, SELinux, permisos, SSH, kernel).
* **Banderas:**
  - `-Q` (*quick*): Modo no interactivo; corre todas las pruebas continuas sin pausar para solicitar pulsar la tecla Enter entre módulos.

---

### 8.4 Consultar la calificación obtenida (Hardening Index)
```bash
grep hardening_index /var/log/lynis-report.dat
```
* **¿Qué hace?** Filtra el archivo de reporte generado por Lynis para mostrar el índice de robustez de 0 a 100.
* **Calificación obtenida en tu VM:**
  ```text
  hardening_index=68
  ```

---

### 8.5 Guardar la línea base (Antes vs Después)
```bash
cp /var/log/lynis-report.dat /root/lynis-inicial.dat
```
* **¿Qué hace?** Copia el reporte inicial a `/root/lynis-inicial.dat` para conservarlo intacto antes de aplicar mejoras y poder presentar la comparativa exigida en la evaluación.

---

### 8.6 Filtrar advertencias críticas del reporte
```bash
grep '^warning\[\]=' /var/log/lynis-report.dat
grep '^suggestion\[\]=' /var/log/lynis-report.dat | head -15
```
* **¿Qué hace?** Extrae las vulnerabilidades graves (`warning`) y las primeras 15 sugerencias de hardening para saber qué configuraciones corregir primero.

---

## Tabla Resumen de Comandos Rápidos

| Comando | Utilidad Principal |
| :--- | :--- |
| `dnf whatprovides <comando>` | Busca qué paquete provee un archivo o ejecutable. |
| `rpm -ivh <archivo.rpm>` | Instala paquete local RPM (no resuelve dependencias). |
| `systemctl enable --now <servicio>` | Inicia un servicio y lo programa para arrancar con el SO. |
| `ls -ldZ <ruta>` | Muestra contexto de SELinux (`usuario:rol:tipo:nivel`). |
| `getenforce` / `setenforce 1` | Consulta o activa modo estricto de SELinux (`Enforcing`). |
| `semanage port -l \| grep <tipo>` | Consulta qué puertos de red están autorizados en SELinux. |
| `semanage port -a -t <tipo> -p tcp <puerto>` | Autoriza un puerto de red en SELinux de forma permanente. |
| `runcon -u system_u -r system_r -t <tipo> <cmd>` | Ejecuta un comando en un dominio confinado para probar contención. |
| `firewall-cmd --permanent --add-port=<puerto/proto>` | Abre un puerto permanente en el cortafuegos. |
| `firewall-cmd --reload` | Aplica cambios del firewall sin desconectar sesiones activas. |
| `lynis audit system -Q` | Realiza auditoría de seguridad automática en el servidor. |
| `grep hardening_index /var/log/lynis-report.dat` | Consulta la calificación numérica de seguridad (0 a 100). |
