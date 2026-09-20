-- already defined in dbt_project.yml as table 
select * from {{ source('source', 'dim_customer') }}
