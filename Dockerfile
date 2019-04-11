FROM centos:latest
MAINTAINER Dan Burkland <dburkland@dburkland.com>
ENV container docker
COPY netapp-harvest-*.zip /root/
COPY netapp-manageability-sdk-* /root/
COPY *.sh /root/
#COPY *.json /root/
COPY bashrc /root/.bashrc
COPY netapp_harvest_automated_setup /etc/init.d/
WORKDIR /root
RUN cat netapp-manageability-sdk-9.5* > netapp-manageability-sdk-9.5.zip
RUN mkdir /opt/netapp-harvest-conf
RUN yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
RUN yum -y update
RUN yum -y install initscripts; rm /etc/rc.d/rc*.d/*
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;
RUN yum install -y rsyslog net-tools git wget openssh-clients unzip mariadb-server php-pdo php php-mysql php-gd php-fpm perl \
perl-JSON perl-libwww-perl perl-XML-Parser perl-Net-SSLeay perl-Excel-Writer-XLSX perl-Time-HiRes perl-IO-Socket-SSL perl-LWP-Protocol-https unzip \
graphite-web mariadb mariadb-server MySQL-python python-carbon expect
RUN yum install https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-5.0.3-1.x86_64.rpm -y; yum clean all
RUN systemctl enable carbon-aggregator; systemctl enable carbon-cache; systemctl enable grafana-server; systemctl enable httpd; systemctl enable mariadb; chkconfig --add netapp_harvest_automated_setup; chkconfig netapp_harvest_automated_setup on
EXPOSE 80
EXPOSE 2003
EXPOSE 2004
EXPOSE 8080

VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]