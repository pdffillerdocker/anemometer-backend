FROM centos:7


RUN yum update -y
RUN yum -y install python awscli perl

##instal percona
RUN yum -y install http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum update percona-release -y
RUN yum -y install percona-toolkit

COPY entrypoint.sh /usr/bin/

RUN chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["bash", "entrypoint.sh"]