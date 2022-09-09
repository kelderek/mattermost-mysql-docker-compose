#Update permissions to allow mmuser to connect from the other container
#Change the database from mattermost and user from mmuser if necessary for your environment
use mysql;
update user set host='%' where user='mmuser' and host='localhost';
update db set host='%' where db='mattermost' and user='mmuser' and host='localhost';
flush privileges;

#Per https://docs.mattermost.com/install/software-hardware-requirements.html#database-software MySQL 8 uses
#a new default collation and it needs to be updated for all tables as part of the migration

# Per https://github.com/mattermost/mattermost-server/issues/18624, dropping foreign keys prior to conversion then re-adding
use mattermost;
ALTER TABLE RetentionPoliciesChannels DROP FOREIGN KEY FK_RetentionPoliciesChannels_RetentionPolicies;
ALTER TABLE RetentionPoliciesTeams DROP FOREIGN KEY FK_RetentionPoliciesTeams_RetentionPolicies;

# create a procedure to interate through all the tables of the mattermost database and update the collation
delimiter //

drop procedure if exists mattermost_change_collation //
create procedure mattermost_change_collation()
begin
    DECLARE done BOOL default false;
    DECLARE tablename CHAR(255);

    DECLARE cur1 cursor for SELECT TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = "mattermost";
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    open cur1;

    myloop: loop
        fetch cur1 into tablename;
        if done then
            leave myloop;
        end if;
        set @sql = CONCAT('ALTER TABLE `mattermost`.', tablename, ' CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci');
        prepare stmt from @sql;
        execute stmt;
        drop prepare stmt;
    end loop;

    close cur1;
end //

delimiter ;

# run the procedure
call mattermost_change_collation();

# drop the procedure
drop procedure mattermost_change_collation;

# recreate dropped foreign keys
ALTER TABLE RetentionPoliciesChannels ADD CONSTRAINT FK_RetentionPoliciesChannels_RetentionPolicies FOREIGN KEY (PolicyId) REFERENCES RetentionPolicies (Id) ON DELETE CASCADE;
ALTER TABLE RetentionPoliciesTeams ADD CONSTRAINT FK_RetentionPoliciesTeams_RetentionPolicies FOREIGN KEY (PolicyId) REFERENCES RetentionPolicies (Id) ON DELETE CASCADE;
