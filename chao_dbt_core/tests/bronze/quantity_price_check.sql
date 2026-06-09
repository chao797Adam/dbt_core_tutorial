-- find invalid quantities and unit prices
select sales_id, quantity, unit_price
from {{ ref('bronze_sales') }}
where quantity <= 0 or unit_price < 0 or quantity > 100
