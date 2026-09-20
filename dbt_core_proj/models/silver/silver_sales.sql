with
    sales as (
        select *, {{ multiply('unit_price', 'quantity') }} as calculated_gross_amount
        -- keep the original gross_amount for comparison
        from {{ ref('bronze_sales') }}
    ),
    bronze_products as (select * from {{ ref('bronze_product') }}),
    bronze_customers as (select * from {{ ref('bronze_customer') }}),
    bronze_date as (select * from {{ ref('bronze_date') }}),
    bronze_store as (select * from {{ ref('bronze_store') }}),
    joined_query as (
        select
            s.sales_id,
            s.quantity,
            s.unit_price,
            s.gross_amount,
            s.calculated_gross_amount,
            s.discount_amount,
            s.net_amount,
            s.payment_method,

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
            c.signup_date,

            d.date,
            d.year,
            d.quarter,
            d.month,
            d.month_name,
            d.day,
            d.day_name,
            d.day_of_week,

            st.store_code,
            st.store_name,
            st.city,
            st.state_province,
            st.region,
            st.country,
            st.open_date,
            st.sq_ft

        from sales s
        left join bronze_products p on s.product_sk = p.product_sk
        left join bronze_customers c on s.customer_sk = c.customer_sk
        left join bronze_date d on s.date_sk = d.date_sk
        left join bronze_store st on s.store_sk = st.store_sk
    )
select *
from joined_query
