{%- set apples = ["gala", "fuji", "pink lady", "honeycrisp", "granny smith"] -%}

{% for i in apples -%}
    {%- if i != "fuji" -%}
        {{ i }}  
    {%- else -%}
        I hate {{ i }}
    {%- endif %}
{% endfor %}