-- 定义你想处理的列名列表
{% set cols = ["sales_id", "product_sk", "quantity", "unit_price"] %}

select
    {% for col in cols -%}
        {# 如果列名里包含 'id'，就直接输出 #}
        {%- if "id" in col -%}
            {{ col }}
        {# 如果是数值列，就做空值处理 #}
        {%- else -%}
            coalesce({{ col }}, 0) as {{ col }}
        {%- endif -%}
        
        {# 处理逗号：只要不是最后一列，就加逗号 #}
        {{ "," if not loop.last }}
    {%- endfor %}
from {{ ref('bronze_sales') }}