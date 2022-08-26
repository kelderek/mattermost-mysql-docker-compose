#!/bin/bash
echo
echo "Before continuing, make sure you have:"
echo "--Updated the variables in this file to match your environment"
echo "--Setup your .env file based on the env.example file"
echo "--If you use a database name other than mattermost, you have updated the mysql8-mattermost.sql script with the correct database name"
echo "--You have at least read rights to all files and folders in the source server's mattermost data, config, logs, client/plugins, and plugins folders"
echo "--You have at least read rights to all files and folders in the source server's MySQL data folder"
echo "--Stopped the MySQL service on the source server unless you are just pre-syncing the data"
echo "--The passwords available to ssh from the source server(s) and to connect to MySQL as root"
echo "--Run this script as root or with sudo"
echo
while true
do
   read -p "Do you want to proceed? (yes/NO) " PROMPT
   if [ "${PROMPT,,}" == "yes" ] || [ "${PROMPT,,}" == "y" ]
   then
      break
   elif [ "${PROMPT,,}" == "no" ] || [ "${PROMPT,,}" == "n" ] || [ "${PROMPT,,}" == "" ]
   then
      echo "Cancelling, no changes have been made to the system.."
      exit
   fi
   echo "Sorry, I didn't understand that. Please type yes or no"
done

#variables
MIGRATION_USER=migration_user
SOURCE_MATTERMOST_HOST=mattermost_server
SOURCE_MATTERMOST_PATH=/opt/mattermost
SOURCE_MYSQL_HOST=mysql_server
SOURCE_MYSQL_PATH=/var/lib/mysql
DEST_COMPOSE_PATH=/etc/docker/compose/mattermost
DEST_MATTERMOST_PATH=/etc/docker/compose/mattermost/volumes/mattermost
DEST_MYSQL_PATH=/etc/docker/compose/mattermost/volumes/mysql

echo
echo "Creating the data folders..."
mkdir -p ${DEST_MATTERMOST_PATH}/{data,config,logs,client/plugins,plugins}
mkdir -p ${DEST_MYSQL_PATH}

echo
echo
echo "Syncing up the files from the source mattermost server..."
rsync -rlpt --delete --info=progress2 ${MIGRATION_USER}@${SOURCE_MATTERMOST_HOST}:${SOURCE_MATTERMOST_PATH}/data ${MIGRATION_USER}@${SOURCE_MATTERMOST_HOST}:${SOURCE_MATTERMOST_PATH}/config ${MIGRATION_USER}@${SOURCE_MATTERMOST_HOST}:${SOURCE_MATTERMOST_PATH}/logs ${MIGRATION_USER}@${SOURCE_MATTERMOST_HOST}:${SOURCE_MATTERMOST_PATH}/client/plugins ${MIGRATION_USER}@${SOURCE_MATTERMOST_HOST}:${SOURCE_MATTERMOST_PATH}/plugins ${DEST_MATTERMOST_PATH}
echo
echo
echo "Syncing up the files from the source database server..."
rsync -a --delete --info=progress2 ${MIGRATION_USER}@${SOURCE_MYSQL_HOST}:${SOURCE_MYSQL_PATH}/ ${DEST_MYSQL_PATH}

echo
echo "Data sync is complete.  If there were errors above or you were just pre-syncing the data, stop the script now and run it again when the errors have been resolved and/or the source mattermost and MySQL services have been stopped."
while true
do
   read -p "Do you want to proceed? (yes/NO) " PROMPT
   if [ "${PROMPT,,}" == "yes" ] || [ "${PROMPT,,}" == "y" ]
   then
      break
   elif [ "${PROMPT,,}" == "no" ] || [ "${PROMPT,,}" == "n" ] || [ "${PROMPT,,}" == "" ]
   then
      echo "Ending the script now."
      exit
   fi
   echo "Sorry, I didn't understand that. Please type yes or no"
done

echo
echo "Setting correct ownership (id 2000 is mattermost user in the container)..."
chown -R 2000:2000 ${DEST_MATTERMOST_PATH}

echo "Updating config.json..."
#modify config.json directory under filesettings to set the new data path:
sed -i.bak "s%\"Directory\": \"${SOURCE_MATTERMOST_PATH}%\"Directory\": \"/mattermost%g" ${DEST_MATTERMOST_PATH}/config/config.json

#take sensitive db connection info out of config.json now that it is no longer needed there because it gets it from .env and docker-compose.yml
sed -i 's%"DataSource".*%"DataSource": "mmuser:mmuser-password@tcp(mattermost_mysql:3306)/mattermost?charset=utf8mb4,utf8\u0026writeTimeout=30s",%g' ${DEST_MATTERMOST_PATH}/config/config.json

echo
echo
echo "Starting MySQL only to allow for data upgrade and migration tasks..."
#start mysql by itself so it can automatically upgrade my data files from version 5, then update mysql permissions
#to allow connecting from the other docker container.
docker-compose -f ${DEST_COMPOSE_PATH}/mysql-only.yml up -d
cp ${DEST_COMPOSE_PATH}/mysql8-migration.sql ${DEST_MYSQL_PATH}
echo
echo "Giving MySQL a few seconds to start..."
while true
do
   sleep 3
   echo "Checking to see if MySQL is ready.."
   docker logs mattermost_mysql 2>&1 | grep -q "mysqld: ready for connections"
   if [ $? == 0 ]
   then
      echo "MySQL container reported it is ready.  Proceeding..."
      break
   fi

   echo
   echo "MySQL doesn't appear to be ready yet..."
   while true
   do
      echo "It doesn't look MySQL has started yet, but it may just need a little more time."
      read -p "Wait a few more seconds, view the docker logs output, or quit? (WAIT/logs/quit) " PROMPT
      if [ "${PROMPT,,}" == "wait" ] || [ "${PROMPT,,}" == "w" ] || [ "${PROMPT,,}" == "" ]
      then
         echo
         break
      elif [ "${PROMPT,,}" == "logs" ] || [ "${PROMPT,,}" == "l" ]
      then
         docker logs mattermost_mysql
		 break
      elif [ "${PROMPT,,}" == "quit" ] || [ "${PROMPT,,}" == "q" ]
      then
         echo
         echo
         echo "Quitting the script, but the MySQL container is still running.  Run:"
         echo "sudo docker-compose -f ${DEST_COMPOSE_PATH}/mysql-only.yml down"
         echo "to stop the MySQL container and run:"
         echo "rm -f ${DEST_MYSQL_PATH}/mysql8-migration.sql"
         echo "to remove the migration script from the docker volume."
         exit
      fi
      echo "Sorry, I didn't understand that. Please type wait, logs, or quit"
   done
done
echo
echo "Running migration script to allow mmuser to access the database from % instead of localhost, and update collation for MySQL 8"
echo "This might take a while; for my server with about 300k posts it took about 30 minutes."
docker exec -it mattermost_mysql mysql -p -e source /var/lib/mysql/mysql8-migration.sql
rm -f ${DEST_MYSQL_PATH}/mysql8-migration.sql
docker-compose -f ${DEST_COMPOSE_PATH}/mysql-only.yml down

echo
echo "That should be it! Starting it all up..."
docker-compose up -d
