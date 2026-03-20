/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: 01_database_creation.sql
AUTOR: Carlos Corrales
FECHA: 13/02/2026
DESCRIPCION:
Este script inicializa el entorno de base de datos para el
proyecto de análisis de aplicaciones de Google Play Store.

Este proyecto simula un entorno real de análisis de datos,
incluyendo:

- Importación de datos crudos
- Limpieza de datos
- Transformación
- Validación
- Análisis exploratorio

OBJETIVO:
Construir una base de datos limpia y optimizada lista para análisis.
==========================================================
*/

-- Seleccionar la base de datos del proyecto
-- En PostgreSQL esto depende del cliente (DBeaver),
-- pero este comentario documenta el contexto correcto.
-- Base de datos utilizada:
-- google_play


/*****************************************************
FASE 1: CREACION DE TABLA DE IMPORTACION CRUDA
*****************************************************/

-- Esta tabla almacenará los datos EXACTAMENTE como vienen
-- del CSV, sin transformación ni validación.
-- Esto es una práctica estándar en ingeniería de datos.
SELECT CURRENT_DATABASE();



CREATE TABLE IF NOT EXISTS staging_apps_raw (
    raw_line TEXT
);

/*****************************************************
FASE 2: VERIFICACION DE CREACION
*****************************************************/

-- Verificar que la tabla fue creada correctamente

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public';

