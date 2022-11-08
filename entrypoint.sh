#!/usr/bin/env bash
#set -x
# ([^:]*)$   - from arn

#if you need to switch ssh, uncomment next row
#/usr/local/bin/sshd-entrypoint.sh &

#This function assumed roles and create credentials for awscli
#parameters: $1 role ARN
#            $2 session name
#            $3 sts-external-id
function RoleToCredentials() {
  local roleARN=$1
  local rolesessionName=$2
  local stsexternalid=$3

  export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
  $(/usr/local/bin/aws sts assume-role \
  --role-arn ${roleARN} \
  --role-session-name ${rolesessionName} \
  --external-id ${stsexternalid} \
  --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
  --output text))
}

#This function clear aws session
function unsetCredentials() {
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
}

function info () {
    if [[ ${DEBUGLEVEL} -gt 0 ]] ; then
    echo "$@"
    fi
}

#This function is a wrapper on aws rds download-db-log-file-portion
#parameters: $1 RDS DBInstanceIdentifier
#            $2 slow_log file name
#            $3 local fie with slow log
function downloadLog () {
   local instanceID=$1
   local log=$2
   local downloadedfile=$3

  /usr/local/bin/aws rds download-db-log-file-portion  \
   --output text \
   --db-instance-identifier ${instanceID} \
   --log-file-name $log \
   --starting-token 0 >${downloadedfile} 2>> /tmp/anenom.err
   err="$(cat /tmp/anenom.err)"
}

#This function search RDS in account with tags Anemometer=true and needed environment name
#parameters: $1 environment name
function getRdsArn () {
    local environment=$1

   /usr/local/bin/aws resourcegroupstaggingapi get-resources \
    --resource-type-filters rds:db \
    --query 'ResourceTagMappingList[*].[ResourceARN]' \
    --tag-filters "Key=Anemometer,Values=true" "Key=Env,Values=${ENV_NAME}" \
    --output text | grep -Po '([^:]*)$'
}

#This function search RDS engine name
#parameters: $1 RDS arn
function describeEngine () {
    local rdsarn=$1

   /usr/local/bin/aws rds describe-db-instances \
    --db-instance-identifier ${rdsName} \
    --query 'DBInstances[*].[Engine]' \
    --output text
}

# Set external variable
# This parameter is using for checking slowlog per hour by size. If the file's size is
# less than 1024 bytes the slowlog file isn't valid for parsing.
CHECKSIZE=1023

# development or RC or production environment
ENV_NAME=${ENV_NAME}
# Set internal variable
declare -i statuscode
declare -i trycounter
datestring=$(date +%Y-%m-%d)

# receive the secret externalIDs for sts assume role
stsexternalid_listaccount=$( echo ${STSEXTERNALIDs} | jq -r .STSEXTERNALID_LISTACCOUNT )
stsexternalid_collect_slowlogs=$( echo ${STSEXTERNALIDs} | jq -r .STSEXTERNALID_COLLECTSLOWLOG )

# assume role and create credentials for collecting accountIDs from organization account
RoleToCredentials ${LISTACCOUNTIDSROLE} anemometer-list-accountIDs ${stsexternalid_listaccount}

accountIDs_list=$(/usr/local/bin/aws organizations list-accounts --query 'Accounts[*].[Id]' --output text)

roleCollectSlowLogs=${COLLECTSLOWLOGSROLE}

#Creation suffix for downloading slowlogs from mysql engine. log.2022-10-29.0, log.2022-10-29.1 ... log.2022-10-29.23
for hour in $(seq 0 23) ; do
    hourbackdate=$(date -u -d "${hour} hour ago" +"%Y-%m-%d.%-H")
    suffixesdatenozero="${suffixesdatenozero} log.${hourbackdate}"
done

#Creation suffix for downloading slowlogs from aurora-mysql and aurora engines. log.2022-10-29.0, log.2022-10-29.01 ... log.2022-10-29.23
for hour in $(seq 0 23) ; do
    hourbackdate=$(date -u -d "${hour} hour ago" +"%Y-%m-%d.%H")
    suffixesdate="${suffixesdate} log.${hourbackdate}"
done

#info "INFO: ${ENV_NAME} allDB The list of suffixes for slowlogs files ${suffixes} were created"
info "INFO: allDB The list of suffixes for Aurora RDS slowlogs files ${suffixesdate} were created"
info "INFO: allDB Lets find RDS ARNs  where tag Anemometer=true"


for accountID in ${accountIDs_list[@]} ; do
    #clear previously assumed role
    unsetCredentials
    echo "account id ${accountID}"
    #assume role for account
    RoleToCredentials ${roleCollectSlowLogs/000000000000/$accountID} anemometer-collect-slowlogs ${stsexternalid_collect_slowlogs}
    for ENV_NAME in ${ENV_NAMES_LIST[@]} ; do
        info "INFO: Let's start collect slow logs from account ${accountID} with tag ENV=${ENV_NAME}"
        # Lets find if RDS is in account
        rdsNames=$( getRdsArn ${ENV_NAME})
        # If no RDS was find go to another account
        if [ -z "${rdsNames}" ] ; then
            info "INFO: There is no RDS with tags Anemometer=true and ENV=${ENV_NAME} in account ${accountID}"
        else
        # If there is RDS lets check engine and tags
            info "INFO: ${ENV_NAME} Such RDS with tag Anemometer was found : ${rdsNames}"
            # Collecting slow logs from all RDSs in account with assumed role
            for rdsName in ${rdsNames}; do
                info "INFO: ${ENV_NAME} allDB Lets check RDS engine for ${rdsName}"
                #Checking engine type
                engineRDS=$(describeEngine ${rdsName} )
                info "INFO: ${ENV_NAME} ${rdsName} The rds ${rdsName} engine type is ${engineRDS}"
                commontemporary="/tmp/generalslow-${rdsName}-$datestring.log"
                #Choosing suffix format for the type of engine collected earlier
                if [ "${engineRDS}" == "aurora-mysql" ] || [ "${engineRDS}" == "aurora" ] ; then
                    info "INFO: ${ENV_NAME} ${rdsName} Lets start to download slowlogs for Aurora RDS ${rdsName}, engine is ${engineRDS} "
                    nextstep="yes"
                    for suffdate in ${suffixesdate} ; do
                        temporaryfile="/tmp/slow-${rdsName}.${suffdate}"
                        trycounter=0
                        while [ ${trycounter} -lt 1 ] ; do
                            info "INFO: ${ENV_NAME} ${rdsName} Downloading  ${temporaryfile}"
                            info "INFO: ${ENV_NAME} ${rdsName} Free disk space before downloading df -h " : $(df -h)
                            downloadLogs=$(downloadLog ${rdsName} slowquery/mysql-slowquery."${suffdate}" ${temporaryfile})
                            statuscode=$?
                            sleep 2
                            info "INFO: ${ENV_NAME} ${rdsName} downloadLogs function statuscode=${statuscode}"
                            if [ ${statuscode} -gt 0 ] ; then
                                echo "INFO: ${ENV_NAME} ${rdsName} stdout log file"
                                echo "CRITICAL: ${ENV_NAME} ${rdsName} An error occurred (DBLogFileNotFoundFault) when calling the DownloadDBLogFilePortion operation: DBLog File: slow-log file is not found on the ${instanceID}. The problem file is slowquery/mysql-slowquery."${suff}" "
                                ((trycounter++))
                                info "INFO: ${ENV_NAME} ${rdsName} counter=${trycounter}"
                                sleep 2
                            else
                                temporaryfilesize=$(stat -c%s "$temporaryfile")
                                echo " File size of ${temporaryfile} is ${temporaryfilesize}"
                                sleep 2
                                if [[ ${temporaryfilesize} -le ${CHECKSIZE} ]] ; then
                                    echo "ERROR: ${ENV_NAME} ${rdsName} The problem is with downloading ${temporaryfile}. The files size is less than ${CHECKSIZE} bytes"
                                    ((trycounter++))
                                    sleep 2
                                else
                                    info "INFO: ${ENV_NAME} ${rdsName} Downloading finished OK. The size of ${temporaryfile} = ${temporaryfilesize} bytes. Start to add it into  ${commontemporary}"
                                    info "INFO: ${ENV_NAME} ${rdsName} Free disk space after downloading ${temporaryfile} df -h " : $(df -h)
                                    cat ${temporaryfile} >> ${commontemporary}
                                    echo >> ${commontemporary}
                                    commontemporaryfilesize=$(stat -c%s "$commontemporary")
                                    info "INFO: ${ENV_NAME} ${rdsName} Size of collecting file is $commontemporary = $commontemporaryfilesize bytes."
                                    trycounter=10
                                fi
                            fi
                        done
                    done
                else
                    nextstep="yes"
                    for suffdate in ${suffixesdatenozero} ; do
                        temporaryfile="/tmp/slow-${rdsName}.${suffdate}"
                        trycounter=0
                        while [ ${trycounter} -lt 1 ] ; do
                            info "INFO: ${ENV_NAME} ${rdsName} Downloading  ${temporaryfile}"
                            info "INFO: ${ENV_NAME} ${rdsName} Free disk space before downloading df -h " : $(df -h)
                            downloadLogs=$(downloadLog ${rdsName} slowquery/mysql-slowquery."${suffdate}" ${temporaryfile})
                            statuscode=$?
                            sleep 2
                            info "INFO: ${ENV_NAME} ${rdsName} downloadLogs function statuscode=${statuscode}"
                            if [ ${statuscode} -gt 0 ] ; then
                                echo "INFO: ${ENV_NAME} ${rdsName} stdout log file"
                                echo "CRITICAL: ${ENV_NAME} ${rdsName} An error occurred (DBLogFileNotFoundFault) when calling the DownloadDBLogFilePortion operation: DBLog File: slow-log file is not found on the ${instanceID}. The problem file is slowquery/mysql-slowquery."${suff}" "
                                ((trycounter++))
                                info "INFO: ${ENV_NAME} ${rdsName} counter=${trycounter}"
                                sleep 2
                            else
                                temporaryfilesize=$(stat -c%s "$temporaryfile")
                                echo " File size of ${temporaryfile} is ${temporaryfilesize}"
                                sleep 2
                                if [[ ${temporaryfilesize} -le ${CHECKSIZE} ]] ; then
                                    echo "ERROR: ${ENV_NAME} ${rdsName} The problem is with downloading ${temporaryfile}. The files size is less than ${CHECKSIZE} bytes"
                                    ((trycounter++))
                                    sleep 2
                                else
                                    info "INFO: ${ENV_NAME} ${rdsName} Downloading finished OK. The size of ${temporaryfile} = ${temporaryfilesize} bytes. Start to add it into  ${commontemporary}"
                                    info "INFO: ${ENV_NAME} ${rdsName} Free disk space after downloading ${temporaryfile} df -h " : $(df -h)
                                    cat ${temporaryfile} >> ${commontemporary}
                                    echo >> ${commontemporary}
                                    commontemporaryfilesize=$(stat -c%s "$commontemporary")
                                    info "INFO: ${ENV_NAME} ${rdsName} Size of collecting file is $commontemporary = $commontemporaryfilesize bytes."
                                    trycounter=10
                                fi
                            fi
                        done
                    done
                    #Sending collected slowlogs to AnemometerDB
                    info "INFO: ${ENV_NAME} ${rdsName} Finished downloading ${rdsName} slowlogs by hours"
                    if [[ "${nextstep}" = "yes" && -f "${commontemporary}" ]] ; then
                        info "INFO: ${ENV_NAME} ${rdsName}. Starting to digest collected file ${commontemporary} and add result into anemometer database"
                        /usr/bin/pt-query-digest --user=$ANEMOMETER_MYSQL_USER --password=$ANEMOMETER_MYSQL_PASSWORD \
                                                --review h=$ANEMOMETER_MYSQL_HOST,D=$ANEMOMETER_MYSQL_DB,t=global_query_review \
                                                --history h=$ANEMOMETER_MYSQL_HOST,D=$ANEMOMETER_MYSQL_DB,t=global_query_review_history \
                                                --no-report --limit=0% \
                                                --filter=" \$event->{Bytes} = length(\$event->{arg}) and \$event->{hostname}=\"${rdsName}\"" \
                                                ${commontemporary}
                        statuscode=$?
                        info "statuscode=${statuscode} of percona digest tool"
                        if [ ${statuscode} -gt 0 ] ; then
                            echo "CRITICAL: ${ENV_NAME} ${rdsName} slowlogs digest problem. the statuscode=${statuscode} "
                        else
                            info "INFO: ${ENV_NAME} ${rdsName} Digest of ${commontemporary} was successful"
                            rm -f "${commontemporary}"
                        fi
                    fi
                fi
            done
            #Uploading raw format of slowlogs to S3
            for rdsName in ${rdsNames}; do
                info "INFO: ${ENV_NAME} ${rdsName} Copy slow logs to s3"
                # clear previously assumed role and upload collected files to S3 the task role
                unsetCredentials
                workfolder="${ENV_NAME}/${rdsName}/${datestring}"
                cpslowToS3=$( /usr/local/bin/aws s3 cp /tmp/  s3://${S3_BUCKET}/slowlogs/${workfolder}/  --recursive --exclude "*" --include "slow-${rdsName}.*")
                rm -r /tmp/slow-${rdsName}.*
            done
        fi
    done
done

## if you use ssh, uncomment the sleep for debug
#sleep 300m

exit 0
