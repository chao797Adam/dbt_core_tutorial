# dbt Core Tutorial — Retail Sales Analytics

A production-ready dbt project built on **Databricks / Delta Lake**, implementing a **Medallion Architecture** for retail sales data. Covers data ingestion, transformation, testing, SCD Type 2 snapshots, and multi-environment deployment.

---

## Architecture

```
Source (dbt_core_case.source)
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
chao_dbt_core/
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

## Data Tests

### Generic Tests (properties.yml)
- `not_null` — sales_id, store_sk, country, store_name
- `unique` — sales_id, store_sk
- `accepted_values` — country (USA, Canada, Mexico), store_name, payment_method
- `dbt_expectations.expect_column_values_to_be_between` — gross_amount

### Custom Singular Tests
- `assert_refund_less_than_sales` — refund amount must not exceed sales
- `negative_sales` — no negative gross amount
- `duplicate_store_names` — no duplicate store names
- `payment_method_check` — valid payment methods only
- `quantity_price_check` — quantity × price = gross amount

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
chao_dbt_core:
  outputs:
    dev:
      type: databricks
      catalog: dbt_core_case
      host: <your-databricks-host>
      http_path: <your-http-path>
      schema: default
      threads: 4
      token: <your-token>
    prod:
      type: databricks
      catalog: dbt_core_case_prod
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
| dev | `dbt_core_case` | Development & testing |
| prod | `dbt_core_case_prod` | Production deployment |

Source data is shared from `dbt_core_case.source` across both environments.
