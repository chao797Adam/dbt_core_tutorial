-- find stores with invalid country values
select store_sk, store_name, country
from {{ ref('bronze_store') }}
where country not in ('USA', 'Canada') and country is not null
