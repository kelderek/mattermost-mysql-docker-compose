# Migrating from a traditional install of Mattermost with MySQL/MariaDB to Docker
The docker-compose files are based on the official docker-compose files at https://github.com/mattermost/docker

The official docker-compose files use PostgreSQL and migrating from our existing MySQL install was proving to be a pain, so I converted the docker-compose files to use MySQL instead.  We were using an older version of MySQL so per https://docs.mattermost.com/install/software-hardware-requirements.html#database-software the collation needed to be upgraded, which is done as part of the migration script.  It also mentioned needing to add ```mysql_native_password``` to your MySQL config file but mine worked without it so I didn't do that.

## Assumptions:
- Moving from MySQL version less than 8 to latest (8.0.30 as of this writing)
- Moving all MySQL databases; previous MySQL instance was dedicated to Mattermost
- Database name is mattermost
- Mattermost uses an existing reverse proxy; nginx is NOT part of this docker-compose
- MySQL has been stopped on source server (MySQL won't upgrade data copied over while the source MySQL service is running)
- You have ssh access to the source server(s) for migrating data and database
- You have root MySQL access for the database permission and collation updates
- You are not running a Mattermost cluster.  I don't have an enterprise license so I can't test against that use case.
- There is a single database server (which can be the same as the Mattermost server or different)

## Usage
1. Copy ```env.example``` to ```.env``` and update the variables for your system/needs.  Note that I use the "latest" tag for Mattermost and MySQL, which may have some risk, particularly when using MySQL
2. Update the variables in ```migration.sh``` to match your environment
3. If you use a database name other than mattermost or db username other than mmuser, update the ```mysql8-mattermost.sql``` script with the correct database name and/or user
4. Stop the MySQL service on the source server
5. Run ```sudo ./migration.sh``` to start the process of migrating data and setting up the docker containers

## Notes and Troubleshooting
- You can run the migration script ahead of time to pre-sync the data while the source Mattermost and MySQL services are still running, then run it again as many times as needed to resolve issues and/or when ready for the final migration.  It uses rsync so it will only redownload changes.
- You may need to add your SSH user to the mattermost and/or mysql groups on the source server to get the read access needed for the copy.  Here are some sample commands:
```
usermod -a -G mattermost username
usernmod -a -G mysql username
```
- You may also get denied access to some files without group permissions.  Here are some sample commands to run on the source server to add read rights to the group account.  It assumes Mattermost is at ```/opt/mattermost```:
```
  chmod -R g+r /opt/mattermost/data
  chmod -R g+rx /opt/mattermost/client/plugins
  chmod -R g+rx /opt/mattermost/plugins
```