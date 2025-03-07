CREATE EXTERNAL TABLE currency_rates (
    date STRING,
    timestamp TIMESTAMP,
    base_currency STRING,
    target_currency STRING,
    exchange_rate DOUBLE,
    hour INT
)
PARTITIONED BY (
    year INT,
    month INT,
    day INT
)
STORED AS PARQUET
LOCATION 's3://your-bucket-name/processed_data/'
TBLPROPERTIES ('parquet.compression'='SNAPPY');