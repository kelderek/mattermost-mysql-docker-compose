based on official docker-compose https://github.com/mattermost/docker

assumptions:
moving older mysql to current mysql (version as of this writing)
moving all mysql databases
db name is mattermost (can edit files)
using existing reverse proxy - nginx not part of docker compose
mysql stopped on current server
ssh access to current server(s) for migrating data and database
uses latest tag of mattermost and mysql docker containers - may have some risk, particularly for mysql
single mattermost server
single database server (can be the same as mattermost server)

echo "Before continuing, make sure you have:"
echo "--Updated the variables in this file to match your environment"
echo "--Setup your .env file based on the env.example file"
echo "--If you use a database name other than mattermost, you have updated the mysql8-mattermost.sql script with the correct database name"
echo "--You have at least read rights to all files and folders in the source server's mattermost data, config, logs, client/plugins, and plugins folders"
echo "--You have at least read rights to all files and folders in the source server's mysql data folder" ***GIVE COMMANDS***
echo "--Stopped the MySQL service on the source server"
echo "--The passwords available to ssh from the source server(s) and to connect to MySQL as root"
echo "--Run this script as root or with sudo"

can run the migration script ahead of time to pre-sync the data while the old mattermost and mysql services are still running, then run it again as many times as needed to resolve issues and/or when ready for the final migration