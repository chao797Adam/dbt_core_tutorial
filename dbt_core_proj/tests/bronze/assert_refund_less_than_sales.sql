-- tests/assert_refund_less_than_sales.sql
with
    returns as (
        select sales_id, sum(refund_amount) as total_refund
        from {{ ref('bronze_returns') }}
        group by 1
    ),

    sales as (select sales_id, gross_amount from {{ ref('bronze_sales') }})

select r.sales_id, r.total_refund, s.gross_amount
from returns r
join sales s on r.sales_id = s.sales_id
where round(r.total_refund, 2) > round(s.gross_amount, 2)
