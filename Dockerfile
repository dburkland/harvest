FROM centos:centos6
MAINTAINER Dan Burkland <dburkland@dburkland.com>
ENV container docker
#PROXY_PLACEHOLDER1
COPY netapp-harvest-*.zip /root/
COPY netapp-manageability-sdk-*.zip /root/
COPY *.sh /root/
COPY bashrc /root/.bashrc
COPY netapp_harvest_automated_setup /etc/init.d/
WORKDIR /root
RUN yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
RUN yum -y update
RUN yum -y install initscripts; rm /etc/rc.d/rc*.d/*
RUN mv /etc/init/serial.conf /etc/init/serial.conf.disabled; \
mv /etc/init/tty.conf /etc/init/tty.conf.disabled; \
mv /etc/init/start-ttys.conf /etc/init/start-ttys.conf.disabled
RUN yum install perl perl-JSON perl-libwww-perl perl-XML-Parser perl-Net-SSLeay perl-Excel-Writer-XLSX perl-Time-HiRes perl-IO-Socket-SSL unzip \
graphite-web mysql mysql-server MySQL-python python-carbon expect -y
RUN yum install https://grafanarel.s3.amazonaws.com/builds/grafana-3.1.1-1470047149.x86_64.rpm -y; yum clean all
RUN chkconfig carbon-aggregator on; chkconfig carbon-cache on; chkconfig grafana-server on; chkconfig httpd on; chkconfig mysqld on; chkconfig --add netapp_harvest_automated_setup; chkconfig netapp_harvest_automated_setup on
EXPOSE 80
EXPOSE 2003
EXPOSE 2004
EXPOSE 8080
#PROXY_PLACEHOLDER2
CMD ["/sbin/init"]
