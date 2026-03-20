/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: 00_enhanced_database_setup.sql
PROPÓSITO: Script mejorado para crear la base de datos
sin errores de carga

DESCRIPCIÓN:
Este script establece un entorno robusto y limpio para
la importación y análisis de datos de Google Play Store.
Implementa validaciones para evitar errores comunes.

FASES:
1. Creación de tablas staging
2. Importación segura de datos crudos
3. Validación de integridad
4. Preparación para limpieza

==========================================================
*/

-- Verificar y mostrar la base de datos actual
SELECT CURRENT_DATABASE();


/*****************************************************
FASE 1: PREPARACIÓN - LIMPIAR TABLAS EXISTENTES
*****************************************************/

-- Eliminar todas las tablas existentes si es necesario
-- para evitar conflictos con datos anteriores

DROP TABLE IF EXISTS clean_apps CASCADE;
DROP TABLE IF EXISTS staging_apps CASCADE;
DROP TABLE IF EXISTS staging_apps_raw CASCADE;

-- Confirmación
SELECT 'Base de datos preparada para nueva carga' AS status;


/* mirando que las cosas que se tienen por delante no son las mismas que los demas determinan  para los problemas de la sociedad*/

/*****************************************************
FASE 2: CREAR TABLA PARA IMPORTACIÓN CRUDA (RAW)
*****************************************************/

-- Esta tabla almacenará cada línea del CSV exactamente como viene
-- Sin transformación, esto previene errores de parsing

CREATE TABLE staging_apps_raw (
    row_id SERIAL PRIMARY KEY,
    raw_line TEXT NOT NULL,
    import_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_header BOOLEAN DEFAULT FALSE
);

-- Crear índice para búsquedas rápidas
CREATE INDEX idx_raw_line ON staging_apps_raw(raw_line);

SELECT 'Tabla staging_apps_raw creada exitosamente' AS status;


/*****************************************************
FASE 3: CREAR TABLA ESTRUCTURADA CON TIPOS CORRECTOS
*****************************************************/

DROP TABLE IF EXISTS staging_apps CASCADE;

CREATE TABLE staging_apps (
    app_id SERIAL PRIMARY KEY,
    app_name TEXT,
    category TEXT,
    rating TEXT,              -- Mantener como texto para limpieza posterior
    reviews TEXT,             -- Mantener como texto para limpiar
    size TEXT,                -- Mantener como texto (tiene M, k, etc.)
    installs TEXT,            -- Mantener como texto (tiene comas, +)
    type TEXT,                -- Free o Paid
    price TEXT,               -- Mantener como texto
    content_rating TEXT,      -- Mantener como texto
    genres TEXT,
    last_updated TEXT,        -- Mantener como texto para validación de fecha
    current_version TEXT,
    android_version TEXT,
    load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear índices para búsquedas frecuentes
CREATE INDEX idx_category ON staging_apps(category);
CREATE INDEX idx_content_rating ON staging_apps(content_rating);
CREATE INDEX idx_type ON staging_apps(type);

SELECT 'Tabla staging_apps creada exitosamente' AS status;


/*****************************************************
FASE 4: CREAR FUNCIÓN DE UTILIDAD PARA VALIDACIÓN
*****************************************************/

-- Función para validar si un texto es un número válido
CREATE OR REPLACE FUNCTION is_numeric(p_text TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_text IS NULL OR p_text = '' THEN
        RETURN FALSE;
    END IF;
    BEGIN
        CAST(p_text AS NUMERIC);
        RETURN TRUE;
    EXCEPTION WHEN OTHERS THEN
        RETURN FALSE;
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT 'Función de validación creada' AS status;


/*****************************************************
FASE 5: VALIDACIÓN FINAL
*****************************************************/

-- Mostrar todas las tablas creadas
SELECT 
    table_name,
    table_schema
FROM information_schema.tables
WHERE table_schema = 'public' 
    AND table_name LIKE '%apps%'
ORDER BY table_name;

SELECT 'Setup completado - Listo para importación de datos' AS status;
