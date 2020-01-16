FROM centos:centos7
MAINTAINER Dariya Mykhaylyshyn <mykhaylyshyn.dariya@pdffiller.team>


ENV LANG en_US.utf8
ENV LC_ALL en_US.utf8

RUN yum update -y
RUN yum -y install python awscli perl unzip

##install percona
RUN yum -y install https://www.percona.com/downloads/percona-toolkit/2.2.19/RPM/percona-toolkit-2.2.19-1.noarch.rpm && \
    yum -y install percona-toolkit

# RUN ln -s /dev/stdout /tmp/app-access.log

COPY entrypoint.sh /usr/bin/

RUN chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["bash", "entrypoint.sh"]