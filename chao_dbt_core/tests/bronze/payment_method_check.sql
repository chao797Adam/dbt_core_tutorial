-- 检查支付方式是否在允许的范围内
SELECT 
    sales_id,
    payment_method
FROM {{ ref('bronze_sales') }}
WHERE payment_method NOT IN ('Digital Wallet', 'Cash', 'Card', 'Gift Card')
   OR payment_method IS NULL