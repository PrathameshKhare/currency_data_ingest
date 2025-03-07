# Currency Data Ingestion Process

## Architecture Overview

```
                     ┌─── Secrets Manager
                     ↓
EventBridge → Lambda → Fixer API
                     ↓
                    S3
```
### Flow Explanation:
1. EventBridge triggers the Lambda function hourly
2. Lambda retrieves API key from Secrets Manager
3. Lambda calls Fixer API with the retrieved credentials
4. Lambda stores the response data in S3

### Components
- **EventBridge**: Scheduled trigger (hourly)
- **Lambda**: Python 3.12 runtime, 128MB memory, 60s timeout
- **Secrets Manager**: Stores Fixer API credentials
- **S3**: Stores currency data in JSON format

## 1. API Selection:
We selected the **Fixer.io API** to fetch currency exchange rate data. Currently, we are using the **free version** of the API, which unfortunately comes with some limitations. One of the key restrictions is that the free plan allows us to only use **EURO (EUR)** as the base currency for comparison with others. Despite this limitation, we can still track the relative exchange rates for other currencies, with EURO serving as the standard.

## 2. Using AWS Lambda with EventBridge for Hourly Ingestion:
To process and ingest the currency data into AWS, we use **AWS Lambda** in conjunction with **AWS EventBridge**. This setup triggers the Lambda function every hour to fetch updated currency data and store it into an S3 bucket.

The cadence of **hourly execution** is chosen based on the fact that currency exchange rates typically refresh on an hourly basis. This allows us to capture and store the most up-to-date exchange rate data on an ongoing basis. EventBridge is configured to trigger the Lambda function automatically, ensuring that no manual intervention is required.

### Lambda Code:
The Lambda function is written in **Python**, leveraging the `requests` module to fetch the currency data from the Fixer API and `boto3` to interact with AWS services such as S3 and Secrets Manager. Here’s a brief breakdown of the process:
- **Fetch API Credentials**: The function retrieves the API key stored in AWS **Secrets Manager**.
- **Fetch Currency Data**: It then calls the Fixer API to retrieve the latest exchange rates.
- **Store Data in S3**: The fetched data is stored in an S3 bucket with a key that includes the current **date** (partitioned daily).
- **File Naming**: The S3 key is created using the current date in **YYYY-MM-DD** format, ensuring that files are stored in specific folders for each day. Files are named using the timestamp of the request (e.g., `currency_data/YYYY-MM-DD/HH-MM-SS_currencies.json`) to avoid overwriting previous data and keep each hourly file distinct.

### Lambda Configuration
Environment variables:
- `SECRET_NAME`: Points to AWS Secrets Manager secret (fixer_api_credentials)
- `S3_BUCKET_NAME`: Auto-populated from Terraform S3 bucket resource

### S3 Storage Structure
```plaintext
bucket-name/
├── currency_data/
│   ├── 2025-03-06/
│   │   ├── 10-00-00_currencies.json
│   │   ├── 11-00-00_currencies.json
│   │   └── ...
│   └── ...
```

## 3. Infrastructure as Code (IaC) Using Terraform:
We’ve used **Terraform** to define and provision the required AWS resources. The following files are part of the IaC setup:

- **`provider.tf`**: Configures the AWS provider for Terraform. It sets up the credentials and region for resource management.
- **`s3.tf`**: Defines the S3 bucket where the currency data will be stored. The bucket is configured to store partitioned data based on the current **date** (e.g., `year=YYYY/month=MM/day=DD`).
- **`lambda.tf`**: Configures the Lambda function resource. It specifies the function’s code location, the runtime (Python 3.12 in our case), and the necessary environment variables (e.g., the Secret Name and S3 Bucket Name). The Lambda function is triggered by EventBridge.
- **`eventbridge.tf`**: Sets up the EventBridge rule to trigger the Lambda function every hour. The rule defines the schedule for when the Lambda function is invoked, ensuring that currency data is ingested once every hour.
- **`iam.tf`**: Defines the IAM roles and policies needed for the Lambda function to interact with S3, Secrets Manager, and other AWS resources securely.
- **`outputs.tf`**: Outputs the key information about the deployed resources, such as the S3 bucket name and Lambda function ARN, for easy reference.
  
The Terraform configuration ensures that all AWS resources are deployed automatically and consistently, without requiring manual intervention.

## 4. Architecture Overview:
The architecture of the currency data ingestion process is as follows:

1. **Fixer API**: The source of currency data, specifically the exchange rates for various currencies (relative to EURO).
2. **AWS Lambda**: The service responsible for executing the data ingestion process. It is triggered every hour by **AWS EventBridge**, which calls the Lambda function to fetch the latest currency data from the API.
3. **AWS Secrets Manager**: Stores the API key securely. Lambda fetches this API key to authenticate requests to the Fixer API.
4. **AWS EventBridge**: Triggers the Lambda function on an hourly basis to ensure that currency data is ingested regularly.
5. **Amazon S3**: The destination where the ingested currency data is stored. Data is saved in **partitioned folders based on the current date** (e.g., `currency_data/YYYY-MM-DD/HH-MM-SS_currencies.json`), ensuring the data is organized by the day and hour of ingestion.

The Lambda function performs the following tasks:
- Fetches the API key from Secrets Manager.
- Retrieves the currency data from the Fixer API.
- Stores the data in an S3 bucket, using the current date and time to partition the files.

The entire infrastructure (Lambda, EventBridge, IAM roles, and S3 bucket) is managed using Terraform, ensuring that the resources are provisioned, updated, and maintained as code.

## 5. ETL Process and Analytics Setup

### ETL Pipeline
The ETL process transforms raw JSON currency data into analytics-ready Parquet format:

1. **Extract**: 
   - Triggered automatically when new data lands in S3
   - S3 event notification triggers ETL Lambda function
   - Raw JSON is read from `currency_data/{date}/` directory

2. **Transform**:
   - Flattens nested JSON structure
   - Converts to tabular format with columns:
     - date
     - timestamp
     - base_currency
     - target_currency
     - exchange_rate
     - hour
   - Adds partition columns (year, month, day)

3. **Structure of data**:
Each Parquet file would contain rows like this:
```
date       | timestamp           | base_currency | target_currency | exchange_rate | hour
-----------|--------------------|---------------|----------------|---------------|-----
2025-03-06 | 2025-03-06T00:00Z | EUR          | USD            | 1.08032      | 0
2025-03-06 | 2025-03-06T00:00Z | EUR          | GBP            | 0.85674      | 0
2025-03-06 | 2025-03-06T00:00Z | EUR          | JPY            | 161.234      | 0
```

4. **Load**:
   - Writes data as Parquet files
   - Partitioned structure:
   ```plaintext
        processed_data/
        ├── year=2025/
        │   ├── month=03/
        │   │   ├── day=06/
        │   │   │   ├── currency_rates_00.parquet  # Data from 00:00
        │   │   │   ├── currency_rates_01.parquet  # Data from 01:00
        │   │   │   ├── currency_rates_02.parquet  # Data from 02:00
        │   │   │   └── ...
        │   │   └── day=07/
        │   │       ├── currency_rates_00.parquet
        │   │       └── ...
        │   └── month=04/
        │       └── ...
   ```
### Infrastructure Components
- **ETL Lambda**: Processes raw data (`etl_processor.py`)
- **Glue Data Catalog**: Manages table schema
- **Athena**: Executes SQL queries
- **S3**: Stores both raw and processed data

## Summary:
- **Data Collection**:
  - Source: Fixer.io API (free version, limited to EURO base currency)
  - Frequency: Hourly data collection via EventBridge trigger
  - Initial Storage: Raw JSON in S3 (`currency_data/YYYY-MM-DD/HH-MM-SS_currencies.json`)

- **ETL Process**:
  - Trigger: S3 event-based processing
  - Transformation: JSON to Parquet conversion
  - Storage: Partitioned data structure (`processed_data/year=YYYY/month=MM/day=DD/`)
  - Format: Analytics-optimized Parquet files

- **Infrastructure**:
  - Primary Lambda: Data collection from Fixer API
  - ETL Lambda: Data transformation and partitioning
  - Storage: S3 for both raw and processed data
  - Security: Secrets Manager for API credentials
  - Analytics: AWS Athena for SQL querying
  - IaC: Terraform for all AWS resource provisioning

This approach ensures an efficient, automated, and scalable process for ingesting and storing currency data on a regular basis.
