#! /bin/bash
# File Location - /ap-scripts/ap-backups.sh
#
# Increase Security For Sourcing The Config File - Remove the ability to execute commands
# Change the way backups are compressed and removed using find with -mtime
# Add in remote backups via rsync?
#
# To do;
#
# Config file additons to add in -
# Change the archive of backups (How long they are kept etc)
# Add blacklist for MySQL Dumps
#

    # Exit the scipt is a command returns anything other than exit status 0 on error
    set -e

    # We are going to enable logging on the entire script so we can verify backups and debug any errors 
    exec 3>&1 4>&2
    trap 'exec 2>&4 1>&3' 0 1 2 3
    exec 1>>/var/log/ap-backups/ap-backups.log 2>&1
    # Redirect stdout to file log.out then redirect stderr to stdout. Note that the order is important when you want them going to the same file. stdout must be redirected before stderr is redirected to stdout   

    # Include The Config File That Was Created In The Installation
    source /etc/ap-scripts/ap-backups-main.conf

    timestamp=$(date +"%F")
    backup_dir="/backups/$timestamp"
    backup_dir_db="$backup_dir/databases"
    backupconfig="/etc/ap-scripts/ap-backups-main.conf"

    timestamp1=$(date +"%F" --date='1 day ago')
    timestamp2=$(date +"%F" --date='2 days ago')

    # We are defining the date/time for our logging in a function so that it is updated as the event occours instead of a variable where it would only keep the time where it was first stored
	datetime() {
	    date +"%b %d %T"
		   }

    echo "$(datetime) *****************************************************************"
    echo "$(datetime) ********************Starting Backup Procedure********************"
    echo "$(datetime) *****************************************************************"

	# Make Our Inital Directory To Put All The Things, or exit if a folder is already found to avoid running out of disk space if the script goes loopy.
	if [ ! -d "$backup_dir" ]; then
	  mkdir -p $backup_dir
	  echo "$(datetime) Making A New Directory Under: $backup_dir"
	else
	  echo "$(datetime) Backup For $timestamp Has Already Been Completed & Is Avalible Under $backup_dir"
	  echo "$(datetime) *****************************************************************"
	  exit 0
	fi

    echo "$(datetime) Checking For Enough Avalible Disk Space To Perform The Backup. This Does Not Take Into Account Any New Backup Items Added Since Last Succesful Backup."

	total_space=$(df -m $backup_dir | awk '{print $4}' | grep -v "Available")

	if [ -d "/backups/$timestamp1" ]; then
		prev_bkup_total=$(du -mxc /backups/$timestamp1 | grep "total" | awk '{print $1}')
	    	echo "$(datetime) Previous Backup Total Is $prev_bkup_total M & Total Avalible Space Is $total_space M"
			if [ "$prev_bkup_total" -le "$total_space" ]; then
		    		echo "$(datetime) There Is Approxmitly Enough Space To Complete This Backup. Proceeding..."
			else
		    		echo "$(datetime) There Is Approxmitly Not Enough Space To Complete This Backup, Please Check The File System For Disk Usage"
		    		exit 0
			fi
	elif [ -f "/backups/$timestamp1.tar.gz" ]; then
		prev_bkup_total_comp=$(du -mxc /backups/$timestamp1.tar.gz | grep "total" | awk '{print $1}')
                echo "$(datetime) Previous Backup Total Is $prev_bkup_total_comp M & Total Avalible Space Is $total_space M"
                        if [ "$prev_bkup_total_comp" -le "$total_space" ]; then
                                echo "$(datetime) There Is Approxmitly Enough Space To Complete This Backup. Proceeding..."
                        else
                                echo "$(datetime) There Is Approxmitly Not Enough Space To Complete This Backup, Please Check The File System For Disk Usage"
                                exit 0
                        fi
	else
		echo "$(datetime) There Is No Previous Backups To Estimate The Backup Size, Proceeding..."
	fi

	# Starting the file level backup process, this grabs all the paths from the config file
    echo "$(datetime) Starting The File Level Backup Process"
    echo "$(datetime) Proceeding With Backing Up Configuration Defined Directory's"
	backup_dir_new=$(echo $backup_directory | tr ',' '\n')
	echo "$backup_dir_new"

                        for backup_dir_n in $backup_dir_new; do
                            if [ -d $backup_dir_n ]; then
                                    vhostname=`echo "${backup_dir_n%/}" | awk -F/ '{print $NF}'`
                                if [ ! -f $backup_dir/$vhostname-$timestamp.tar.gz ]; then
                                    echo "$(datetime) Starting File Level Backup For $vhostname"
                                    tar -C $backup_dir_n -zcf $backup_dir/$vhostname-$timestamp.tar.gz .
                                    echo "$(datetime) Site $vhostname has been succesfully backed up & Is Avalible Under $backup_dir/$vhostname-$timestamp.tar.gz"
                                else
                                    echo "$(datetime) Error - $backup_dir/$vhostname-$timestamp.tar.gz Backup Already Exists - Do You Have A Duplicate Backup?"
                                fi
                            else
                                echo "$(datetime) Error - Directory $vhost does not exist"
                            fi
                        done

    echo "$(datetime) Starting The Database Backup Process"

	# MySQL Backups
	if [ -d "$backup_dir" ]; then
		echo "$(datetime) Creating Databse Backup Folder Under $backup_dir_db"
		mkdir "$backup_dir_db"
	else
		echo "$(datetime) Error - Cannot Create Directory For Database Backup's Please Review The Logs"
		exit 0
	fi
	
	databases=`mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`
	echo "$(datetime) Proeeding With Backing Up The Following Databases -"
	echo "$databases"

	for db in $databases; do
		echo "$(datetime) Starting Dump For Database '$db'"
  		mysqldump --force --opt --databases $db | gzip > "$backup_dir_db/$db-$timestamp.gz"
		echo "$(datetime) Completed Dump For Database '$db', this can be found at $backup_dir_db/$db-$timestamp.gz"
	done

	# This needs updating to read off the config file

    echo "$(datetime) Starting Clean Up Process For Old Backups"

	    if [ -d "$backup_dir" ]; then
		if [ -d "$backup_dir_db" ]; then
		    if [ -d "/backups/$timestamp1" ]; then
		        echo "$(datetime) Compressing Backup from $timestamp1"
                        tar -C /backups/$timestamp1 -zcf /backups/$timestamp1.tar.gz .
                        echo "$(datetime) Compression For Backup From $timestamp1 has been complete and is avalible in /backups/$timestamp1.tar.gz"
			    if [ -f "/backups/$timestamp1.tar.gz" ]; then
			        echo "$(datetime) Removing Old Backup Directory /backups/$timestamp1/"
			        rm -rf /backups/$timestamp1/
				    if [ -f "/backups/$timestamp2.tar.gz" ]; then
			                echo "$(datetime) Removing Old Backup From /backups/$timestamp2.tar.gz"
			                rm -rf /backups/$timestamp2.tar.gz
				    else
					echo "$(datetime) There Is No Backup Under /backups/$timestamp2.tar.gz. Proceeding.."
				    fi
			    else
		    	        echo "$(datetime) Error - Please Check If Backup Archive For /backups/$timestamp1.tar.gz Completed Correctly"
			    fi 
		    else
			echo "$(datetime) Error - Please Check That Recent Backups Have Processed Correctly - $timestamp1"
		    fi
		else
		    echo "$(datetime) Error - Not Continuing With Archive & Compression Due To Error In The Database Backup Process"
		    echo "$(datetime) Error - Please Check That Recent Backups Have Processed Correctly"
		fi
	    else
		echo "$(datetime) Error - Not Continuing With Archive & Compression Due To Error In The File Level Backup Process"
		echo "$(datetime) Error - Please Check That Recent Backups Have Processed Correctly"
	    fi		

    echo "$(datetime) Summary Of Completed Work;"
    find $backup_dir -type f -print0 | xargs -0r ls -lah | awk '{print $5,$9}'

    echo "$(datetime) *****************************************************************"
    echo ""
