select
    sales_id,
    payment_method,
    unit_price,
    quantity,
    {{ multiply('unit_price', 'quantity') }} as calculated_gross_amount,
    -- keep the original gross_amount for comparison
    gross_amount,
    product_sk,
    customer_sk
from {{ ref('bronze_sales') }}
