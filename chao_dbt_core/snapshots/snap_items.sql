{% snapshot snap_items %}
    {{
        config(
          target_database=target.catalog,  
          target_schema='snapshots',
          unique_key='id',
          strategy='check',
          check_cols=['name', 'category'],
          dbt_valid_to_current="to_date('9999-12-31', 'yyyy-MM-dd')"
        )
    }}

    select id, name, category, updatedate
    from
        (
            select *, row_number() over (partition by id order by updatedate desc) as rn
            from {{ source('source', 'item') }}
        )
    where rn = 1

{% endsnapshot %}
