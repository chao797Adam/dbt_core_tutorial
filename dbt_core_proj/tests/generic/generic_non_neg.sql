-- purpose: generic test to check if a column has negative values
{% test generic_non_neg(model, column_name) %}

    select * from {{ model }} where {{ column_name }} < 0

{% endtest %}
