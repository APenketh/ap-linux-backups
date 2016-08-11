#!/bin/bash

	AP_BACKUPS_VERSION="v0.1"
	AP_BACKUPS_AUTHOR="Alex Penketh"

# Exit the scipt is a command returns anything other than exit status 0 on error
	set -e

# Include The Config File That Was Created In The Installation
	source /etc/ap-scripts/ap-backups-main.conf

# Read The Options From The Command Line
	GETOPT_TMP=`getopt -q -o rushv --long runbackup,updatevhosts,sync,help,version -- "$@"`
	eval set -- "$GETOPT_TMP"

# Work Fucntions Below
# We are defining the date/time for our logging in a function so that it is updated as the event occours therefore providing a valid time
	datetime()	{
		date +"%b %d %T"
       	 		}

# Performed the sync of backup files to the remote server
	rsync_job()	{
                # We are going to enable logging on the entire script so we can verify backups and debug any errors
                exec 3>&1 4>&2
                trap 'exec 2>&4 1>&3' 0 1 2 3
                exec 1>>/var/log/ap-backups/ap-backups.log 2>&1
                # Redirect stdout to file log.out then redirect stderr to stdout. Note that the order is important when you want them going to the same file. stdout must be redirected before stderr is redirected to stdout
		local TIMESTAMP=$(date +"%F")
        	CONNCT_STATS=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -p $RSYNCTARGETPORT $RSYNCTARGETNAME@$RSYNCTARGET echo ok 2>&1)
        	if [[ $RSYNCENABLED == "yes" ]]; then
                	echo "$(datetime) Starting Backup Procedure"
                	echo "$(datetime) Testing Connection To Remote Server"
                        if [[ $CONNCT_STATS == ok ]] ; then
                        	echo "Connection To Remote Server Succesfull"
                                ssh -p $RSYNCTARGETPORT $RSYNCTARGETNAME@$RSYNCTARGET "test -d $RSYNCREMOTEPATH || mkdir -p $RSYNCREMOTEPATH$LOCALHOSTNAME/ && exit"
                                rsync -avz -e "ssh -p $RSYNCTARGETPORT" /backups/$TIMESTAMP $RSYNCTARGETNAME@$RSYNCTARGET:$RSYNCREMOTEPATH$LOCALHOSTNAME/ > /dev/null
                        elif [[ $CONNCT_STATS == "Permission denied"* ]] ; then
                                echo "No Authorization To Access Remote Server - Please Check If SSH Key Has Been Added"
                        else
                                echo "Can't Connect To The Remote Server To Complete Rsync, Please Attempt Troubleshooting."
                        fi
        	elif [ $RSYNCENABLED == "no"]; then
                	echo "$(datetime) Rsync Remote Archive Is Not Enabled, Proceeding.."
        	else		
                	echo "$(datetime) Rsync Remote Archive Is Not Enabled, Proceeding.."
        	fi
			}

# Thos function is the backup script and can be called from cron or manually
	main_backup_job()	{
   		# We are going to enable logging on the entire script so we can verify backups and debug any errors
    		exec 3>&1 4>&2
    		trap 'exec 2>&4 1>&3' 0 1 2 3
		exec 1>>/var/log/ap-backups/ap-backups.log 2>&1
    		# Redirect stdout to file log.out then redirect stderr to stdout. Note that the order is important when you want them going to the same file. stdout must be redirected before stderr is redirected to stdout

    		local TIMESTAMP=$(date +"%F")
    		local BACKUP_DIR="/backups/$TIMESTAMP"
    		local BACKUP_DIR_DB="$BACKUP_DIR/databases"
    		local BACKUPCONFIG="/etc/ap-scripts/ap-backups-main.conf"
    		local TIMESTAMP1=$(date +"%F" --date='1 day ago')
    		local TIMESTAMP2=$(date +"%F" --date='2 days ago')

    		echo "$(datetime) *****************************************************************"
    		echo "$(datetime) ********************Starting Backup Procedure********************"
    		echo "$(datetime) *****************************************************************"

        	# Make Our Inital Directory To Put All The Things, or exit if a folder is already found to avoid running out of disk space if the script goes loopy.
        	if [ ! -d "$BACKUP_DIR" ]; then
          		mkdir -p $BACKUP_DIR
          		echo "$(datetime) Making A New Directory Under: $BACKUP_DIR"
        	else
          		echo "$(datetime) Backup For $TIMESTAMP Has Already Been Completed & Is Avalible Under $BACKUP_DIR"
          		echo "$(datetime) *****************************************************************"
          		exit 0
        	fi

    		echo "$(datetime) Checking For Enough Avalible Disk Space To Perform The Backup. This Does Not Take Into Account Any New Backup Items Added Since Last Succesful Backup."

        	local TOTAL_SPACE=$(df -m $BACKUP_DIR | awk '{print $4}' | grep -v "Available")

        	if [ -d "/backups/$TIMESTAMP1" ]; then
                	local PREV_BKUP_TOTAL=$(du -mxc /backups/$TIMESTAMP1 | grep "total" | awk '{print $1}')
                	echo "$(datetime) Previous Backup Total Is $PREV_BKUP_TOTAL M & Total Avalible Space Is $TOTAL_SPACE M"
                        if [ "$PREV_BKUP_TOTAL" -le "$TOTAL_SPACE" ]; then
                                echo "$(datetime) There Is Approxmitly Enough Space To Complete This Backup. Proceeding..."
                        else
                                echo "$(datetime) There Is Approxmitly Not Enough Space To Complete This Backup, Please Check The File System For Disk Usage"
                                exit 0
                        fi
        	elif [ -f "/backups/$timestamp1.tar.gz" ]; then
                	local PREV_BKUP_TOTAL_COMP=$(du -mxc /backups/$TIMESTAMP1.tar.gz | grep "total" | awk '{print $1}')
                echo "$(datetime) Previous Backup Total Is $PREV_BKUP_TOTAL_COMP M & Total Avalible Space Is $TOTAL_SPACE M"
                        if [ "$PREV_BKUP_TOTAL_COMP" -le "$TOTAL_SPACE" ]; then
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
        	if [[ $VHOST_BACKUP_DIRECTORY != "" ]]; then
                	local VHOST_BACKUP_DIR_NEW=$(echo $VHOST_BACKUP_DIRECTORY | tr ',' '\n')
                	for VHOST_BACKUP_DIR_N in $VHOST_BACKUP_DIR_NEW; do
                        	if [ -d $VHOST_BACKUP_DIR_N ]; then
                                	local VHOSTNAME=`echo "${VHOST_BACKUP_DIR_N:1}" | sed 's/\//\-/g'`
                                	if [ ! -f $BACKUP_DIR/$VHOSTNAME$TIMESTAMP.tar.gz ]; then
                                        	echo "$(datetime) Starting File Level Backup For $VHOSTNAME"
                                        	tar -C $VHOST_BACKUP_DIR_N -zcf $BACKUP_DIR/$VHOSTNAME$TIMESTAMP.tar.gz .
                                        	echo "$(datetime) Site $VHOSTNAME has been succesfully backed up & Is Avalible Under $BACKUP_DIR/$VHOSTNAME-$TIMESTAMP.tar.gz"
                                	else
                                        	echo "$(datetime) Error - $BACKUP_DIR/$VHOSTNAME$TIMESTAMP.tar.gz Backup Already Exists - Do You Have A Duplicate Backup?"
                                	fi
                        	else
                                	echo "$(datetime) Error - Directory $VHOST does not exist"
                        	fi
                	done
        	else
                	echo "$(datetime) No Vhost Directorys Defined Proceeding.."
        	fi

        	echo "$(datetime) Proceeding With Backing Up Configuration Defined Directorys"
        	if [[ $BACKUP_DIRECTORY != "" ]]; then
                	local BACKUP_DIR_NEW=$(echo $BACKUP_DIRECTORY | tr ',' '\n')
                	for BACKUP_DIR_N in $BACKUP_DIR_NEW; do
                        	if [ -d $BACKUP_DIR_N ]; then
                                	local VHOSTNAME=`echo "${BACKUP_DIR_N:1}" | sed 's/\//\-/g'`
                                	if [ ! -f $BACKUP_DIR/$VHOSTNAME$TIMESTAMP.tar.gz ]; then
                                        	echo "$(datetime) Starting File Level Backup For $VHOSTNAME"
                                        	tar -C $BACKUP_DIR_N -zcf $BACKUP_DIR/$VHOSTNAME$TIMESTAMP.tar.gz .
                                        	echo "$(datetime) Site $VHOSTNAME has been succesfully backed up & Is Avalible Under $BACKUP_DIR/$VHOSTNAME-$TIMESTAMP.tar.gz"
                                	else
                                        	echo "$(datetime) Error - $BACKUP_DIR/$VHOSTNAME-$TIMESTAMP.tar.gz Backup Already Exists - Do You Have A Duplicate Backup?"
                                	fi
                        	else
                                	echo "$(datetime) Error - Directory $VHOST does not exist"
                        	fi
                	done
        	else
                	echo "$(datetime) No Extra Directory's Defined For Backup Proceeding.."
        	fi

        	echo "$(datetime) Starting The Database Backup Process"

        	# Start of Database Backups
        	if [[ $DATABASE_SERVICE == "non" ]]; then
                	echo "$(datetime) There Are No Databases To Backup Proceeding.."
        	elif [[ $DATABASE_SERVICE == "mysql" ]]; then
                	if [ -d "$BACKUP_DIR" ]; then
                        	echo "$(datetime) Creating Databse Backup Folder Under $BACKUP_DIR_DB"
                        	mkdir "$BACKUP_DIR_DB"
                	else
                        	echo "$(datetime) Error - Cannot Create Directory For Database Backup's Please Review The Logs"
                        	exit 0
                	fi

                local DATABASES=`mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`
                local LIST_EXCLUDE_DB=' $exclude_databases'
                echo "$(datetime) Proeeding With Backing Up The Following Databases -"
                echo "$DATABASES"

                for DB in $DATABASES; do
                        echo "$(datetime) Starting Dump For Database '$DB'"
                        mysqldump --force --opt --databases $DB | gzip > "$BACKUP_DIR_DB/$DB-$TIMESTAMP.gz"
                        echo "$(datetime) Completed Dump For Database '$DB', this can be found at $BACKUP_DIR_DB/$DB-$TIMESTAMP.gz"
                done
        	else
                	echo "$(datetime) Backing Up Databases Failed Proceeding"
        	fi

        	# Starting the removal and compression process
        	local TOTAL_DAYS_TO_REMOVE=$(($TOTAL_BACKUP_DAYS-1))
        	echo "$(datetime) Starting The Clean Up Process For Old Backups"
        	if [[ $TOTAL_BACKUP_DAYS == "0" ]]; then
                	echo "$(datetime) Backups Are Currently Set To Unlimited. Proceeding Without Any Removals"
        	else
                	echo "$(datetime) Removing The Following Directory's"
                	find /backups/* -mtime +"$TOTAL_DAYS_TO_REMOVE" -print;
                	find /backups/* -mtime +"$TOTAL_DAYS_TO_REMOVE" -delete;
                	echo "$(datetime) Backup Removal Complete"
        	fi

		# Call rsync job to be ran
		rsync_job;
	
		echo "$(datetime) Summary Of Completed Work;"
    		find $BACKUP_DIR -type f -print0 | xargs -0r ls -lah | awk '{print $5,$9}'

    		echo "$(datetime) *****************************************************************"
    		echo ""
         		}

# This function is to update any vhosts as per the config file
	vhost_updater() {
                	}

	help_option()	{
		echo ""
        	echo "Usage:";
        	echo "        apbackups.sh -[shortoption] --[longoption]"
        	echo "Options:"
        	echo "        Either long or short options are allowed."
        	echo "        --runbackup       -r            Perform A Backup Based Off The Parameters In The Configuration File"
        	echo "        --sync            -s            Performed A Manual Sync Of Previous Backups To The Remote Host Defined In The Configuration File"
        	echo "        --updatevhosts    -u            Update The Vhost To Backup In The Config File"
        	echo "        --version         -v            Get Script Information & Version"
        	echo "        --help            -h            Display The Help"
		echo ""
			}

# Extract options chosen and call the appropriate function
	while true ; do
    		case "$1" in
        	-r|--runbackup)		main_backup_job; 
					exit;;
        	-u|--updatevhosts)	vhost_updater; 
					exit;;
        	-s|--sync)		rsync_job;
					exit;; 
        	-h|--help)		help_option; 	
					exit;;
		-v|--version)		echo "AP-Backups $AP_BACKUPS_VERSION";
					echo "Author: $AP_BACKUPS_AUTHOR";
					exit;;
        	--) 			echo "AP-Backups $AP_BACKUPS_VERSION: Invalid Option Specified";
					echo "Try 'apbackups.sh -h' or 'apbackups.sh --help' for more information.";
					exit;;
        	*) 			echo "Internal error!" ; 
					exit;;
    		esac
	done

# If no options are specified then the user is given the output below
	echo "AP-Backups $AP_BACKUPS_VERSION: no command specified"
	echo "Try 'apbackups.sh -h' or 'apbackups.sh --help' for more information."
