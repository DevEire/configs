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

command_exists () {
	if [[ "$OSTYPE" == "linux-gnu" ]]; then
        hash "$1" 2>/dev/null || { echo >&2 "Installing $1 ..."; apt-get install --assume-yes "$1"; }
	fi
}


apt update

#  Check for required binaries
command_exists "git"
command_exists "wget"
command_exists "mysql-server"
command_exists "nginx"

cd /opt

# Create project directory
PROJECT_TOP_LEVEL=`echo $PROJECT | awk '{print toupper($0)}'`
mkdir ${PROJECT_TOP_LEVEL}
cd ${PROJECT_TOP_LEVEL}

echo "Geting and extract server binaries"
wget ${TOMCAT_PATH}${TOMCAT_DIR}${TOMCAT_EXT}
wget ${SOLR_PATH}${SOLR_DIR}${SOLR_EXT}

echo "Extracting server binaries"
tar -xvzf ${TOMCAT_DIR}${TOMCAT_EXT}
tar -xvzf ${SOLR_DIR}${SOLR_EXT}


echo "Download Java8"
wget ${JAVA_PATH}${JAVA_DIR}${JAVA_EXT}
tar -xvzf ${JAVA_DIR}${JAVA_EXT}
ln -s  ${JAVA_EXPDIR} "java"
export JAVA_HOME="/opt/BRIGHTSPOT/java/"


echo "Setting up solr..."
cp -R "${SOLR_DIR}/example/solr" "${TOMCAT_DIR}/"
cp -rv "${SOLR_DIR}/example/lib/ext/"* "${TOMCAT_DIR}/lib"
cp "${SOLR_DIR}/dist/${SOLR_DIR}.war" "${TOMCAT_DIR}/webapps/solr.war"

echo "Download and install Solr config"
wget https://raw.githubusercontent.com/perfectsense/dari/master/etc/solr/config-5.xml
wget https://raw.githubusercontent.com/perfectsense/dari/master/etc/solr/schema-12.xml
mv config-5.xml "${TOMCAT_DIR}/solr/collection1/conf/solrconfig.xml"
mv schema-12.xml "${TOMCAT_DIR}/solr/collection1/conf/schema.xml"

echo "Using bare bones tomcat config.."
wget https://raw.githubusercontent.com/DevEire/configs/master/context.xml
wget https://raw.githubusercontent.com/DevEire/configs/master/server.xml

rm -rf "${TOMCAT_DIR}/conf/server.xml"
rm -rf "${TOMCAT_DIR}/conf/context.xml"
mv server.xml "${TOMCAT_DIR}/conf/server.xml"
mv context.xml "${TOMCAT_DIR}/conf/context.xml"


echo "Getting Mysql driver..."
wget "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.40.tar.gz"
tar -xvzf mysql-connector-java-5.1.40.tar.gz
cp "mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar" "${TOMCAT_DIR}/lib"
rm -f mysql-connector-java-5.1.40.tar.gz
rm -rf mysql-connector-java-5.1.40

echo "Create local database"

if [[ "$MYSQL_PASS" -ne "" ]]; then
	echo "CREATE DATABASE IF NOT EXISTS ${MYSQL_DB}" | /usr/bin/mysql"-u$MYSQL_USER" "-p$MYSQL_PASS"
else
	echo "CREATE DATABASE IF NOT EXISTS ${MYSQL_DB}" | /usr/bin/mysql "-u$MYSQL_USER"
fi

	#	git clone "${CODE}"
	# if this is a base project then rename with project name
	#if [ $BASE_PROJECT -eq "1" ]; then
	#	mv base-project "${PROJECT}"
	#	sed -i "" 's|<artifactId>base-project</artifactId>|<artifactId>'${PROJECT}'</artifactId>|g' "${PROJECT}/pom.xml"
	#fi

	#echo "Build project..."
	#mvn -f "${PROJECT}/pom.xml" clean install

	#echo "Link target directory to tomcat.."	
	#target_dir=`find ${PROJECT}/target -type f -name "*.war" | sed -e 's/'${PROJECT}'\/\(.*\).war/\1/'`
	#rm -rf "${TOMCAT_DIR}/webapps/ROOT"
	#ln -sf "../../${PROJECT}/${target_dir}" "${TOMCAT_DIR}/webapps/ROOT"

	echo "Clean up.."
	rm -f ${TOMCAT_DIR}${TOMCAT_EXT}
	rm -f ${SOLR_DIR}${SOLR_EXT}


unlink /etc/nginx/sites-enabled/default
wget https://raw.githubusercontent.com/DevEire/configs/master/readymade.conf
mv readymade.conf /etc/nginx/sites-enabled/readymade.conf

systemctl start nginx.service


echo "Start tomcat.."
${TOMCAT_DIR}/bin/startup.sh
