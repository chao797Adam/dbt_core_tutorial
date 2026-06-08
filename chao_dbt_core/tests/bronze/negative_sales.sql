-- 找出销售额为负的记录
SELECT 
    sales_id,
    gross_amount
FROM {{ ref('bronze_sales') }}
WHERE gross_amount < 0 
and
 net_amount < 0