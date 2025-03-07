# Glue Catalog Database
resource "aws_glue_catalog_database" "currency_db" {
  name = "currency_exchange_db"
  description = "Database for currency exchange rate data"
}

# Glue Catalog Table
resource "aws_glue_catalog_table" "currency_rates" {
  name          = "currency_rates"
  database_name = aws_glue_catalog_database.currency_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"        = "parquet"
    "parquet.compression"   = "SNAPPY"
    "EXTERNAL"             = "TRUE"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.currency_data_bucket.id}/processed_data/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    
    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "date"
      type = "string"
    }
    columns {
      name = "timestamp"
      type = "timestamp"
    }
    columns {
      name = "base_currency"
      type = "string"
    }
    columns {
      name = "target_currency"
      type = "string"
    }
    columns {
      name = "exchange_rate"
      type = "double"
    }
    columns {
      name = "hour"
      type = "int"
    }
  }

  partition_keys {
    name = "year"
    type = "int"
  }
  partition_keys {
    name = "month"
    type = "int"
  }
  partition_keys {
    name = "day"
    type = "int"
  }
}