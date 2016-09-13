#!/bin/bash

# Prowler is a tool that provides automate auditing and hardening guidance of an AWS account.
# It is based on AWS-CLI commands. It follows guidelines present in the CIS Amazon
# Web Services Foundations Benchmark at:
# https://d0.awsstatic.com/whitepapers/compliance/AWS_CIS_Foundations_Benchmark.pdf

# This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0
# International Public License. The link to the license terms can be found at
# https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
#
# Author: Toni de la Fuente - @ToniBlyx / Alfresco Software Inc.

# Prowler - Iron Maiden
#
# Walking through the city, looking oh so pretty
# I've just got to find my way
# See the ladies flashing
# All there legs and lashes
# I've just got to find my way...

# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
# set -ue
# set -o pipefail
# set -vx

# Exits if any error is found
#set -e

# Colors
NORMAL="[0;39m"
WARNING="[1;33m"          # Bad (red)
SECTION="[1;33m"          # Section (yellow)
NOTICE="[1;33m"           # Notice (yellow)
OK="[1;32m"               # Ok (green)
BAD="[1;31m"              # Bad (red)
CYAN="[0;36m"
BLUE="[0;34m"
BROWN="[0;33m"
DARKGRAY="[0;30m"
GRAY="[0;37m"
GREEN="[1;32m"
MAGENTA="[1;35m"
PURPLE="[0;35m"
RED="[1;31m"
YELLOW="[1;33m"
WHITE="[1;37m"

DEFULT_AWS_PROFILE="default"
DEFAULT_AWS_REGION="us-east-1"

# Command usage menu
usage(){
  echo -e "\nUSAGE:
      `basename $0` -p <profile> -r <region> [ -v ] [ -h ]
  Options:
      -p <profile>  specify your AWS profile to use (i.e.: default)
      -r <region>   specify a desired AWS region to use (i.e.: us-east-1)
      -h            this help
  "
  exit
}

while getopts "hp:r:" OPTION; do
   case $OPTION in
     h )
        usage
        exit 1
        ;;
     p )
        PROFILE=$OPTARG
        ;;
     r )
        REGION=$OPTARG
        ;;
     : )
        echo -e "\n$RED ERROR!$NORMAL  -$OPTARG requires an argument\n"
        exit 1
        ;;
     ? )
        echo -e "\n$RED ERROR!$NORMAL Invalid option"
        usage
        exit 1
        ;;
   esac
done

# Functions to manage dates depending on OS
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  # function to compare in days, usage how_older_from_today date
  # date format %Y-%m-%d
  how_older_from_today()
    {
      DATE_TO_COMPARE=$1
      TODAY_IN_DAYS=$(date -d "$(date +%Y-%m-%d)" +%s)
      DATE_FROM_IN_DAYS=$(date -d $DATE_TO_COMPARE +%s)
      DAYS_SINCE=$((($TODAY_IN_DAYS - $DATE_FROM_IN_DAYS )/60/60/24))
      echo $DAYS_SINCE
    }
  # function to convert from timestamp to date, usage timestamp_to_date timestamp
  # output date format %Y-%m-%d
  timestamp_to_date()
    {
      # remove fractions of a second
      TIMESTAMP_TO_CONVERT=$(echo $1 | cut -f1 -d".")
      OUTPUT_DATE=$(date -d @$TIMESTAMP_TO_CONVERT +'%Y-%m-%d')
      echo $OUTPUT_DATE
    }
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # BSD/OSX coommands compatibility
  how_older_from_today()
      {
        DATE_TO_COMPARE=$1
        TODAY_IN_DAYS=$(date +%s)
        DATE_FROM_IN_DAYS=$(date -jf %Y-%m-%d $DATE_TO_COMPARE +%s)
        DAYS_SINCE=$((($TODAY_IN_DAYS - $DATE_FROM_IN_DAYS )/60/60/24))
        echo $DAYS_SINCE
      }
  timestamp_to_date()
    {
      # remove fractions of a second
      TIMESTAMP_TO_CONVERT=$(echo $1 | cut -f1 -d".")
      OUTPUT_DATE=$(date -r $TIMESTAMP_TO_CONVERT +'%Y-%m-%d')
      echo $OUTPUT_DATE
    }

elif [[ "$OSTYPE" == "cygwin" ]]; then
  # POSIX compatibility layer and Linux environment emulation for Windows
  how_older_from_today()
      {
        DATE_TO_COMPARE=$1
        TODAY_IN_DAYS=$(date -d "$(date +%Y-%m-%d)" +%s)
        DATE_FROM_IN_DAYS=$(date -d $DATE_TO_COMPARE +%s)
        DAYS_SINCE=$((($TODAY_IN_DAYS - $DATE_FROM_IN_DAYS )/60/60/24))
        echo $DAYS_SINCE
      }
  timestamp_to_date()
    {
      # remove fractions of a second
      TIMESTAMP_TO_CONVERT=$(echo $1 | cut -f1 -d".")
      OUTPUT_DATE=$(date -d @$TIMESTAMP_TO_CONVERT +'%Y-%m-%d')
      echo $OUTPUT_DATE
    }
else
        echo "Unknown Operating System"
        exit
fi

if (($# == 0)); then
  PROFILE=$DEFULT_AWS_PROFILE
  REGION=$DEFAULT_AWS_REGION
fi

if [[ ! -f ~/.aws/credentials ]]; then
  echo -e "\n$RED ERROR!$NORMAL AWS credentials file not found (~/.aws/credentials). Run 'aws configure' first. \n"
  return 1
fi

# AWS-CLI variables
AWSCLI=$(which aws)
if [ -z "${AWSCLI}" ]; then
  echo -e "\n$RED ERROR!$NORMAL AWS-CLI (aws command) not found. Make sure it is installed correctly and in your \$PATH\n"
  exit
fi

# if [ -z "${PROFILE}" ] || [ -z "${REGION}" ]; then
#   PROFILE=$($AWSCLI configure list | grep "profile" | awk '{ print $2 }')
#   REGION=$($AWSCLI configure list | grep "region" | awk '{ print $2 }')
#   if [ -z "${PROFILE}" ] || [ -z "${REGION}" ]; then
#     echo -e "\n $RED ERROR!$NORMAL No profile or region found, configure it using 'aws configure'\n"
#     echo -e "     or specify options -p <profile> -r <region>\n"
#     exit
#   fi
# fi

# if this script runs in an AWS instance
# INSTANCE_PROFILE=$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/)
# AWS_ACCESS_KEY_ID=$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/${INSTANCE_PROFILE} | grep AccessKeyId | cut -d':' -f2 | sed 's/[^0-9A-Z]*//g')
# AWS_SECRET_ACCESS_KEY_ID=$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/${INSTANCE_PROFILE} | grep SecretAccessKey | cut -d':' -f2 | sed 's/[^0-9A-Za-z/+=]*//g')
# AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
# AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY_ID}

#cat ~/.aws/credentials

prowlerBanner() {
echo -e "$CYAN                          _"
echo -e "  _ __  _ __ _____      _| | ___ _ __"
echo -e " | '_ \| '__/ _ \ \ /\ / / |/ _ \ '__|"
echo -e " | |_) | | | (_) \ V  V /| |  __/ |"
echo -e " | .__/|_|  \___/ \_/\_/ |_|\___|_|"
echo -e " |_|$NORMAL$BLUE CIS based AWS Account Hardening Tool$NORMAL\n"
}

# Get whoami in AWS, who is the user running this shell script
getWhoami() {
  echo -e "\nThis report is being generated using credentials below:\n"
  echo -e "AWS-CLI Profile: $NOTICE[$PROFILE]$NORMAL AWS Region: $NOTICE[$REGION]$NORMAL\n"
  $AWSCLI sts get-caller-identity --output table --profile $PROFILE --region $REGION
}

prowlerBanner
echo -e "\nDate: $NOTICE$(date)$NORMAL"
getWhoami

echo -e "\nColors Code for results: $NOTICE INFORMATIVE$NORMAL,$OK OK (RECOMMENDED VALUE)$NORMAL, $BAD CRITICAL (FIX REQUIRED)$NORMAL  \n"

# Generate Credential Report
genCredReport() {
  echo -en '\nGenerating Credential Report...'
  while STATE=$($AWSCLI iam generate-credential-report --output text --query 'State' --profile $PROFILE --region $REGION)
    test "$STATE" = "STARTED"
  do
    sleep 1
    echo -n '.'
  done
  echo -en " COMPLETE!"
}
genCredReport

# Save report to a file, deletion at finish. ACB stands for AWS CIS Benchmark
TEMP_REPORT_FILE=/tmp/.acb
$AWSCLI iam get-credential-report --query 'Content' --output text --profile $PROFILE --region $REGION | base64 -D > $TEMP_REPORT_FILE

# Get a list of all available AWS Regions
REGIONS=$($AWSCLI ec2 describe-regions --query 'Regions[].RegionName' \
  --output text \
  --profile $PROFILE \
  --region $REGION)

TITLE1="$BLUE 1 Identity and Access Management *********************************$NORMAL"
echo -e "\n\n$TITLE1 "

# 1.1
TITLE11="$BLUE 1.1$NORMAL Avoid the use of the root account (Scored). Last time root account was used
     (password last used, access_key_1_last_used, access_key_2_last_used): "
  COMMAND11=$(cat $TEMP_REPORT_FILE| grep '<root_account>' | cut -d, -f5,11,16)
  echo -e "\n$TITLE11 $NOTICE $COMMAND11 $NORMAL"

# 1.2
TITLE12="$BLUE 1.2$NORMAL Ensure multi-factor authentication (MFA) is enabled for all IAM users that have a console password (Scored)"
  # List users with password enabled
  COMMAND12_LIST_USERS_WITH_PASSWORD_ENABLED=$(cat $TEMP_REPORT_FILE|awk -F, '{ print $1,$4 }' |grep true | awk '{ print $1 }')
  COMMAND12=$(
    for i in $COMMAND12_LIST_USERS_WITH_PASSWORD_ENABLED; do
      cat $TEMP_REPORT_FILE|awk -F, '{ print $1,$8 }' |grep $i| grep false | awk '{ print $1 }'|tr '\n' ' ';
    done)

  echo -e "\n$TITLE12"
    if [[ $COMMAND12 ]]; then
      echo "     List of users with Password enabled but MFA disabled: $RED $COMMAND12 $NORMAL"
    else
      echo "     $OK CORRECT! No users found with Password enabled and MFA disabled $NORMAL"
    fi

# 1.3
TITLE13="$BLUE 1.3$NORMAL Ensure credentials unused for 90 days or greater are disabled (Scored)"
  COMMAND13=$(
    for i in $COMMAND12_LIST_USERS_WITH_PASSWORD_ENABLED; do
      cat $TEMP_REPORT_FILE|awk -F, '{ print $1,$5 }' |grep $i| grep false | awk '{ print $1 }'|tr '\n' ' ';
    done)
  # list of users that have used password
  USERS_PASSWORD_USED=$($AWSCLI iam list-users --query "Users[?PasswordLastUsed].UserName" --output text --profile $PROFILE --region $REGION)

  echo -e "\n$TITLE13 "
    # look for users with a password last used more or equal to 90 days
    echo -e "     User list: "
    for i in $USERS_PASSWORD_USED; do
      DATEUSED=$($AWSCLI iam list-users --query "Users[?UserName=='$i'].PasswordLastUsed" --output text --profile $PROFILE --region $REGION | cut -d'T' -f1)
      HOWOLDER=$(how_older_from_today $DATEUSED)
      if [ $HOWOLDER -gt "90" ];then
        echo "     $RED $i $NORMAL"
      else
        echo "     $OK OK $NORMAL"
      fi
    done

# 1.4
TITLE14="$BLUE 1.4$NORMAL Ensure access keys are rotated every 90 days or less (Scored)" # also checked by Security Monkey
LIST_OF_USERS_WITH_ACCESS_KEY1=$(cat $TEMP_REPORT_FILE| awk -F, '{ print $1, $9 }' |grep "\ true" | awk '{ print $1 }')
LIST_OF_USERS_WITH_ACCESS_KEY2=$(cat $TEMP_REPORT_FILE| awk -F, '{ print $1, $14 }' |grep "\ true" | awk '{ print $1 }')
  echo -e "\n$TITLE14 "
    echo -e "     Users with access key 1 older than 90 days: "
    for user in $LIST_OF_USERS_WITH_ACCESS_KEY1; do
      # check access key 1
      DATEROTATED1=$(cat $TEMP_REPORT_FILE | grep $user| awk -F, '{ print $10 }' | grep -v "N/A" | awk -F"T" '{ print $1 }')
      HOWOLDER=$(how_older_from_today $DATEROTATED1)

      if [ $HOWOLDER -gt "90" ];then
        echo -e "     $RED $user $NORMAL"
      fi
    done

    echo -e "     Users with access key 2 older than 90 days: "
    for user in $LIST_OF_USERS_WITH_ACCESS_KEY2; do
      # check access key 2
      DATEROTATED2=$(cat $TEMP_REPORT_FILE | grep $user| awk -F, '{ print $10 }' | grep -v "N/A" | awk -F"T" '{ print $1 }')
      HOWOLDER=$(how_older_from_today $DATEROTATED2)
      if [ $HOWOLDER -gt "90" ];then
        echo -e "     $RED $user $NORMAL"
      fi
    done

# 1.5
TITLE15="$BLUE 1.5$NORMAL Ensure IAM password policy requires at least one uppercase letter (Scored)"
COMMAND15=$($AWSCLI iam get-account-password-policy --profile $PROFILE --region $REGION --query 'PasswordPolicy.RequireUppercaseCharacters') # must be true
  echo -e "\n$TITLE15 "
  if [ $COMMAND15 == "True" ];then
    echo -e "     $OK OK $NORMAL"
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

# 1.6
TITLE16="$BLUE 1.6$NORMAL Ensure IAM password policy require at least one lowercase letter (Scored)"
COMMAND16=$($AWSCLI iam get-account-password-policy --profile $PROFILE --region $REGION --query 'PasswordPolicy.RequireLowercaseCharacters') # must be true
  echo -e "\n$TITLE16 "
  if [ $COMMAND16 == "True" ];then
    echo -e "     $OK OK $NORMAL"
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

# 1.7
TITLE17="$BLUE 1.7$NORMAL Ensure IAM password policy require at least one symbol (Scored)"
COMMAND17=$($AWSCLI iam get-account-password-policy --profile $PROFILE --region $REGION --query 'PasswordPolicy.RequireSymbols') # must be true
  echo -e "\n$TITLE17 "
  if [ $COMMAND17 == "True" ];then
    echo -e "     $OK OK $NORMAL"
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

# 1.8
TITLE18="$BLUE 1.8$NORMAL Ensure IAM password policy require at least one number (Scored)"
COMMAND18=$($AWSCLI iam get-account-password-policy --profile $PROFILE --region $REGION --query 'PasswordPolicy.RequireNumbers') # must be true
  echo -e "\n$TITLE18 "
  if [ $COMMAND18 == "True" ];then
    echo -e "     $OK OK $NORMAL"
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

# 1.9
TITLE19="$BLUE 1.9$NORMAL Ensure IAM password policy requires minimum length of 14 or greater (Scored)"
COMMAND19=$($AWSCLI iam get-account-password-policy --profile $PROFILE --region $REGION --query 'PasswordPolicy.MinimumPasswordLength')
  echo -e "\n$TITLE19 "
  if [ $COMMAND19 -gt "13" ];then
    echo -e "     $OK OK $NORMAL"
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

# 1.10
TITLE110="$BLUE 1.10$NORMAL Ensure IAM password policy prevents password reuse (Scored)"
COMMAND110=$($AWSCLI iam get-account-password-policy --profile $PROFILE --region $REGION --query 'PasswordPolicy.PasswordReusePrevention' | grep PasswordReusePrevention | awk -F: '{ print $2 }'|sed 's/\ //g'|sed 's/,/ /g')
  echo -e "\n$TITLE110 "
  if [[ $COMMAND110 ]];then
    if [[ $COMMAND110 -gt "23" ]];then
      echo -e "     $OK OK $NORMAL"
    fi
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

# 1.11
TITLE111="$BLUE 1.11$NORMAL Ensure IAM password policy expires passwords within 90 days or less (Scored)"
COMMAND111=$($AWSCLI iam get-account-password-policy --profile $PROFILE --region $REGION | grep MaxPasswordAge | awk -F: '{ print $2 }'|sed 's/\ //g'|sed 's/,/ /g')
  echo -e "\n$TITLE111 "
  if [[ $COMMAND111 ]];then
    if [ $COMMAND111 == "90" ];then
      echo -e "     $OK OK $NORMAL"
    fi
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

# 1.12
TITLE112="$BLUE 1.12$NORMAL Ensure no root account access key exists (Scored)"
# ensure the access_key_1_active and access_key_2_active fields are set to FALSE.
ROOTKEY1=$(cat $TEMP_REPORT_FILE |grep root_account|awk -F, '{ print $9 }')
ROOTKEY2=$(cat $TEMP_REPORT_FILE |grep root_account|awk -F, '{ print $14 }')
  echo -e "\n$TITLE112 "
  if [ $ROOTKEY1 == false ];then
    echo -e "     $OK OK $NORMAL No access key 1 found "
  else
    echo -e "     $RED Found access key 1 $NORMAL"
  fi
  if [ $ROOTKEY2 == false ];then
    echo -e "     $OK OK $NORMAL No access key 2 found "
  else
    echo -e "     $RED Found access key 2 $NORMAL"
  fi

# 1.13
TITLE113="$BLUE 1.13$NORMAL Ensure hardware MFA is enabled for the root account (Scored)"
COMMAND113=$($AWSCLI iam list-virtual-mfa-devices --profile $PROFILE --region $REGION --query 'VirtualMFADevices[*].User.Arn' --output text | awk -F":" '{ print $6 }'|tr '\n' ' ')
echo -e "\n$TITLE113"
  if [ $COMMAND113 ]; then
    echo "     $OK OK $NORMAL"
  else
    echo "     $RED WARNING, MFA is not ENABLED for root account $NORMAL"
  fi

# 1.14
TITLE114="$BLUE 1.14$NORMAL Ensure security questions are registered in the AWS account (Not Scored)"
# No command available
echo -e "\n$TITLE114"
echo -e "     $NOTICE No command available for check 1.14"
echo -e "      Login to the AWS Console as root, click on the Account "
echo -e "      Name -> My Account -> Configure Security Challenge Questions $NORMAL"

# 1.15
TITLE115="$BLUE 1.15$NORMAL Ensure IAM policies are attached only to groups or roles (Scored)"
echo -e "\n$TITLE115"
LIST_USERS=$($AWSCLI iam list-users --query 'Users[*].UserName' --output text --profile $PROFILE --region $REGION)
echo -e "      Users with policy attached to them instead to groups: (it may take few seconds...) "
  for user in $LIST_USERS;do
    USER_POLICY=$($AWSCLI iam list-attached-user-policies --output text --profile $PROFILE --region $REGION --user-name $user)
    if [[ $USER_POLICY ]]; then
      echo -e "     $RED $user $NORMAL"
    fi
  done

TITLE2="$BLUE 2 Logging ********************************************************$NORMAL"
echo -e "\n\n$TITLE2 "

TITLE21="$BLUE 2.1$NORMAL Ensure CloudTrail is enabled in all regions (Scored)"
echo -e "\n$TITLE21"
COMMAND21=$($AWSCLI cloudtrail describe-trails --profile $PROFILE --region $REGION --query 'trailList[*].IsMultiRegionTrail' --output text)
  if [[ $COMMAND21 ]];then
    if [ $COMMAND21 == "True" ];then
      echo -e "     $OK OK $NORMAL"
    fi
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

TITLE22="$BLUE 2.2$NORMAL Ensure CloudTrail log file validation is enabled (Scored)"
echo -e "\n$TITLE22"
COMMAND22=$($AWSCLI cloudtrail describe-trails --profile $PROFILE --region $REGION --query 'trailList[*].LogFileValidationEnabled' --output text
)
  if [[ $COMMAND22 ]];then
    if [ $COMMAND22 == "True" ];then
      echo -e "     $OK OK $NORMAL"
    fi
  else
    echo -e "     $RED FALSE $NORMAL"
  fi

TITLE23="$BLUE 2.3$NORMAL Ensure the S3 bucket CloudTrail logs to is not publicly accessible (Scored)"
echo -e "\n$TITLE23"

CLOUDTRAILBUCKET=$($AWSCLI cloudtrail describe-trails --query 'trailList[*].S3BucketName' --output text --profile $PROFILE --region $REGION)
  if [[ $CLOUDTRAILBUCKET ]];then
    CLOUDTRAILBUCKET_HASALLPERMISIONS=$($AWSCLI s3api get-bucket-acl --bucket $CLOUDTRAILBUCKET --query 'Grants[?Grantee.URI==`http://acs.amazonaws.com/groups/global/AllUsers`]' --profile $PROFILE --region $REGION --output text)
    # aws s3api get-bucket-policy --bucket $CLOUDTRAILBUCKET --profile $PROFILE --region $REGION --output text
    if [[ $CLOUDTRAILBUCKET_HASALLPERMISIONS ]];then
      echo -e "     $RED WARNING, check your CloudTrail bucket ACL and Policy!$NORMAL"
    else
      echo -e "     $OK OK $NORMAL"
    fi
  else
    echo -e "     $RED WARNING, CloudTrail bucket doesn't exist!$NORMAL"
  fi

TITLE24="$BLUE 2.4$NORMAL Ensure CloudTrail trails are integrated with CloudWatch Logs (Scored)"
echo -e "\n$TITLE24"

LIST_OF_TRAILS=$($AWSCLI cloudtrail describe-trails --profile $PROFILE --region $REGION --query 'trailList[*].Name' --output text)
if [[ $LIST_OF_TRAILS ]];then
  for trail in $LIST_OF_TRAILS;do
    LATESTDELIVERY_TIMESTAMP=$($AWSCLI cloudtrail get-trail-status --name $trail --profile $PROFILE --region $REGION --query 'LatestCloudWatchLogsDeliveryTime')
    LATESTDELIVERY_DATE=$(timestamp_to_date $LATESTDELIVERY_TIMESTAMP)
    HOWOLDER=$(how_older_from_today $LATESTDELIVERY_DATE)
    if [ $HOWOLDER -gt "1" ];then
      echo -e "     $RED $trail is not logging in the last 24h $NORMAL"
    else
      echo -e "     $OK $trail has been logging during the last 24h $NORMAL"
    fi
  done
else
  echo -e "     $RED WARNING, No CloudTrail trails found!$NORMAL"
fi

TITLE25="$BLUE 2.5$NORMAL Ensure AWS Config is enabled in all regions (Scored)"
echo -e "\n$TITLE25"
for regx in $REGIONS; do
  CHECK_AWSCONFIG_STATUS=$($AWSCLI configservice get-status --profile $PROFILE --region $regx | grep recorder)
  if [[ $CHECK_AWSCONFIG_STATUS ]];then
    echo -e "     $OK Region $regx has AWS Config $CHECK_AWSCONFIG_STATUS $NORMAL"
  else
    echo -e "     $RED WARNING, Region $regx has AWS Config disabled or not configured$NORMAL"
  fi
done

TITLE26="$BLUE 2.6$NORMAL Ensure S3 bucket access logging is enabled on the CloudTrail S3 bucket (Scored)"
echo -e "\n$TITLE26"
CLOUDTRAILBUCKET=$($AWSCLI cloudtrail describe-trails --query 'trailList[*].S3BucketName' --output text --profile $PROFILE --region $REGION)
  if [[ $CLOUDTRAILBUCKET ]];then
    CLOUDTRAILBUCKET_LOGENABLED=$($AWSCLI s3api get-bucket-logging --bucket $CLOUDTRAILBUCKET --profile $PROFILE --region $REGION --query 'LoggingEnabled.TargetBucket' --output text|grep -v None)
    if [[ $CLOUDTRAILBUCKET_LOGENABLED ]];then
      echo -e "     $OK OK $NORMAL"
    else
      echo -e "     $RED WARNING, access logging is not enabled in your CloudTrail S3 bucket!$NORMAL"
    fi
  else
    echo -e "     $RED WARNING, CloudTrail bucket doesn't exist!$NORMAL"
  fi

TITLE27="$BLUE 2.7$NORMAL Ensure CloudTrail logs are encrypted at rest using KMS CMKs (Scored)"
echo -e "\n$TITLE27"
CLOUDTRAILNAME=$($AWSCLI cloudtrail describe-trails --query 'trailList[*].Name' --output text --profile $PROFILE --region $REGION)
  if [[ $CLOUDTRAILNAME ]];then
    CLOUDTRAILENC_ENABLED=$($AWSCLI cloudtrail describe-trails --profile $PROFILE --region $REGION --trail $CLOUDTRAILNAME --query 'trailList[*].KmsKeyId' --output text)
    if [[ $CLOUDTRAILENC_ENABLED ]];then
      echo -e "     $OK OK $NORMAL"
    else
      echo -e "     $RED WARNING, encryption is not enabled in your CloudTrail trail, KMS key not found!$NORMAL"
    fi
  else
    echo -e "     $RED WARNING, CloudTrail bucket doesn't exist!$NORMAL"
  fi

TITLE28="$BLUE 2.8$NORMAL Ensure rotation for customer created CMKs is enabled (Scored)"
echo -e "\n$TITLE28"
for regx in $REGIONS; do
  CHECK_KMS_KEYLIST=$($AWSCLI kms list-keys --profile $PROFILE --region $regx --output text --query 'Keys[*].KeyId')
  if [[ $CHECK_KMS_KEYLIST ]];then
      for key in $CHECK_KMS_KEYLIST; do
        CHECK_KMS_KEY_ROTATION=$($AWSCLI kms get-key-rotation-status --key-id $key --profile $PROFILE --region $regx --output text)
        if [ $CHECK_KMS_KEY_ROTATION == "True" ];then
          echo -e "     $OK OK $NORMAL, Key $key in Region $regx is set correctly"
        else
          echo -e "     $RED WARNING, Key $key in Region $regx is not set to rotate!$NORMAL"
        fi
      done
  else
    echo -e "     $NOTICE Region $regx doesn't have encryption keys $NORMAL"
  fi
done

TITLE3="$BLUE 3 Monitoring *****************************************************"
echo -e "\n\n$TITLE3 "
# 3 Monitoring check commands / Mostly covered by SecurityMonkey

TITLE31="$BLUE 3.1$NORMAL Ensure a log metric filter and alarm exist for unauthorized API calls (Scored)"
echo -e "\n$TITLE31 "
CLOUDWATCH_GROUP=$($AWSCLI cloudtrail describe-trails --profile $PROFILE --region $REGION --query 'trailList[*].CloudWatchLogsLogGroupArn' --output text | awk -F: '{ print $7 }')
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep AccessDenied)
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters for Access Denied enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE32="$BLUE 3.2$NORMAL Ensure a log metric filter and alarm exist for Management Console sign-in without MFA (Scored)"
echo -e "\n$TITLE32 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'userIdentity.sessionContext.attributes.mfaAuthenticated.*true')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters for sign-in Console without MFA enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE33="$BLUE 3.3$NORMAL Ensure a log metric filter and alarm exist for usage of root account (Scored)"
echo -e "\n$TITLE33 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'Root.*AwsServiceEvent')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters for usage of root account enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE34="$BLUE 3.4$NORMAL Ensure a log metric filter and alarm exist for IAM policy changes (Scored)"
echo -e "\n$TITLE34 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'DeleteGroupPolicy.*DeleteRolePolicy.*DeleteUserPolicy.*PutGroupPolicy.*PutRolePolicy.*PutUserPolicy.*CreatePolicy.*DeletePolicy.*CreatePolicyVersion.*DeletePolicyVersion.*AttachRolePolicy.*DetachRolePolicy.*AttachUserPolicy.*DetachUserPolicy.*AttachGroupPolicy.*DetachGroupPolicy')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters for IAM policy changes enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE35="$BLUE 3.5$NORMAL Ensure a log metric filter and alarm exist for CloudTrail configuration changes (Scored)"
echo -e "\n$TITLE35 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'CreateTrail.*UpdateTrail.*DeleteTrail.*StartLogging.*StopLogging')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters for CloudTrail configuration changes enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE36="$BLUE 3.6$NORMAL Ensure a log metric filter and alarm exist for AWS Management Console authentication failures (Scored)"
echo -e "\n$TITLE36 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'ConsoleLogin.*Failed')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters for usage of root account enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE37="$BLUE 3.7$NORMAL Ensure a log metric filter and alarm exist for disabling or scheduled deletion of customer created CMKs (Scored)"
echo -e "\n$TITLE37 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'kms.amazonaws.com.*DisableKey.*ScheduleKeyDeletion')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE38="$BLUE 3.8$NORMAL Ensure a log metric filter and alarm exist for S3 bucket policy changes (Scored)"
echo -e "\n$TITLE38 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 's3.amazonaws.com.*PutBucketAcl.*PutBucketPolicy.*PutBucketCors.*PutBucketLifecycle.*PutBucketReplication.*DeleteBucketPolicy.*DeleteBucketCors.*DeleteBucketLifecycle.*DeleteBucketReplication')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE39="$BLUE 3.9$NORMAL Ensure a log metric filter and alarm exist for AWS Config configuration changes (Scored)"
echo -e "\n$TITLE39 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'config.amazonaws.com.*StopConfigurationRecorder.*DeleteDeliveryChannel.*PutDeliveryChannel.*PutConfigurationRecorder')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE310="$BLUE 3.10$NORMAL Ensure a log metric filter and alarm exist for security group changes (Scored)"
echo -e "\n$TITLE310 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'AuthorizeSecurityGroupIngress.*AuthorizeSecurityGroupEgress.*RevokeSecurityGroupIngress.*RevokeSecurityGroupEgress.*CreateSecurityGroup.*DeleteSecurityGroup')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE311="$BLUE 3.11$NORMAL Ensure a log metric filter and alarm exist for changes to Network Access Control Lists (NACL) (Scored)"
echo -e "\n$TITLE311 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'CreateNetworkAcl.*CreateNetworkAclEntry.*DeleteNetworkAcl.*DeleteNetworkAclEntry.*ReplaceNetworkAclEntry.*ReplaceNetworkAclAssociation')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE312="$BLUE 3.12$NORMAL Ensure a log metric filter and alarm exist for changes to network gateways (Scored)"
echo -e "\n$TITLE312 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'CreateCustomerGateway.*DeleteCustomerGateway.*AttachInternetGateway.*CreateInternetGateway.*DeleteInternetGateway.*DetachInternetGateway')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE313="$BLUE 3.13$NORMAL Ensure a log metric filter and alarm exist for route table changes (Scored)"
echo -e "\n$TITLE313 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'CreateRoute.*CreateRouteTable.*ReplaceRoute.*ReplaceRouteTableAssociation.*DeleteRouteTable.*DeleteRoute.*DisassociateRouteTable')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE314="$BLUE 3.14$NORMAL Ensure a log metric filter and alarm exist for VPC changes (Scored)"
echo -e "\n$TITLE314 "
if [[ $CLOUDWATCH_GROUP ]];then
  METRICFILTER_SET=$($AWSCLI logs describe-metric-filters --log-group-name CloudTrail/CloudWatchGroup --profile $PROFILE --region $REGION --query 'trailList' | grep -E 'CreateVpc.*DeleteVpc.*ModifyVpcAttribute.*AcceptVpcPeeringConnection.*CreateVpcPeeringConnection.*DeleteVpcPeeringConnection.*RejectVpcPeeringConnection.*AttachClassicLinkVpc.*DetachClassicLinkVpc.*DisableVpcClassicLink.*EnableVpcClassicLink')
  if [[ $METRICFILTER_SET ]];then
    echo -e "     $OK OK, CloudWatch group found, and metric filters enabled$NORMAL"
  else
    echo -e "     $RED WARNING, CloudWatch group found, but no metric filters or alarms associated$NORMAL"
  fi
else
  echo -e "     $RED WARNING, No CloudWatch group found, no metric filters or alarms associated$NORMAL"
fi

TITLE315="$BLUE 3.15$NORMAL Ensure security contact information is registered (Scored)"
# No command available
echo -e "\n$TITLE315 "
echo -e "     $NOTICE No command available for check 3.15"
echo -e "      Login to the AWS Console, click on My Account "
echo -e "      Go to Alternate Contacts -> make sure Security section is filled $NORMAL"

TITLE316="$BLUE 3.16$NORMAL Ensure appropriate subscribers to each SNS topic (Not Scored)"
echo -e "\n$TITLE316 "
for regx in $REGIONS; do
  TOPICS_LIST=$($AWSCLI sns list-topics --profile $PROFILE --region $regx --output text --query 'Topics[*].TopicArn')
  if [[ $TOPICS_LIST ]];then
      for topic in $TOPICS_LIST; do
        CHECK_TOPIC_LIST=$($AWSCLI sns list-subscriptions-by-topic --topic-arn $topic --profile $PROFILE --region $regx --query 'Subscriptions[*].{Endpoint:Endpoint,Protocol:Protocol}' --output text)
        if [[ $CHECK_TOPIC_LIST ]]; then
          TOPIC_SHORT=$(echo $topic | awk -F: '{ print $7 }')
          echo -e "     $NOTICE Region $regx with Topic $TOPIC_SHORT: $NORMAL "
          echo -e "     $NOTICE - Suscription: $CHECK_TOPIC_LIST $NORMAL"
        else
          echo -e "     $RED WARNING, No suscription found in Region $regx and Topic $topic $NORMAL"
        fi
      done
  else
    echo -e "     $NOTICE Region $regx doesn't have topics $NORMAL"
  fi
done

TITLE4="$BLUE 4 Networking **************************************************$NORMAL"
echo -e "\n\n$TITLE4 "

TITLE41="$BLUE 4.1$NORMAL Ensure no security groups allow ingress from 0.0.0.0/0 to port 22 (Scored)"
echo -e "\n$TITLE41 "
for regx in $REGIONS; do
  SG_LIST=$($AWSCLI ec2 describe-security-groups --filters "Name=ip-permission.to-port,Values=22" --query 'SecurityGroups[?length(IpPermissions[?ToPort==`22` && contains(IpRanges[].CidrIp, `0.0.0.0/0`)]) > `0`].{GroupName: GroupName}' --profile $PROFILE --region $regx --output text)
  if [[ $SG_LIST ]];then
    for SG in $SG_LIST;do
      echo -e "     $RED Found Security Group: $SG open to 0.0.0.0/0 in Region $regx $NORMAL "
    done
  else
    echo -e "     $OK OK, No Security Groups found in $regx with port 22 TCP open to 0.0.0.0/0 $NORMAL "
  fi
done

TITLE42="$BLUE 4.2$NORMAL Ensure no security groups allow ingress from 0.0.0.0/0 to port 3389 (Scored)"
echo -e "\n$TITLE42 "
for regx in $REGIONS; do
  SG_LIST=$($AWSCLI ec2 describe-security-groups --filters "Name=ip-permission.to-port,Values=3389" --query 'SecurityGroups[?length(IpPermissions[?ToPort==`3389` && contains(IpRanges[].CidrIp, `0.0.0.0/0`)]) > `0`].{GroupName: GroupName}' --profile $PROFILE --region $regx --output text)
  if [[ $SG_LIST ]];then
    for SG in $SG_LIST;do
      echo -e "     $RED Found Security Group: $SG open to 0.0.0.0/0 in Region $regx $NORMAL "
    done
  else
    echo -e "     $OK OK, No Security Groups found in $regx with port 3389 TCP open to 0.0.0.0/0 $NORMAL "
  fi
done

TITLE43="$BLUE 4.3$NORMAL Ensure VPC Flow Logging is Enabled in all Applicable Regions (Scored)"
echo -e "\n$TITLE43 "
for regx in $REGIONS; do
  CHECK_FL=$($AWSCLI ec2 describe-flow-logs --profile $PROFILE --region $regx --query 'FlowLogs[?FlowLogStatus==`ACTIVE`].LogGroupName' --output text)
  if [[ $CHECK_FL ]];then
    for FL in $CHECK_FL;do
      echo -e "     $OK OK, VPCFlowLog is enabled for LogGroupName: $FL in Region $regx $NORMAL "
    done
  else
    echo -e "     $RED WARNING, no VPCFlowLog has been found in Region $regx $NORMAL "
  fi
done

TITLE44="$BLUE 4.4$NORMAL Ensure the default security group restricts all traffic (Scored)"
echo -e "\n$TITLE44 "
#COMMAND44= Ensure the default security group restricts all traffic
#aws ec2 describe-security-groups --filters Name=group-name,Values='default' --profile internalmg --region us-east-1


# Final
echo -e "\n$BLUE - For more information and reference:$NORMAL"
echo -e "  $NOTICE https://d0.awsstatic.com/whitepapers/compliance/AWS_CIS_Foundations_Benchmark.pdf$NORMAL"

# Delete temp file
rm -fr $TEMP_REPORT_FILE
