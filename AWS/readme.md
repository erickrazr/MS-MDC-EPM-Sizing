# AWS - DCSPM and EPM Resource Count sizing Script 

## Overview
This Bash script enumerates various AWS resources across regions and accounts within an AWS Organization. It's particularly useful for getting a comprehensive view of resource utilization for billing and management purposes. The script counts resources like EC2 instances, RDS instances, Lambda functions, EKS clusters, and more.

## Prerequisites
- **jq**: The script requires jq for JSON processing. Ensure it's installed and in your execution path.
- **AWS CLI**: The AWS CLI should be properly configured with the necessary permissions.
- **Bash Environment**: The script is intended for use in a bash environment.

## Usage
To use the script, run it in your bash shell with optional arguments:

```bash
./aws_resource_counting_script.sh [org] [epm]
```

- `org`: Include to query AWS Organizations.
- `epm`: Include to report on EPM Sizing


## Features
- **AWS Organization Querying**: Optionally queries the AWS Organization.
- **EPM Sizing Reporting**: Optional EPM Sizing reporting.
- **Utility Functions**: Includes functions for error handling and AWS resource descriptions.
- **Resource Counting**: Iterates through accounts and regions, counting AWS resources.

## AWS Utility Functions
Contains various functions for interacting with AWS services like EC2, RDS, Lambda, and others.

## Microsoft CSPM and Entra Permissions Management
Includes methods for describing and listing resources relevant to Microsoft CSPM Premium Billable Resources and Entra Permissions Management.

## Output
Provides a summary of resource counts in the AWS environment.

## Note
This script is for informational purposes and should be used according to your AWS environment and policies.

## Contact
For queries or issues, open an issue on the GitHub repository.

