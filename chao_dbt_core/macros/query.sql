{% macro calculate_total(quantity, unit_price) -%}
    (coalesce({{ quantity }}, 0) * coalesce({{ unit_price }}, 0))
{%- endmacro %}