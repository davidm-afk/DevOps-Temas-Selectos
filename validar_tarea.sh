#!/bin/bash

echo "========================================================"
echo "  REPORTE DE VALIDACIÓN - TAREA CLASE 4: PODMAN"
echo "========================================================"
echo "Fecha y Hora del Sistema: $(date)"
echo "Host: $(hostname)"
echo "Versión de Podman: $(podman --version)"
echo ""

echo "========================================================"
echo "  1. ESTADO GENERAL DE CONTENEDORES (podman ps -a)"
echo "========================================================"
podman ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "========================================================"
echo "  2. EJERCICIO 1: BASE DE DATOS POSTGRESQL (db-postgres)"
echo "========================================================"
echo "[Paso 2.1] Directorio y Archivos del Proyecto:"
ls -la /root/db-postgres/
echo ""

echo "[Paso 2.2] Contenido de init.sql:"
cat /root/db-postgres/init.sql
echo ""

echo "[Paso 2.3] Contenido de Containerfile:"
cat /root/db-postgres/Containerfile
echo ""

echo "[Paso 2.4] Inspección del Volumen Persistente pgdata:"
podman volume inspect pgdata --format "Nombre: {{.Name}} | Punto de Montaje: {{.Mountpoint}}"
echo ""

echo "[Paso 2.5] Validación de Usuarios Creados en PostgreSQL (\du):"
podman exec -i db psql -U postgres -c '\du'
echo ""

echo "[Paso 2.6] Consulta de Datos como app_user (Dueño con Permisos):"
podman exec -i db psql -U app_user -d inventario -c 'SELECT * FROM productos;'
echo ""

echo "[Paso 2.7] Consulta de Solo Lectura como usuario reporte:"
podman exec -i db psql -U reporte -d inventario -c 'SELECT count(*) AS total_productos FROM productos;'
echo ""

echo "[Paso 2.8] Prueba de Restricción de Seguridad:"
echo "Intentando INSERT con el usuario reporte (debe fallar con permiso denegado):"
podman exec -i db psql -U reporte -d inventario -c "INSERT INTO productos(nombre) VALUES ('IntentoNoAutorizado');" 2>&1 || true
echo ""

echo "========================================================"
echo "  3. EJERCICIO 2: UBUNTU CON USUARIOS DESDE ARCHIVO"
echo "========================================================"
echo "[Paso 3.1] Directorio y Archivos del Proyecto:"
ls -la /root/ubuntu-usuarios/
echo ""

echo "[Paso 3.2] Contenido de usuarios.txt:"
cat /root/ubuntu-usuarios/usuarios.txt
echo ""

echo "[Paso 3.3] Contenido de Containerfile:"
cat /root/ubuntu-usuarios/Containerfile
echo ""

echo "[Paso 3.4] Verificación del Grupo devops en la Imagen Compilada:"
podman run --rm localhost/ubuntu-usuarios:1.0 getent group devops
echo ""

echo "[Paso 3.5] Verificación de los Directorios Home Creados:"
podman run --rm localhost/ubuntu-usuarios:1.0 ls -la /home
echo ""

echo "[Paso 3.6] Prueba Interactiva con Usuario daniel y Privilegios Sudo:"
podman run --rm localhost/ubuntu-usuarios:1.0 su - daniel -c 'id; echo "--- Prueba de sudo ---"; sudo apt list --upgradable 2>&1 | head -n 5'
echo ""

echo "========================================================"
echo "  FIN DE LAS VALIDACIONES"
echo "========================================================"
