/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: MASTER_PIPELINE.sql

PROPÓSITO: Ejecutar todo el pipeline de ETL en orden

DESCRIPCIÓN:
Este script ejecuta secuencialmente todos los pasos
necesarios para limpiar y preparar los datos de
Google Play Store para análisis.

FASES DEL PIPELINE:
0. Configuración y Setup
1. Importación segura de datos crudos
2. Estructuración de datos crudos
3. Limpieza de columnas específicas
4. Creación de tabla final lista para análisis

DURACIÓN ESTIMADA: 2-5 minutos (depende del tamaño del CSV)

INSTRUCCIONES DE USO:
1. Verifica que el archivo CSV existe en la ruta especificada
2. Ajusta la ruta del archivo CSV si es necesario (Línea ~150)
3. Abre DBeaver u otro cliente SQL
4. Ejecuta este script línea por línea o en secciones
5. Verifica los resultados en cada fase antes de continuar

==========================================================
*/

-- Verificar base de datos activa
SELECT CURRENT_DATABASE();

-- Mostrar marca de tiempo
SELECT NOW() AS start_time, 'INICIANDO PIPELINE DE ETL' AS status;


/*****************************************************
FASE 0: SETUP Y CONFIGURACIÓN INICIAL
*****************************************************/

-- Crear esquema si no existe (opcional)
CREATE SCHEMA IF NOT EXISTS analytics;

-- Crear base de datos de métricas de calidad
CREATE TABLE IF NOT EXISTS data_quality_metrics (
    metric_name TEXT PRIMARY KEY,
    metric_value FLOAT,
    calculation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT 'Fase 0: Setup completado' AS status;


/*****************************************************
FASE 1: PREPARACIÓN DE TABLAS RAW
*****************************************************/

DROP TABLE IF EXISTS staging_apps_raw CASCADE;
DROP TABLE IF EXISTS import_error_log CASCADE;

CREATE TABLE staging_apps_raw (
    row_id SERIAL PRIMARY KEY,
    raw_line TEXT NOT NULL,
    import_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_header BOOLEAN DEFAULT FALSE
);

CREATE TABLE import_error_log (
    error_id SERIAL PRIMARY KEY,
    error_type TEXT,
    raw_line TEXT,
    column_count INT,
    error_message TEXT,
    error_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT 'Fase 1: Tablas preparadas' AS status;


/*****************************************************
FASE 2: IMPORTAR DATOS DEL CSV
*****************************************************/

-- AJUSTA ESTA RUTA SEGÚN TU MÁQUINA LOCAL
-- Verifica que el archivo existe en esta ubicación:
-- D:\ANALISIS DE DATOS\AnalisisDatos\Portafolio\01_Analisis_Google_Play_Store\data\googleplaystore.csv



COPY staging_apps_raw (raw_line
FROM 'D:\ANALISIS DE DATOS\AnalisisDatos\Portafolio\01_Analisis_Google_Play_Store\data\googleplaystore.csv'WITH ( FORMAT csv, DELIMITER E'\n',NULL '');

-- Validar importación
SELECT 
    'Importación completada' AS status,
    COUNT(*) AS total_rows,
    COUNT(CASE WHEN raw_line LIKE 'App,%' THEN 1 END) AS header_rows
FROM staging_apps_raw;

SELECT 'Fase 2: Importación completada' AS status;


/*****************************************************
FASE 3: ESTRUCTURAR DATOS CRUDOS
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
    validation_message TEXT,
    load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Función para dividir CSV
CREATE OR REPLACE FUNCTION safe_split_csv(p_line TEXT, p_index INT)
RETURNS TEXT AS $$
DECLARE
    v_parts TEXT[];
    v_result TEXT;
BEGIN
    v_parts := string_to_array(p_line, ',');
    IF p_index > array_length(v_parts, 1) OR p_index < 1 THEN
        RETURN NULL;
    END IF;
    v_result := TRIM(v_parts[p_index]);
    IF v_result LIKE '"%' THEN
        v_result := TRIM('"' FROM v_result);
    END IF;
    RETURN NULLIF(v_result, '');
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Insertar datos estructurados
INSERT INTO staging_apps (
    app_name, category, rating, reviews, size, installs,
    type, price, content_rating, genres, last_updated,
    current_version, android_version, is_valid, validation_message
)
SELECT
    safe_split_csv(raw_line, 1),
    safe_split_csv(raw_line, 2),
    safe_split_csv(raw_line, 3),
    safe_split_csv(raw_line, 4),
    safe_split_csv(raw_line, 5),
    safe_split_csv(raw_line, 6),
    safe_split_csv(raw_line, 7),
    safe_split_csv(raw_line, 8),
    safe_split_csv(raw_line, 9),
    safe_split_csv(raw_line, 10),
    safe_split_csv(raw_line, 11),
    safe_split_csv(raw_line, 12),
    safe_split_csv(raw_line, 13),
    CASE
        WHEN raw_line LIKE 'App,%' THEN FALSE
        WHEN safe_split_csv(raw_line, 1) IS NULL THEN FALSE
        ELSE TRUE
    END,
    CASE
        WHEN raw_line LIKE 'App,%' THEN 'HEADER_ROW'
        WHEN safe_split_csv(raw_line, 1) IS NULL THEN 'MISSING_APP_NAME'
        ELSE NULL
    END
FROM staging_apps_raw;

-- Reporte de estructuración
SELECT
    'Estructura completada' AS status,
    COUNT(*) AS total_rows,
    COUNT(CASE WHEN is_valid = TRUE THEN 1 END) AS valid_rows,
    ROUND(COUNT(CASE WHEN is_valid THEN 1 END) * 100.0 / COUNT(*), 2) AS validity_pct
FROM staging_apps;

SELECT 'Fase 3: Estructuración completada' AS status;


/*****************************************************
FASE 4: CREAR FUNCIONES DE LIMPIEZA
*****************************************************/

-- Función para normalizar SIZE
CREATE OR REPLACE FUNCTION normalize_size(p_size TEXT)
RETURNS FLOAT AS $$
DECLARE
    v_numeric_part FLOAT;
    v_cleaned TEXT;
BEGIN
    IF p_size IS NULL OR TRIM(p_size) = '' THEN
        RETURN NULL;
    END IF;
    v_cleaned := TRIM(p_size);
    IF v_cleaned ~ '[Mm]$' THEN
        v_numeric_part := NULLIF(regexp_replace(v_cleaned, '[^0-9.]', '', 'g'), '')::FLOAT;
        RETURN COALESCE(v_numeric_part * 1000000, NULL);
    ELSIF v_cleaned ~ '[Kk]$' THEN
        v_numeric_part := NULLIF(regexp_replace(v_cleaned, '[^0-9.]', '', 'g'), '')::FLOAT;
        RETURN COALESCE(v_numeric_part * 1000, NULL);
    ELSIF v_cleaned ~ '^[0-9]+(\.[0-9]+)?$' THEN
        RETURN v_cleaned::FLOAT;
    ELSE
        RETURN NULL;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Tablas de mapeo
DROP TABLE IF EXISTS mapping_content_rating CASCADE;
CREATE TABLE mapping_content_rating (
    content_rating_original TEXT PRIMARY KEY,
    content_rating_numeric INT,
    severity_level TEXT
);

INSERT INTO mapping_content_rating VALUES
    ('Everyone', 1, 'LOWEST'),
    ('Everyone 10+', 2, 'LOW'),
    ('Teen', 3, 'MEDIUM'),
    ('Mature 17+', 4, 'HIGH'),
    ('Adults only 18+', 5, 'HIGHEST'),
    ('Unrated', 0, 'UNKNOWN'),
    ('', 0, 'UNKNOWN'),
    (NULL, 0, 'UNKNOWN');

-- Función para normalizar CONTENT_RATING
CREATE OR REPLACE FUNCTION normalize_content_rating(p_content_rating TEXT)
RETURNS INT AS $$
BEGIN
    IF p_content_rating IS NULL THEN
        RETURN 0;
    END IF;
    SELECT content_rating_numeric INTO p_content_rating
    FROM mapping_content_rating
    WHERE UPPER(TRIM(content_rating_original)) = UPPER(TRIM(p_content_rating))
    LIMIT 1;
    RETURN COALESCE(p_content_rating::INT, 0);
EXCEPTION WHEN OTHERS THEN
    RETURN 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Función para normalizar TYPE
CREATE OR REPLACE FUNCTION normalize_app_type(p_type TEXT)
RETURNS INT AS $$
BEGIN
    IF p_type IS NULL OR TRIM(p_type) = '' THEN
        RETURN 0;  -- Free
    END IF;
    IF UPPER(TRIM(p_type)) = 'PAID' THEN
        RETURN 1;
    ELSE
        RETURN 0;  -- Free
    END IF;
EXCEPTION WHEN OTHERS THEN
    RETURN 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT 'Fase 4: Funciones de limpieza creadas' AS status;


/*****************************************************
FASE 5: CALCULAR MÉTRICAS DE CALIDAD
*****************************************************/

-- Calcular media de SIZE para valores faltantes
DELETE FROM data_quality_metrics WHERE metric_name = 'avg_size';
INSERT INTO data_quality_metrics (metric_name, metric_value)
SELECT 
    'avg_size',
    AVG(normalize_size(size))
FROM staging_apps
WHERE size IS NOT NULL AND size != '';

SELECT 'Media de tamaño calculada' AS status;


/*****************************************************
FASE 6: CREAR TABLA LIMPIA FINAL
*****************************************************/

DROP TABLE IF EXISTS clean_apps CASCADE;

CREATE TABLE clean_apps AS
SELECT
    app_id,
    app_name,
    category,
    CASE
        WHEN rating ~ '^[0-9]+(\.[0-9]+)?$'
        THEN rating::FLOAT
        ELSE NULL
    END AS rating,
    CASE
        WHEN reviews ~ '^[0-9]+$'
        THEN reviews::BIGINT
        ELSE NULL
    END AS reviews,
    normalize_size(size) AS size,
    NULLIF(regexp_replace(installs, '[^0-9]+', '', 'g'), '')::BIGINT AS installs,
    NULLIF(regexp_replace(price, '[^0-9.]', '', 'g'), '')::FLOAT AS price,
    type,
    normalize_app_type(type) AS type_numeric,
    content_rating,
    normalize_content_rating(content_rating) AS content_rating_numeric,
    genres,
    CASE 
        WHEN last_updated ~ '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
        THEN to_date(last_updated, 'Month DD, YYYY')
        ELSE NULL
    END AS last_updated,
    current_version,
    android_version
FROM staging_apps
WHERE is_valid = TRUE;

-- Llenar valores NULL de size con la media
UPDATE clean_apps
SET size = (SELECT metric_value FROM data_quality_metrics WHERE metric_name = 'avg_size')
WHERE size IS NULL;

SELECT 'Tabla clean_apps creada' AS status;


/*****************************************************
FASE 7: VALIDACIÓN FINAL
*****************************************************/

-- Estadísticas finales
SELECT
    'VALIDACIÓN FINAL' AS fase,
    COUNT(*) AS total_rows,
    COUNT(CASE WHEN rating IS NOT NULL THEN 1 END) AS valid_ratings,
    COUNT(CASE WHEN size IS NOT NULL THEN 1 END) AS valid_sizes,
    COUNT(CASE WHEN installs IS NOT NULL THEN 1 END) AS valid_installs,
    COUNT(CASE WHEN price IS NOT NULL THEN 1 END) AS valid_prices
FROM clean_apps;

-- Mostrar muestra de datos limpios
SELECT 
    app_name,
    category,
    rating,
    size,
    type,
    content_rating_numeric,
    last_updated
FROM clean_apps
LIMIT 20;

-- Resumen de limpieza
SELECT
    'SIZE' AS columna,
    COUNT(CASE WHEN size IS NOT NULL THEN 1 END) AS non_null_count,
    ROUND(AVG(size), 2) AS average,
    ROUND(MIN(size), 2) AS minimum,
    ROUND(MAX(size), 2) AS maximum
FROM clean_apps
UNION ALL
SELECT
    'RATING',
    COUNT(CASE WHEN rating IS NOT NULL THEN 1 END),
    ROUND(AVG(rating), 2),
    ROUND(MIN(rating), 2),
    ROUND(MAX(rating), 2)
FROM clean_apps
UNION ALL
SELECT
    'CONTENT_RATING_NUMERIC',
    COUNT(CASE WHEN content_rating_numeric IS NOT NULL THEN 1 END),
    ROUND(AVG(content_rating_numeric), 2),
    ROUND(MIN(content_rating_numeric), 2),
    ROUND(MAX(content_rating_numeric), 2)
FROM clean_apps;

SELECT NOW() AS end_time, 'PIPELINE COMPLETADO EXITOSAMENTE' AS status;
