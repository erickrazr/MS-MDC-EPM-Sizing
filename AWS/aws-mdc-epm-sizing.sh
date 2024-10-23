#!/bin/bash

#Script maintained by Erick Ferreira - github @erickrazr

# shellcheck disable=SC2102,SC2181,SC2207

if ! type "jq" > /dev/null; then
  echo "Error: jq not installed or not in execution path, jq is required for script execution."
  exit 1
fi

##########################################################################################
## Optionally query the AWS Organization by passing "org" as an argument.
##########################################################################################

if [ "${1}X" == "orgX" ] || [ "${2}X" == "orgX" ] || [ "${3}X" == "orgX" ]; then
   USE_AWS_ORG="true"
else
   USE_AWS_ORG="false"
fi

#### Use epm parameter to report EPM Sizing

if [ "${1}X" == "epmX" ] || [ "${2}X" = "epmX" ] || [ "${3}X" == "epmX" ]; then
   WITH_EPM="true"
else
   WITH_EPM="false"
fi



##########################################################################################
## Utility functions.
##########################################################################################

error_and_exit() {
  echo
  echo "ERROR: ${1}"
  echo
  exit 1
}

##########################################################################################
## AWS Utility functions.
##########################################################################################

aws_ec2_describe_regions() {
    aws ec2 describe-regions --output json 2>/dev/null || return 1
}

####

aws_organizations_describe_organization() {
    aws organizations describe-organization --output json 2>/dev/null || return 1
}

aws_organizations_list_accounts() {
    aws organizations list-accounts --output json 2>/dev/null || return 1
}

aws_sts_assume_role() {
 aws sts assume-role --role-arn="${1}" --role-session-name=pcs-sizing-script --duration-seconds=999 --output json 2>/dev/null || return 1
}

####### Begin --- Microsoft CSPM Premium Billable Resources  Methods #####

aws_ec2_describe_instances() {
  RESULT=$(aws ec2 describe-instances --max-items 99999 --region="${1}" --filters "Name=instance-state-name,Values=running" --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

aws_s3api_list_buckets() {
  RESULT=$(aws s3api list-buckets --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

aws_rds_describe_db_instances() {
  RESULT=$(aws rds describe-db-instances --max-items 99999 --region="${1}" --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

####### END --- Microsoft CSPM Premium Billable Resources  Methods #####


####### BEGIN --- Microsoft Entra Permissions Management Methods #####

aws_lambda_list_functions() {
  RESULT=$(aws lambda list-functions --region="${1}" --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

aws_dynamodb_list_tables() {
  RESULT=$(aws dynamodb list-tables --region="${1}" --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

aws_emr_list_clusters() {
  RESULT=$(aws emr list-clusters --region="${1}" --active --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

aws_kinesis_list_streams() {
  RESULT=$(aws kinesis list-streams --region="${1}" --active --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

aws_elasticache_describe_cache_clusters() {
  RESULT=$(aws elasticache describe-cache-clusters --region="${1}" --active --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

aws_ecs_list_clusters() {
  RESULT=$(aws ecs list-clusters --max-items 99999 --region="${1}" --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}

aws_eks_list_clusters() {
  RESULT=$(aws eks list-clusters --max-items 99999 --region="${1}" --output json --no-cli-pager 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "${RESULT}"
  else
    echo '{"Error": [] }'
  fi
}


####### End --- Microsoft Entra Permissions Management Methods #####


####

get_region_list() {
  echo "Querying AWS Regions"
  REGIONS=$(aws_ec2_describe_regions | jq -r '.Regions[] | .RegionName' 2>/dev/null | sort) || error_and_exit "Failed to get region list"
  REGION_LIST=($REGIONS)

  if [ ${#REGION_LIST[@]} -eq 0 ]; then
    error_and_exit "No regions found. Exiting."
  fi

  echo "Total number of regions: ${#REGION_LIST[@]}"
}

get_account_list() {
 if [ "$USE_AWS_ORG" = "true" ]; then
    echo "Querying AWS Organization"
    MASTER_ACCOUNT_ID=$(aws_organizations_describe_organization | jq -r '.Organization.MasterAccountId' 2>/dev/null) || error_and_exit "Failed to describe AWS Organization"
    MASTER_AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
    MASTER_AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
    MASTER_AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN

    ACCOUNT_LIST=$(aws_organizations_list_accounts) || error_and_exit "Failed to list AWS Organization accounts"
    TOTAL_ACCOUNTS=$(echo "${ACCOUNT_LIST}" | jq '.Accounts | length' 2>/dev/null)
    echo "Total number of member accounts: ${TOTAL_ACCOUNTS}"
  else
    MASTER_ACCOUNT_ID=""
    ACCOUNT_LIST=""
    TOTAL_ACCOUNTS=1
  fi
}

assume_role() {
  ACCOUNT_NAME="${1}"
  ACCOUNT_ID="${2}"
  echo "###################################################################################"
  echo "Processing Account: ${ACCOUNT_NAME} (${ACCOUNT_ID})"
  if [ "${ACCOUNT_ID}" = "${MASTER_ACCOUNT_ID}" ]; then
    echo "  Account is the master account, skipping assume role ..."

  ROLES=("OrganizationAccountAccessRole" "AWSControlTowerExecution")
  for ROLE in "${ROLES[@]}"; do
    ACCOUNT_ASSUME_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE}"
    SESSION_DATA=$(aws_sts_assume_role "${ACCOUNT_ASSUME_ROLE_ARN}")
    
    if [ $? -eq 0 ] && [ -n "${SESSION_DATA}" ]; then
      echo "  Successfully assumed role: ${ROLE}"

      # Exportar as credenciais da role assumida
      AWS_ACCESS_KEY_ID=$(echo "${SESSION_JSON}"     | jq .Credentials.AccessKeyId     2>/dev/null | sed -e 's/^"//' -e 's/"$//')
      AWS_SECRET_ACCESS_KEY=$(echo "${SESSION_JSON}" | jq .Credentials.SecretAccessKey 2>/dev/null | sed -e 's/^"//' -e 's/"$//')
      AWS_SESSION_TOKEN=$(echo "${SESSION_JSON}"     | jq .Credentials.SessionToken    2>/dev/null | sed -e 's/^"//' -e 's/"$//')
      export AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY
      export AWS_SESSION_TOKEN
    fi
  fi
  echo "###################################################################################"
  echo ""
}

##########################################################################################
# Unset environment variables used to assume role into the last member account.
##########################################################################################

unassume_role() {
  AWS_ACCESS_KEY_ID=$MASTER_AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY=$MASTER_AWS_SECRET_ACCESS_KEY
  AWS_SESSION_TOKEN=$MASTER_AWS_SESSION_TOKEN
}

##########################################################################################
## Set or reset counters.
##########################################################################################

reset_account_counters() {
  EC2_INSTANCE_COUNT=0
  RDS_INSTANCE_COUNT=0
  S3_BUCKETS_COUNT=0
  LAMBDA_COUNT=0
  EKS_CLUSTER_COUNT=0
  ECS_CLUSTER_COUNT=0
  DynamoDB_COUNT=0
  EMR_COUNT=0
  KINESIS_COUNT=0
  ELASTICACHE_COUNT=0
  S3_BUCKETS_COUNT=0
  
}

reset_global_counters() {
  EC2_INSTANCE_COUNT_GLOBAL=0
  RDS_INSTANCE_COUNT_GLOBAL=0
  S3_BUCKETS_COUNT_GLOBAL=0
  LAMBDA_COUNT_GLOBAL=0
  EKS_CLUSTER_COUNT_GLOBAL=0
  ECS_CLUSTER_COUNT_GLOBAL=0
  DynamoDB_COUNT_GLOBAL=0
  EMR_COUNT_GLOBAL=0
  KINESIS_COUNT_GLOBAL=0
  ELASTICACHE_COUNT_GLOBAL=0

}

##########################################################################################
## Iterate through the (or each member) account, region, and billable resource type.
##########################################################################################

count_account_resources() {

  for ((ACCOUNT_INDEX=0; ACCOUNT_INDEX<=(TOTAL_ACCOUNTS-1); ACCOUNT_INDEX++))
  do
    if [ "${USE_AWS_ORG}" = "true" ]; then
      ACCOUNT_NAME=$(echo "${ACCOUNT_LIST}" | jq -r .Accounts["${ACCOUNT_INDEX}"].Name 2>/dev/null)
      ACCOUNT_ID=$(echo "${ACCOUNT_LIST}"   | jq -r .Accounts["${ACCOUNT_INDEX}"].Id   2>/dev/null)
      ASSUME_ROLE_ERROR=""
      assume_role "${ACCOUNT_NAME}" "${ACCOUNT_ID}"
      if [ -n "${ASSUME_ROLE_ERROR}" ]; then
        continue
      fi
    fi

    echo "###################################################################################"
    echo "Running EC2 Instances"
    for i in "${REGION_LIST[@]}"
    do
      RESOURCE_COUNT=$(aws_ec2_describe_instances "${i}" | jq '[ .Reservations[].Instances[] ] | length' 2>/dev/null)
      echo " EC2 Instances Running in Region ${i}: ${RESOURCE_COUNT}"
      EC2_INSTANCE_COUNT=$((EC2_INSTANCE_COUNT + RESOURCE_COUNT))
    done
    echo "Total EC2 Instances Running - all regions: ${EC2_INSTANCE_COUNT}"
    echo "###################################################################################"
    echo ""

    echo "###################################################################################"
    echo "RDS Instances"
    for i in "${REGION_LIST[@]}"
    do
      RESOURCE_COUNT=$(aws_rds_describe_db_instances "${i}" | jq '.[] | length' 2>/dev/null)
      echo "  RDS Instances in Region ${i}: ${RESOURCE_COUNT}"
      RDS_INSTANCE_COUNT=$((RDS_INSTANCE_COUNT + RESOURCE_COUNT))
    done
    echo "Total RDS Instances - all regions: ${RDS_INSTANCE_COUNT}"
    echo "###################################################################################"
    echo ""

    echo "###################################################################################"
    echo "S3 Buckets on all Regions"
    S3_BUCKETS_COUNT=$(aws_s3api_list_buckets | jq '.Buckets | length')
    echo "Total S3 Buckets - all regions: ${S3_BUCKETS_COUNT}"
    echo "###################################################################################"
    echo ""

    if [ "${WITH_EPM}" = "true" ]; then

      echo "###################################################################################"
      echo "Lambda Functions"
      for i in "${REGION_LIST[@]}"
      do
        RESOURCE_COUNT=$(aws_lambda_list_functions "${i}" | jq -r '.Functions | length' 2>/dev/null)
        echo " Lambda Functions in Region ${i}: ${RESOURCE_COUNT}"
        LAMBDA_COUNT=$((LAMBDA_COUNT + RESOURCE_COUNT))
      done
      echo "Total Lambda Functions - all regions: ${LAMBDA_COUNT}"
      echo "###################################################################################"
      echo ""

      echo "###################################################################################"
      echo "EKS Clusters"
      for i in "${REGION_LIST[@]}"
      do
        RESOURCE_COUNT=$(aws_eks_list_clusters "${i}" | jq -r '.Clusters | length')
        echo "  EKS Cluster in Region ${i}: ${RESOURCE_COUNT}"
        EKS_CLUSTER_COUNT=$((EKS_CLUSTER_COUNT + RESOURCE_COUNT))
      done
      echo "Total EKS Cluster - all regions: ${EKS_CLUSTER_COUNT}"
      echo "###################################################################################"
      echo ""

      echo "###################################################################################"
      echo "ECS Clusters"
      for i in "${REGION_LIST[@]}"
      do
        RESOURCE_COUNT=$(aws_ecs_list_clusters "${i}" | jq -r '.clusterArns | length')
        echo "  ECS Cluster in Region ${i}: ${RESOURCE_COUNT}"
        ECS_CLUSTER_COUNT=$((ECS_CLUSTER_COUNT + RESOURCE_COUNT))
      done
      echo "Total ECS Cluster - all regions: ${ECS_CLUSTER_COUNT}"
      echo "###################################################################################"
      echo ""

      echo "###################################################################################"
      echo "DynamoDB Tables"
      for i in "${REGION_LIST[@]}"
      do
        RESOURCE_COUNT=$(aws_dynamodb_list_tables "${i}" |  jq -r '.TableNames | length')
        echo "  DynamoDB Tables in Region ${i}: ${RESOURCE_COUNT}"
        DynamoDB_COUNT=$((DynamoDB_COUNT + RESOURCE_COUNT))
      done
      echo "Total DynamoDB Tables - all regions: ${DynamoDB_COUNT}"
      echo "###################################################################################"
      echo ""

      echo "###################################################################################"
      echo "Elastic MapReduce"
      for i in "${REGION_LIST[@]}"
      do
        RESOURCE_COUNT=$(aws_emr_list_clusters "${i}" |  jq -r '.Clusters | length')
        echo "  Elastic MapReduce in Region ${i}: ${RESOURCE_COUNT}"
        EMR_COUNT=$((EMR_COUNT + RESOURCE_COUNT))
      done
      echo "Total Elastic MapReduce - all regions: ${EMR_COUNT}"
      echo "###################################################################################"
      echo ""

      echo "###################################################################################"
      echo "Kinesis"
      for i in "${REGION_LIST[@]}"
      do
        RESOURCE_COUNT=$(aws_kinesis_list_streams "${i}" |  jq -r '.Clusters | length')
        echo "   Kinesis streams in Region ${i}: ${RESOURCE_COUNT}"
        KINESIS_COUNT=$((KINESIS_COUNT + RESOURCE_COUNT))
      done
      echo "Total Kinesis Streams - all regions: ${KINESIS_COUNT}"
      echo "###################################################################################"
      echo ""

      echo "###################################################################################"
      echo "Elasticache Clusters"
      for i in "${REGION_LIST[@]}"
      do
        RESOURCE_COUNT=$(aws_elasticache_describe_cache_clusters "${i}" |  jq -r '.Clusters | length')
        echo "   Elasticache Clusters in Region ${i}: ${RESOURCE_COUNT}"
        ELASTICACHE_COUNT=$((ELASTICACHE_COUNT + RESOURCE_COUNT))
      done
      echo "Total Elasticache Clusters - all regions: ${ELASTICACHE_COUNT}"
      echo "###################################################################################"
      echo ""

    fi


    EC2_INSTANCE_COUNT_GLOBAL=$((EC2_INSTANCE_COUNT_GLOBAL + EC2_INSTANCE_COUNT))
    RDS_INSTANCE_COUNT_GLOBAL=$((RDS_INSTANCE_COUNT_GLOBAL + RDS_INSTANCE_COUNT))
    S3_BUCKETS_COUNT_GLOBAL=$((S3_BUCKETS_COUNT_GLOBAL + S3_BUCKETS_COUNT))
    LAMBDA_COUNT_GLOBAL=$((LAMBDA_COUNT_GLOBAL + LAMBDA_COUNT))
    EKS_CLUSTER_COUNT_GLOBAL=$((EKS_CLUSTER_COUNT_GLOBAL + EKS_CLUSTER_COUNT))
    ECS_CLUSTER_COUNT_GLOBAL=$((ECS_CLUSTER_COUNT_GLOBAL + ECS_CLUSTER_COUNT))
    DynamoDB_COUNT_GLOBAL=$((DynamoDB_COUNT_GLOBAL + DynamoDB_COUNT))
    EMR_COUNT_GLOBAL=$((EMR_COUNT_GLOBAL + EMR_COUNT))
    KINESIS_COUNT_GLOBAL=$((KINESIS_COUNT_GLOBAL + KINESIS_COUNT))
    ELASTICACHE_COUNT_GLOBAL=$((ELASTICACHE_COUNT_GLOBAL + ELASTICACHE_COUNT))

    reset_account_counters

    if [ "${USE_AWS_ORG}" = "true" ]; then
      unassume_role
    fi
  done

  
  EPM_COUNT_GLOBAL=$((EC2_INSTANCE_COUNT_GLOBAL + RDS_INSTANCE_COUNT_GLOBAL + LAMBDA_COUNT_GLOBAL + EKS_CLUSTER_COUNT_GLOBAL + ECS_CLUSTER_COUNT_GLOBAL + DynamoDB_COUNT_GLOBAL + EMR_COUNT_GLOBAL + ELASTICACHE_COUNT_GLOBAL + KINESIS_COUNT_GLOBAL + S3_BUCKETS_COUNT_GLOBAL))
  DCSPM_COUNT_GLOBAL=$((EC2_INSTANCE_COUNT_GLOBAL + RDS_INSTANCE_COUNT_GLOBAL + S3_BUCKETS_COUNT_GLOBAL))
  
  echo "###################################################################################"
  echo "List of Microsoft Defender CSPM Billable Resources:"
  echo "  Total EC2 Instances:     ${EC2_INSTANCE_COUNT_GLOBAL}"
  echo "  Total RDS Instances:     ${RDS_INSTANCE_COUNT_GLOBAL}"
  echo "  Total S3 Buckets:        ${S3_BUCKETS_COUNT_GLOBAL}"
  echo ""
  echo "Total DCSPM Resources:   ${DCSPM_COUNT_GLOBAL}"
  echo ""
  echo "###################################################################################"

  if [ "${WITH_EPM}" = "true" ]; then
    LAMBDA_CREDIT_USAGE_GLOBAL=$((LAMBDA_COUNT_GLOBAL))
    COMPUTE_CREDIT_USAGE_GLOBAL=$((LAMBDA_CREDIT_USAGE_GLOBAL))
    echo ""
    echo "###################################################################################"
    echo "EPM Billable Resources:"
    echo "  Total EC2 Instances: ${EC2_INSTANCE_COUNT_GLOBAL}"
    echo "  Total RDS Instances: ${RDS_INSTANCE_COUNT_GLOBAL}"
    echo "  Total S3 Buckets: ${S3_BUCKETS_COUNT_GLOBAL}"
    echo "  Total Lambda Functions: ${LAMBDA_COUNT_GLOBAL}"
    echo "  Total EKS Cluster: ${EKS_CLUSTER_COUNT_GLOBAL}"
    echo "  Total ECS Clusters: ${ECS_CLUSTER_COUNT_GLOBAL}"
    echo "  Total DynamoDB Tables: ${DynamoDB_COUNT_GLOBAL}"
    echo "  Total Elastic MapReduce(EMR): ${EMR_COUNT_GLOBAL}"
    echo "  Total Amazon Kinesis: ${KINESIS_COUNT_GLOBAL}"
    echo "  Total ElastiCache: ${ELASTICACHE_COUNT_GLOBAL}"
    echo ""
    echo "Total EPM Resources:   ${EPM_COUNT_GLOBAL}"
    echo ""
    echo "###################################################################################"
  fi


  echo ""
  echo "The script outputs the count of various resources in the AWS environment, giving a detailed view of the resources in each region and account. The totals are based on resource counts at the time of script execution."

}

##########################################################################################
# Allow shellspec to source this script.
##########################################################################################

${__SOURCED__:+return}

##########################################################################################
# Main.
##########################################################################################

get_account_list
get_region_list
reset_account_counters
reset_global_counters
count_account_resources
