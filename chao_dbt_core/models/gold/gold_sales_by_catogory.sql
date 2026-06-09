with silver as (select * from {{ ref('silver_sales') }})
select
    category,
    round(sum(total_gross_amount), 2) as total_gross_amount,
    round(sum(total_calculated_gross_amount), 2) as total_calculated_gross_amount
from silver
group by category
order by total_gross_amount desc
