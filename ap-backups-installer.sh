#! /bin/bash

	# Exit the scipt is a command returns anything other than exit status 0 on error
	set -e

	# Script Varibles
	scripts_dir="/ap-scripts/ap-backups/"
	log_dir="/var/log/ap-scripts/"
	backupscript="/ap-scripts/ap-backups/ap-backups.sh"
	backupconfig="/etc/ap-scripts/ap-backups-main.conf"
	backupconfigold="/etc/ap-scripts/ap-backups-main.old"
	backupconfigdir="/etc/ap-scripts/"
	webservice=""
	supportedwebservice="nginx, apache2, httpd"
	backup_dir_hold=""
	vhost_backup_dir_hold=""
	excludedb_hold=""
	databaseservice=""
	supporteddatabase="mysql"
        rsynchost=$(hostname)
        rsyncaddress="127.0.0.1"
        rsyncusername="ap-backups"
        rsyncdir="/ap-scripts/backups/archive/"
        rsyncenabled=""
	rsyncport="22"

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
		mkdir -p $scripts_dir
		echo "$Creating Directory $scripts_dir"
	else
		echo "Great! $scripts_dir already exists"
	fi
	#Create log directory for putting the installation log and also the backup logs
	if [ ! -d "$log_dir" ]; then
		mkdir -p $log_dir
	    	echo "$Creating Directory $log_dir"
	else
	    	echo "Great! $log_dir already exists"
	fi
        #Create config directory for putting the configuration file
        if [ ! -d "$backupconfigdir" ]; then
            	mkdir -p $backupconfigdir
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

	detectingdatabaseservice() 	{
                while true; do
                        read -p "We Have Detected You Are Running The Following Database Service On This Server '$databaseservice' Is This Correct? Please Select [y/N]" yn
                        case $yn in
                                [Yy]* )
                                        echo "database_service=\"$databaseservice\"" >> $backupconfig;
                                        break;;
                                [Nn]* )
                                        echo "Please Enter The Database Service That You Will Be Using, The Supported Database Service's are: $supporteddatabase. If You Do Not Plan On Using A Database Please Enter "non""
                                        while true ; do
                                                read -e newdatab
                                                if [ "$newdatab" != "mysql" -a "$newdatab" != "non" ]; then
                                                        while true; do
                                                        read -p "You Have Entered The Database Service $newdatab. Is This Correct? Please Select [y/N]" yn
                                                                case $yn in
                                                                        [Yy]* )
                                                                                if [ "$newdatab" = "mysql" -a "$newdatab" = "non" ]; then
                                                                                        echo "database_service=\"$newdatab\"" >> $backupconfig;
                                                                                        break;
                                                                                else
                                                                                        echo "Unfortunately The Value You Entered Is Not Supported. Please Enter A Valid Database - Such As $supporteddatabase" or 'non';
                                                                                        break;
                                                                                fi
                                                                                        break;;
                                                                        [Nn]* )
                                                                                echo "Please Enter Your Corrected Database Service.";
                                                                                break;;
                                                                        * )
                                                                                echo "Please Select [y/N]";;
                                                                esac
                                                        done
                                                else
                                                        echo "We Have Finished Reviewing The Database Service. Proceeding To The Next Step.."
                                                        echo "database_service=\"$newdatab\"" >> $backupconfig
                                                        break;
                                                fi
                                        done
                                        break;;
                                * )
                                        echo "Please Select [y/N]";;
                        esac
                done
					}

	# Function for creating the parameters for the rsync
	rsyncconfig()	{

                # Start of the setup of the rsync parameter's
                echo "" >> $backupconfig
                echo "# Rsync Settings" >> $backupconfig

                while true; do
                        read -p "Do You Wish To Setup Rsync To Archive The Backups In Another Server? Please Select [y/N]" yn
                        case $yn in
                                [Yy]* ) echo "Proceeding With Setting Up Rsync.";
                                        rsyncenabled="yes";
                                        echo "rsyncenabled=\"yes\"" >> $backupconfig;
                                        break;;
                                [Nn]* ) echo "Proceeding Without Setting Up Rsync.";
                                        rsyncenabled="no";
                                        echo "rsyncenabled=\"no\"" >> $backupconfig;
                                        break;;
                                * ) echo "Please Select [y/N]";;
                        esac
                done

                if [ $rsyncenabled == "yes" ]; then
                        # Identifying The Hostname They Wish To Use
                        while true; do
                                read -p "Please Select How You Wish To Identify This Server, Do You Wish To Use The Current Hostname $rsynchost. Please Select [y/N]" yn
                                case $yn in
                                        [Yy]* ) echo "Thanks You For Confirm The Hostname \"$rsynchost\". Proceeding..";
                                                echo "localhostname=\"$rsynchost\"" >> $backupconfig;
                                                break;;
                                        [Nn]* ) echo "Please Enter A New Hostname To Use.";
                                                while true; do
                                                        if [[ $rsynchost != $newrsynchost ]]; then
                                                        read -e newrsynchost
                                                                while true; do
                                                                        read -p "You Have Entered The Hostname \"$newrsynchost\". Is This Correct? Please Select [y/N]" yn
                                                                        case $yn in
                                                                                [Yy]* ) rsynchost="$newrsynchost";
                                                                                        echo "Using \"$newrsynchost\" As The Local Hostname Identifier.";
                                                                                        echo "localhostname=\"$rsynchost\"" >> $backupconfig;
                                                                                        break;;
                                                                                [Nn]* ) echo "Please Enter Your Corrected Hostname.";
                                                                                        break;;
                                                                                * ) echo "Please Select [y/N]";;
                                                                        esac
                                                                done
                                                        else
                                                        break;
                                                        fi
                                                done
                                                break;;
                                        * ) echo "Please Select [y/N]";;
                                esac
                        done

                        # Address Of Remote Server To Store The Backups
                        echo "Please Enter The Address Of The Server You Wish To Backup To:"
                        while true; do
                                if [[ $rsyncaddress != $newrsyncaddress ]]; then
                                read -e newrsyncaddress
                                        while true; do
                                        read -p "You Have Entered The Address \"$newrsyncaddress\". Is This Correct? Please Select [y/N]" yn
                                                case $yn in
                                                        [Yy]* ) rsyncaddress="$newrsyncaddress";
                                                                echo "Using \"$newrsyncaddress\" As The Local Hostname Identifier.";
                                                                echo "rsynctarget=\"$rsyncaddress\"" >> $backupconfig;
                                                                break;;
                                                        [Nn]* ) echo "Please Enter Your Corrected Address.";
                                                                break;;
                                                        * ) echo "Please Select [y/N]";;
                                                esac
                                        done
                                else
                                        break;
                                fi
                        done

                        # Remote Port Used For Connecting.
                        while true; do
                                read -p "Please Enter The Port Of The Remote Server You Will Be Using, Do You Wish To Use The Default Port $rsyncport? Please Select [y/N]" yn
                                case $yn in
                                        [Yy]* ) echo "Thanks You For Confirming The Default Port \"$rsyncport\". Proceeding..";
                                                echo "rsynctargetport=\"$rsyncport\"" >> $backupconfig;
                                                break;;
                                        [Nn]* ) echo "Please Enter A New Port To Use.";
                        			while true; do
                                			if [[ $rsyncport != $newrsyncport ]]; then
                                			read -e newrsyncport
                                        			while true; do
                                        			read -p "You Have Entered The Port \"$newrsyncport\". Is This Correct? Please Select [y/N]" yn
                                                			case $yn in
                                                        			[Yy]* ) rsyncport="$newrsyncport";
                                                                			echo "Using \"$newrsyncport\" As The Remote Port.";
                                                                			echo "rsynctargetport=\"$rsyncport\"" >> $backupconfig;
                                                                			break;;
                                                        			[Nn]* ) echo "Please Enter Your Corrected Port.";
                                                               	 			break;;
                                                        			* ) echo "Please Select [y/N]";;
                                                			esac
                                        			done
                                			else
                                        			break;
                                			fi
                        			done
                                                break;;
                                        * ) echo "Please Select [y/N]";;
                                esac
                        done


                        # Remote username used for the backups - Possible provide printed pub key or create one.
                        echo "Please Enter The Username Of The Remote User You Will Be Using:"
                        while true; do
                                if [[ $rsyncusername != $newrsyncusername ]]; then
                                read -e newrsyncusername
                                        while true; do
                                        read -p "You Have Entered The Username \"$newrsyncusername\". Is This Correct? Please Select [y/N]" yn
                                                case $yn in
                                                        [Yy]* ) rsyncusername="$newrsyncusername";
                                                                echo "Using \"$newrsyncusername\" As The Remote Username.";
                                                                echo "rsynctargetname=\"$rsyncusername\"" >> $backupconfig;
                                                                break;;
                                                        [Nn]* ) echo "Please Enter Your Corrected Username.";
                                                                break;;
                                                        * ) echo "Please Select [y/N]";;
                                                esac
                                        done
                                else
                                        break;
                                fi
                        done

                        # Path of the directory to store the backups - Default is /ap-scripts/backups/archive
                        echo "Please Enter The Full Directory Of The Path You Wish To Store The Archive On The Remote Server:"
                        while true; do
                                read -p "Please Select Which Directory You Wish To Store The Archive On The Remote Server, Do You Wish To Use The Default Path $rsyncdir? Please Select [y/N]" yn
                                case $yn in
                                        [Yy]* ) echo "Thanks You For Confirm The Default Path \"$rsyncdir\". Proceeding..";
                                                echo "rsyncremotepath=\"$rsyncdir\"" >> $backupconfig;
                                                break;;
                                        [Nn]* ) echo "Please Enter A New Path To Use.";
                                                while true; do
                                                        if [[ $rsyncdir != $newrsyncdir ]]; then
                                                        read -e newrsyncdir
                                                                while true; do
                                                                        read -p "You Have Entered The Path \"$newrsyncdir\". Is This Correct? Please Select [y/N]" yn
                                                                        case $yn in
                                                                                [Yy]* ) rsyncdir="$newrsyncdir";
                                                                                        echo "Using \"$newrsyncdir\" As The Remote Archive Path.";
                                                                                        echo "rsyncremotepath=\"$rsyncdir\"" >> $backupconfig;
                                                                                        break;;
                                                                                [Nn]* ) echo "Please Enter Your Corrected Path.";
                                                                                        break;;
                                                                                * ) echo "Please Select [y/N]";;
                                                                        esac
                                                                done
                                                        else
                                                        break;
                                                        fi
                                                done
                                                break;;
                                        * ) echo "Please Select [y/N]";;
                                esac
                        done
                else
                        break;
                fi
			}

	# Fuction for installing a new config file, this also includes the removal of old config files if theoption was chosen to do so
        newconfig()     {

        	if [ -f "$backupconfig" ]; then
			rm -f $backupconfig
			echo "Removing Old Configuration File.."
	    	fi

	    	echo "Creating AP-Backup Configuration File under $backupconfig"
            	touch $backupconfig
	    	echo "# *****************************************************************" >> $backupconfig
	    	echo "#                 AP-Backups Configuration File" >> $backupconfig
	    	echo "# *****************************************************************" >> $backupconfig
	    	echo "" >> $backupconfig

	    	# Asking the user if they are running a webserivce, if so detecting what web server they currently have running and then confirming if thats the one they want to be included
    		echo "# Web Service Settings" >> $backupconfig

    		while true; do
			read -p "Are You Running A Webservice? Please Select [y/N]" yn
	    		case $yn in
				[Yy]* )
        	    			echo "Checking For Currently Avalible Web Hosts..";
				                if netstat -plnt | grep 80 | grep -i "nginx" > /dev/null; then
				                        webservice="nginx";
                					detectingwebservice;
							break;
                				elif netstat -plnt | grep 80 | grep -i "apache2" > /dev/null; then
                        				webservice="apache2";
                					detectingwebservice;
							break;
                				elif netstat -plnt | grep 80 | grep -i "httpd" > /dev/null; then
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
					echo "";
		    			echo "Proceeding With No Webservice";
					webservice="non";
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

		#Wrapping this up so if the user has not selected any web services they can skip this part
		if [ "$webservice" == "non" ]; then
			echo "Skipping Setting Up Vhost Backup Directory's As You Have Selected No Web Service"
			echo ""
		else
			echo "Currently Scanning $webservice For Potential Backup Locations"

			# Nginx Config;
			nginxvhosts=`grep -ri "set $root_path" /etc/nginx/sites-enabled/* | tr -d ';' | tr -d "'" | awk '{print $NF}'`

			for nginxvhost in $nginxvhosts; do
               			read -p "We Have Detected The Following Vhost $nginxvhost. Do You Wish For This Vhost To Be Backed Up? Please Select [y/N]" yn
				case $yn in
                        		[Yy]* ) local vhlength=${#extradir}
                                        	local vhlastchar=${extradir:extlength-1:1}
                                        	# Variable needs a / at the end. If it does we add the path in as is, if not we will add the / on for the user and then submit. This is to stop the script breaking.
                                        	if [ "$vhlastchar" != "/" ]; then
                                			vhost_backup_dir_hold="$vhost_backup_dir_hold$nginxvhost/,"
                        			else
                                			vhost_backup_dir_hold="$vhost_backup_dir_hold$nginxvhost,"
                        			fi
						;;
                               		[Nn]* ) ;;
                                	* ) 	echo "Please Select [y/N]";;
                      		esac    
			done

			echo "Proceeding.."

                	# Below variable change is to remove the last comma that is inserted by the above statement which helps clean up the config file. It then inserts the paths into the config file.
                	vhost_backup_dir_hold="${vhost_backup_dir_hold%?}"
                	echo "vhost_backup_directory=\"$vhost_backup_dir_hold\"" >> $backupconfig
                	echo "" >> $backupconfig		
                	echo ""		
		fi

			while true; do
                		read -p "Do You Wish To Enter Any Custom Directory's To Be Included In The Backup? Please Select [y/N]" yn
                    		case $yn in
                    			[Yy]* ) 
			    			echo "Please Enter The Full Paths To The Extra Directory's You Wish To Backup (You May Use Tab To Assist). Once Complete Please Enter 'Finish'"
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

			# Below variable change is to remove the last comma that is inserted by the above statement which helps clean up the config file. It then inserts the paths into the config file.
	    		backup_dir_hold="${backup_dir_hold%?}"
	    		echo "backup_directory=\"$backup_dir_hold\"" >> $backupconfig
	    		echo "" >> $backupconfig

                echo "# Database Service Settings" >> $backupconfig

                while true; do
                        read -p "Are You Running A Database Service? Please Select [y/N]" yn
                        case $yn in
                                [Yy]* )
                                        echo "Checking For Currently Avalible Database Software..";
                                        if netstat -plnt | grep "mysql" > /dev/null; then
                                                databaseservice="mysql";
                                                detectingdatabaseservice;
                                                break;
                                        elif netstat -plnt | grep "mysqld" > /dev/null; then
                                                databaseservice="mysql";
                                                detectingdatabaseservice;
                                                break;
                                        else
                                                webservice="non";
                                                detectingdatabaseservice;
                                                break;
                                        fi
                                                break;;
                                [Nn]* )
                                        echo "Proceeding With No Database Service";
					echo ""
					databaseservice="non";
                                        echo "database=\"non\"" >> $backupconfig;
                                        break;;
                                * )
                                        echo "Please Select [y/N]";;
                        esac
                done

                echo "" >> $backupconfig

		if [ "$databaseservice" == "non" ]; then
			echo "Skipping Setting Up Excluded Databases To Include In The Backup Due To No Database Service Being Selected"
			echo ""
		else
        		# Giving The User A Choice To Enter Any Databases They Wish To Exclude From The Backups
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
		fi

		# Adding the MySQL Databases Entered into the config file
		excludedb_hold="${excludedb_hold%?}"
		echo "exclude_databases=\"$excludedb_hold\"" >> $backupconfig;

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

		# Call Function To Set-Up Rsync config (Called a seperate function so that we may recall if changes are needed when info is checked)
		rsyncconfig

		# Give the user the ability to check there connection details and see if it works as intended.
		if [ $rsyncenabled == "yes" ]; then
			# Seeing if an SSH Key current edits, if so printing it out, if not then asking the user if they want to generate one
			if [ -f ~/.ssh/id_rsa.pub ]; then
				echo "We Have Detected That You Already Have An SSH Key Setup Under $sshkey, You Will Need This When Setting Up Rsync So We Have Printed This For You Below;"
				cat ~/.ssh/id_rsa.pub
			else
                        	while true; do
                                	read -p "We can't find a Public Key Associated With This User, Do You Wish To Create One? Please Select [y/N]" yn
                                	case $yn in
                                        	[Yy]* ) echo "Creating A New SSH Key";
							ssh-keygen -f ~/.ssh/id_rsa -t rsa -N '' > /dev/null;
							cat ~/.ssh/id_rsa.pub;
                                                	break;;
                                        	[Nn]* ) echo "Proceeding Without Creating A Key.";
                                                	break;;
                                        	* ) echo "Please Select [y/N]";;
                                	esac
                        	done
			fi

			status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -p $rsyncport $rsyncusername@$rsyncaddress echo ok 2>&1)

			if [ -f ~/.ssh/id_rsa.pub ]; then
                                while true; do
                                        read -p "Please Make Sure Your Public SSH Key Is On The Allowed List On The Remote Server So That We Can Test The Connection. When Finished Please Enter "y". If You Wish To Skip Testing The Connection Please Select " yn
                                        case $yn in
                                                [Yy]* ) echo "Testing Connection To Remote Server"
                                			if [[ $status == ok ]] ; then
                                        			echo "Connection To Remote Server Succesfull"
                                        			while true; do
                                                		read -p "Do You Wish To Test The Rysnc Details By Sending Over A Test File? Please Select [y/N]" yn
                                                			case $yn in
                                                        			[Yy]* ) echo "Attempting Connection.."
                                                                			touch $scripts_dir/$rsynchost-rsynctest.txt
                                                                			ssh -p $rsyncport $rsyncusername@$rsyncaddress "test -d $rsyncdir || mkdir -p $rsyncdir && exit"
                                                                			rsync -avz -e "ssh -p $rsyncport" $scripts_dir/$rsynchost-rsynctest.txt $rsyncusername@$rsyncaddress:$rsyncdir > /dev/null
                                                                			break;;
                                                        			[Nn]* ) echo "Proceeding Without Testing The Connection."
                                                                			break;;
                                                        			* ) echo "Please Select [y/N]";;
                                                			esac
                                        			done
                                			elif [[ $status == "Permission denied"* ]] ; then
                                        			echo "No Authorization To Access Remote Server - Please Check If SSH Key Has Been Added"
                                			else
                                        			echo "Can't Connect To The Remote Server, After The Installation Is Complete Please Continue Troubleshooting Efforts"
                                			fi
                                                        break;;
                                                [Nn]* ) echo "Proceeding Without Testing The Connection.";
                                                        break;;
                                                * ) echo "Please Select [y/N]";;
                                        esac
                                done
			else
                               	break;
                        fi
		else
			break;
		fi

		echo "" >> $backupconfig
		echo "# Cron Job Settings" >> $backupconfig

                # Define what time the user wants to run the backup job
                echo "Please Enter The Time That You Want To Backup Job To Run In The Following Format [XX:XX]"
	        while true; do
                      	if [[ $jobtime != $newjobtime ]]; then
                        read -e newjobtime
				if [[ "$newjobtime" =~ ^[0-2][0-9]:[0-9][0-9]$ ]]; then
                        		while true; do
                                	read -p "You Have Entered The Time \"$newjobtime\". Is This Correct? Please Select [y/N]" yn
                                		case $yn in
                                        		[Yy]* ) jobtime="$newjobtime";
                                                        	echo "Using \"$newjobtime\" As The Remote Username.";
                                                        	echo "cronjob_time=\"$jobtime\"" >> $backupconfig;
                                                        	break;;
                                               		[Nn]* ) echo "Please Enter Your Corrected Time.";
                                                        	break;;
                                                	* ) echo "Please Select [y/N]";;
                                        	esac
                                	done
				else
					echo "Please Enter A Time In The Following Format XX:XX"
				fi
                        else
                                break;
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
			break;
		fi

                testcompressiondays=$(grep "compression_delay" $backupconfig | awk -F\' '{print $2}')

                if [[ "$testcompressiondays" =~ ^[0-9]{1,3}$ ]]; then
		        echo "Time To Trigger Backup Compression Is Valid"
                else
                        echo "Verification Check Of The Original Configuration File Failed, Moving The Old Config File To $backupconfigold & Starting Process To Create New Confg File"
                        mv $backupconfig $backupconfigold;
                        newconfig;
			break;
                fi
                        }

	# Detecting if a previous configuration file exists, this will then trigger one of two functions. One to create a new one and one to check an old existing one
	if [ -f "$backupconfig" ]; then
                while true; do
                	read -p "Configuration File For Ap-Backups Already Exists Under $backupconfig. Do You Wish To Display The Contents Of This File Below?. Please Select [y/N]" yn
                        case $yn in
                        	[Yy]* ) echo "";
                                	echo "";
					cat $backupconfig;
					echo "";
					echo "";
                                        break;;
                                [Nn]* ) echo "Proceeding Without Displaying The Old Configuration File.";
                                	break;;
                                * ) echo "Please Select [y/N]";;
                        esac
                done

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

	# Download The Backup Script
	echo "Downloading The Backup Script, This Will Be Stored In \"/ap-scripts/\""
	wget http://dl.apenketh.com/ap-backups/ap-backups.sh -P /ap-scripts/ > /dev/null

	echo "Installation of AP-Backups has been succesfully completed"

    	echo ""
    	echo "*****************************************************************"
    	echo ""
