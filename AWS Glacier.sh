#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to install jq using Homebrew
install_jq_with_brew() {
  echo "Installing jq using Homebrew..."
  brew install jq
}

# Function to install jq using MacPorts
install_jq_with_macports() {
  echo "Installing jq using MacPorts..."
  sudo port install jq
}

# Function to check if jq is installed
check_jq_installed() {
  if ! command -v jq &> /dev/null; then
    return 1
  fi
}

# Function to check if the AWS CLI is installed
check_aws_cli_installed() {
  if ! command -v aws &> /dev/null; then
    return 1
  fi
}

# Function to check if the AWS CLI is properly configured
check_aws_cli_configured() {
  aws sts get-caller-identity &> /dev/null
}

# Function to check if the vault exists
check_vault_exists() {
  aws glacier describe-vault --vault-name "$1" --account-id "$2" --region "$3" &> /dev/null
}

# Function to validate AWS Account ID
validate_aws_account_id() {
  local account_id_regex="^[0-9]{12}$"
  if ! [[ $1 =~ $account_id_regex ]]; then
    return 1
  fi
}

# Disclaimer
echo -e "${RED}DISCLAIMER: Please ensure that the AWS CLI is already installed and configured with the appropriate credentials.${NC}"
echo -e "${RED}This script assumes that the AWS CLI is properly installed and configured before proceeding.${NC}"
echo -e "${RED}If you have not installed or configured the AWS CLI, please do so before running this script.${NC}"
echo -e "${RED}THIS BASH SCRIPT IS WRITTEN FOR MAC OS.${NC}"
echo -e "${RED} ${NC}"
echo -e "${RED}Press Enter to continue, or Ctrl+C to abort.${NC}"
read

# Check if the AWS CLI is installed
if ! check_aws_cli_installed; then
  echo -e "${RED}Error: AWS CLI is not installed.${NC}"
  exit 1
fi

# Check if the AWS CLI is configured
if ! check_aws_cli_configured; then
  echo -e "${RED}Error: AWS CLI is not properly configured.${NC}"
  exit 1
fi

# Prompt the user for the necessary information
read -p "Enter the AWS Region (default: eu-central-1): " aws_region
aws_region=${aws_region:-eu-central-1} # Set default value to "eu-central-1"

while true; do
  read -p "Enter the AWS Account ID: " aws_account_id
  if validate_aws_account_id "$aws_account_id"; then
    break
  else
    echo -e "${RED}Error: Invalid AWS Account ID. Please enter a valid 12-digit AWS Account ID.${NC}"
  fi
done

read -p "Enter the name of the vault: " vault_name

# Check if the vault exists
if check_vault_exists "$vault_name" "$aws_account_id" "$aws_region"; then
  echo -e "${GREEN}Vault found.${NC}"
else
  echo -e "${RED}Error: Vault not found.${NC}"
  exit 1
fi

# Function to install jq if not installed
install_jq_if_not_installed() {
  if ! check_jq_installed; then
    echo "jq is not installed. Installing..."
    # Check if Homebrew is installed
    if command -v brew &> /dev/null; then
      install_jq_with_brew
    # Check if MacPorts is installed
    elif command -v port &> /dev/null; then
      install_jq_with_macports
    else
      echo "Neither Homebrew nor MacPorts found. Please install jq manually."
      exit 1
    fi

    # Verify if jq is installed after installation
    if ! check_jq_installed; then
      echo "jq installation failed. Please install jq manually."
      exit 1
    fi
  fi
}

# Install jq if not installed
install_jq_if_not_installed

# Prompt the user if they have a job ID
read -p "Do you have a Job ID? (yes/no) [if it's the first time you launch the script type no]: " has_job_id

if [[ "$has_job_id" == "yes" ]]; then
  read -p "Enter the Job ID: " job_id
else
  # Initiate the inventory retrieval job
  initiate_job_output=$(aws glacier initiate-job --vault-name "$vault_name" --account-id "$aws_account_id" --job-parameters '{"Type":"inventory-retrieval"}' --region "$aws_region")

  # Extract the Job ID from the initiate job output
  job_id=$(echo "$initiate_job_output" | jq -r '.jobId')
  echo "Inventory retrieval job initiated with Job ID: $job_id"
fi

# Function to get the job status
get_job_status() {
  job_status_output=$(aws glacier describe-job --vault-name "$vault_name" --account-id "$aws_account_id" --job-id "$job_id" --region "$aws_region")
  echo "$job_status_output" | jq -r '.StatusCode'
}

# Check the status of the job
job_status=$(get_job_status)
echo -e "Job Status: ${ORANGE}$job_status${NC}"

# Check if the job is in progress and display the note
if [[ "$job_status" == "InProgress" ]]; then
  echo -e "${YELLOW}NOTE: The inventory retrieval job may take hours or days to complete, depending on the number of archives in the vault.${NC}"
  echo -e "${YELLOW}Only if you have a few archives, don't stop the script, otherwise SAVE the job ID, and when you rerun the script and are asked if you have the job ID, respond yes and proceed.${NC}"
  echo -e "${YELLOW}The job has been launched on AWS${NC}"
fi

# Wait for the job to complete
while [[ "$job_status" != "Succeeded" && "$job_status" != "Failed" ]]; do
  sleep 59
  job_status=$(get_job_status)
done

# Check if the job succeeded or failed and display the status in the respective color
if [[ "$job_status" == "Succeeded" ]]; then
  echo -e "${GREEN}Job completed successfully.${NC}"
else
  echo -e "${RED}Job failed.${NC}"
  exit 1
fi

# Download the job output
aws glacier get-job-output --vault-name "$vault_name" --account-id "$aws_account_id" --job-id "$job_id" "output.json" --region "$aws_region"
echo "Job output downloaded to output.json"

# Extract the Archive IDs from the job output
archive_ids=$(jq -r '.ArchiveList[].ArchiveId' "output.json")

# Delete each archive from the vault
for archive_id in $archive_ids; do
  echo "Deleting archive with ID: $archive_id"
  aws glacier delete-archive --vault-name "$vault_name" --account-id "$aws_account_id" --archive-id "$archive_id" --region "$aws_region"
done

echo "All archives deleted. Now wait a few hours. Then delete the AWS Glacier from the AWS console and it's done."


