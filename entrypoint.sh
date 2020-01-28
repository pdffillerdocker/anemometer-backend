#!/usr/bin/env bash
set -x

root_folder="$HOME/.aws"
mkdir -p ${root_folder}
path_credentials=$HOME/.aws/credentials
path_config=$HOME/.aws/config

if [[ -e ${path_credentials} && -e ${path_config} ]]; then
    echo "File $1 already exists!"
    rm -f ${path_credentials}
    rm -f ${path_config}
fi
copyconffile=$(aws s3 cp s3://${S3_SYSTEM}/anemometer-bk/config ${path_config})
copycredfile=$(aws s3 cp s3://${S3_SYSTEM}/anemometer-bk/credentials ${path_credentials})

/usr/bin/aws --version
python --version
sleep 2

# Set external variable
# This parameter is using for checking slowlog per hour by size. If the file's size is
# less than 1024 bytes the slowlog file isn't valid for parsing.
CHECKSIZE=1023

# Set internal variable
declare -i statuscode
declare -i trycounter
datestring=$(date +%Y%m%d)
datetimestring=$(date +%Y%m%d%H%M)

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
   local profile=$1
   local region=$2
   local instanceID=$3
   local log=$4
   local downloadedfile=$5

   /usr/bin/aws rds download-db-log-file-portion  \
   --profile=${profileID} \
   --region ${REGION} \
   --output text \
   --db-instance-identifier ${instanceID} \
   --log-file-name $log \
   --starting-token 0 >${downloadedfile} 2>&1
}

function getRdsArn () {
    local profile=$1
    local region=$2

    /usr/bin/aws resourcegroupstaggingapi get-resources \
    --profile=${profileID} \
    --region ${REGION} \
    --resource-type-filters rds:db \
    --query 'ResourceTagMappingList[*].[ResourceARN]' \
    --tag-filters Key=Anemometer,Values=true \
    --output text
}

function describeRDS () {
    local profile=$1
    local region=$2
    local rdsarn=$3

    /usr/bin/aws rds describe-db-instances \
    --profile=${profileID} \
    --region ${REGION} \
    --filters "Name=db-instance-id,Values=${rdsArn}" \
    --query 'DBInstances[*].[DBInstanceIdentifier]' \
    --output text

}

#####  ----------------------------
# compdate=$( date -d '-90 days' '+%Y%m%d' )  ----------------------- date
#for fname in *; do
#    if (( ${fname//[^0-9]} < compdate )); then
#        echo "$fname"
#        info "INFO: ${ENV_NAME} ${instanceID} The file  if older than 90 days "
#    fi
#done

########### ------------------------------


for hour in $(seq 0 23) ; do suffixes="${suffixes} log.$hour" ; done
info "INFO: ${ENV_NAME} allDB The list of suffixes for slowlogs files ${suffixes} were created"
info "INFO: ${ENV_NAME} allDB Lets find RDS ARNs  where tag Anemometer=true"

profileIDs=($(echo "$PROFILE_NAMES" | tr ',' '\n'))
echo "${profileIDs[@]}"
for profileID in ${profileIDs[@]}; do
    ENV_NAME=${profileID}
    info "INFO: ${ENV_NAME} allDB Lets start work in ${profileID} "
    rdsArns=$(getRdsArn ${profileID} ${REGION} )
    info "INFO: ${ENV_NAME} allDB Such arns was found : ${rdsArns}"
    for rdsArn in ${rdsArns}; do
        info "INFO: ${ENV_NAME} allDB Lets describe RDS instance name in the account for ${rdsArn}"
        describedRDS=$(describeRDS ${profileID} ${REGION} ${rdsArn} )
        info "INFO: ${ENV_NAME} allDB such instance was found : ${describedRDS}"
        for instanceID in ${describedRDS}; do
           nextstep="yes"
           commontemporary="/tmp/slow-${instanceID}-$datestring.log"
           info "INFO: ${ENV_NAME} ${instanceID} Start to download slowlogs"
            for suff in ${suffixes} ; do
                temporaryfile="/tmp/slow-${instanceID}.${suff}"
                trycounter=0
                while [ ${trycounter} -lt 5 ] ; do
                    info "INFO: ${ENV_NAME} ${instanceID} Downloading  ${temporaryfile}"
                    info "INFO: ${ENV_NAME} ${instanceID} Free disk space before downloading df -h " : $(df -h)
                    downloadLogs=$(downloadLog ${profileID} ${REGION} ${instanceID} slowquery/mysql-slowquery."${suff}" ${temporaryfile})
                    statuscode=$?
                    sleep 2
                    echo "INFO: ${REGION} ${instanceID} ${temporaryfile} stat information " : $(stat -f ${temporaryfile})
                    info "INFO: ${ENV_NAME} ${instanceID} downloadLogs function statuscode=${statuscode}"
                    if [ ${statuscode} -gt 0 ] ; then
                        echo "INFO: ${ENV_NAME} ${instanceID} stdout log file"  $(cat /tmp/app-access.log)
                        echo "CRITICAL: ${ENV_NAME} ${instanceID} An error occurred (DBLogFileNotFoundFault) when calling the DownloadDBLogFilePortion operation: DBLog File: slow-log file is not found on the ${instanceID}. The problem file is slowquery/mysql-slowquery."${suff}" "
                        ((trycounter++))
                        info "INFO: ${ENV_NAME} ${instanceID} counter=${trycounter}"
                        sleep 2
                    else
                        workfolder="${ENV_NAME}/${instanceID}/${datestring}"
                        info "INFO: ${ENV_NAME} ${instanceID} Let's copy ${temporaryfile} to S3 bucket into ${workfolder}"
                        cpslowToS3=$( aws s3 cp ${temporaryfile}  s3://${S3_BUCKET}/slowlogs/${workfolder}/ )
                        temporaryfilesize=$(stat -c%s "$temporaryfile")
                        if [[ ${temporaryfilesize} -le ${CHECKSIZE} ]] ; then
                            echo "ERROR: ${ENV_NAME} ${instanceID} The problem is with downloading ${temporaryfile}. The files size is less than ${CHECKSIZE} bytes"
                            ((trycounter++))
                            sleep 2
                        else
                            info "INFO: ${ENV_NAME} ${instanceID} Downloading finished OK. The size of ${temporaryfile} = ${temporaryfilesize} bytes. Start to add it into  ${commontemporary}"
                            info "INFO: ${ENV_NAME} ${instanceID} Free disk space after downloading ${temporaryfile} df -h " : $(df -h)
                            cat ${temporaryfile} >> ${commontemporary}
                            echo >> ${commontemporary}
                            rm -r ${temporaryfile}
                            commontemporaryfilesize=$(stat -c%s "$commontemporary")
                            info "INFO: ${ENV_NAME} ${instanceID} Size of collecting file is $commontemporary = $commontemporaryfilesize bytes."
                            trycounter=10
                        fi
                    fi
                done
            done
            info "INFO: ${ENV_NAME} ${instanceID} Finished downloading ${instanceID} slowlogs by hours"
            if [[ "${nextstep}" = "yes" && -f "${commontemporary}" ]] ; then
                info "INFO: ${ENV_NAME} ${instanceID}. Starting to digest collected file ${commontemporary} and add result into anemometer database"
                /usr/bin/pt-query-digest --user=$ANEMOMETER_MYSQL_USER --password=$ANEMOMETER_MYSQL_PASSWORD \
                                        --review h=$ANEMOMETER_MYSQL_HOST,D=$ANEMOMETER_MYSQL_DB,t=global_query_review \
                                        --history h=$ANEMOMETER_MYSQL_HOST,D=$ANEMOMETER_MYSQL_DB,t=global_query_review_history \
                                        --no-report --limit=0% \
                                        --filter=" \$event->{Bytes} = length(\$event->{arg}) and \$event->{hostname}=\"${instanceID}\"" \
                                        ${commontemporary}
                statuscode=$?
                info "statuscode=${statuscode} of percona digest tool"
                if [ ${statuscode} -gt 0 ] ; then
                    echo "CRITICAL: ${ENV_NAME} ${instanceID} slowlogs digest problem. the statuscode=${statuscode} "
                else
                    info "INFO: ${ENV_NAME} ${instanceID} Digest of ${commontemporary} was successful"
                    rm -f "${commontemporary}"
                fi
            fi
        done
    done
done

exit 0