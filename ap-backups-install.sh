#! /bin/bash
# File Location - /ap-scripts/ap-installbackup.sh
#
# To do;

# FIX THIS - If you select to keep your old configuration file and it fails the verification test, it will run through the setup of a new one but then when finished will look around and do everything again minus the backup/compression times?? Werid issue.
#
# Add Ability To Change Cron Job Times
# 
#

	# Exit the scipt is a command returns anything other than exit status 0 on error
	set -e

	scripts_dir="/ap-backups/"
	log_dir="/var/log/ap-backups/"
	backupscript="/ap-backups/ap-backups.sh"
	backupconfig="/etc/ap-scripts/ap-backups-main.conf"
	backupconfigold="/etc/ap-scripts/ap-backups-main.old"
	backupconfigdir="/etc/ap-scripts/"
	webservice=""
	supportedwebservice="nginx, apache2, httpd"
	backup_dir_hold=""
	excludedb_hold=""

	# We are defining the date/time for our logging in a function so that it is updated as the event occours instead of a variable where it would only keep the time where it was first stored
        datetime() {
        	date +"%b %d %T"
                   }

	echo "*****************************************************************"
	echo "***********Starting AP-Backup Installation Procedure*************"
	echo "*****************************************************************"
	echo ""

	# Sanity check to see if this script is already installed
	if [ -f "$backupscript" ]; then
		echo "Error - You Alrady Have AP-Backups Installed Please Check $backupscript Location"
		echo "*****************************************************************"
		echo ""
		exit 0
	else
		echo "Proceding With Creating Inital Directory's;"
	fi

	# Create scripts directory for storing the backup script
	if [ ! -d "$scripts_dir" ]; then
		mkdir $scripts_dir
		echo "$Creating Directory $scripts_dir"
	else
		echo "Great! $scripts_dir already exists"
	fi
	#Create log directory for putting the installation log and also the backup logs
	if [ ! -d "$log_dir" ]; then
		mkdir $log_dir
	    	echo "$Creating Directory $log_dir"
	else
	    	echo "Great! $log_dir already exists"
	fi
        #Create config directory for putting the configuration file
        if [ ! -d "$backupconfigdir" ]; then
            	mkdir $backupconfigdir
            	echo "Creating Directory $backupconfigdir"
        else
            	echo "Great! $backupconfigdir already exists"
        fi

	detectingwebservice()	{
		while true; do
                    	read -p "We Have Detected You Are Running The Following Webservice On This Server '$webservice' Is This Correct? Please Select [y/N]" yn
                    	case $yn in
                    	    	[Yy]* )
                                	echo "webservice=\"$webservice\"" >> $backupconfig;
                                	break;;
                    	    	[Nn]* )
					echo "Please Enter The Webservice That You Will Be Using, The Supported Webservices's are: $supportedwebservice. If You Do Not Plan On Using A Webservice Please Enter "non""
                                	while true ; do
                            			read -e newservice
                                		if [ "$newservice" != "nginx" -a "$newservice" != "apache2" -a "$newservice" != "httpd" -a "$newservice" != "non" ]; then
                                    	    		while true; do
                                        		read -p "You Have Entered The Webservice $newservice. Is This Correct? Please Select [y/N]" yn
                                            	    		case $yn in
                                            				[Yy]* ) 
							    			if [ "$newservice" = "nginx" -a "$newservice" = "apache2" -a "$newservice" = "httpd" -a "$newservice" = "non" ]; then
							    				echo "webservice=\"$newservice\"" >> $backupconfig;
                                                    	    				break;
							    			else
											echo "Please Enter A Valid WebHost - Such As $supportedwebservice" or 'non';
											break;
							    			fi
											break;;
                                            				[Nn]* ) 
							    			echo "Please Enter Your Corrected Web Service.";
                                                    	    			break;;
                                            				* ) 
							    			echo "Please Select [y/N]";;
                                        			esac
                                    	    		done
                                		else
                                    	    		echo "We Have Finished Reviewing The Webservice. Proceeding To The Next Step.."
					    		echo "webservice=\"$newservice\"" >> $backupconfig
                                    	    		break;
                                		fi
                            		done
					break;;
                    		* )
                            		echo "Please Select [y/N]";;
                	esac
            	done	
				}


	# Fuction for installing a new config file, this also includes the removal of old config files if theoption was chosen to do so
        newconfig()     {

        	if [ -f "$backupconfig" ]; then
			rm -f $backupconfig
			echo "Removing Old Configuration File.."
	    	fi

	    	echo "Creating AP-Backup Configuration File under $backupconfig"
            	touch $backupconfig
	    	echo "# AP-Backups Configuration File" >> $backupconfig
	    	echo "" >> $backupconfig

	    	# Asking the user if they are running a webserivce, if so detecting what web server they currently have running and then confirming if thats the one they want to be included
    		echo "# Web Service Configuration" >> $backupconfig

    		while true; do
			read -p "Are You Running A Webservice? Please Select [y/N]" yn
	    		case $yn in
				[Yy]* )
        	    			echo "Checking For Currently Avalible Web Hosts..";
            	    			if netstat -plnt | grep 80 | grep -i "nginx"; then
                				webservice="nginx";
                				detectingwebservice;
						break;
            	    			elif netstat -plnt | grep 80 | grep -i "apache2"; then
                				webservice="apache2";
                				detectingwebservice;
						break;
            	    			elif netstat -plnt | grep 80 | grep -i "httpd"; then
                				webservice="httpd";
                				detectingwebservice;
						break;
            	    			else
                				webservice="non";
                				detectingwebservice;
						break;
            	    			fi
		    				break;;
				[Nn]* )
		    			echo "Proceeding With No Webservice";
		    			echo "webservice=\"non\"" >> $backupconfig;
		    			break;;
				* )
		    			echo "Please Select [y/N]";;
            		esac
        	done

	    	# Giving The User A Choice To Enter Any Further Backup Directory's That They May Have
	    	echo "" >> $backupconfig
	   	echo "# Directory's To Include In The Backups (These Must Be Comma Seperated);" >> $backupconfig
	    	echo ""
            	
		while true; do
                	read -p "Do You Wish To Enter Any Custom Directory's To Be Backups That Are Not Included In Your Vhosts? Please Select [y/N]" yn
                    	case $yn in
                    		[Yy]* ) 
			    		echo "Please Enter The Full Paths To The Extra Directory's You Wish To Backup. Once Complete Please Enter 'Finish'"
			    		while true ; do
			    		read -e extradir
			    			if [ "$extradir" != "finish" -a "$extradir" != "Finish" ]; then
				    			while true; do
                					read -p "You Have Entered The Directory $extradir. Is This Correct? Please Select [y/N]" yn
                    			    		case $yn in
                    			    			[Yy]* ) local extlength=${#extradir}
						    			local extlastchar=${extradir:extlength-1:1}
						   		 	# Variable needs a / at the end. If it does we add the path in as is, if not we will add the / on for the user and then submit. This is to stop the script breaking.
						    			if [ $extlastchar != "/" ]; then
										backup_dir_hold="$backup_dir_hold$extradir/,"
						    			else
										backup_dir_hold="$backup_dir_hold$extradir,"
						    			fi
                    				    			echo "Please Enter Another Directory Or Type 'Finish' To Proceed."
						    			break;;
                    			    			[Nn]* ) echo "Please Enter Your Corrected Directory Or Type 'Finish' To Proceed." 
						    			break;;
                    			    			* ) echo "Please Select [y/N]";;
                					esac
            			    			done
			    			else
				    			echo "You Have Finished Entering Directory's To Backup. Proceeding To The Next Step.."
				    			break;
			    			fi
			    		done
			    		break;;
                    		[Nn]* ) 
			    		echo "You Do Not Have Any Extra Directory's To Add Into The Backup. Proceeding.."; 
			    		break;;
                    		* ) 
			    		echo "Please Select [y/N]";;
                	esac
		done

		# Below variable change is to remove the last comma that is inserted by the above statement which helps clean up the config file. It then inserts the paths into the config file under the variable "backup_directory"
	    	backup_dir_hold="${backup_dir_hold%?}"
	    	echo "backup_directory=\"$backup_dir_hold\"" >> $backupconfig
	    	echo "" >> $backupconfig


        	# Giving The User A Choice To Enter Any MySQL Databases They Wish To Exclude From The Backups
		echo "By Default All Databases Are Included In The Backup, If You Have Specific Databases You Do Not Wish To Backup You Can Do This Below"
		echo "# Databases That Are Not To Be Included In The Backups (These Must Be Comma Seperated);" >> $backupconfig

            	while true; do
                read -p "Do You Wish To Enter Any Databases To Exclude From The Backups? Please Select [y/N]" yn
               		case $yn in
                    		[Yy]* )
                            		echo "Please Enter The Name Of The Databases You Do Not Wish To Backup. Once Complete Please Enter 'Finish'"
                            		while true ; do
                                	read -e excludedb
                                	if [ "$excludedb" != "finish" -a "$excludedb" != "Finish" ]; then
                                    		while true; do
                                        	read -p "You Have Entered The Database $excludedb. Is This Correct? Please Select [y/N]" yn
                                            		case $yn in
                                            			[Yy]* ) excludedb_hold="$excludedb_hold$excludedb,"
                                                    			echo "Please Enter Another Database Or Type 'Finish' To Proceed."
                                                    			break;;
                                            			[Nn]* ) echo "Please Enter Your Corrected Database Or Type 'Finish' To Proceed."
                                                    			break;;
                                            			* ) echo "Please Select [y/N]";;
                                        		esac
                                    		done
                                	else
                                    		echo "You Have Finished Entering Backups To Exclude. Proceeding To The Next Step.."
                                    		break;
                                	fi
                            		done
                            			break;;
                    		[Nn]* )
                            		echo "You Do Not Have Any To Exclude From The Backup. Proceeding..";
                            		break;;
                    		* )
                            		echo "Please Select [y/N]";;
                		esac
            	done

		# Adding the MySQL Databases Entered into the config file
		excludedb_hold="${excludedb_hold%?}"
		echo "exclude_database=\"$excludedb_hold\"" >> $backupconfig;

	    	# Now we need to get the user to set up their archive preferences this is going to be done by how many days and then what they want to happen with the backup on those days.
	    	echo "" >> $backupconfig
	    	echo "# Backup Archive Settings;" >> $backupconfig

            	echo "How Many Days Of Backups Do You Wish To Keep? (Please Enter '0' For Unlimited)"
                while true ; do
			if [ "$archivedays_true" = "Next" ]; then
                            	break;
				echo "Added In $archivedays Days To Backup"
			else
                            	read -e archivedays
				if [[ "$archivedays" =~ ^[0-9]{1,3}$ ]]; then
			     	    	while true; do
                                    	read -p "You Have Entered $archivedays Day's Is That Correct. Please Select [y/N]" yn
                                    		case $yn in
                                            		[Yy]* ) echo "total_backup_days=\"$archivedays\"" >> $backupconfig;
                                                    	archivedays_true="Next";
                                                    	break;;
                                            	[Nn]* ) echo "Please Re-Enter The Correct Amount Of Days";
                                                    	break;;
                                            	* ) echo "Please Select [y/N]";;
                                        	esac
                                    	done
				else
			            	echo "Please Enter A Number Between 0-999"
    	     	        	fi			    
			fi
		done

	    	echo "How Many Days Do You Wish To Wait Until Backups Are Compressed. Enter 0 To Compress Backups When They Are Created."
                while true ; do
                        if [ "$compressdays_true" = "Next" ]; then
                            	break;
                        else
                            	read -e compressdays
                                if [[ "$compressdays" =~ ^[0-9]{1,3}$ ]]; then
                                    	while true; do
                                    	read -p "You Have Entered $compressdays Day's Is That Correct. Please Select [y/N]" yn
                                        	case $yn in
                                            		[Yy]* ) echo "compression_delay=\"$compressdays\"" >> $backupconfig;
                                                    		compressdays_true="Next";
                                                    		break;;
                                            		[Nn]* ) echo "Please Re-Enter The Correct Amount Of Days";
                                                    		break;;
                                            		* ) echo "Please Select [y/N]";;
                                        	esac
                                    	done
                                else
                                    	echo "Please Enter A Number Between 0-999"
                                fi
                        fi
		done
			}

	# Create function for proceeding with old config file, at this point we will check the config file incase there is some modification that we do not want (this will be also done on the fly while the script is running).
        oldconfig()     {
        	echo "Proceeding with Old Configuration File. Performing A Configuration Check.."

		testbackupdays=$(grep "total_backup_days" $backupconfig | awk -F\' '{print $2}')

		if [[ "$testbackupdays" =~ ^[0-9]{1,3}$ ]]; then
			echo "Amount Of Time To Keep Backups Is Valid"
		else
		        echo "Verification Check Of The Original Configuration File Failed, Moving The Old Config File To $backupconfigold & Starting Process To Create New Confg File"
		        mv $backupconfig $backupconfigold;
			newconfig;
		fi

                testcompressiondays=$(grep "compression_delay" $backupconfig | awk -F\' '{print $2}')

                if [[ "$testcompressiondays" =~ ^[0-9]{1,3}$ ]]; then
		        echo "Time To Trigger Backup Compression Is Valid"
                else
                        echo "Verification Check Of The Original Configuration File Failed, Moving The Old Config File To $backupconfigold & Starting Process To Create New Confg File"
                        mv $backupconfig $backupconfigold;
                        newconfig;
                fi
                        }

	# Detecting if a previous configuration file exists, this will then trigger one of two functions. One to create a new one and one to check an old existing one
	if [ -f "$backupconfig" ]; then
            	echo "Configuration File For Ap-Backups Already Exists Under $backupconfig. The Contents Of This File Are Below;"
	    	echo ""
	    	echo ""
		cat $backupconfig
	    	echo ""
	    	echo ""
	    	while true; do
    		read -p "Do You Wish To Proceed With The Old Configuration File? Warning If No This Will Remove Your Previous Configuration. Please Select [y/N]." yn
    		    	case $yn in
        	    		[Yy]* ) oldconfig; 
			    		break;;
        	    		[Nn]* ) newconfig; 
			    		break;;
        	    		* ) echo "Please Select [y/N]";;
    			esac
	    	done
        else
	   	newconfig
        fi

	# Create backup script - Externally downloaded?
	# wget dl.apenketh.com/ap-scripts/ap-backups.sh /ap-scripts/

	# Creating Cronjob for running the backup script
	if crontab -l | grep "/bin/bash /ap-scripts/ap-backups.sh"; then 
	    	echo "Cron Job Is Already Set-up"; 
	else
	    	echo "Creating Cron Job To Automatically Run The Backup At 10PM Server Time Every Night"
	    	crontab -l | { cat; echo "0 22 * * *  /bin/bash $backupscript"; } | crontab -
	fi

    	echo ""
    	echo "*****************************************************************"
    	echo ""
