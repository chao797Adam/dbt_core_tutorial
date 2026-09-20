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

* **Option A: Single Model Example (`bronze_sales`)**
  * **YAML Definition (`properties.yml`)**:
    ```yaml
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

* **Option B: Global Generic-Only (Exclude All Singular Tests, 10 test result)**
  * **CLI Command**:
    ```bash
    dbt test --exclude test_type:singular
    ```

---

## Snapshot — SCD Type 2

`snap_items` tracks historical changes to the `item` table using the `check` strategy.

- **unique_key**: `id`
- **strategy**: `check` (monitors `name` and `category`)
- **deduplication**: `ROW_NUMBER()` ensures one row per `id` from source
- **valid_to default**: `9999-12-31`

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