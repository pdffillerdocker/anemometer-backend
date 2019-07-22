FROM centos:7
MAINTAINER Dariya Mykhaylyshyn <mykhaylyshyn.dariya@pdffiller.team>

RUN yum update -y
RUN yum -y install python awscli perl

##install percona
RUN yum -y install https://www.percona.com/downloads/percona-toolkit/2.2.19/RPM/percona-toolkit-2.2.19-1.noarch.rpm && \
    yum update percona-release -y && \
    yum -y install percona-toolkit

COPY entrypoint.sh /usr/bin/

RUN chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["bash", "entrypoint.sh"]