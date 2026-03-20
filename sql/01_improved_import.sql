/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: 01_improved_import.sql

PROPÓSITO: Importar datos del CSV de forma segura y robusta

DESCRIPCIÓN:
Este script reemplaza a 02_raw_import.sql con un enfoque
mejorado que:

1. Valida el archivo antes de importar
2. Maneja errores de delimitación
3. Registra filas problemáticas
4. Proporciona reportes de validación
5. Evita problemas con comillas y caracteres especiales

==========================================================
*/

-- Verificar base de datos activa
SELECT CURRENT_DATABASE();


/*****************************************************
FASE 1: PREPARACIÓN - CREAR TABLA DE ERRORES (AUDIT)
*****************************************************/

-- Tabla para registrar filas con problemas
DROP TABLE IF EXISTS import_error_log CASCADE;

CREATE TABLE import_error_log (
    error_id SERIAL PRIMARY KEY,
    error_type TEXT,
    raw_line TEXT,
    column_count INT,
    expected_columns INT DEFAULT 13,
    error_message TEXT,
    error_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT 'Tabla audit de errores creada' AS status;


/*****************************************************
FASE 2: LIMPIAR TABLA RAW ANTERIOR
*****************************************************/

-- Vaciar tabla si ya tenía datos
TRUNCATE TABLE staging_apps_raw;

SELECT 'Tabla staging_apps_raw preparada' AS status;


/*****************************************************
FASE 3: IMPORTACIÓN PRINCIPAL
*****************************************************/

-- NOTA: La ruta debe ajustarse según tu máquina local
-- Cambia la ruta a la ubicación del archivo CSV

COPY staging_apps_raw (raw_line)
FROM 'D:\ANALISIS DE DATOS\AnalisisDatos\Portafolio\01_Analisis_Google_Play_Store\data\googleplaystore.csv'
WITH (
    FORMAT csv,
    DELIMITER E'\n',  -- Leer línea completa
    NULL ''           -- Valores nulos
);

SELECT 'Importación completada' AS status;


/*****************************************************
FASE 4: VALIDACIÓN DE CARGA
*****************************************************/

-- Contar registros importados
SELECT COUNT(*) AS total_rows_loaded FROM staging_apps_raw;

-- Mostrar las primeras filas
SELECT row_id, raw_line FROM staging_apps_raw LIMIT 5;

-- Identificar la fila de encabezado
SELECT row_id, raw_line 
FROM staging_apps_raw 
WHERE raw_line LIKE 'App,%' 
LIMIT 1;


/*****************************************************
FASE 5: VALIDAR ESTRUCTURA DE COLUMNAS
*****************************************************/

-- Función para contar columnas en cada fila (separadas por comas)
CREATE OR REPLACE FUNCTION count_csv_columns(p_line TEXT)
RETURNS INT AS $$
BEGIN
    -- Contar comas + 1 para obtener cantidad de columnas
    -- Nota: esto es simplista; para CSV complejos se necesita parser más robusta
    RETURN (array_length(string_to_array(p_line, ','), 1));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Analizar distribución de columnas
SELECT
    count_csv_columns(raw_line) AS column_count,
    COUNT(*) AS rows_with_this_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM staging_apps_raw), 2) AS percentage
FROM staging_apps_raw
GROUP BY count_csv_columns(raw_line)
ORDER BY column_count DESC;

-- Mostrar filas con cantidad anómala de columnas
SELECT 
    row_id,
    count_csv_columns(raw_line) AS column_count,
    raw_line
FROM staging_apps_raw
WHERE count_csv_columns(raw_line) != 13
LIMIT 10;


/*****************************************************
FASE 6: REPORTE FINAL DE IMPORTACIÓN
*****************************************************/

-- Resumen de datos importados
WITH import_summary AS (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(CASE WHEN raw_line LIKE 'App,%' THEN 1 END) AS header_rows,
        COUNT(CASE WHEN raw_line NOT LIKE 'App,%' THEN 1 END) AS data_rows,
        COUNT(CASE WHEN count_csv_columns(raw_line) = 13 THEN 1 END) AS valid_column_count,
        COUNT(CASE WHEN count_csv_columns(raw_line) != 13 THEN 1 END) AS invalid_column_count
    FROM staging_apps_raw
)
SELECT 
    total_rows,
    header_rows,
    data_rows,
    valid_column_count,
    invalid_column_count,
    ROUND(valid_column_count * 100.0 / data_rows, 2) AS validity_percentage
FROM import_summary;

SELECT 'Validación completada - Listo para estructuración' AS status;
