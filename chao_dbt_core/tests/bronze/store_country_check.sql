-- 检查store表中是否有非法的国家代码
SELECT 
    store_sk,
    store_name,
    country
FROM {{ ref('bronze_store') }}
WHERE country NOT IN ('USA', 'Canada')
  AND country IS NOT NULL