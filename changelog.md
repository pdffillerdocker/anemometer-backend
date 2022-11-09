### 3.0.0
*Changes :*
- add receiving accountIDs from organization account
- collecting algorithm. The slow logs will be collected with assumed role

*Updates :*
- add environment into query for filtering slowlog 

*Fix :*
- slowlogs filename format for RDS mysql engine

### 2.0.30
*Changes :*
- add possibility to store slow-logs to s3
- collecting algorithm. The slow logs will be collected from one AWS account
- realize possibility to download slowlogs from Aurora RDS (engine: aurora and aurora-mysql)
- add code that switch on ssh in Fargate container.

---

### 2.0.29 - Working images
*Changes :*
- debug mode - turn off

---

### 2.0.28 - bad image. please don't use it
*Changes :*
- debug mode - turn off

---

### 2.0.27 - TEST IMAGE
*Changes :*
- test image based on centos
- debug is on 
- for test RDS use tag Key=Slowlog,Values=true

---

### 2.0.26
*Changes :*
- itest image based on ubuntu

---

### 2.0.25
*Changes :*
- test image

---

### 2.0.24
*Changes :*
- test image

---

### 2.0.23
*Changes :*
- fix debug output

---

### 2.0.21
*Changes :*
- add LC_ALL en_US.utf8

---

### 2.0.20
*Changes :*
- add ENV LANG en_US.utf8
- remove stat -f for temporary downloaded file
- set -x is off

---

### 2.0.19
*Changes :*
- add stat -f for temporary downloaded file
- set -x is on

---

### 2.0.18
*Changes :*
- add debug option for aws rds download-db-log-file-portion

---

### 2.0.17
*Changes :*
- remove Excluded_RDS variable
- add a function that filters ARNs RDS by tag where slow log must be downloaded

---

### 2.0.16
*Changes :*
add check disk space before and after downloading slow-logs

---

### 2.0.15
*Changes :*
fix condition for digest

---

### 2.0.14
*Changes :*

---

### 2.0.13
*Changes :*
turn-on debug option into download-db-log-file-portion

---
### 2.0.12
*Changes :*
update filter that will describe aurora-mysql engine"

---

### 2.0.11
* Update: *
Critical message - add slow-log name during download problem

---

### 2.0.10
*Changes :*
 
---

### 2.0.9
*Changes :*
add Excluded_RDS and REGION variables

---

### 2.0.8
*Changes :*
add filter that will exclude Postgres db from describing RDS

---

### 2.0.7
*Changes :*
add CRITICAL debug level

---

### 2.0.5
*Changes :*
delete break from hourly temporaryfilesize checking  

---

### 2.0.4
*Changes :*
add definition "allDB" for the info message

---

### 2.0.3
*Changes :*
add MIT license
add verification if slow-log is on

---
### 2.0.2
*Changes :*
add ENV_NAME variable
 
---
 
### v2.0.1
 *Changes :*
downgrade percona tools release to 2.2.19

---

### v2.0.0
 *Changes :*
upgrade percona tools release to 3.0.15

---

### v1.0.0
First release based on bash script with debug level

---