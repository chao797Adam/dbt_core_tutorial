select category, gender, sum(gross_amount) as total_gross_amount
from {{ ref('silver_sales') }}
group by 1, 2
order by 1, 3 desc
