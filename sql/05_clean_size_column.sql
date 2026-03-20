/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: 05_clean_size_column.sql

PROPÓSITO: Limpiar y normalizar la columna 'size'

DESCRIPCIÓN:
La columna size contiene valores de diferente formato:
- Con 'M': 19M, 14M, 25M
- Con 'k': 103k, 116k, 1020k
- Sin unidad: números simples
- Valores inválidos o vacíos

TRANSFORMACIÓN:
1. Convertir 'M' a megabytes multiplicando por 1,000,000
2. Convertir 'k' a kilobytes multiplicando por 1,000
3. Reemplazar valores no numéricos con la media calculada
4. Convertir todo a FLOAT

==========================================================
*/

-- Verificar la base de datos activa
SELECT CURRENT_DATABASE();


/*****************************************************
FASE 1: ANÁLISIS PREVIO DE LA COLUMNA SIZE
*****************************************************/

-- Ver examples de valores actuales
SELECT DISTINCT size
FROM staging_apps
WHERE size IS NOT NULL
ORDER BY size
LIMIT 20;

-- Contar valores válidos, inválidos y vacíos
SELECT
    COUNT(*) AS total_rows,
    COUNT(CASE WHEN size IS NULL OR size = '' THEN 1 END) AS empty_values,
    COUNT(CASE WHEN size ~ '^[0-9]+(\.[0-9]+)?[kM]?$' THEN 1 END) AS valid_numeric_format,
    COUNT(CASE WHEN size !~ '^[0-9]+(\.[0-9]+)?[kM]?$' AND size IS NOT NULL AND size != '' THEN 1 END) AS invalid_values
FROM staging_apps;


/*****************************************************
FASE 2: CREAR FUNCIÓN PARA NORMALIZAR SIZE
*****************************************************/

-- Función que convierte size a bytes (número decimal)
CREATE OR REPLACE FUNCTION normalize_size(p_size TEXT)
RETURNS FLOAT AS $$
DECLARE
    v_numeric_part FLOAT;
    v_cleaned TEXT;
BEGIN
    -- Si es nulo o vacío, retornar NULL
    IF p_size IS NULL OR TRIM(p_size) = '' THEN
        RETURN NULL;
    END IF;

    -- Limpiar espacios
    v_cleaned := TRIM(p_size);

    -- Caso 1: Termina con 'M' (megabytes)
    IF v_cleaned ~ '[Mm]$' THEN
        v_numeric_part := NULLIF(
            regexp_replace(v_cleaned, '[^0-9.]', '', 'g'),
            ''
        )::FLOAT;
        RETURN COALESCE(v_numeric_part * 1000000, NULL);

    -- Caso 2: Termina con 'k' (kilobytes)
    ELSIF v_cleaned ~ '[Kk]$' THEN
        v_numeric_part := NULLIF(
            regexp_replace(v_cleaned, '[^0-9.]', '', 'g'),
            ''
        )::FLOAT;
        RETURN COALESCE(v_numeric_part * 1000, NULL);

    -- Caso 3: Es un número puro (asumir que está en bytes)
    ELSIF v_cleaned ~ '^[0-9]+(\.[0-9]+)?$' THEN
        RETURN v_cleaned::FLOAT;

    -- Caso 4: Contiene caracteres no válidos
    ELSE
        RETURN NULL;
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT 'Función normalize_size creada' AS status;


/*****************************************************
FASE 3: CALCULAR LA MEDIA DE SIZE (PARA VALORES FALTANTES)
*****************************************************/

-- Calcular la media de size válida (excluir NULLs)
WITH size_numeric AS (
    SELECT normalize_size(size) AS normalized_size
    FROM staging_apps
    WHERE size IS NOT NULL AND size != ''
)
SELECT
    AVG(normalized_size) AS average_size,
    AVG(normalized_size)::BIGINT AS average_size_bytes,
    ROUND(AVG(normalized_size) / 1000000, 2) AS average_size_mb
FROM size_numeric
WHERE normalized_size IS NOT NULL;

-- Guardar el valor en una tabla de referencia (opcional, para consultas posteriores)
CREATE TABLE IF NOT EXISTS data_quality_metrics (
    metric_name TEXT PRIMARY KEY,
    metric_value FLOAT,
    calculation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar o actualizar la métrica
DELETE FROM data_quality_metrics WHERE metric_name = 'avg_size';
INSERT INTO data_quality_metrics (metric_name, metric_value)
SELECT 'avg_size', AVG(normalized_size)
FROM (
    SELECT normalize_size(size) AS normalized_size
    FROM staging_apps
    WHERE size IS NOT NULL AND size != ''
) t
WHERE normalized_size IS NOT NULL;

SELECT 'Métrica de media calculada' AS status;


/*****************************************************
FASE 4: CREAR TABLA LIMPIA CON SIZE NORMALIZADO
*****************************************************/

-- Si table clean_apps no existe, crearla; si existe, mantener datos existentes
-- y actualizar la columna size

ALTER TABLE clean_apps 
ADD COLUMN IF NOT EXISTS size_numeric FLOAT;

-- Actualizar la columna size_numeric con valores normalizados
UPDATE clean_apps
SET size_numeric = normalize_size(
    COALESCE(
        (SELECT size FROM staging_apps WHERE staging_apps.app_id = clean_apps.app_id),
        NULL
    )
);

-- Para los valores NULL, rellenar con la media
UPDATE clean_apps
SET size_numeric = (SELECT metric_value FROM data_quality_metrics WHERE metric_name = 'avg_size')
WHERE size_numeric IS NULL;

SELECT 'Columna size_numeric actualizada' AS status;


/*****************************************************
FASE 5: VALIDACIÓN DE RESULTADOS
*****************************************************/

-- Estadísticas de la columna size_numeric
SELECT
    COUNT(*) AS total_rows,
    COUNT(size_numeric) AS non_null_values,
    COUNT(*) - COUNT(size_numeric) AS null_values,
    ROUND(AVG(size_numeric), 2) AS average_bytes,
    ROUND(AVG(size_numeric) / 1000000, 2) AS average_mb,
    ROUND(MIN(size_numeric), 2) AS min_bytes,
    ROUND(MAX(size_numeric), 2) AS max_bytes,
    ROUND(MAX(size_numeric) / 1000000, 2) AS max_mb
FROM clean_apps;

-- Ver ejemplos de transformación
SELECT DISTINCT
    size,
    normalize_size(size) AS size_bytes,
    ROUND(normalize_size(size) / 1000000, 2) AS size_mb,
    CASE
        WHEN normalize_size(size) IS NULL THEN 'FILLED_WITH_AVERAGE'
        ELSE 'ORIGINAL'
    END AS status
FROM staging_apps
WHERE size IS NOT NULL
LIMIT 20;

SELECT 'Validación completada' AS status;
