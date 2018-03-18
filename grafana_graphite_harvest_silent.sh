#!/bin/bash
# Filename:             grafana_graphite_harvest_silent.sh
# By:                   Dan Burkland
# Date:                 2015-12-23
# Purpose:              The purpose of this script is to silently configure Graphite,
#			Grafana, and NetApp Harvest. This script has been designed to be executed within
#			the "dburkland/harvest" Docker container. 

### Setup Graphite ###
echo "Setting up Graphite..."

# Not required in actual script
GRAPHITE_ROOT_PASSWORD=abcd1234

SILENT_GRAPHITE=$(expect -c "

set timeout 10

spawn /usr/lib/python2.7/site-packages/graphite/manage.py syncdb

expect \"Would you like to create one now? (yes/no):\"
send \"yes\r\"

expect \"Username (leave blank to use 'root'):\"
send \"\r\"

expect \"Email address:\"
send \"root@localdomain.com\r\"

expect \"Password:\"
send \"netapp123\r\"

expect \"Password (again):\"
send \"netapp123\r\"

expect eof
")

echo "$SILENT_GRAPHITE"

# Restart mysqld to avoid any database locking issues
systemctl restart mariadb 2>&1

# Fix Graphite Database File Directory Permissions if need be
CARBONUID=$(id -u carbon)
CARBONGID=$(id -g carbon)
CARBONDATADIR="/var/lib/carbon/whisper"
CURCARBONDIROWNER=$(ls -ldn $CARBONDATADIR | awk '{ print $3 }')

if [ "$CURCARBONDIROWNER" -ne "$CARBONUID" ]; then
  echo "Fixing Graphite Database File Directory permissions..."
  chown -Rv ${CARBONUID}:${CARBONGID} $CARBONDATADIR
fi

sed -i 's/MAX_CREATES_PER_MINUTE =.*/MAX_CREATES_PER_MINUTE = 500/g' /etc/carbon/carbon.conf

cat << EOF > /etc/carbon/storage-schemas.conf
# Schema definitions for Whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds.
#
#  [name]
#  pattern = regex
#  retentions = timePerPoint:timeToStore, timePerPoint:timeToStore, ...

# Carbon's internal metrics. This entry should match what is specified in
# CARBON_METRIC_PREFIX and CARBON_METRIC_INTERVAL settings
[carbon]
pattern = ^carbon\.
retentions = 60:90d

# NetApp OPM Performance Data
#[netapp-opm]
#pattern = ^netapp\-opm\..*
#retentions = 5m:100d

# NetApp Harvest Capacity Data
[netapp.capacity]
pattern = ^netapp\.capacity\.*
retentions = 15m:100d, 1d:5y

# NetApp Harvest Poller Capacity Data
[netapp.poller.capacity]
pattern = ^netapp\.poller\.capacity\.*
retentions = 15m:100d, 1d:1y

# NetApp Harvest Performance Data
[netapp.perf]
pattern = ^netapp\.perf\.*
retentions = 60s:30d, 5m:60d, 15m:120d, 1h:1y

# NetApp Harvest Poller Performance Data
[netapp.poller.perf]
pattern = ^netapp\.poller\.perf\.*
retentions = 60s:30d, 5m:60d, 15m:120d, 1h:1y

[default_1min_for_1day]
pattern = .*
retentions = 60s:1h

EOF

cat << EOF > /etc/carbon/storage-aggregation.conf
# Aggregation methods for whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds
#
#  [name]
#  pattern = <regex>
#  xFilesFactor = <float between 0 and 1>
#  aggregationMethod = <average|sum|last|max|min>
#
#  name: Arbitrary unique name for the rule
#  pattern: Regex pattern to match against the metric name
#  xFilesFactor: Ratio of valid data points required for aggregation to the next retention to occur
#  aggregationMethod: function to apply to data points for aggregation
#
[min]
pattern = \.min$
xFilesFactor = 0.1
aggregationMethod = min

[max]
pattern = \.max$
xFilesFactor = 0.1
aggregationMethod = max

[sum]
pattern = \.count$
xFilesFactor = 0
aggregationMethod = sum

[default_average]
pattern = .*
xFilesFactor = 0.5
aggregationMethod = average

EOF

sed -i 's/#LOG_CACHE_PERFORMANCE.*/LOG_CACHE_PERFORMANCE = True/g' /etc/graphite-web/local_settings.py

sed -i 's/Listen 80/Listen 8080/g' /etc/httpd/conf/httpd.conf

cat << EOF > /etc/httpd/conf.d/graphite-web.conf
# Graphite Web Basic mod_wsgi vhost

<VirtualHost *:8080>
  ServerName graphite-web
  DocumentRoot "/usr/share/graphite/webapp"
  ErrorLog /var/log/httpd/graphite-web-error.log
  CustomLog /var/log/httpd/graphite-web-access.log common

  # Header set Access-Control-Allow-Origin "*"
  # Header set Access-Control-Allow-Methods "GET, OPTIONS"
  # Header set Access-Control-Allow-Headers "origin, authorization, accept"
  # Header set Access-Control-Allow-Credentials true

  WSGIScriptAlias / /usr/share/graphite/graphite-web.wsgi
  WSGIImportScript /usr/share/graphite/graphite-web.wsgi process-group=%{GLOBAL} application-group=%{GLOBAL}

  <Location "/content/">
    SetHandler None
  </Location>

  Alias /media/ "/usr/lib/python2.7/site-packages/django/contrib/admin/media/"
  <Location "/media/">
    SetHandler None
  </Location>

  <Directory "/usr/share/graphite/">
    # Apache 2.2
    Require all granted
    Order allow,deny
    Allow from all
  </Directory>
</VirtualHost>
EOF

# Fix directory permissions
chmod 775 /var/log/graphite-web/
chmod 775 /var/lib/graphite-web/

# Restart Apache to apply the previous configuration changes
systemctl restart httpd 2>&1 

echo "Setup of Graphite is complete."
###

### Setup Grafana ###
echo "Setting up Grafana..."

# Configure Grafana to run on port 80
sed -i 's/;http_port.*/http_port = 80/g' /etc/grafana/grafana.ini
setcap 'cap_net_bind_service=+ep' /usr/sbin/grafana-server

# Restart Grafana to apply the change the in previous step
systemctl restart grafana-server 2>&1
sleep 10

# If HTTP/HTTPS proxy environment variables are set, temporarily unset them so the appropriate curl commands do not fail

# Create Graphite Datasource
curl -s --noproxy '*' 'http://admin:admin@localhost:80/api/datasources' -X POST -H 'Content-Type:application/json;charset=UTF-8' --data-binary '{"name":"Graphite","type":"graphite","url":"http://localhost:8080","access":"proxy","isDefault":true}' > /dev/null

# Create and store API key
APIKEYCREATE=$(curl -s --noproxy '*' 'http://admin:admin@localhost:80/api/auth/keys' -X POST -H 'Content-Type:application/json;charset=UTF-8' --data-binary '{"name":"netapp-harvest","role":"Editor"}')
APIKEY=$(echo $APIKEYCREATE | python -c "import json,sys;obj=json.load(sys.stdin);print obj['key'];")

echo "Setup of Grafana is complete."
###

### Setup Harvest ###
echo "Setting up Harvest..."
cd /root
unzip '*netapp-harvest-*.zip' 2>&1
tar xvf *netapp-harvest-*.tgz -C /opt/
#mv -v netapp-harvest /opt/
#mv -vf *db_netapp*.json /opt/netapp-harvest/grafana/

if [ ! -e /opt/netapp-harvest-conf/netapp-harvest.conf ]; then
cat << EOF > /opt/netapp-harvest-conf/netapp-harvest.conf
##
## Configuration file for NetApp Harvest
##
## Create a section header and then populate with key/value parameters
## for each system to monitor.  Lines can be commented out by preceding them
## with a hash symbol ('#').  Values in all capitals should be replaced with
## your values, all other values can be left as-is to use defaults
##
## There are two reserved section names:
## [global]  - Global key/value pairs for installation
## [default] - Any key/value pairs specified here will be the default
##             value for a poller should it not be listed in a poller section.
##

##
## Global reserved section
##

[global]
grafana_api_key = $APIKEY
grafana_url = http://localhost
grafana_dl_tag =

##
## Default reserved section
##

[default]
#====== Graphite server setup defaults ========================================
graphite_enabled  = 1
graphite_server   = localhost
graphite_port     = 2003
graphite_proto    = tcp
normalized_xfer   = mb_per_sec
normalized_time   = millisec
graphite_root     =  default
graphite_meta_metrics_root  = default

#====== Polled host setup defaults ============================================
host_type         = FILER
host_port         = 443
host_enabled      = 1
template          = default
data_update_freq  = 60
ntap_autosupport  = 0
latency_io_reqd   = 10
auth_type         = password
username          = svc-harvest
password          = netapp123
#ssl_cert          = INSERT_PEM_FILE_NAME_HERE
#ssl_key           = INSERT_KEY_FILE_NAME_HERE


##
## Monitored host examples - Use one section like the below for each monitored host
##

#====== 7DOT (node) or cDOT (cluster LIF) for performance info ================
#
# [INSERT_CLUSTER_OR_CONTROLLER_NAME_HERE]
# hostname       = INSERT_IP_ADDRESS_OR_HOSTNAME_OF_CONTROLLER_OR_CLUSTER_LIF_HERE
# site           = INSERT_SITE_IDENTIFIER_HERE

#====== OnCommand Unified Manager (OCUM) for cDOT capacity info ===============
#
# [INSERT_OCUM_SERVER_NAME_HERE]
# hostname          = INSERT_IP_ADDRESS_OR_HOSTNAME_OF_OCUM_SERVER
# site              = INSERT_SITE_IDENTIFIER_HERE
# host_type         = OCUM
# data_update_freq  = 900
# normalized_xfer   = gb_per_sec

EOF
else
	sed -i "s/grafana_api_key.*/grafana_api_key = $APIKEY/g" /opt/netapp-harvest-conf/netapp-harvest.conf
fi

ln -s /opt/netapp-harvest-conf/netapp-harvest.conf /opt/netapp-harvest/netapp-harvest.conf

# Copy NetApp SDK Perl Modules To Harvest Directory
cd /root
unzip netapp-manageability-sdk-*.zip netapp-manageability-sdk-*/lib/perl/NetApp/* 2>&1
mv -v netapp-manageability-sdk-*/lib/perl/NetApp/* /opt/netapp-harvest/lib/

# Copy the updated node dashboard files which include the latest fixes as of 2017-07-13
#mv -v db_netapp-*.json /opt/netapp-harvest/grafana/

# Enable Harvest to start at boot and start it
ln -s /opt/netapp-harvest/util/netapp-harvest /etc/init.d/
chkconfig --add netapp-harvest
chkconfig netapp-harvest on
/etc/init.d/netapp-harvest start 2>&1

# Import the custom NetApp Dashboards into Grafana
/opt/netapp-harvest/netapp-manager -import

# Final restart of Apache & MySQL
systemctl restart mariadb 2>&1
systemctl restart httpd 2>&1 

echo "Setup of Harvest is complete."
###
