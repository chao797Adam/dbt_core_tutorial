# dbt Core Tutorial — Retail Sales Analytics

A production-ready dbt project built on **Databricks / Delta Lake**, implementing a **Medallion Architecture** for retail sales data. Covers data ingestion, transformation, testing, SCD Type 2 snapshots, and multi-environment deployment.

---

## Architecture

```
Source (dbt_core_Tutorial.source)
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
│             │  - lookup (seed)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Silver    │  Cleaned, joined, enriched data
│             │  - silver_sales (joins sales, product, customer, store)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Gold     │  Aggregated business metrics (BI-ready)
│             │  - gold_sales_by_category
└─────────────┘

┌─────────────┐
│  Snapshots  │  SCD Type 2 — tracks historical changes
│             │  - snap_items (check strategy, deduped source)
└─────────────┘
```

---

## Tech Stack

| Tool | Version |
|------|---------|
| dbt Core | 1.11.8 |
| dbt-databricks | 1.12.0 |
| Databricks / Delta Lake | - |
| Python | 3.12 |
| dbt-expectations | (package) |
| dbt-date | (package) |

---

## Project Structure

```
dbt_core_proj/
├── models/
│   ├── _sources.yml          # Source definitions
│   ├── bronze/               # Raw ingestion layer
│   │   ├── bronze_*.sql
│   │   └── properties.yml    # Tests & documentation
│   ├── silver/               # Transformation layer
│   │   └── silver_sales.sql
│   └── gold/                 # Business metrics layer
│       └── gold_sales_by_category.sql
├── snapshots/
│   └── snap_items.sql        # SCD Type 2 snapshot
├── tests/
│   └── bronze/               # Custom singular tests
├── macros/
│   ├── multiply.sql          # Custom macro
│   ├── generic_non_neg.sql   # Generic test macro
│   └── ...
├── seeds/
│   └── lookup.csv            # Static reference data
├── dbt_project.yml
└── packages.yml
```

---

### Config Precedence (High to Low)

1. **Model `.sql` file**: `{{ config(...) }}` — **Highest**
2. **Properties `.yml` file**: `config:` block (e.g., `models/bronze/properties.yml`)
3. **Project config**: `dbt_project.yml` under `+config` — **Lowest**

### Custom Schema Name Macro (`generate_schema_name`)

> **Problem Solved**: Prevents dbt from prefixing custom schemas with `target.schema` (e.g., turning `silver` into `dev_silver`), ensuring clean schema isolation in Unity Catalog/Data Warehouse.

#### Implementation (`macros/schema.sql`)
```jinja
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

## Data Tests

### 1. Data Tests Inventory

#### Generic Tests (`models/.../properties.yml`)
| Model | Column | Tests Configured | Severity / Notes |
| :--- | :--- | :--- | :--- |
| `bronze_sales` | `sales_id` | `unique`, `not_null` | Error (default) |
| `bronze_sales` | `gross_amount` | `generic_non_neg`, `dbt_expectations.expect_column_values_to_be_between` (`0` to `100000`) | Error (default) |
| `bronze_store` | `store_sk` | `unique`, `not_null` | Error (default) |
| `bronze_store` | `store_name` | `not_null`, `accepted_values` (`['MegaMart Manhattan', 'MegaMart Austin', 'MegaMart San Jose', 'MegaMart Toronto', 'MegaMart Brooklyn', 'xc']`) | `severity: warn` |
| `bronze_store` | `country` | `not_null`, `accepted_values` (`['USA', 'Canada', 'Mexico']`) | `severity: warn` |

#### Custom Singular Tests (`tests/`)
*(Singular tests placed under `tests/` for cross-column business rule or dataset-level validation)*
| Test Name | SQL Logic / Purpose |
| :--- | :--- |
| `assert_refund_less_than_sales` | Refund amount must not exceed sales |
| `negative_sales` | No negative gross amount |
| `duplicate_store_names` | No duplicate store names |
| `payment_method_check` | Valid payment methods only |
| `quantity_price_check` | Quantity × price = gross amount |

---

### 2. Execution Guide: Running Generic Tests Only

* **Single Model Example (`bronze_sales`)**
  * **YAML Definition (`properties.yml`)**:
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
      - name: store_name
        data_tests:            
          - not_null
          - accepted_values:
              values: ['MegaMart Manhattan', 'MegaMart Austin', 'MegaMart San Jose', 'MegaMart Toronto', 'MegaMart Brooklyn', 'xc']
            config:         
              severity: warn
      - name: country
        data_tests:
          - not_null              
          - accepted_values:
              values: ['USA', 'Canada', 'Mexico']
            config:         
              severity: warn
```

* **Option A: Single Model Generic Tests Only (`bronze_sales`, 4 test results)**
  * **CLI Command**:
    ```bash
    dbt test --select bronze_sales --exclude test_type:singular
    ```
  * **Behavior**: Runs strictly the generic column-level tests for `bronze_sales` (4 tests), omitting related singular SQL tests.

* **Option B: Global Generic-Only (Exclude All Singular Tests, 10 test results)**
  * **CLI Command**:
    ```bash
    dbt test --exclude test_type:singular
    ```

### 3. Execution Guide: Running Singular Tests
* **Singular Test: Duplicate Store Names (`tests/duplicate_store_names.sql`)**
  * **CLI Command**:
    ```bash
    dbt test --select duplicate_store_names
    ```
  * **SQL Query**:
    ```sql
    -- find duplicate store names
    select store_name, count(*) as duplicate_count
    from {{ ref('bronze_store') }}
    group by store_name
    having count(*) > 1
    ```
  * **Test Evaluation Logic**
    * **0 rows**: **Pass** (no duplicate store names found)
    * **> 0 rows**: **Fail** (each returned row represents a duplicate store name)
    
* **Custom Generic Test: Non-Negative Check (`macros/generic_non_neg.sql` or `tests/generic/`)**
  * **SQL Definition**:
    ```sql
    {% test generic_non_neg(model, column_name) %}
        select * from {{ model }} where {{ column_name }} < 0
    {% endtest %}
    ```
  * **YAML Configuration (`properties.yml`)**:
    ```yaml
    models:
      - name: bronze_sales
        columns:
          - name: gross_amount
            data_tests:
              - generic_non_neg
    ```
  * **CLI Command**:
    ```bash
    dbt test --select bronze_sales
    ```

---

## Jinja Basics & Dynamic SQL (Analyses)

* **Basic Variable Assignment (`analyses/jinja1.sql`)**
  * **Code**:
    ```jinja
    {% set my_var = 'xc' %}
    SELECT '{{ my_var }}' AS val
    ```
  * **Note**: Must be wrapped in a valid SQL select statement for compilation.

* **List Iteration (`analyses/jinja2.sql`)**
  * **Code**:
    ```jinja
    {% set apples = ["Gala", "Red Delicious", "Fuji", "McIntosh", "Honeycrisp"] %}

    {% for i in apples %}
        {{ i }}
    {% endfor %}
    ```

* **Conditional Loop (`analyses/jinja3.sql` variant)**
  * **Code**:
    ```jinja
    {%- set apples = ["Gala", "Red Delicious", "Fuji", "McIntosh", "Honeycrisp"] -%}

    {% for i in apples %}
        {% if i != "McIntosh" %}
            {{ i }}
        {% else %}
            I hate {{ i }}
        {% endif %}
    {% endfor %}
    ```

* **Dynamic Columns & Trailing Comma Fix (`analyses/jinja3.sql`)**
  * **Pitfall Note**: Direct trailing commas like `{{ i }},` produce syntax errors (`order_amount, FROM ...`). Use `loop.last` check.
  * **Fixed Code**:
    ```sql
    {% set inc_flag = 1 %}
    {% set last_load = 3 %}
    {% set cols_list = ["sales_id", "date_sk", "gross_amount"] %}

    SELECT
        {% for i in cols_list %}
            {{ i }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM
        {{ ref('bronze_sales') }}

    {% if inc_flag == 1 %}
        WHERE date_sk > {{ last_load }}
    {% endif %}
    ```
---
## 💡 Architecture Notes & Trade-offs (Silver Layer Scope)

> **Tutorial Reality vs. Enterprise Best Practice**:
> * **Tutorial Scope**: In this tutorial/video, the Silver layer joins the fact table directly with 5 core entities (`sales` + `product` + `customer` + `store` + `date`).
> * **Production Standard**: Production-grade standards dictate that the Silver layer should remain **atomic**, handling data cleansing and foreign key preservation (`*_sk`), while pushing multi-table denormalized wide-table assembly down to the **Gold (Mart)** layer.

### Architectural Comparison

| Dimension / Layer | Tutorial Implementation | Production Best Practice |
| :--- | :--- | :--- |
| **Silver Layer** | Multi-entity enriched details (5-table JOIN) | Pure atomic entities & fact tables (retaining `*_sk`) |
| **Gold Layer** | Lightweight aggregation or pass-through | Wide denormalized business mart (`gold_sales_wide`) + agg tables (`_agg`) |
| **Trade-off** | Intuitive and fast for rapid tutorial setup | High dimension reusability; prevents metric drift & implicit row inflation |

> 📌 **Note**: Using a 5-table Silver join for hands-on practice is completely fine. Evolving your architecture toward `Silver (atomic) -> Gold (wide/agg)` later is a great way to showcase architectural maturity.

---

## Snapshot — SCD Type 2

### Purpose

Source tables such as `items` only store the **current state** of each record. When a row is updated, the previous value is overwritten and the history is lost.

A dbt snapshot solves this by implementing a **Slowly Changing Dimension Type 2 (SCD2)** pattern: every time a tracked record changes, the old version is closed out and a new version is inserted. This makes it possible to:

- Audit what a record looked like at any point in time
- Run point-in-time analysis (e.g. "which category did item 1 belong to last month?")
- Keep historical dimension values aligned with historical facts

### Overview

| Property | Value |
|---|---|
| Source | `source('source', 'items')` |
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

Note: with `timestamp`, a change is only detected if `updateDate` also changes.

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

```bash
dbt run --select item_dedup
dbt snapshot --select snap_items
```

Snapshots are executed with `dbt snapshot`, not `dbt run`. Run it on a schedule; each execution captures the state of the source at that moment.

### Verification

Current records only:

```sql
select * from snapshots.snap_items
where dbt_valid_to = '9999-12-31';
```

Full history of one record:

```sql
select * from snapshots.snap_items
where id = 1
order by dbt_valid_from;
```

### Limitations

- A snapshot only captures the state **at the time it runs**. If a record changes several times between two runs, intermediate versions are not recorded. Increase the run frequency if this matters.
- The source (or the dedup model) must guarantee one row per `unique_key`.
- Changing `unique_key` or `strategy` on an existing snapshot requires a manual migration or a rebuild of the snapshot table.

---

## Setup

### Prerequisites
- Python 3.12+
- Databricks workspace with SQL Warehouse
- Access to `dbt_core_case` catalog

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

### Configure profiles.yml

Add to `~/.dbt/profiles.yml`:

```yaml
dbt_core_proj:
  outputs:
    dev:
      type: databricks
      catalog: dbt_core_tutorial
      host: <your-databricks-host>
      http_path: <your-http-path>
      schema: default
      threads: 4
      token: <your-token>
    prod:
      type: databricks
      catalog: dbt_core_tutorial_prod
      host: <your-databricks-host>
      http_path: <your-http-path>
      schema: default
      threads: 8
      token: <your-token>
  target: dev
```

---

## Usage

```bash
# Install dbt packages
dbt deps

# Run all models + tests + snapshots (dev)
dbt build

# Run specific layer
dbt run --select bronze
dbt run --select silver
dbt run --select gold

# Run tests only
dbt test

# Run snapshot
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

Source data is shared from `dbt_core_tutorial.source` across both environments.

*Reference: [Ansh Lamba — DBT The Ultimate Guide](https://www.youtube.com/watch?v=B8uwFmVt4sU&t=5009s)* [cite: 3]