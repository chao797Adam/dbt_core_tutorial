{%- set apples = ["gala", "fuji", "pink lady", "honeycrisp", "granny smith"] -%}

{% for i in apples -%}
 {{ i }}
{% endfor %}