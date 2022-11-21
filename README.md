# Anemometer-backend for anemometer service

This service is backend part of Anemometer service. 
To view the visual result you need to install the web server. Please follow the link  https://github.com/pdffillerdocker/anemometer-front

This Anemometer-backend is used for 
- describing RDSs instances in AWS accounts that you will need from one.
- store slow-log origins file on S3 
- collecting slow log for last 24 hours and analyze with  pt-query-digest (Percona Tools) after analyzing push data to anemometer-front service and then exit from the container

Image create by launch on ECS or FARGATE container via scheduler

The RDS instance must have 2 tags Anemometer=true and Env=value from ENV_NAMES_LIST

### Environment Variables

|Name | Description                                                                                                                                                       | Default value  |
| ------------ |-------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|
| ANEMOMETER_MYSQL_HOST | The database hostname where slow logs will be stored                                                                                                              |                |
| ANEMOMETER_MYSQL_USER | Username for the master DB user                                                                                                                                   |                |
| ANEMOMETER_MYSQL_PASSWORD | The master password                                                                                                                                               |                |
| ANEMOMETER_MYSQL_PORT | The port on which the DB accepts connections                                                                                                                      |                |
| ANEMOMETER_MYSQL_DB | The database name                                                                                                                                                 | slow_query_log |
| S3_BUCKET  | The bucket name where slow log origins will be stored                                                                                                             |                |
| SERVICE_NAME  | The service name                                                                                                                                                  |                |
| REGION  | The region name                                                                                                                                                   |                |
| COLLECTSLOWLOGSROLE | The role name that allows collect slow logs from RDS                                                                                                              |                |
| LISTACCOUNTIDSROLE | The role name that allows list accountIDs from organization account                                                                                               |                |
| ENV_NAMES_LIST | The value for Env tag                                                                                                                                             |                |
| DEBUGLEVEL  | The parameter shows more information messages of the script. It should be 0 or 1. The value 0 will show only error messages. The values 1 will show all messages. | 0              |

### Secrets Variables

|Name | Description                          | Default value  |
| ------------ |--------------------------------------|----------------|
| STSEXTERNALIDs | The value for sts-external-id option |                |

**Warning** don't change ANEMOMETER_MYSQL_DB value

### For local debug run command 

`$ docker run -d  -e DEBUGLEVEL="1"  pdffiller/anemometer-backend:tag `

### License

pdffillerdocker/anemometer-backend is licensed under the [MIT License](https://github.com/pdffillerdocker/anemometer-backend/blob/master/LICENSE)
