{% set all_columns = adapter.get_columns_in_relation(ref('bronze_sales')) %}

select
    {% for col in all_columns -%}
        {{ col.name }}{{ "," if not loop.last }}
    {% endfor %}
from {{ ref('bronze_sales') }}