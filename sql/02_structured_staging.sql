/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: 02_structured_staging.sql

PROPÓSITO: Transformar datos crudos en estructura tabular

DESCRIPCIÓN:
Este script toma los datos crudos de staging_apps_raw
y los transforma en una tabla estructurada staging_apps
con columnas claramente definidas.

Mejoras respecto a versión anterior:
1. Manejo mejorado de caracteres especiales
2. Validación de filas de encabezado
3. Registro de filas problemáticas
4. Mejor control de errores

==========================================================
*/

-- Verificar base de datos activa
SELECT CURRENT_DATABASE();


/*****************************************************
FASE 1: CREAR TABLA STAGING ESTRUCTURADA
*****************************************************/

DROP TABLE IF EXISTS staging_apps CASCADE;

CREATE TABLE staging_apps (
    app_id SERIAL PRIMARY KEY,
    app_name TEXT,
    category TEXT,
    rating TEXT,
    reviews TEXT,
    size TEXT,
    installs TEXT,
    type TEXT,
    price TEXT,
    content_rating TEXT,
    genres TEXT,
    last_updated TEXT,
    current_version TEXT,
    android_version TEXT,
    is_valid BOOLEAN DEFAULT TRUE,
    validation_message TEXT DEFAULT NULL,
    load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_category ON staging_apps(category);
CREATE INDEX idx_content_rating ON staging_apps(content_rating);
CREATE INDEX idx_type ON staging_apps(type);
CREATE INDEX idx_is_valid ON staging_apps(is_valid);

SELECT 'Tabla staging_apps creada' AS status;


/*****************************************************
FASE 2: INSERTAR DATOS TRANSFORMADOS - CON VALIDACIÓN
*****************************************************/

-- Función auxiliar para dividir CSV con validación
CREATE OR REPLACE FUNCTION safe_split_csv(p_line TEXT, p_index INT)
RETURNS TEXT AS $$
DECLARE
    v_parts TEXT[];
    v_result TEXT;
BEGIN
    -- Dividir por comas
    v_parts := string_to_array(p_line, ',');

    -- Validar que el índice existe
    IF p_index > array_length(v_parts, 1) OR p_index < 1 THEN
        RETURN NULL;
    END IF;

    v_result := TRIM(v_parts[p_index]);

    -- Remover comillas si existen
    IF v_result LIKE '"%' THEN
        v_result := TRIM('"' FROM v_result);
    END IF;

    -- Retornar NULL si está vacío
    RETURN NULLIF(v_result, '');

EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT 'Función safe_split_csv creada' AS status;


-- Insertar datos validando estructura
INSERT INTO staging_apps (
    app_name, category, rating, reviews, size, installs,
    type, price, content_rating, genres, last_updated,
    current_version, android_version, is_valid, validation_message
)
SELECT
    -- Nota: El orden en el CSV es: App, Category, Rating, Reviews, Size, Installs, Type, Price, Content Rating, Genres, Last Updated, Current Ver, Android Ver
    safe_split_csv(raw_line, 1) as app_name,
    safe_split_csv(raw_line, 2) as category,
    safe_split_csv(raw_line, 3) as rating,
    safe_split_csv(raw_line, 4) as reviews,
    safe_split_csv(raw_line, 5) as size,
    safe_split_csv(raw_line, 6) as installs,
    safe_split_csv(raw_line, 7) as type,
    safe_split_csv(raw_line, 8) as price,
    safe_split_csv(raw_line, 9) as content_rating,
    safe_split_csv(raw_line, 10) as genres,
    safe_split_csv(raw_line, 11) as last_updated,
    safe_split_csv(raw_line, 12) as current_version,
    safe_split_csv(raw_line, 13) as android_version,
    CASE
        -- Validar que la fila no es encabezado
        WHEN raw_line LIKE 'App,%' THEN FALSE
        -- Validar que tiene app_name
        WHEN safe_split_csv(raw_line, 1) IS NULL OR safe_split_csv(raw_line, 1) = '' THEN FALSE
        -- Si pasa ambas validaciones
        ELSE TRUE
    END AS is_valid,
    CASE
        WHEN raw_line LIKE 'App,%' THEN 'HEADER_ROW'
        WHEN safe_split_csv(raw_line, 1) IS NULL OR safe_split_csv(raw_line, 1) = '' THEN 'MISSING_APP_NAME'
        ELSE NULL
    END AS validation_message
FROM staging_apps_raw;

SELECT 'Datos insertados en staging_apps' AS status;


/*****************************************************
FASE 3: VALIDACIÓN DE CARGA
*****************************************************/

-- Reporte de validación
SELECT
    COUNT(*) AS total_rows,
    COUNT(CASE WHEN is_valid = TRUE THEN 1 END) AS valid_rows,
    COUNT(CASE WHEN is_valid = FALSE THEN 1 END) AS invalid_rows,
    ROUND(
        COUNT(CASE WHEN is_valid = TRUE THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS validity_percentage
FROM staging_apps;

-- Detalles de filas inválidas
SELECT
    validation_message,
    COUNT(*) AS count
FROM staging_apps
WHERE is_valid = FALSE
GROUP BY validation_message;

-- Muestra de datos válidos
SELECT 
    app_id,
    app_name,
    category,
    rating,
    reviews,
    size,
    type,
    content_rating
FROM staging_apps
WHERE is_valid = TRUE
LIMIT 10;


/*****************************************************
FASE 4: ANÁLISIS EXPLORATORIO INICIAL
*****************************************************/

-- Categorías únicas
SELECT COUNT(DISTINCT category) AS unique_categories FROM staging_apps WHERE is_valid = TRUE;

-- Content Ratings únicos
SELECT DISTINCT content_rating FROM staging_apps WHERE is_valid = TRUE ORDER BY content_rating;

-- Tipos de apps
SELECT DISTINCT type FROM staging_apps WHERE is_valid = TRUE ORDER BY type;

-- Distribución por categoría
SELECT 
    category,
    COUNT(*) AS app_count
FROM staging_apps
WHERE is_valid = TRUE
GROUP BY category
ORDER BY app_count DESC
LIMIT 15;

SELECT 'Estructura completa y validada' AS status;
