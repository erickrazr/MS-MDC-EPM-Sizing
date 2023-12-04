# AWS - DCSPM and EPM Resource Count sizing Script 
<br />

### Disclaimer: Unofficial Tool

### AWS - Done

### GCP - WIP
<br />


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

License
This project is licensed under the **MIT License**.

<br />
<br />

#### Not Microsoft Endorsed or Affiliated

##### This MS-MDC-EPM-Sizing Script is an independent project and is not affiliated with, officially maintained, authorized, endorsed, or sponsored by Microsoft Corporation or any of its affiliates. Microsoft, AWS, and any associated names, trademarks, or logos are the property of their respective owners.

#### Purpose and Use
##### The purpose of this script is to assist in managing and enumerating resources in AWS environments for Microsoft Defender for CSPM and Entra Permissions Management. It is not intended to replace any official tools or services provided by Microsoft. Users should exercise caution and understand that the functionality and output of this script are not guaranteed to align with Microsoft's official tools

#### Liability
##### The authors and contributors of this script are not liable for any misuse, misinterpretation, or damage derived from its use. Users should use this script in compliance with all relevant laws, regulations, and cloud service agreements. 

#### Independent Development
##### This script was developed independently and should be used at the user's discretion. While the script interacts with services that may be monitored or secured by Microsoft tools, it is not a part of any Microsoft product or service suite.

#### Recommendations
##### Users are advised to verify the script's functionality in a non-production environment and ensure that its use aligns with their organizational policies and technical requirements before deploying it in a production environment.
