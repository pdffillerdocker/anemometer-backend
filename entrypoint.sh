#!/usr/bin/env bash
set -x

# Start download slowlog from RDS instances in aws account
    DATE=$(date +%Y%m%d)

    function downloadLog () {
      local instanceID=$1
      local log=$2


      /usr/bin/aws rds download-db-log-file-portion  \
        --output text \
        --db-instance-identifier ${instanceID} \
        --log-file-name $log \
        --starting-token 0
    }

    instanceIDs=$(/usr/bin/aws rds  describe-db-instances --region us-east-1 --query 'DBInstances[*].[DBInstanceIdentifier]' --output text)
        for instanceID in ${instanceIDs}; do
                echo "Start to download ${instanceID} slowlog"
                downloadLog ${instanceID} slowquery/mysql-slowquery.log > /tmp/slow-${instanceID}-$DATE.log

                echo "Start to download ${instanceID} slowlog by hours"
                for i in $(seq 0 23); do
                  downloadLog ${instanceID} slowquery/mysql-slowquery.log.$i >> /tmp/slow-${instanceID}-$DATE.log

                done

                echo "Finished downloading ${instanceID} slowlog by hours"
# Parse  mysql slow log and add result into anemometer database
                echo "Start digest /tmp/slow-${instanceID}-$DATE.log"

                /usr/bin/pt-query-digest --user=$ANEMOMETER_MYSQL_USER --password=$ANEMOMETER_MYSQL_PASSWORD \
                                         --review h=$ANEMOMETER_MYSQL_HOST,D=$ANEMOMETER_MYSQL_DB,t=global_query_review \
                                         --history h=$ANEMOMETER_MYSQL_HOST,D=$ANEMOMETER_MYSQL_DB,t=global_query_review_history \
                                         --no-report --limit=0% \
                                         --filter=" \$event->{Bytes} = length(\$event->{arg}) and \$event->{hostname}=\"${instanceID}\"" \
                                         /tmp/slow-${instanceID}-$DATE.log

                echo "Finished digesting /tmp/slow-${instanceID}-$DATE.log"
                echo "Delete digest /tmp/slow-${instanceID}-$DATE.log file"

                rm -f /tmp/slow-$instanceID-$DATE.log
                sleep 5

        done

exit 0