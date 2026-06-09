with
    sales as (
        select
            sales_id,
            payment_method,
            {{ multiply('unit_price', 'quantity') }} as calculated_gross_amount,
            -- keep the original gross_amount for comparison
            gross_amount,
            product_sk,
            customer_sk
        from {{ ref('bronze_sales') }}
    ),
    bronze_products as (select product_sk, category from {{ ref('bronze_product') }}),
    bronze_customers as (select customer_sk, gender from {{ ref('bronze_customer') }}),
    joined_query as (
        select
            s.sales_id,
            s.payment_method,
            s.gross_amount,
            s.calculated_gross_amount,
            p.category,
            c.gender
        from sales s
        left join bronze_products p on s.product_sk = p.product_sk
        left join bronze_customers c on s.customer_sk = c.customer_sk
    )
select
    category,
    gender,
    round(sum(gross_amount), 2) as total_gross_amount,
    round(sum(calculated_gross_amount), 2) as total_calculated_gross_amount
from joined_query
group by category, gender
order by total_gross_amount desc
