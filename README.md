# dbt Core Tutorial — Retail Sales Analytics

A production-style dbt project on **Databricks / Delta Lake (Unity Catalog)**, implementing a **Medallion Architecture** for retail sales data. Covers ingestion, transformation, data testing, SCD Type 2 snapshots, and multi-environment (dev / prod) deployment.

**Highlights**

- Medallion architecture (bronze / silver / gold) with schema isolation in Unity Catalog
- 15 data tests (generic, custom generic, singular) that gate downstream models
- SCD Type 2 snapshot built on a deduplicated source
- Dev / prod separation through separate catalogs and a custom `generate_schema_name` macro
- Full `dbt build --target prod`: 26 nodes (seed, models, snapshot, tests), all passing

---

## Architecture

```
Source (dbt_core_tutorial.source)
        │
        ▼
┌─────────────┐
│   Bronze    │  Raw ingestion from source tables
│             │  - bronze_customer
│             │  - bronze_date
│             │  - bronze_product
│             │  - bronze_returns
│             │  - bronze_sales
│             │  - bronze_store
│             │  - item_dedup (view, input for snapshot)
│             │  - lookup (seed)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Silver    │  Joined and enriched data
│             │  - silver_sales (fact joined with dimension tables)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Gold     │  Aggregated business metrics (BI-ready)
│             │  - gold_agg
└─────────────┘

┌─────────────┐
│  Snapshots  │  SCD Type 2 — tracks historical changes
│             │  - snap_items (check strategy, deduplicated source)
└─────────────┘
```

---

## Tech Stack

| Tool | Version |
|------|---------|
| dbt Core | 1.12.5 |
| dbt-databricks | 1.10.9 |
| Databricks / Delta Lake | Unity Catalog, SQL Warehouse |
| Python | 3.11 |
| dbt-expectations | package (see `packages.yml`) |

---

## Project Structure

```
dbt_core_proj/
├── models/
│   ├── _sources.yml          # Source definitions
│   ├── bronze/               # Raw ingestion layer
│   │   ├── bronze_*.sql
│   │   ├── item_dedup.sql    # Deduplicated items (input for snapshot)
│   │   └── properties.yml    # Tests & documentation
│   ├── silver/               # Transformation layer
│   │   └── silver_sales.sql
│   └── gold/                 # Business metrics layer
│       └── gold_agg.sql
├── snapshots/
│   └── snap_items.yml        # SCD Type 2 snapshot
├── tests/                    # Custom singular tests
├── macros/
│   ├── schema.sql            # Overrides generate_schema_name
│   ├── multiply.sql          # Custom macro
│   ├── generic_non_neg.sql   # Custom generic test
│   └── ...
├── seeds/
│   └── lookup.csv            # Static reference data
├── dbt_project.yml
└── packages.yml
```

---

## Quick Start

### Prerequisites

- Python 3.11+
- Databricks workspace with a SQL Warehouse
- Access to the `dbt_core_tutorial` catalog

### Installation

```bash
# Clone the repo
git clone https://github.com/chao797Adam/dbt_core_tutorial.git
cd dbt_core_tutorial

# Create virtual environment
python -m venv .venv
.venv\Scripts\activate      # Windows
source .venv/bin/activate   # Mac/Linux

# Install dependencies
pip install dbt-core dbt-databricks
```

### Configure `profiles.yml`

Add to `~/.dbt/profiles.yml` (Windows: `C:\Users\<user>\.dbt\profiles.yml`):

```yaml
dbt_core_proj:
  target: dev
  outputs:
    dev:
      type: databricks
      catalog: dbt_core_tutorial
      host: <your-databricks-host>
      http_path: <your-http-path>
      schema: default
      threads: 3
      token: "{{ env_var('DATABRICKS_TOKEN') }}"
    prod:
      type: databricks
      catalog: dbt_core_tutorial_prod
      host: <your-databricks-host>
      http_path: <your-http-path>
      schema: default
      threads: 4
      token: "{{ env_var('DATABRICKS_TOKEN') }}"
```

>Never commit tokens to Git. `profiles.yml` lives outside the repository.

Verify both environments:

```bash
dbt debug
dbt debug --target prod
```

### Usage

```bash
# Install dbt packages
dbt deps

# Run everything: seeds, models, snapshots, tests (dev)
dbt build

# Run a specific layer
dbt run --select bronze
dbt run --select silver
dbt run --select gold

# Tests only
dbt test

# Snapshot only
dbt snapshot

# Deploy to production
dbt build --target prod
```

---

## Environments

| Environment | Catalog | Purpose |
|-------------|---------|---------|
| dev | `dbt_core_tutorial` | Development & testing |
| prod | `dbt_core_tutorial_prod` | Production deployment |

Each environment reads its own source data: dev reads `dbt_core_tutorial.source`, prod reads `dbt_core_tutorial_prod.source` (copied from dev, see below).

```bash
dbt build                  # dev (default target)
dbt build --target prod    # prod
```

### Environment-Aware Sources

`_sources.yml` follows the active target instead of hard-coding the catalog:

```yaml
sources:
  - name: source
    database: "{{ target.catalog }}"
    schema: source
```

Verify without touching any data:

```bash
dbt compile --select bronze_customer --target prod
```

The compiled SQL should reference `dbt_core_tutorial_prod`.`source`.`dim_customer`.

### Prepare Prod Source Data

The prod catalog must exist and contain the source tables before running with `--target prod`. Copy the 7 source tables from dev using one of the two methods below.

```sql
CREATE SCHEMA IF NOT EXISTS dbt_core_tutorial_prod.source;
```

#### Option A: CTAS (CREATE TABLE AS SELECT)

```sql
CREATE OR REPLACE TABLE dbt_core_tutorial_prod.source.dim_customer AS
SELECT * FROM dbt_core_tutorial.source.dim_customer;

CREATE OR REPLACE TABLE dbt_core_tutorial_prod.source.dim_date AS
SELECT * FROM dbt_core_tutorial.source.dim_date;

CREATE OR REPLACE TABLE dbt_core_tutorial_prod.source.dim_product AS
SELECT * FROM dbt_core_tutorial.source.dim_product;

CREATE OR REPLACE TABLE dbt_core_tutorial_prod.source.dim_store AS
SELECT * FROM dbt_core_tutorial.source.dim_store;

CREATE OR REPLACE TABLE dbt_core_tutorial_prod.source.fact_returns AS
SELECT * FROM dbt_core_tutorial.source.fact_returns;

CREATE OR REPLACE TABLE dbt_core_tutorial_prod.source.fact_sales AS
SELECT * FROM dbt_core_tutorial.source.fact_sales;

CREATE OR REPLACE TABLE dbt_core_tutorial_prod.source.items AS
SELECT * FROM dbt_core_tutorial.source.items;
```

#### Option B: DEEP CLONE (loop over all tables)

Requires Delta source tables and a SQL Warehouse that supports SQL scripting.

```sql
BEGIN
  FOR t AS (
    SELECT table_name
    FROM dbt_core_tutorial.information_schema.tables
    WHERE table_schema = 'source'
      AND table_type <> 'VIEW'
  ) DO
    EXECUTE IMMEDIATE
      'CREATE OR REPLACE TABLE dbt_core_tutorial_prod.source.`' || t.table_name || '`
       DEEP CLONE dbt_core_tutorial.source.`' || t.table_name || '`';
  END FOR;
END;
```

| | CTAS | DEEP CLONE |
|---|---|---|
| Data and schema | Copied | Copied |
| Column comments, table properties, constraints | Not preserved | Preserved |
| Source format | Any queryable table | Delta only |
| Best for | A few tables, simple copy | Many tables, full-fidelity copy |

Verify the copy:

```sql
SHOW TABLES IN dbt_core_tutorial_prod.source;
```

### Build Summary

`dbt build --target prod` runs seeds, models, snapshots and tests in dependency order (26 nodes in total):

| Type | Count | Content |
|---|---|---|
| Table model | 8 | `bronze_customer`, `bronze_date`, `bronze_product`, `bronze_returns`, `bronze_sales`, `bronze_store`, `silver_sales`, `gold_agg` |
| View model | 1 | `item_dedup` |
| Seed | 1 | `lookup` |
| Snapshot | 1 | `snap_items` |
| Data test | 15 | 10 generic + 5 singular |
| **Total** | **26** | |

Tests act as gates: if a bronze test fails, downstream models (`silver_sales`, `gold_agg`) are skipped.

### Snapshot History in Prod

A snapshot stores its history only in the snapshot table itself; it cannot be rebuilt from the source. The prod source tables are copied from dev with CTAS (current state only), so the prod snapshot starts with a single version per record and history accumulates from the first prod run.

To carry over history from dev, clone the snapshot table **before** the first prod snapshot run:

```sql
CREATE OR REPLACE TABLE dbt_core_tutorial_prod.snapshots.snap_items
DEEP CLONE dbt_core_tutorial.snapshots.snap_items;
```

Never drop or full-refresh a snapshot table in prod, as the history cannot be recovered.

---

## Configuration

### Config Precedence (High to Low)

1. **Model `.sql` file**: `{{ config(...) }}` — **Highest**
2. **Properties `.yml` file**: `config:` block (e.g. `models/bronze/properties.yml`)
3. **Project config**: `dbt_project.yml` under `+config` — **Lowest**

In this project, `materialized` and `schema` are set per layer in `dbt_project.yml`, so model files contain only SQL.

### Custom Schema Name Macro (`generate_schema_name`)

**Problem solved**: by default dbt prefixes custom schemas with `target.schema` (e.g. `silver` becomes `default_silver`). The override uses the custom schema name as-is, so every environment gets clean `bronze` / `silver` / `gold` schemas and isolation is done at the catalog level.

`macros/schema.sql`

```jinja
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

---

## Data Tests

### Inventory

#### Generic Tests (`models/bronze/properties.yml`)

| Model | Column | Tests Configured | Severity |
| :--- | :--- | :--- | :--- |
| `bronze_sales` | `sales_id` | `unique`, `not_null` | error (default) |
| `bronze_sales` | `gross_amount` | `generic_non_neg`, `dbt_expectations.expect_column_values_to_be_between` (`0` to `100000`) | error (default) |
| `bronze_store` | `store_sk` | `unique`, `not_null` | error (default) |
| `bronze_store` | `store_name` | `not_null`, `accepted_values` (list of known stores) | `warn` |
| `bronze_store` | `country` | `not_null`, `accepted_values` (`USA`, `Canada`, `Mexico`) | `warn` |

#### Singular Tests (`tests/`)

Singular tests are SQL queries for cross-column business rules or dataset-level validation. A test passes when its query returns 0 rows.

| Test Name | Purpose |
| :--- | :--- |
| `assert_refund_less_than_sales` | Refund amount must not exceed sales |
| `negative_sales` | No negative gross amount |
| `duplicate_store_names` | No duplicate store names |
| `payment_method_check` | Valid payment methods only |
| `quantity_price_check` | Quantity × price = gross amount |

### Example: Properties Definition

```yaml
version: 2

models:
  - name: bronze_sales
    description: "sales for bronze layer"
    columns:
      - name: sales_id
        description: "primary ID"
        data_tests:
          - unique
          - not_null

      - name: gross_amount
        description: "total amount"
        data_tests:
          - generic_non_neg
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 100000

  - name: bronze_store
    columns:
      - name: store_sk
        data_tests:
          - unique
          - not_null
      - name: country
        data_tests:
          - not_null
          - accepted_values:
              values: ['USA', 'Canada', 'Mexico']
              config:
                severity: warn
```

### Example: Singular Test

`tests/duplicate_store_names.sql`

```sql
-- find duplicate store names
select store_name, count(*) as duplicate_count
from {{ ref('bronze_store') }}
group by store_name
having count(*) > 1
```

- **0 rows**: pass (no duplicates)
- **more than 0 rows**: fail (each row is a duplicate store name)

### Example: Custom Generic Test

`macros/generic_non_neg.sql`

```sql
{% test generic_non_neg(model, column_name) %}
    select * from {{ model }} where {{ column_name }} < 0
{% endtest %}
```

Used in YAML like any built-in test (`- generic_non_neg` under a column's `data_tests`).

### Running Tests

```bash
# All tests
dbt test

# One model
dbt test --select bronze_sales

# Generic tests only (10 tests)
dbt test --exclude test_type:singular

# Generic tests of one model only (4 tests for bronze_sales)
dbt test --select bronze_sales --exclude test_type:singular

# One singular test
dbt test --select duplicate_store_names
```

---

## Snapshot — SCD Type 2

### Purpose

Source tables such as `items` only store the **current state** of each record. When a row is updated, the previous value is overwritten and the history is lost.

A dbt snapshot implements a **Slowly Changing Dimension Type 2 (SCD2)** pattern: every time a tracked record changes, the old version is closed out and a new version is inserted. This makes it possible to:

- Audit what a record looked like at any point in time
- Run point-in-time analysis (e.g. "which category did item 1 belong to last month?")
- Keep historical dimension values aligned with historical facts

### Overview

| Property | Value |
|---|---|
| Source | `source('source', 'items')` (via `item_dedup`) |
| Dedup model | `item_dedup` |
| Snapshot | `snap_items` |
| Target schema | `snapshots` |
| Strategy | `check` |
| Unique key | `id` |
| Tracked columns | `name`, `category` |
| `dbt_valid_to` for current rows | `9999-12-31` |

### How It Works

dbt adds four metadata columns to the snapshot table:

| Column | Meaning |
|---|---|
| `dbt_scd_id` | Unique identifier of each record version |
| `dbt_updated_at` | Timestamp when dbt captured this version |
| `dbt_valid_from` | Start of the period in which this version is valid |
| `dbt_valid_to` | End of the validity period (`9999-12-31` = current version) |

Example: `category` of item 1 changes from `category1` to `category1_new`.

| id | name | category | dbt_valid_from | dbt_valid_to |
|---|---|---|---|---|
| 1 | item1 | category1 | 2026-09-01 10:00 | 2026-09-10 08:30 |
| 1 | item1 | category1_new | 2026-09-10 08:30 | 9999-12-31 |

### Implementation

#### 1. Deduplicate the source

A snapshot requires **exactly one row per `unique_key`** on every run. If the source can contain multiple rows for the same `id` (e.g. append-only updates), the snapshot fails or produces duplicate "current" records. `ROW_NUMBER()` keeps only the latest row per `id`.

`models/bronze/item_dedup.sql`

```sql
select id, name, category, updateDate
from (
    select *,
           row_number() over (partition by id order by updateDate desc) as rn
    from {{ source('source', 'items') }}
)
where rn = 1
```

#### 2. Define the snapshot (YAML, dbt 1.9+)

`snapshots/snap_items.yml`

```yaml
snapshots:
  - name: snap_items
    relation: ref('item_dedup')
    config:
      schema: snapshots
      unique_key: id
      strategy: check
      check_cols: [name, category]
      dbt_valid_to_current: "to_date('9999-12-31', 'yyyy-MM-dd')"
```

If the source has a reliable update timestamp, the `timestamp` strategy is more efficient because it avoids column-by-column comparison:

```yaml
      strategy: timestamp
      updated_at: updateDate
```

With `timestamp`, a change is only detected if `updateDate` also changes. The `check` strategy does not depend on the timestamp being maintained correctly.

#### 3. Legacy approach (SQL block)

Before dbt 1.9, snapshots were defined as a `{% snapshot %}` block in a `.sql` file. This syntax is still supported.

`snapshots/snap_items.sql`

```sql
{% snapshot snap_items %}
    {{
        config(
          target_schema='snapshots',
          unique_key='id',
          strategy='check',
          check_cols=['name', 'category'],
          dbt_valid_to_current="to_date('9999-12-31', 'yyyy-MM-dd')"
        )
    }}

    select id, name, category, updateDate
    from (
        select *, row_number() over (partition by id order by updateDate desc) as rn
        from {{ source('source', 'items') }}
    )
    where rn = 1

{% endsnapshot %}
```

| | YAML (current) | SQL `{% snapshot %}` (legacy) |
|---|---|---|
| Location | `snapshots/*.yml` | `snapshots/*.sql` |
| Data input | `relation: source(...)` / `ref(...)` | Inline `select` statement |
| Custom SQL inside snapshot | Not supported (use an upstream model) | Supported |
| Config names | `database`, `schema` | `target_database`, `target_schema` |
| Recommended for | New projects | Existing projects |

The YAML approach separates configuration from transformation logic, which is why the deduplication lives in its own model (`item_dedup`).

### Running

Snapshots are executed with `dbt snapshot`, not `dbt run`. Run it on a schedule; each execution captures the state of the source at that moment.

`dbt snapshot` does not build upstream models, so whether `item_dedup` must be run first depends on how it is materialized:

| `item_dedup` materialization | Command | Notes |
|---|---|---|
| `view` | `dbt snapshot --select snap_items` | The view reads the source in real time, so only one command is needed. Suitable for small to medium datasets. |
| `table` | `dbt build --select +snap_items` | The table must be refreshed before each snapshot, otherwise new source changes are missed. `dbt build` runs `item_dedup` first, then `snap_items`. |

In this project `item_dedup` is a **view**, so `dbt snapshot --select snap_items` is enough.

### Verification

Current records only:

```sql
select * from dbt_core_tutorial.snapshots.snap_items
where dbt_valid_to = '9999-12-31';
```

Full history of one record:

```sql
select * from dbt_core_tutorial.snapshots.snap_items
where id = 1
order by dbt_valid_from;
```

### Limitations

- A snapshot only captures the state **at the time it runs**. If a record changes several times between two runs, intermediate versions are not recorded. Increase the run frequency if this matters.
- The source (or the dedup model) must guarantee one row per `unique_key`.
- Changing `unique_key` or `strategy` on an existing snapshot requires a manual migration or a rebuild of the snapshot table.

---

## Design Notes & Trade-offs

**Silver layer scope.** In this project, `silver_sales` joins the sales fact table with several dimension tables to produce an enriched, analysis-ready table. This is quick to build and easy to query, but it mixes cleansing and denormalization in one layer.

A more production-oriented design keeps Silver **atomic** (cleansing, type casting, foreign keys preserved as `*_sk`) and moves wide, denormalized assembly to the Gold layer:

| Dimension / Layer | This project | Production-oriented design |
| :--- | :--- | :--- |
| **Silver** | Fact joined with dimensions (enriched) | Atomic entities & fact tables, `*_sk` retained |
| **Gold** | Aggregation (`gold_agg`) | Wide denormalized mart (e.g. `gold_sales_wide`) + aggregate tables (`_agg`) |
| **Trade-off** | Simple and fast to set up | Better dimension reuse; avoids metric drift and accidental row inflation from joins |

**Source data quality.** The source data is already clean, so the Silver layer contains no heavy cleansing logic. Data quality is enforced through tests on the Bronze layer instead.

---

*Reference: [Ansh Lamba — DBT The Ultimate Guide](https://www.youtube.com/watch?v=B8uwFmVt4sU&t=5009s)*
