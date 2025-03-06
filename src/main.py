from datetime import datetime, timezone
import json
import re
import boto3
import requests
from botocore.exceptions import ClientError
import os

# Initialize clients for AWS services
s3_client = boto3.client('s3')
secrets_manager_client = boto3.client('secretsmanager')

# Function to fetch API credentials from AWS Secrets Manager
def get_api_credentials():
    secret_name = os.environ['SECRET_NAME']  # Name of the secret stored in Secrets Manager
    try:
        secret_value = secrets_manager_client.get_secret_value(SecretId=secret_name)
        secret = secret_value['SecretString']
        return json.loads(secret)
    except ClientError as e:
        print(f"Error retrieving secret: {e}")
        raise e

# Function to fetch data from the Fixer API
def fetch_currency_data(api_url, api_key):
    url = api_url.format(PASTE_YOUR_API_KEY_HERE=api_key)
    
    response = requests.get(url)
    
    if response.status_code == 200:
        return response.json()
    else:
        raise Exception(f"Failed to fetch data. Status code: {response.status_code}")

# Function to process and store data in S3
def store_in_s3(data, bucket_name, s3_key):
    try:
        s3_client.put_object(
            Bucket=bucket_name,
            Key=s3_key,
            Body=json.dumps(data),
            ContentType='application/json'
        )
        print(f"Data successfully stored in S3 bucket {bucket_name} at key {s3_key}")
    except ClientError as e:
        print(f"Error storing data in S3: {e}")
        raise e

# Function to save data as a local JSON file
def save_as_json(data, file_name):
    # Sanitize the file name to remove invalid characters
    sanitized_file_name = re.sub(r'[\\/*?:"<>|]', "_", file_name)  # Replace invalid characters with underscores
    try:
        with open(sanitized_file_name, 'w') as json_file:
            json.dump(data, json_file, indent=4)
        print(f"Data successfully saved to {sanitized_file_name}")
    except Exception as e:
        print(f"Error saving data to file: {e}")
        raise e

# Lambda handler
def lambda_handler(event, context):
    # Generate current time in the desired format for file names
    event_time = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
    
    # Fetch the credentials from Secrets Manager
    secrets = get_api_credentials()
    api_key = secrets['api_key']
    # api_key = "secret" # For local testing only, replace with actual API key
    api_url = f'http://data.fixer.io/api/latest?access_key={api_key}'

    # Fetch data from the Fixer API
    data = fetch_currency_data(api_url, api_key)
    print(data)
    
    # Get the current date in YYYY-MM-DD format to create a folder for the day
    current_date = datetime.now().strftime('%Y-%m-%d')

    # Define the S3 bucket and key for storing the data
    bucket_name = os.environ['S3_BUCKET_NAME']
    s3_key = f"currency_data/{current_date}/{event_time}_currencies.json"
    
    # Store the data in S3
    store_in_s3(data, bucket_name, s3_key)
    
    # Save the data as a local JSON file (for testing purposes)
    local_file_name = f"currency_data_{event_time}.json"
    save_as_json(data, local_file_name)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Currency data ingestion successful')
    }

# Main function for running the script locally
if __name__ == "__main__":
    # Mock event and context for local execution
    event = {} 
    context = {}
    
    os.environ['SECRET_NAME'] = "fixer_api_credentials"  
    os.environ['S3_BUCKET_NAME'] = "your-s3-bucket-name" 
    
    lambda_handler(event, context)
