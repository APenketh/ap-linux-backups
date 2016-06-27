#! /bin/bash

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

        echo "$(datetime) Proceeding With Backing Up Vhost Defined Directorys"

	if [ $vhost_backup_directory != "" ]; then
        	vhost_backup_dir_new=$(echo $vhost_backup_directory | tr ',' '\n')

        	for vhost_backup_dir_n in $vhost_backup_dir_new; do
                	if [ -d $vhost_backup_dir_n ]; then
                        	vhostname=`echo "${vhost_backup_dir_n:1}" | sed 's/\//\-/g'`
                        	if [ ! -f $backup_dir/$vhostname$timestamp.tar.gz ]; then
                                	echo "$(datetime) Starting File Level Backup For $vhostname"
                                	tar -C $vhost_backup_dir_n -zcf $backup_dir/$vhostname$timestamp.tar.gz .
                                	echo "$(datetime) Site $vhostname has been succesfully backed up & Is Avalible Under $backup_dir/$vhostname-$timestamp.tar.gz"
                        	else
                               	 	echo "$(datetime) Error - $backup_dir/$vhostname$timestamp.tar.gz Backup Already Exists - Do You Have A Duplicate Backup?"
                        	fi
                	else
                        	echo "$(datetime) Error - Directory $vhost does not exist"
                	fi
        	done
	else
		echo "$(datetime) No Vhost Directorys Defined Proceeding.."
	fi	

    	echo "$(datetime) Proceeding With Backing Up Configuration Defined Directorys"

	if [ $backup_directory != "" ]; then
		backup_dir_new=$(echo $backup_directory | tr ',' '\n')

		for backup_dir_n in $backup_dir_new; do
        		if [ -d $backup_dir_n ]; then
                		vhostname=`echo "${backup_dir_n:1}" | sed 's/\//\-/g'`
                        	if [ ! -f $backup_dir/$vhostname$timestamp.tar.gz ]; then
                        		echo "$(datetime) Starting File Level Backup For $vhostname"
                                	tar -C $backup_dir_n -zcf $backup_dir/$vhostname$timestamp.tar.gz .
                                	echo "$(datetime) Site $vhostname has been succesfully backed up & Is Avalible Under $backup_dir/$vhostname-$timestamp.tar.gz"
                        	else
                        		echo "$(datetime) Error - $backup_dir/$vhostname-$timestamp.tar.gz Backup Already Exists - Do You Have A Duplicate Backup?"
                        	fi
			else
                        	echo "$(datetime) Error - Directory $vhost does not exist"
                	fi
        	done
	else
		echo "$(datetime) No Extra Directory's Defined For Backup Proceeding.."
	fi

    	echo "$(datetime) Starting The Database Backup Process"

	# Start of Database Backups
	if [ $database_service == "non" ]; then
		echo "$(datetime) There Are No Databases To Backup Proceeding.."
	elif [ $database_service == "mysql" ]; then
		if [ -d "$backup_dir" ]; then
			echo "$(datetime) Creating Databse Backup Folder Under $backup_dir_db"
			mkdir "$backup_dir_db"
		else
			echo "$(datetime) Error - Cannot Create Directory For Database Backup's Please Review The Logs"
			exit 0
		fi
	
		databases=`mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`
		list_exclude_db=' $exclude_databases'
		echo "$(datetime) Proeeding With Backing Up The Following Databases -"
		echo "$databases"

		for db in $databases; do
			echo "$(datetime) Starting Dump For Database '$db'"
  			mysqldump --force --opt --databases $db | gzip > "$backup_dir_db/$db-$timestamp.gz"
			echo "$(datetime) Completed Dump For Database '$db', this can be found at $backup_dir_db/$db-$timestamp.gz"
		done
	else
		echo "$(datetime) Backing Up Databases Failed Proceeding"
	fi

	# Starting the removal and compression process
	echo "$(datetime) Starting The Clean Up Process For Old Backups"
	if [ $total_backup_days == "0" ]; then
		echo "$(datetime) Backups Are Currently Set To Unlimited. Proceeding Without Any Removals"
	else
		find /backups/* -mtime +$total_backup_days -exec rm {} \;
	fi

	# Start Rsync
	connct_status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -p $rsynctargetport $rsynctargetname@$rsynctarget echo ok 2>&1)

	if [ $rsyncenabled == "yes" ]; then
		echo "$(datetime) Starting Backup Procedure"
		echo "$(datetime) Testing Connection To Remote Server"
	        	if [[ $connct_status == ok ]] ; then
                        	echo "Connection To Remote Server Succesfull"
                                ssh -p $rsynctargetport $rsynctargetname@$rsynctarget "test -d $rsyncremotepath || mkdir -p $rsyncremotepath$localhostname/ && exit"
				if [ $compression_delay != "0" ]; then
                                	rsync -avz -e "ssh -p $rsynctargetport" /backups/$timestamp $rsynctargetname@$rsynctarget:$rsyncremotepath$localhostname/ > /dev/null
				else
					rsync -avz -e "ssh -p $rsynctargetport" /backups/$timestamp.tar.gz $rsynctargetname@$rsynctarget:$rsyncremotepath$localhostname/ > /dev/null
				fi
                        elif [[ $connct_status == "Permission denied"* ]] ; then
                        	echo "No Authorization To Access Remote Server - Please Check If SSH Key Has Been Added"
                        else
                        	echo "Can't Connect To The Remote Server To Complete Rsync, Please Attempt Troubleshooting."
                        fi
	elif [ $rsyncenabled == "no"]; then
		echo "$(datetime) Rsync Remote Archive Is Not Enabled, Proceeding.."
	else
		echo "$(datetime) Rsync Remote Archive Is Not Enabled, Proceeding.."
	fi	

    echo "$(datetime) Summary Of Completed Work;"
    find $backup_dir -type f -print0 | xargs -0r ls -lah | awk '{print $5,$9}'

    echo "$(datetime) *****************************************************************"
    echo ""
