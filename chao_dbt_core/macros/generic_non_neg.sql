{% test generic_non_neg(model, column_name) %}

    select *
    from {{ model }}
    where {{ column_name }} < 0

{% endtest %}