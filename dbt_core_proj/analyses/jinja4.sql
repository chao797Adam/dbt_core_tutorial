{% set inc_flag = 1 %}
{% set last_load = 3 %}

{% set cols_list = ["sales_id", "date_sk", "order_amount"] %}

select {% for i in cols_list %} {{ i }}, {% endfor %}
from {{ ref('bronze_sales') }}

{% if inc_flag == 1 %} where date_sk > {{ last_load }} {% endif %}
