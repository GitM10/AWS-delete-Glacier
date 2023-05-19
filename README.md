# AWS-remove-Glacier

It is a bash script FOR MAC OS that interacts with the AWS Command Line Interface (CLI) to perform operations on an AWS Glacier vault.
Please note that this script assumes it is running on a macOS system, and it requires the AWS CLI to be already installed and properly configured with the necessary credentials.

Description of the script:

- The script checks if the necessary dependencies, such as jq and the AWS CLI, are installed, if not try to install them using homebrew or mac port.
- It prompts the user to enter the AWS Region, AWS Account ID, and the name of the Glacier vault.
- The script verifies the existence of the vault.
- If jq is not installed, it offers to install it using either Homebrew or MacPorts.
- The script asks the user if they have a Job ID. If they do, it prompts for the Job ID; otherwise, it initiates an inventory retrieval job and extracts the Job ID from the output.
- It checks the status of the job and displays it.
- If the job is in progress, it displays a note stating that the inventory retrieval job may take hours or days to complete, and suggests not stopping the script if there are only a few archives. Otherwise, it advises to save the Job ID for future use.
- The script waits for the job to complete.
- Once the job is completed, it checks if it succeeded or failed and displays the status accordingly.
- It downloads the job output to a file named "output.json".
- It extracts the Archive IDs from the job output.
- It deletes each archive from the vault by iterating over the Archive IDs and calling the aws glacier delete-archive command.
- Finally, it displays a message indicating that all archives have been deleted.


