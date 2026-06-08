{% set var_name = "xc" -%}
select '{{ var_name }}' as var_test;

{% set var_name = "xc" -%}{{- var_name -}}