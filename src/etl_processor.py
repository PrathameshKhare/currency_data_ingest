import boto3
import json
import pandas as pd
from datetime import datetime
import pytz
from typing import Dict, Any
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def read_from_s3(s3_client, bucket: str, key: str) -> Dict:
    """Read JSON data from S3"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        return json.loads(response['Body'].read().decode('utf-8'))
    except Exception as e:
        logger.error(f"Error reading from S3: {str(e)}")
        raise

def transform_to_dataframe(data: Dict) -> pd.DataFrame:
    """Transform currency JSON data into a pandas DataFrame"""
    try:
        # Extract metadata
        base_currency = data['base']
        timestamp = datetime.fromtimestamp(data['timestamp'], tz=pytz.UTC)
        date = data['date']
        
        # Transform rates into rows
        currency_rows = [
            {
                'date': date,
                'timestamp': timestamp.isoformat(),
                'base_currency': base_currency,
                'target_currency': currency,
                'exchange_rate': rate,
                'year': timestamp.year,
                'month': timestamp.month,
                'day': timestamp.day,
                'hour': timestamp.hour
            }
            for currency, rate in data['rates'].items()
        ]
        
        return pd.DataFrame(currency_rows)
    
    except Exception as e:
        logger.error(f"Error transforming data: {str(e)}")
        raise

def write_partitioned_parquet(df: pd.DataFrame, s3_client, bucket: str) -> list:
    """Write DataFrame to partitioned Parquet files in S3"""
    processed_files = []
    
    try:
        # Group by partition columns and write Parquet files
        for (year, month, day), group in df.groupby(['year', 'month', 'day']):
            # Define partitioned path
            target_key = (
                f"processed_data/year={year}/month={month:02d}/"
                f"day={day:02d}/currency_rates_{group['hour'].iloc[0]:02d}.parquet"
            )
            
            # Convert to Parquet format
            parquet_buffer = group.to_parquet()
            
            # Upload to S3
            s3_client.put_object(
                Bucket=bucket,
                Key=target_key,
                Body=parquet_buffer,
                ContentType='application/x-parquet'
            )
            
            processed_files.append(target_key)
            logger.info(f"Written Parquet file: {target_key}")
        
        return processed_files
    
    except Exception as e:
        logger.error(f"Error writing Parquet files: {str(e)}")
        raise

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler that converts raw JSON currency data to partitioned Parquet files.
    Triggered by S3 events when new currency data is uploaded.
    """
    try:
        # Initialize S3 client
        s3_client = boto3.client('s3')
        
        # Get source file details from S3 event
        source_bucket = event['Records'][0]['s3']['bucket']['name']
        source_key = event['Records'][0]['s3']['object']['key']
        
        logger.info(f"Processing file: {source_key} from bucket: {source_bucket}")
        
        # Read source JSON file
        raw_data = read_from_s3(s3_client, source_bucket, source_key)
        
        # Transform data to DataFrame
        df = transform_to_dataframe(raw_data)
        
        # Write partitioned Parquet files
        processed_files = write_partitioned_parquet(df, s3_client, source_bucket)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Currency data ETL completed successfully',
                'source_file': source_key,
                'records_processed': len(df),
                'files_created': processed_files
            })
        }
    
    except Exception as e:
        logger.error(f"ETL process failed: {str(e)}")
        raise