#!/bin/bash

PROJECT="brightspot"

MYSQL_USER="root"
MYSQL_PASS=""
MYSQL_DB=${PROJECT}

TOMCAT_PATH="http://archive.apache.org/dist/tomcat/tomcat-8/v8.0.32/bin/"
TOMCAT_DIR="apache-tomcat-8.0.32"
TOMCAT_EXT=".tar.gz"

SOLR_PATH="http://archive.apache.org/dist/lucene/solr/4.8.1/"
SOLR_DIR="solr-4.8.1"
SOLR_EXT=".tgz"

JAVA_PATH="https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u212-b03/"
JAVA_DIR="OpenJDK8U-jre_x64_linux_hotspot_8u212b03"
JAVA_EXPDIR="jdk8u212-b03-jre"
JAVA_EXT=".tar.gz"

cmd_exists () {
	if [[ "$OSTYPE" == "linux-gnu" ]]; then
        hash "$1" 2>/dev/null || { echo >&2 "Installing $1 ..."; apt-get install --assume-yes "$1"; }
	fi
}

cmd_wgetWithRetries () {
	while sleep 1;
	do
        wget -O $2 $1 -t 90 >& /dev/null
        if( test $? -eq 0 ) then
                echo "Got " +$1
                break;
        else
                echo "Retrying for " + $1
        fi
	done

}

export DEBIAN_FRONTEND=noninteractive

apt update

#  Check for required binaries
cmd_exists "wget"
sleep 1
cmd_exists "nginx"
sleep 1

systemctl start nginx.service

#Start nginx first so users get status page while env is getting setup
sleep 1
cd /opt
unlink /etc/nginx/sites-enabled/default
cmd_wgetWithRetries https://raw.githubusercontent.com/DevEire/configs/master/nginx-waiting.conf nginx-waiting.conf
cmd_wgetWithRetries https://raw.githubusercontent.com/DevEire/configs/master/readymade-building.html readymade-building.html
mv  readymade-building.html /usr/share/nginx/html/readymade-building.html
mv nginx-waiting.conf /etc/nginx/sites-enabled/nginx.conf

systemctl restart nginx.service

# Fetch Mysql
cmd_exists "mysql-server"

# Create project directory
PROJECT_TOP_LEVEL=`echo $PROJECT | awk '{print toupper($0)}'`
mkdir ${PROJECT_TOP_LEVEL}
cd ${PROJECT_TOP_LEVEL}

echo "Geting and extract server binaries"
cmd_wgetWithRetries ${TOMCAT_PATH}${TOMCAT_DIR}${TOMCAT_EXT} ${TOMCAT_DIR}${TOMCAT_EXT}
cmd_wgetWithRetries ${SOLR_PATH}${SOLR_DIR}${SOLR_EXT} ${SOLR_DIR}${SOLR_EXT}

echo "Extracting server binaries"
tar -xvzf ${TOMCAT_DIR}${TOMCAT_EXT}
tar -xvzf ${SOLR_DIR}${SOLR_EXT}


echo "Download Java8"
cmd_wgetWithRetries ${JAVA_PATH}${JAVA_DIR}${JAVA_EXT} ${JAVA_DIR}${JAVA_EXT}
tar -xvzf ${JAVA_DIR}${JAVA_EXT}
ln -s  ${JAVA_EXPDIR} "java"
export JAVA_HOME="/opt/BRIGHTSPOT/java/"
export JAVA_OPTS="-Dsolr.solr.home=/opt/BRIGHTSPOT/${TOMCAT_DIR}/solr"
export CLASSPATH="$CLASSPATH:/opt/${PROJECT_TOP_LEVEL}/${TOMCAT_DIR}/solr/collection1/conf/"

echo "Using bare bones tomcat config.."
cmd_wgetWithRetries https://raw.githubusercontent.com/DevEire/configs/master/context.xml context.xml
cmd_wgetWithRetries https://raw.githubusercontent.com/DevEire/configs/master/server.xml server.xml

rm -rf "${TOMCAT_DIR}/conf/server.xml"
rm -rf "${TOMCAT_DIR}/conf/context.xml"
mv server.xml "${TOMCAT_DIR}/conf/server.xml"
mv context.xml "${TOMCAT_DIR}/conf/context.xml"


echo "Setting up solr..."
cp -R "${SOLR_DIR}/example/solr" "${TOMCAT_DIR}/"
cp -rv "${SOLR_DIR}/example/lib/ext/"* "${TOMCAT_DIR}/lib"
cp "${SOLR_DIR}/dist/${SOLR_DIR}.war" "${TOMCAT_DIR}/webapps/solr.war"

echo "Download and install Solr config"
cmd_wgetWithRetries https://raw.githubusercontent.com/perfectsense/dari/master/etc/solr/config-5.xml config-5.xml
cmd_wgetWithRetries https://raw.githubusercontent.com/perfectsense/dari/master/etc/solr/schema-12.xml schema-12.xml
mkdir -p "/opt/${PROJECT_TOP_LEVEL}/${TOMCAT_DIR}/solr/collection1/conf/"
mv config-5.xml "/opt/${PROJECT_TOP_LEVEL}/${TOMCAT_DIR}/solr/collection1/conf/solrconfig.xml"
mv schema-12.xml "/opt/${PROJECT_TOP_LEVEL}/${TOMCAT_DIR}/solr/collection1/conf/schema.xml"



echo "Getting Mysql driver..."
cmd_wgetWithRetries https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.40.tar.gz  mysql-connector-java-5.1.40.tar.gz 
tar -xvzf mysql-connector-java-5.1.40.tar.gz
cp "mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar" "${TOMCAT_DIR}/lib"
rm -f mysql-connector-java-5.1.40.tar.gz
rm -rf mysql-connector-java-5.1.40

echo "Create local database"
echo "CREATE DATABASE IF NOT EXISTS ${MYSQL_DB}" | /usr/bin/mysql "-u$MYSQL_USER"
echo "grant all privileges on *.* to 'brightspot'@'localhost' identified by 'p8ssw0rd' with grant option" | /usr/bin/mysql "-u$MYSQL_USER"
echo "flush privileges"  | /usr/bin/mysql "-u$MYSQL_USER"


rm -rf /opt/BRIGHTSPOT/apache-tomcat-8.0.32/webapps/ROOT
rm -rf /opt/BRIGHTSPOT/apache-tomcat-8.0.32/webapps/docs
rm -rf /opt/BRIGHTSPOT/apache-tomcat-8.0.32/webapps/examples
rm -rf /opt/BRIGHTSPOT/apache-tomcat-8.0.32/webapps/host-manager
rm -rf /opt/BRIGHTSPOT/apache-tomcat-8.0.32/webapps/manager

cmd_wgetWithRetries  https://s3-eu-west-1.amazonaws.com/deveire-readymade/express-site-4.1-SNAPSHOT.war express-site-4.1-SNAPSHOT.war
cp express-site-4.1-SNAPSHOT.war /opt/BRIGHTSPOT/apache-tomcat-8.0.32/webapps/ROOT.war

echo "Clean up.."
rm -f ${TOMCAT_DIR}${TOMCAT_EXT}
rm -f ${SOLR_DIR}${SOLR_EXT}

echo "Start tomcat.."
${TOMCAT_DIR}/bin/startup.sh

while sleep 1;
do
        wget -O - -t 5 http://127.0.0.1:8080/ >& /dev/null
        if( test $? -eq 0 ) then
                echo "Tomcat Running"
                break;
        else
                echo "Tomcat Still Starting up..."
        fi
done
sleep 2

cmd_wgetWithRetries https://raw.githubusercontent.com/DevEire/configs/master/nginx.conf nginx.conf
mv nginx.conf /etc/nginx/sites-enabled/nginx.conf
systemctl restart nginx.service



