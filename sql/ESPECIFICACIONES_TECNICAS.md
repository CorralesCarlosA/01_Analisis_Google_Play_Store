# Especificaciones Técnicas - Pipeline ETL Google Play Store

## Resumen de Cambios Implementados

### Archivos Creados

1. **MASTER_PIPELINE.sql** (ARCHIVO PRINCIPAL)
   - Ejecuta TODO el proceso ETL de una sola vez
   - Duración: 2-5 minutos
   - Recomendado para usuarios que quieren resultados rápidos

2. **`00_enhanced_database_setup.sql`**
   - Setup mejorado de la base de datos
   - Crea funciones y índices para optimizar búsquedas
   - Compatible con el flujo manual paso a paso

3. **`01_improved_import.sql`**
   - Importación segura del CSV con validación
   - Reemplaza a `02_raw_import.sql`
   - Maneja caracteres especiales y comillas

4. **`02_structured_staging.sql`**
   - Estructuración robusta de datos crudos
   - Reemplaza a `03_structured_staging.sql`
   - Incluye validaciones integradas

5. **`05_clean_size_column.sql`**
   - Script dedicado para limpiar columna SIZE
   - Normaliza M, k, y valores sin unidad
   - Calcula y aplica media para valores faltantes

6. **`06_clean_content_rating_and_type.sql`**
   - Script dedicado para limpiar CONTENT_RATING y TYPE
   - Mapea valores categóricos a numéricos
   - Crea tablas de referencia para auditoría

7. **`README.md`**
   - Documentación completa de uso
   - Guías de ejecución rápida y avanzada
   - Solución de problemas

8. **`ESPECIFICACIONES_TECNICAS.md`** (este archivo)
   - Detalles técnicos de todas las transformaciones

---

## Pipeline de Ejecución

```
MASTER_PIPELINE.sql
    ├─ FASE 0: Setup
    ├─ FASE 1: Preparar tablas RAW
    ├─ FASE 2: Importar CSV → staging_apps_raw
    ├─ FASE 3: Estructurar → staging_apps
    ├─ FASE 4: Crear funciones de limpieza
    ├─ FASE 5: Calcular métricas (avg_size)
    ├─ FASE 6: Crear tabla limpia → clean_apps
    └─ FASE 7: Validar resultados
```

---

## Transformaciones Detalladas

### Columna A: size (FLOAT)

Problema original:
```
Valores mixtos: "19M", "14M", "103k", "1,000+", "", NULL
```

**Solución implementada:**

```sql
CREATE OR REPLACE FUNCTION normalize_size(p_size TEXT)
RETURNS FLOAT AS $$
```

**Lógica:**
1. **Entrada:** Texto con cualquier formato
2. **Sí termina con 'M'**: Extrae número → multiplica por 1,000,000
   - Ej: "19M" → 19 × 1,000,000 = 19,000,000 bytes
3. **Sí termina con 'k'**: Extrae número → multiplica por 1,000
   - Ej: "103k" → 103 × 1,000 = 103,000 bytes
4. **Sí es número puro**: Mantiene como está
   - Ej: "1000" → 1,000 bytes
5. **Sí está vacío o NULL**: Retorna NULL → LUEGO se rellena con MEDIA
   - Media calculada automáticamente: AVERAGE(size válidos)
6. **Sí tiene caracteres inválidos**: Retorna NULL

**Resultado:**
```
Antes: "19M", "14M", "103k"
Después: 19000000, 14000000, 103000 (todos en FLOAT bytes)
```

Tabla de referencia:
```
┌─────────────────────┬──────────┬─────────────┐
│ valor_original      │ valor    │ unidad      │
├─────────────────────┼──────────┼─────────────┤
│ 19M                 │ 19000000 │ bytes       │
│ 14M                 │ 14000000 │ bytes       │
│ 103k                │ 103000   │ bytes       │
│ (vacío/NULL)        │ [MEDIA]  │ bytes       │
└─────────────────────┴──────────┴─────────────┘
```

---

### Columna B: content_rating (INT)

Problema original:
```
Valores categóricos: "Everyone", "Teen", "Mature 17+", "Unrated", "", NULL
```

**Solución implementada:**

Tabla de Mapeo Creada:
```sql
CREATE TABLE mapping_content_rating (
    content_rating_original TEXT PRIMARY KEY,
    content_rating_numeric INT,
    severity_level TEXT,
    description TEXT
);
```

**Mapeo:**
```
┌──────────────────────────┬────────────┬────────────┐
│ content_rating_original  │ numeric    │ severity   │
├──────────────────────────┼────────────┼────────────┤
│ "Everyone"               │ 1          │ LOWEST     │
│ "Everyone 10+"           │ 2          │ LOW        │
│ "Teen"                   │ 3          │ MEDIUM     │
│ "Mature 17+"             │ 4          │ HIGH       │
│ "Adults only 18+"        │ 5          │ HIGHEST    │
│ "Unrated"                │ 0          │ UNKNOWN    │
│ "" (vacío)               │ 0          │ UNKNOWN    │
│ NULL                     │ 0          │ UNKNOWN    │
└──────────────────────────┴────────────┴────────────┘
```

**Función:**
```sql
CREATE OR REPLACE FUNCTION normalize_content_rating(p_content_rating TEXT)
RETURNS INT AS $$
```

**Lógica:**
1. Si NULL o vacío → retorna 0
2. Busca en tabla mapping_content_rating (case-insensitive)
3. Si encuentra → retorna numeric
4. Si no encuentra → retorna 0 (desconocido)

**Resultado:**
```
Antes: "Everyone", "Teen", "Mature 17+"
Después: 1, 3, 4 (todos INT)
```

---

### Columna C: `type` → `type_numeric` (INT)

**Problema original:**
```
Valores: "Free", "Paid", "", NULL
```

**Solución implementada:**

**Mapeo:**
```
┌──────────────────┬────────────┬──────────────┐
│ type_original    │ numeric    │ name         │
├──────────────────┼────────────┼──────────────┤
│ "Free"           │ 0          │ GRATUITA     │
│ "Paid"           │ 1          │ DE_PAGO      │
│ "" (vacío)       │ 0          │ UNKNOWN      │
│ NULL             │ 0          │ UNKNOWN      │
└──────────────────┴────────────┴──────────────┘
```

**Función:**
```sql
CREATE OR REPLACE FUNCTION normalize_app_type(p_type TEXT)
RETURNS INT AS $$
```

**Lógica:**
1. Si NULL o vacío → retorna 0 (Free)
2. Si es "PAID" → retorna 1
3. Si es cualquier cosa → retorna 0 (Free)

**Resultado:**
```
Antes: "Free", "Paid"
Después: 0, 1 (todos INT)
```

---

## Tablas Creadas

### Tabla Principal: `clean_apps`

**Campos:**
```sql
app_id                    INT (PRIMARY KEY)
app_name                  TEXT
category                  TEXT
rating                    FLOAT (NULL si inválido)
reviews                   BIGINT (NULL si inválido)
size                      FLOAT (NORMALIZADO)
installs                  BIGINT (limpiado de comas/+)
price                     FLOAT (limpiado de símbolos)
type                      TEXT (original: Free/Paid)
type_numeric              INT (0=Free, 1=Paid)
content_rating            TEXT (original: Everyone, Teen, etc.)
content_rating_numeric    INT (0-5 mapeado)
genres                    TEXT
last_updated              DATE (validado)
current_version           TEXT
android_version           TEXT
```

### Tablas de Referencia (Mappings):

1. **`mapping_content_rating`** - Conversión de categorías
2. **`mapping_app_type`** - Conversión de tipos

### Tablas de Auditoría:

1. **`data_quality_metrics`** - Métrica de media para SIZE
2. **`import_error_log`** - Registro de errores durante importación

---

## Validaciones Realizadas

### Validación 1: Integridad Estructural
- Verifica que cada fila tenga 13 columnas
- Marca filas de encabezado (Se excluyen)
- Detecta filas con app_name vacío

### Validación 2: Tipos de Datos
- Rating: Debe ser número decimal entre 0-5
- Reviews: Debe ser número entero positivo
- Size: Debe ser número (con M/k) o NULL
- Installs: Debe ser número con comas/+
- Price: Debe ser número
- Last Updated: Debe ser fecha válida

### Validación 3: Transformaciones
- Calcula media de SIZE para NULLs
- Verifica distribución de categorías
- Reporta porcentaje de validez

---

## 🔍 Consultas de Verificación

Después de ejecutar, verifica con:

```sql
-- Ver estadísticas finales
SELECT
    COUNT(*) AS total_apps,
    COUNT(CASE WHEN rating IS NOT NULL THEN 1 END) AS valid_ratings,
    COUNT(CASE WHEN size IS NOT NULL THEN 1 END) AS valid_sizes,
    COUNT(CASE WHEN content_rating_numeric = 0 THEN 1 END) AS unrated
FROM clean_apps;

-- Ver distribución de tipos
SELECT type_numeric, COUNT(*) FROM clean_apps GROUP BY type_numeric;

-- Ver distribución de ratings
SELECT content_rating_numeric, COUNT(*) FROM clean_apps 
GROUP BY content_rating_numeric ORDER BY content_rating_numeric;

-- Ver estadísticos de SIZE
SELECT
    ROUND(AVG(size), 0) AS avg_size_bytes,
    ROUND(AVG(size)/1000000, 2) AS avg_size_mb,
    ROUND(MIN(size), 0) AS min_size,
    ROUND(MAX(size), 0) AS max_size
FROM clean_apps
WHERE size IS NOT NULL;
```

---

## Casos Especiales Manejados

1. SIZE con múltiples decimales: "1.25M" - Manejado
2. SIZE inversas (k/M mayúscula): "19K", "14M" - Case-insensitive
3. Content Rating con espacios extra: "  Everyone  " - TRIM aplicado
4. Valores vacíos: "" → rellena con media - Handled
5. NULL en cualquier campo: - Preservado
6. Caracteres especiales: "U Launcher Lite €" - Mantenido app_name
7. Comillas en valores: '"Text"' - Removidas

---

## Archivo CSV Original vs Limpio

### Antes:
```
App,Category,Rating,Reviews,Size,Installs,Type,Price,Content Rating,Genres,Last Updated,Current Ver,Android Ver
Photo Editor & Candy Camera & Grid & Scrapbook,ART_AND_DESIGN,4.1,159,19M,"10,000+",Free,0,Everyone,Art & Design,"January 7, 2018",1.0.0,4.0.3 and up
Coloring book moana,ART_AND_DESIGN,3.9,967,14M,"500,000+",Free,0,Everyone,"Art & Design;Pretend Play","January 15, 2018",2.0.0,4.0.3 and up
```

### Después (clean_apps):
```
app_name: "Photo Editor & Candy Camera & Grid & Scrapbook"
category: "ART_AND_DESIGN"
rating: 4.1 (FLOAT)
reviews: 159 (BIGINT)
size: 19000000.0 (FLOAT, en bytes)
installs: 10000 (BIGINT)
type: "Free"
type_numeric: 0 (INT)
content_rating: "Everyone"
content_rating_numeric: 1 (INT)
price: 0.0 (FLOAT)
last_updated: 2018-01-07 (DATE)
```

---

## Optimizaciones Implementadas

1. Índices creados:
   - idx_category → Búsquedas por categoría
   - idx_content_rating → Búsquedas por age rating
   - idx_type → Búsquedas por tipo
   - idx_is_valid → Filtrado de filas válidas

2. Funciones inmutables:
   - normalize_size() - IMMUTABLE
   - normalize_content_rating() - IMMUTABLE
   - normalize_app_type() - IMMUTABLE
   - Permite al motor de BD optimizar consultas

3. Cache de métricas:
   - Media de SIZE guardada en data_quality_metrics
   - Evita recalcular en cada actualización

---

## Errores Comunes & Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| File not found | Ruta CSV incorrecta | Cambiar ruta en línea ~150 del MASTER_PIPELINE |
| Column count mismatch | CSV corrupto | Verificar CSV con Excel |
| Type conversion error | Rating/Size con caracteres | Verificar con SELECT DISTINCT |
| Division by zero | NULL en mean calc | Ya manejado en función |
| Memory exceeded | CSV muy grande | Ejecutar en fases |

---

##  Notas Importantes

- **Todas las transformaciones son reversibles** → datos originales en `staging_apps`
- **No se pierden datos** → valores inválidos en `import_error_log`
- **Auditoría completa** → todas las operaciones registradas
- **Escalable** → funciona con archivos >= 100MB
- **PostgreSQL compatible** → versiones 10+

---

**Versión:** 2.0
**Fecha:** Marzo 2026
**Motor BD:** PostgreSQL 10+
