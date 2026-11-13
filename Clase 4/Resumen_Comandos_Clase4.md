# Resumen Práctico de Comandos - Clase 4

> **Asignatura:** Temas Selectos de Ingeniería en Computación - DevOps  
> **Tema:** Comandos de la Clase 4 (Identidades con SSSD/Sudo, Ciclo de Vida de Contenedores con Podman, Mapeo de Puertos, Redes Virtuales, Volúmenes Persistentes y Construcción con Containerfile).  
> **Objetivo:** Acordeón de referencia rápida donde cada comando incluye su función exacta, desglose de banderas/argumentos y comportamiento en el sistema.

---

## Índice de Etapas

1. [Identidades y Privilegios en el Host (SSSD / Sudo)](#etapa-1-identidades-y-privilegios-en-el-host)
2. [Instalación y Verificación de Podman](#etapa-2-instalación-y-verificación-de-podman)
3. [Gestión de Imágenes OCI (`podman pull` e `images`)](#etapa-3-gestión-de-imágenes-oci)
4. [Despliegue y Publicación de Puertos (`podman run -p`)](#etapa-4-despliegue-y-publicación-de-puertos)
5. [Inspección de Contenedores y Pruebas de Red](#etapa-5-inspección-de-contenedores-y-pruebas-de-red)
6. [Control de Estados (`stop`, `start` y `ps -a`)](#etapa-6-control-de-estados-del-contenedor)
7. [Interacción con Shell Interna (`podman exec`)](#etapa-7-interacción-con-shell-interna)
8. [Redes Virtuales Personalizadas (`podman network`)](#etapa-8-redes-virtuales-personalizadas)
9. [Persistencia con Volúmenes Gestionados (`podman volume`)](#etapa-9-persistencia-con-volúmenes-gestionados)
10. [Compilación de Imágenes con `Containerfile` (`podman build`)](#etapa-10-compilación-de-imágenes-con-containerfile)

---

## Etapa 1: Identidades y Privilegios en el Host

### 1.1 Limpieza de caché de SSSD y reinicio del demonio
```bash
sss_cache -E && systemctl restart sssd
```
* **¿Qué hace?** Fuerza la expiración de la memoria caché local de usuarios y grupos de red en servidores conectados a Active Directory / FreeIPA, y reinicia el servicio de seguridad del sistema.
* **Banderas:**
  - `-E` (*expire*): Invalida inmediatamente todas las entradas almacenadas en caché (usuarios, grupos y reglas netgroups).
* **Efecto:** Garantiza que cualquier cambio reciente en los permisos de un usuario corporativo sea reconocido al instante.

---

### 1.2 Inspeccionar privilegios de sudo para un usuario
```bash
sudo -l -U operador01
```
* **¿Qué hace?** Muestra la lista de comandos y privilegios de superusuario que tiene permitidos el usuario `operador01` según el archivo `/etc/sudoers`.
* **Banderas:**
  - `-l` (*list*): Lista los privilegios permitidos.
  - `-U operador01` (*user*): Consulta los privilegios del usuario especificado en lugar del usuario actual.

---

### 1.3 Cambio de sesión al usuario con entorno completo
```bash
su - operador01
```
* **¿Qué hace?** Cambia la sesión interactiva al usuario `operador01`.
* **Banderas:**
  - `-` (*login shell*): Carga las variables de entorno completas del usuario (`HOME`, `PATH`, `.bashrc`) como si acabara de iniciar sesión desde cero.

---

## Etapa 2: Instalación y Verificación de Podman

### 2.1 Instalar Podman desde los repositorios oficiales
```bash
dnf install -y podman
```
* **¿Qué hace?** Descarga e instala el motor de contenedores Podman y sus utilerías asociadas (`crun`, `conmon`, `skopeo`, `slirp4netns`).
* **Banderas:**
  - `-y`: Responde "sí" a las confirmaciones de instalación.

---

### 2.2 Verificar versión y estado del entorno Podman
```bash
podman --version
podman info
```
* **¿Qué hace?**
  - `--version`: Imprime la versión binaria instalada (ej. `podman version 5.x / 4.x`).
  - `info`: Muestra la arquitectura del sistema, si está corriendo en modo *rootless* o *rootful*, el runtime OCI (`crun`), el driver de almacenamiento (`overlay`) y los registros configurados.

---

## Etapa 3: Gestión de Imágenes OCI

### 3.1 Consultar imágenes locales
```bash
podman images
```
* **¿Qué hace?** Lista las imágenes de contenedores que ya se encuentran descargadas y almacenadas en el disco local (`/var/lib/containers/storage`).
* **Columnas mostradas:** `REPOSITORY`, `TAG`, `IMAGE ID`, `CREATED`, `SIZE`.

---

### 3.2 Descargar imagen oficial desde Docker Hub
```bash
podman pull docker.io/library/nginx:latest
```
* **¿Qué hace?** Se conecta al registro remoto de Docker Hub, descarga las capas inmutables comprimidas de Nginx y las guarda en el almacenamiento local.
* **Buenas prácticas:** Utilizar el nombre completo calificado (FQIN: `docker.io/library/nginx:latest`) evita ambigüedades y diálogos interactivos de selección de registros.

---

## Etapa 4: Despliegue y Publicación de Puertos

### 4.1 Despliegue básico en segundo plano sin puerto publicado
```bash
podman run -dit --name nginx01 docker.io/library/nginx
```
* **¿Qué hace?** Crea e inicializa un nuevo contenedor aislado llamado `nginx01`.
* **Desglose de banderas:**
  - `-d` (*detached*): Ejecuta el contenedor en segundo plano, liberando la terminal.
  - `-i` (*interactive*): Mantiene abierto el flujo STDIN del contenedor.
  - `-t` (*tty*): Asigna una pseudo-terminal para recibir señales y formatear texto.
  - `--name nginx01`: Asigna un nombre alfanumérico legible para evitar tener que utilizar el hash hexadecimal.
* **Efecto de red:** Solo es accesible por su IP interna privada en la subred de Podman (`10.88.0.x`).

---

### 4.2 Despliegue con mapeo de puertos hacia el host
```bash
podman run -dit --name nginx02 -p 8080:80 docker.io/library/nginx:latest
```
* **¿Qué hace?** Crea el contenedor `nginx02` y publica su servicio web haciéndolo accesible desde fuera del contenedor.
* **Banderas:**
  - **`-p 8080:80`** (*Port Forwarding - Host:Contenedor*): Conecta el puerto `8080` de tu máquina virtual con el puerto `80` interno del contenedor.

---

## Etapa 5: Inspección de Contenedores y Pruebas de Red

### 5.1 Ver interfaces del sistema operativo
```bash
ip addr
```
* **¿Qué hace?** Muestra los adaptadores de red de la máquina virtual. Al ejecutar Podman, se observa la interfaz puente `podman0` con el gateway `10.88.0.1`.

---

### 5.2 Extraer la IP interna asignada al contenedor
```bash
podman inspect nginx02 | grep -i IPAddress
```
* **¿Qué hace?** Inspecciona toda la metadata en formato JSON del contenedor y filtra las líneas donde aparece la IP privada asignada (ej. `10.88.0.3`).

---

### 5.3 Pruebas de conectividad HTTP con `curl`
```bash
# 1. Petición directa a la IP interna del contenedor (funciona dentro de la VM)
curl 10.88.0.3

# 2. Petición por el puerto publicado en localhost
curl localhost:8080

# 3. Petición por la IP de la VM en la red local (para clientes externos)
curl 192.168.71.128:8080
```
* **Resultado:** Devuelve el código HTML `<h1>Welcome to nginx!</h1>`, confirmando que el servidor web interno responde por todas las vías.

---

## Etapa 6: Control de Estados del Contenedor

### 6.1 Detener un contenedor en ejecución
```bash
podman stop nginx02
```
* **¿Qué hace?** Envía la señal `SIGTERM` al proceso principal de Nginx dentro del contenedor para que finalice de manera ordenada; si no responde en 10 segundos, envía `SIGKILL`.
* **Comprobación:** `curl localhost:8080` fallará de inmediato con `Conexión rehusada`.

---

### 6.2 Reanudar la ejecución de un contenedor detenido
```bash
podman start nginx02
```
* **¿Qué hace?** Enciende nuevamente el contenedor conservando todos los cambios y archivos que tenía antes de detenerse.
* **Comprobación:** `curl localhost:8080` vuelve a responder con éxito.

---

### 6.3 Listar todos los contenedores del sistema
```bash
podman ps -a
```
* **¿Qué hace?** Lista el inventario completo de contenedores.
* **Banderas:**
  - `-a` (*all*): Muestra tanto los que están actualmente encendidos (`Up`) como los que están apagados (`Exited`). Sin `-a`, solo muestra los activos.

---

## Etapa 7: Interacción con Shell Interna

### 7.1 Abrir una terminal interactiva dentro del contenedor
```bash
podman exec -it nginx02 /bin/bash
```
* **¿Qué hace?** Lanza un nuevo proceso `/bin/bash` **dentro del contenedor que ya está en marcha**, permitiendo navegar por su sistema de archivos interno.
* **Banderas:**
  - `exec`: Ejecuta un comando en un contenedor activo (a diferencia de `run`, que crea uno nuevo).
  - `-i` (*interactive*) y `-t` (*tty*): Brindan prompt interactivo con colores y cursor.
* **Para salir:** Escribir `exit` y dar Enter (regresa a la terminal del host sin apagar el contenedor).

---

## Etapa 8: Redes Virtuales Personalizadas

### 8.1 Listar las redes existentes
```bash
podman network ls
```
* **¿Qué hace?** Muestra los nombres, controladores e interfaces de las redes virtuales gestionadas por Podman.

---

### 8.2 Crear una red corporativa personalizada
```bash
podman network create --subnet 10.89.0.0/16 --gateway 10.89.0.1 prod
```
* **¿Qué hace?** Crea una red puente virtual aislada llamada `prod`.
* **Argumentos:**
  - `--subnet 10.89.0.0/16`: Rango de direccionamiento IP dedicado.
  - `--gateway 10.89.0.1`: IP asignada al host para enrutar el tráfico de esa red.
  - `prod`: Nombre de la red.

---

### 8.3 Desplegar contenedor en la red `prod`
```bash
podman run -dit --name nginx03 --network prod -p 8081:80 nginx:latest
```
* **¿Qué hace?** Arranca `nginx03` en el puerto `8081` del host, pero conectado al segmento de red `prod`.
* **Comprobación de IP:**
  ```bash
  podman inspect nginx03 | grep -i IPAddress
  # Salida: "10.89.0.2" (perteneciente a la red prod)
  ```

---

## Etapa 9: Persistencia con Volúmenes Gestionados

### 9.1 Crear e inspeccionar un volumen persistente
```bash
podman volume create volngnix
podman volume ls
podman volume inspect volngnix
```
* **¿Qué hace?**
  - `volume create`: Reserva un directorio gestionado en el disco del host.
  - `volume inspect`: Muestra la ruta física en el host donde se guardan los archivos (típicamente `/var/lib/containers/storage/volumes/volngnix/_data`).

---

### 9.2 Montar el volumen en el contenedor
```bash
podman run -dit --name ngnix04 -p 8082:80 --network prod --volume volngnix:/usr/share/nginx/html nginx:latest
```
* **¿Qué hace?** Vincula el volumen persistente `volngnix` del host con la carpeta donde Nginx busca los archivos web (`/usr/share/nginx/html`).
* **Banderas:**
  - `--volume volngnix:/usr/share/nginx/html`: Mapea el volumen del host al destino interno.
* **Ventaja crítica:** Si se borra el contenedor con `podman rm -f ngnix04`, los archivos dentro de `volngnix` en el host **no se pierden**.

---

## Etapa 10: Compilación de Imágenes con `Containerfile`

### 10.1 Compilar una imagen personalizada desde código fuente
```bash
podman build -t py-web:1.0 .
```
* **¿Qué hace?** Lee las instrucciones del archivo `Containerfile` (o `Dockerfile`) ubicado en el directorio actual (`.`), descarga la imagen base, crea usuarios, copia el código y genera la imagen `py-web:1.0`.
* **Banderas:**
  - `-t py-web:1.0` (*tag*): Nombre y etiqueta de versión de la imagen resultante.
  - `.`: Contexto de construcción (directorio donde residen los archivos a empaquetar).

---

### 10.2 Ejecutar la imagen construida
```bash
podman run -d --name web -p 8080:8080 py-web:1.0
```
* **¿Qué hace?** Arranca el microservicio Python exponiendo su puerto `8080`.

---

### 10.3 Monitoreo de logs y verificación de endpoints
```bash
# Consultar logs generados por la aplicación en tiempo real
podman logs web
podman logs -f web

# Validar endpoint HTML principal
curl http://localhost:8080

# Validar endpoint de salud (JSON)
curl http://localhost:8080/health
```

---

## Tabla de Referencia Rápida de Comandos

| Comando | Operación que Realiza |
| :--- | :--- |
| `podman images` | Lista imágenes en el almacén local. |
| `podman pull <imagen>` | Descarga una imagen desde un registro OCI. |
| `podman run -dit --name <n> -p <h>:<c> <img>` | Crea y ejecuta un contenedor con puerto publicado. |
| `podman ps -a` | Muestra estado de todos los contenedores (Up / Exited). |
| `podman inspect <nom> \| grep -i IPAddress` | Obtiene la dirección IP del contenedor. |
| `podman stop <nom>` / `podman start <nom>` | Detiene o reanuda un contenedor existente. |
| `podman rm -f <nom>` | Elimina un contenedor forzando su detención inmediata. |
| `podman exec -it <nom> /bin/bash` | Abre terminal dentro del contenedor en ejecución. |
| `podman network create --subnet <s> <nom>` | Crea una red virtual personalizada. |
| `podman volume create <nom>` | Crea un volumen persistente desacoplado en el host. |
| `podman build -t <tag> .` | Compila una imagen a partir de un `Containerfile`. |
| `podman logs -f <nom>` | Sigue en vivo los logs emitidos por la aplicación. |
