FROM centos:7
MAINTAINER Dariya Mykhaylyshyn <mykhaylyshyn.dariya@pdffiller.team>

RUN yum update -y
RUN yum -y install python awscli perl

##instal percona
RUN yum -y install http://www.percona.com/redir/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm
RUN yum update percona-release -y
RUN yum -y install percona-toolkit

COPY entrypoint.sh /usr/bin/

RUN chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["bash", "entrypoint.sh"]