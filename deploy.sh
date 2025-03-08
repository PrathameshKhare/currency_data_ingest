#!/bin/bash

# Get the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set variables
REGION="ap-southeast-2"
PROJECT_NAME="currency_data_ingest"
LAMBDA_DIR="${SCRIPT_DIR}/src"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
LAYERS_DIR="${TERRAFORM_DIR}/layers/pandas"

# Clean up Terraform state
echo "🧹 Cleaning up Terraform state..."
cd "$TERRAFORM_DIR" || exit
rm -rf .terraform
rm -f .terraform.lock.hcl

# Create pandas layer
echo "Creating pandas layer..."
mkdir -p "$LAYERS_DIR/python"
cd "$LAYERS_DIR" || exit
pip install -r requirements.txt -t python/
cd python || exit
zip -r ../../pandas_layer.zip ./*
cd "$LAYERS_DIR" || exit
echo "Created pandas layer"

echo " Starting deployment of $PROJECT_NAME..."



# Check Terraform installation
if ! command -v terraform &> /dev/null; then
    echo -e "$ Terraform is not installed$"
    exit 1
fi

echo " Creating Lambda packages..."

# Create Lambda packages with lighter dependencies
echo " Creating Lambda packages..."
mkdir -p "${LAMBDA_DIR}/python_packages"
cd "${LAMBDA_DIR}" || exit
pip install -r requirements.txt --no-deps -t python_packages/

# Create main Lambda package
echo "Creating main Lambda package..."
rm -f "${TERRAFORM_DIR}/lambda_function.zip"
cd python_packages || exit
zip -r "${TERRAFORM_DIR}/lambda_function.zip" ./*
cd "${LAMBDA_DIR}" || exit
zip -g "${TERRAFORM_DIR}/lambda_function.zip" main.py requirements.txt
echo " Created main Lambda package"

# Create ETL Lambda package
echo "Creating ETL Lambda package..."
rm -f "${TERRAFORM_DIR}/etl_function.zip"
cd python_packages || exit
zip -r "${TERRAFORM_DIR}/etl_function.zip" ./*
cd "${LAMBDA_DIR}" || exit
zip -g "${TERRAFORM_DIR}/etl_function.zip" etl_processor.py requirements.txt
echo " Created ETL Lambda package"

# Cleanup
cd "${LAMBDA_DIR}" || exit
rm -rf python_packages

# Deploy with Terraform
cd "$TERRAFORM_DIR" || exit
echo "Initializing Terraform..."
terraform init

echo "Validating Terraform configuration..."
terraform validate

echo "Planning Terraform changes..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "Do you want to apply these changes? (y/N) "
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo " Applying Terraform changes..."
    terraform apply "tfplan"
    
    echo " Deployment outputs:"
    terraform output
else
    echo -e "$ Deployment cancelled$"
    exit 1
fi

echo -e "$ Deployment complete!$"