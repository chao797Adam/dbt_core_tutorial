{{
  config(
    materialized = 'table',
    )
}}
select *
from {{ source('source', 'fact_sales') }}
