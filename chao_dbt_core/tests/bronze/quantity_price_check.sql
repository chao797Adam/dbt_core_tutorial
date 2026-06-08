-- 检查数量和单价是否合理
SELECT 
    sales_id,
    quantity,
    unit_price
FROM {{ ref('bronze_sales') }}
WHERE quantity <= 0  -- 数量不能为0或负
   OR unit_price < 0  -- 单价不能为负
   OR quantity > 100  -- 单次购买数量不能太大（业务规则）