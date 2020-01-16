#!/usr/bin/env bash
# set -x

/usr/bin/aws --version
python --version

sleep 5

# Set external variable
# This parameter is using for checking slowlog per hour by size. If the file's size is
# less than 1024 bytes the slowlog file isn't valid for parsing.
CHECKSIZE=1023

# Set internal variable
declare -i statuscode
declare -i trycounter
datestring=$(date +%Y%m%d)

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
   local region=$1
   local instanceID=$2
   local log=$3
   local downloadedfile=$4

   /usr/bin/aws rds download-db-log-file-portion  \
   --region ${REGION} \
   --output text \
   --db-instance-identifier ${instanceID} \
   --log-file-name $log \
   --starting-token 0 >${downloadedfile} 2>/tmp/anenom.err
#   err="$(cat /tmp/anenom.err)"
#   rm /tmp/anenom.err
#   --debug \
}

for hour in $(seq 0 23) ; do suffixes="${suffixes} log.$hour" ; done
info "INFO: ${ENV_NAME} allDB The list of suffixes for slowlogs files ${suffixes} were created"
info "INFO: ${ENV_NAME} allDB Lets find RDS ARNs  where tag Anemometer=true"
rdsArns=$(/usr/bin/aws resourcegroupstaggingapi get-resources --region ${REGION} --resource-type-filters rds:db --query 'ResourceTagMappingList[*].[ResourceARN]' --tag-filters Key=Anemometer,Values=true --output text)
info "INFO: ${ENV_NAME} allDB Such arns was found : ${rdsArns}"
for rdsArn in ${rdsArns}; do
    info "INFO: ${ENV_NAME} allDB Lets describe RDS instance name in the account for ${rdsArn}"
    describedRDS=$(/usr/bin/aws rds describe-db-instances --region ${REGION} --filters "Name=db-instance-id,Values=${rdsArn}" --query 'DBInstances[*].[DBInstanceIdentifier]' --output text)
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
               downloadLogs=$(downloadLog ${REGION} ${instanceID} slowquery/mysql-slowquery."${suff}" ${temporaryfile})
               statuscode=$?
               sleep 2
               # echo "INFO: ${REGION} ${instanceID} ${temporaryfile} stat information " : $(stat -f ${temporaryfile})
               info "INFO: ${ENV_NAME} ${instanceID} downloadLogs function statuscode=${statuscode}"
               if [ ${statuscode} -gt 0 ] ; then
                   err="$(cat /tmp/anenom.err)"
                   echo "CRITICAL: ${ENV_NAME} ${instanceID} An error occurred (DBLogFileNotFoundFault) when calling the DownloadDBLogFilePortion operation: DBLog File: slow-log file is not found on the ${instanceID}. The problem file is slowquery/mysql-slowquery."${suff}" "
                   ((trycounter++))
                   info "INFO: ${ENV_NAME} ${instanceID} counter=${trycounter}"
                   sleep 3
               else
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
exit 0