#!/usr/bin/env bash
#set -x

# Set external variable
# This parameter is using for checking slowlog per hour by size. If the file's size is
# less than 1024 bytes the slowlog file isn't valid for parsing.
CHECKSIZE=1023

# Set internal variable
declare -i statuscode
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
   local instanceID=$1
   local log=$2
   local downloadedfile=$3

   /usr/bin/aws rds download-db-log-file-portion  \
   --output text \
   --db-instance-identifier ${instanceID} \
   --log-file-name $log \
   --starting-token 0 > ${downloadedfile}
}

for hour in $(seq 0 23) ; do suffixes="${suffixes} log.$hour" ; done
info "INFO: ${ENV_NAME} allDB The list of suffixes for slowlogs files ${suffixes} were created"
info "INFO: ${ENV_NAME} allDB Lets describe RDS instances in the account"
instanceIDs=$(/usr/bin/aws rds  describe-db-instances --region us-east-1 --query 'DBInstances[*].[DBInstanceIdentifier]' --output text)
info "INFO: ${ENV_NAME} allDB Such instances was found : ${instanceIDs}"
for instanceID in ${instanceIDs}; do
   nextstep="yes"
   commontemporary="/tmp/slow-${instanceID}-$datestring.log"
   rm -f "${commontemporary}"
   info "INFO: ${ENV_NAME} ${instanceID} Start to download slowlogs"
   for suff in ${suffixes} ; do
        temporaryfile="/tmp/slow-${instanceID}.${suff}"
        rm -f "${temporaryfile}"
        info "INFO: ${ENV_NAME} ${instanceID} Downloading  ${temporaryfile}"
        downloadLogs=$(downloadLog ${instanceID} slowquery/mysql-slowquery."${suff}" ${temporaryfile} 2>&1)
        statuscode=$?
        if [ ${statuscode} -gt 0 ] ; then
            echo "ERROR: ${ENV_NAME} ${instanceID} An error occurred (DBLogFileNotFoundFault) when calling the DownloadDBLogFilePortion operation: DBLog File: slow-log file is not found on the ${instanceID}"
        else
            info  "INFO: ${ENV_NAME} ${instanceID} The slow-log is ON"
        fi
        temporaryfilesize=$(stat -c%s "$temporaryfile")
        if [[ ${temporaryfilesize} -le ${CHECKSIZE} ]] ; then
            echo "ERROR: ${ENV_NAME} ${instanceID} The problem is with downloading ${temporaryfile}. The file's size is less than ${CHECKSIZE} bytes"
            nextstep="no"
            break
        else
            info "INFO: ${ENV_NAME} ${instanceID} Downloading finished OK. The size of ${temporaryfile} = ${temporaryfilesize} bytes. Start to add it into  ${commontemporary}"
            cat ${temporaryfile} >> ${commontemporary}
            rm -r ${temporaryfile}
            commontemporaryfilesize=$(stat -c%s "$commontemporary")
            info "INFO: ${ENV_NAME} ${instanceID} Size of collecting file is $commontemporary = $commontemporaryfilesize bytes."
        fi
   done
   info "INFO: ${ENV_NAME} ${instanceID} Finished downloading ${instanceID} slowlogs by hours"
   if [ "${nextstep}" = "yes" ] ; then
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
          echo "ERROR: ${ENV_NAME} ${instanceID} to digest slowlogs"
       else
          info "INFO: ${ENV_NAME} ${instanceID} Digest of ${commontemporary} was successful"
          rm -f "${commontemporary}"
       fi
   fi
done
exit 0