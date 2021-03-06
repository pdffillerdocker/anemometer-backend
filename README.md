# Anemometer-backend for anemometer service

This service is backend part of Anemometer service. 
To view the visual result you need to install the web server. Please follow the link  https://github.com/pdffillerdocker/anemometer-front

This Anemometer-backend is used for 
- describing RDSs instances in AWS accounts that you will need from one.
- store slow-log origins file on S3 
- collecting slow log for last 24 hours and analyze with  pt-query-digest (Percona Tools) after analyzing push data to anemometer-front service and then exit from the container

Image create by launch on ECS or FARGATE container via scheduler

### Environment Variables

|Name |  Description | Default value  |
| ------------ | ------------ | ------------ |
| ANEMOMETER_MYSQL_HOST  |The database hostname where slow logs will be stored  |   |
| ANEMOMETER_MYSQL_USER |  Username for the master DB user |   |
| ANEMOMETER_MYSQL_PASSWORD  | The master password  |   |
| ANEMOMETER_MYSQL_PORT   | The port on which the DB accepts connections  |   |
| ANEMOMETER_MYSQL_DB  | The database name |  slow_query_log |
| ENV_ORIGIN_NAME  | The environment name where collector will be run |   |
| REGION  | The region name |   |
| S3_BUCKET  | The bucket name where slow log origins will be stored|   |
| S3_SECRET  | The bucket name where credentials for AWS accounts will be located |   |
| DEBUGLEVEL |The parameter shows more information messages of the script. It should be 0 or 1. The value 0 will show only error messages. The values 1 will show all messages.  | 0   |

**Warning** don't change ANEMOMETER_MYSQL_DB value

### For local debug run command 

`$ docker run -d  -e DEBUGLEVEL="1"  pdffiller/anemometer-backend:tag `

### License

 pdffillerdocker/anemometer-backend is licensed under the [MIT License](https://github.com/pdffillerdocker/anemometer-backend/blob/master/LICENSE)
