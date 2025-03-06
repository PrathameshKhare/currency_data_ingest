#!/bin/bash

# Set error handling
set -e

echo " Starting Terraform Deployment Process..."

# Navigate to terraform directory
cd terraform

# Initialize Terraform
echo " Initializing Terraform..."
terraform init

# Format Terraform files
echo " Formatting Terraform files..."
terraform fmt

# Validate Terraform files
echo "Validating Terraform configuration..."
terraform validate

# Create terraform plan
echo " Creating Terraform plan..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "Do you want to apply the above plan? (y/n) " answer

if [ "$answer" == "y" ]; then
    echo " Applying Terraform plan..."
    terraform apply tfplan

    # Clean up the plan file
    rm tfplan

    echo " Deployment completed successfully!"
    
    # Display outputs
    echo " Resource Information:"
    terraform output
else
    echo " Deployment cancelled"
    rm tfplan
    exit 1
fi