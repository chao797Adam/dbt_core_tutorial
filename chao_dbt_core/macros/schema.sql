{% macro generate_schema_name(custom_schema_name, node) -%}

    {#- 如果定义了 custom_schema_name，直接使用它 -#}
    {%- if custom_schema_name is not none -%}
        {{ custom_schema_name | trim }}
    
    {#- 如果没有定义，使用 target.schema -#}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}

{%- endmacro %}