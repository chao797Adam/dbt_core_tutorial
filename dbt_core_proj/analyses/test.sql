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
    bronze_products as (select * from {{ ref('bronze_product') }}),
    bronze_customers as (select * from {{ ref('bronze_customer') }}),
    joined_query as (
        select
            s.sales_id,
            s.payment_method,
            s.gross_amount,
            s.calculated_gross_amount,

            p.product_code,
            p.product_name,
            p.department,
            p.category,
            p.supplier_sk,
            p.list_price,
            p.uom,

            c.gender,
            c.customer_code,
            c.first_name,
            c.last_name,
            c.email,
            c.phone,
            c.loyalty_tier,
            c.signup_date
        from sales s
        left join bronze_products p on s.product_sk = p.product_sk
        left join bronze_customers c on s.customer_sk = c.customer_sk
    )
select *
from joined_query
