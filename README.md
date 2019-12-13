# Anemometer-backend for anemometer service

This service is backend part of Anemometer service. 
To view the visual result you need to install the web server. Please follow the link  https://github.com/pdffillerdocker/anemometer-front

This Anemometer-backend  is used for 
- describing RDSs instances in one AWS account 
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
| ENVIRONMENT  | The environment name |   |
| REGION  | The region name |   |
| EXCLUDED_RDS  | The list of RDS names where don't need to download slow-logs |   |
| DEBUGLEVEL |The parameter shows more information messages of the script. It should be 0 or 1. The value 0 will show only error messages. The values 1 will show all messages.  | 0   |

**Warning** don't change ANEMOMETER_MYSQL_DB value

### For local debug run command 

`$ docker run -d  -e DEBUGLEVEL="1"  pdffiller/anemometer-backend:tag `

### License

 pdffillerdocker/anemometer-backend is licensed under the [MIT License](https://github.com/pdffillerdocker/anemometer-backend/blob/master/LICENSE)
