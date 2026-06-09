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

    -- snapshot for item table
    select *
    from {{ source('source', 'item') }}

{% endsnapshot %}
