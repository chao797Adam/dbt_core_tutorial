-- 找出重复的store_name
SELECT 
    store_name,
    COUNT(*) as duplicate_count
FROM {{ ref('bronze_store') }}
GROUP BY store_name
HAVING COUNT(*) > 1