-- find duplicate store names
select store_name, count(*) as duplicate_count
from {{ ref('bronze_store') }}
group by store_name
having count(*) > 1
