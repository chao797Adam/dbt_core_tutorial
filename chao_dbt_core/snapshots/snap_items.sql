{% snapshot snap_items %}

{{
    config(
      target_database=target.catalog,  
      target_schema='snapshots',
      unique_key='id',
      strategy='timestamp',
      updated_at='updateDate',
      dbt_valid_to_current="to_date('9999-12-31', 'yyyy-MM-dd')"
    )
}}

-- 这里直接 select 原始数据，千万不要去重！
-- 因为 SCD2 需要看到所有的历史变化，dbt 才会帮你对比哪些行变了
select * from {{ source('source', 'item') }}

{% endsnapshot %}