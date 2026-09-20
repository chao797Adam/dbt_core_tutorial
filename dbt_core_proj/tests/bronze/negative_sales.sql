-- find negative sales
select sales_id, gross_amount
from {{ ref('bronze_sales') }}
where gross_amount < 0 and net_amount < 0
