{% set inc_flag = 1 %}
{% set last_load = 3 %}
{% set column_list = ["date_sk", "gross_amount", "sales_id"] %}

select 
{% for i in column_list %}
    {{ i }}{% if not loop.last %},{% endif %}
{% endfor %}
from {{ ref('bronze_sales') }}
{% if inc_flag == 1 %}
where date_sk > {{ last_load }}
{% endif %}