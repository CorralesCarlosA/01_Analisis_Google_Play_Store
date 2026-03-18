# Google Play Store - Pipeline de Limpieza de Datos (ETL)

## Descripción General

Este conjunto de scripts SQL implementa un pipeline completo de Extracción, Transformación y Carga (ETL) para los datos de Google Play Store. El objetivo es:

1. Importar datos crudos del archivo CSV
2. Estructurar datos en una tabla limpia
3. Limpiar columnas problemáticos (size, content_rating, type)
4. Validar integridad de datos
5. Preparar datos para análisis

---

## Estructura de Archivos

```
sql/
├── MASTER_PIPELINE.sql              (ejecutar esto primero)
├── 00_enhanced_database_setup.sql   (alternativa opcional de setup)
├── 01_improved_import.sql           (importación segura)
├── 02_structured_staging.sql        (estructuración)
├── 03_structured_staging.sql        (archivo original, remplazo)
├── 04_data_cleaning.sql             (archivo original)
├── 05_clean_size_column.sql         (limpieza de SIZE)
├── 06_clean_content_rating_and_type.sql  (limpieza de CONTENT_RATING y TYPE)
└── README.md                         (este archivo)
```

---

## Guía de Ejecución - OPCIÓN RECOMENDADA (Rápida)

### Opción 1: Ejecutar TODO en un paso (Recomendado)

1. **Abre DBeaver u otro cliente SQL PostgreSQL**
2. **Selecciona la base de datos `google_play`** (o crea una)
3. **Abre el archivo:**
   ```
   sql/MASTER_PIPELINE.sql
   ```
4. **Ejecuta el script completo** (Ctrl+Enter u opción "Execute All")
5. **Verifica los mensajes de estado** en la consola

**Tiempo estimado:** 2-5 minutos

**Resultado:** 
- Tabla `clean_apps` completamente limpia lista para análisis
- Todos los datos normalizados y validados

---

## Guía de Ejecución - OPCIÓN AVANZADA (Paso a Paso)

Si prefieres ejecutar cada fase manualmente para validar:

### Paso 1: Setup Inicial
```sql
-- Ejecuta: sql/00_enhanced_database_setup.sql
-- Resultado: Tablas base creadas
```

### Paso 2: Importar Datos Crudos
```sql
-- Ejecuta: sql/01_improved_import.sql
-- Resultado: Datos importados en staging_apps_raw
-- Verifica: SELECT COUNT(*) FROM staging_apps_raw;
```

### Paso 3: Estructurar Datos
```sql
-- Ejecuta: sql/02_structured_staging.sql
-- Resultado: Datos estructurados en staging_apps
-- Verifica: SELECT COUNT(*) FROM staging_apps WHERE is_valid = TRUE;
```

### Paso 4: Limpiar Columna SIZE
```sql
-- Ejecuta: sql/05_clean_size_column.sql
-- Resultado: Columna size normalizada a FLOAT
```

### Paso 5: Limpiar CONTENT_RATING y TYPE
```sql
-- Ejecuta: sql/06_clean_content_rating_and_type.sql
-- Resultado: Nuevas columnas numéricas para análisis
```

---

## Transformaciones Realizadas

### 1. Columna SIZE

**Antes:**
```
19M
14M
103k
1,000+
(vacío)
```

**Después (en bytes):**
```
19000000
14000000
103000
1000
[MEDIA si estaba vacío]
```

**Lógica:**
- Si termina con `M` → multiplicar por 1,000,000
- Si termina con `k` → multiplicar por 1,000
- Si es número puro → mantener como está
- Si está vacío → rellenar con la MEDIA calculada

---

### 2. Columna CONTENT_RATING

Antes:
```
Everyone
Everyone 10+
Teen
Mature 17+
Adults only 18+
Unrated
(vacío)
```

Después (Columna content_rating_numeric):
```
1
2
3
4
5
0
0
```

Severidad:
- 0 = Desconocido / Sin clasificación
- 1 = Contenido para todos (Everyone)
- 2 = Mayores de 10 años
- 3 = Adolescentes (Teen)
- 4 = Mayores de 17 años
- 5 = Solo para adultos

---

### 3. Columna TYPE

Antes:
```
Free
Paid
(vacío)
```

Después (Columna type_numeric):
```
0 (Gratuita)
1 (De Pago)
0 (Gratuita - asumir Free si vacío)
```

---

## Validación de Datos

Después de ejecutar el pipeline, verifica:

```sql
-- Ver estadísticas finales
SELECT
    COUNT(*) AS total_apps,
    COUNT(CASE WHEN rating IS NOT NULL THEN 1 END) AS valid_ratings,
    COUNT(CASE WHEN size IS NOT NULL THEN 1 END) AS valid_sizes,
    COUNT(CASE WHEN content_rating_numeric IS NOT NULL THEN 1 END) AS valid_ratings_numeric
FROM clean_apps;

-- Ver muestra de datos limpios
SELECT 
    app_name,
    category,
    rating,
    size,
    type_numeric,
    content_rating_numeric
FROM clean_apps
LIMIT 20;
```

---

## Solución de Problemas

### Error: "File not found" en COPY

**Causa:** La ruta del CSV no es correcta

**Solución:**
1. Verifica que el archivo existe en:
   ```
   D:\ANALISIS DE DATOS\AnalisisDatos\Portafolio\01_Analisis_Google_Play_Store\data\googleplaystore.csv
   ```
2. Si está en otra ubicación, edita la línea en `MASTER_PIPELINE.sql` alrededor de la línea 150:
   ```sql
   COPY staging_apps_raw (raw_line)
   FROM '[TU_RUTA_AQUÍ]\googleplaystore.csv'
   ```

### Error: "Base de datos no existe"

**Solución:**
```sql
-- Crea la base de datos primero
CREATE DATABASE google_play;

-- Luego conecta a ella y ejecuta los scripts
```

### Las columnas numéricas están todas en NULL

**Causa:** Los datos tienen formato inesperado

**Solución:**
1. Verifica los valores originales:
   ```sql
   SELECT DISTINCT size FROM staging_apps LIMIT 20;
   SELECT DISTINCT content_rating FROM staging_apps LIMIT 20;
   ```
2. Revisa las funciones de normalización y ajusta según necesario

---

## Próximos Pasos (Análisis)

Una vez que `clean_apps` esté lista, puedes:

```sql
-- Análisis por categoría
SELECT 
    category,
    COUNT(*) AS app_count,
    ROUND(AVG(rating), 2) AS avg_rating,
    ROUND(AVG(size/1000000), 2) AS avg_size_mb
FROM clean_apps
GROUP BY category
ORDER BY app_count DESC
LIMIT 15;

-- Análisis: Free vs Paid
SELECT
    CASE WHEN type_numeric = 0 THEN 'Free' ELSE 'Paid' END AS app_type,
    COUNT(*) AS app_count,
    ROUND(AVG(rating), 2) AS avg_rating,
    ROUND(AVG(reviews::NUMERIC), 0) AS avg_reviews
FROM clean_apps
GROUP BY type_numeric;

-- Análisis por Content Rating
SELECT
    CASE
        WHEN content_rating_numeric = 1 THEN 'Everyone'
        WHEN content_rating_numeric = 2 THEN 'Everyone 10+'
        WHEN content_rating_numeric = 3 THEN 'Teen'
        WHEN content_rating_numeric = 4 THEN 'Mature 17+'
        WHEN content_rating_numeric = 5 THEN 'Adults 18+'
        ELSE 'Unrated'
    END AS rating_category,
    COUNT(*) AS app_count
FROM clean_apps
GROUP BY content_rating_numeric
ORDER BY app_count DESC;
```

---

## 📝 Notas Técnicas

- **Motor:** PostgreSQL
- **Tipo de datos:** El pipeline maneja conversiones automáticas de TEXT a FLOAT, INT, BIGINT, TIMESTAMP
- **Validación:** Todas las filas se validan antes de insertarse en `clean_apps`
- **Auditoría:** Los datos inválidos se registran en `import_error_log`
- **Métricas:** Las estadísticas de calidad se guardan en `data_quality_metrics`

---

## 🤝 Preguntas o Ayuda

Si encuentras problemas:

1. Verifica que PostgreSQL está ejecutándose
2. Confirma que tienes permisos de lectura en el archivo CSV
3. Revisa los mensajes de error en la consola de DBeaver
4. Verifica la tabla `import_error_log` para detalles de filas problemáticas:
   ```sql
   SELECT * FROM import_error_log LIMIT 10;
   ```

---

**Última actualización:** Marzo 2026
**Versión:** 2.0 (Mejorada)
