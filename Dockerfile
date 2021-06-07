FROM centos:centos7
MAINTAINER Dariya Mykhaylyshyn <mykhaylyshyn.dariya@pdffiller.team>

ENV LANG en_US.utf8
ENV LC_ALL en_US.utf8

RUN yum update -y
RUN yum -y install python perl unzip openssh-server openssh-clients openssl openssl-libs

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

## if you need to switch ssh, uncomment next rows till install percona
#COPY configs/sshd_config /etc/ssh/sshd_config
#
#RUN mkdir -p /root/.ssh/ && \
#    mkdir -p /var/run/sshd && \
#    chmod -rx /var/run/sshd && \
#    ssh-keygen -A
#
##please CHECK that you create the needed key
#COPY authorized-keys/*.pub /root/.ssh/authorized_keys
#RUN chown -R root:root /root/.ssh && chmod -R 600 /root/.ssh
#
#COPY sshd-entrypoint.sh /usr/local/bin/
#RUN chmod +x /usr/local/bin/sshd-entrypoint.sh && \
#    ln -s /usr/local/bin/sshd-entrypoint.sh / && \
#    echo 'root:THEPASSWORDYOUCREATED' | chpasswd

##install percona
RUN yum -y install https://www.percona.com/downloads/percona-toolkit/2.2.19/RPM/percona-toolkit-2.2.19-1.noarch.rpm && \
    yum -y install percona-toolkit

# RUN ln -s /dev/stdout /tmp/app-access.log

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

## if you need to switch ssh, uncomment next row
#EXPOSE 22

ENTRYPOINT ["entrypoint.sh"]
