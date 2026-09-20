{{ config(materialized='view') }}

select id, name, category, updatedate
from
    (
        select *, row_number() over (partition by id order by updatedate desc) as rn
        from {{ source('source', 'items') }}
    )
where rn = 1
