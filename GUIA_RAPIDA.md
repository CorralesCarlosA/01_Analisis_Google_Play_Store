# GUÍA RÁPIDA - Google Play Store ETL Pipeline

**Fecha de creación:** Marzo 11, 2026  
**Última actualización:** Marzo 11, 2026

---

## ¿Qué se hizo?

Creamos un **pipeline completo de limpieza de datos SQL** para normalizar el archivo `googleplaystore.csv` con 3 transformaciones principales:

### 1. SIZE (Columna 5)
- Convierte `19M` → `19,000,000` bytes
- Convierte `103k` → `103,000` bytes  
- Rellena vacíos con la MEDIA calculada
- Resultado: FLOAT

### 2. CONTENT_RATING (Columna 9)
Mapea a números (escala 1-5):
- `Everyone` = 1
- `Everyone 10+` = 2
- `Teen` = 3
- `Mature 17+` = 4
- `Adults only 18+` = 5
- `Unrated` / NULL = 0

### 3. TYPE (Columna 7)
Mapea Free/Paid a números:
- `Free` = 0
- `Paid` = 1

---

## Archivos Principales

```
sql/
├─ MASTER_PIPELINE.sql             (ejecuta todo)
├─ 00_enhanced_database_setup.sql
├─ 01_improved_import.sql
├─ 02_structured_staging.sql
├─ 05_clean_size_column.sql
├─ 06_clean_content_rating_and_type.sql
├─ README.md                        (documentación completa)
└─ ESPECIFICACIONES_TECNICAS.md    (detalles técnicos)
```
---

## EJECUCIÓN RÁPIDA

### Opción 1: TODO en 1 paso (Recomendado)
```sql
-- Abre: sql/MASTER_PIPELINE.sql
-- Ejecuta todo en DBeaver (Ctrl+Enter)
-- Tiempo: 2-5 minutos
-- Resultado: tabla 'clean_apps' lista
```

### Opción 2: Paso a Paso
```sql
1. sql/01_improved_import.sql      (importa CSV)
2. sql/02_structured_staging.sql   (estructura datos)
3. sql/05_clean_size_column.sql    (limpia SIZE)
4. sql/06_clean_content_rating_and_type.sql  (limpia ratings)
```

---

## Verificación Rápida

Después de ejecutar, verifica:

```sql
-- Ver tabla limpia
SELECT 
    app_name,
    size,
    content_rating_numeric,
    type_numeric
FROM clean_apps
LIMIT 20;

-- Ver estadísticas
SELECT 
    COUNT(*) AS total_apps,
    ROUND(AVG(size)/1000000, 2) AS avg_size_mb,
    COUNT(CASE WHEN content_rating_numeric > 0 THEN 1 END) AS rated_apps
FROM clean_apps;
```

---

## Documentación Completa

- **Guía de uso paso a paso:** `sql/README.md`
- **Detalles técnicos:** `sql/ESPECIFICACIONES_TECNICAS.md`
- **Archivos originales:** `sql/03_structured_staging.sql`, `sql/04_data_cleaning.sql`

---

## Base de Datos

- **Engine:** PostgreSQL 10+
- **Tabla final:** `clean_apps`
- **Tablas de referencia:** `mapping_content_rating`, `mapping_app_type`
- **Auditoría:** `data_quality_metrics`, `import_error_log`

---

## Referencias Relacionadas

- CSV original: `data/googleplaystore.csv`
- Directorio SQL: Todos los scripts en esta carpeta
- Documentación: README.md y ESPECIFICACIONES_TECNICAS.md

---

**Nota:** Si necesitas ajustes o tienes nuevas transformaciones, busca esta guía como referencia rápida.
