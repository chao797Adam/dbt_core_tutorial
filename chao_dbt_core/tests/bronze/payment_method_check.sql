-- find invalid payment methods
select sales_id, payment_method
from {{ ref('bronze_sales') }}
where
    payment_method not in ('Digital Wallet', 'Cash', 'Card', 'Gift Card')
    or payment_method is null
