*** **Warning This Script Is Currently In A Development State And Therefore No Guarantees Are Made As To The Results Of This Script. Please Use At Your Own Risk.** ***

***

# Ap-Backups
The Ap-Backups script was created primarily as a simple way to back up folders and/or databases and then provide an option to copy them to another remote location to provide backups over time. It is currently developed in Bash and is intended to work out of the box with the following Operating Systems: RHEL/CentOS 6 & 7, Ubuntu 14.04 & 16.04.

## Usage
### Installation
The installer provides to you via the command line the ability to interact and customize the configuration file to suit your specific needs. It is built for ease of use so you do not have to remember any specific build options or cravats with its use.

To download and run the installer script you can run the following one line command directly from your CLI as the root user:

`curl -OsS https://raw.githubusercontent.com/APenketh/ap-linux-backups/Live/apb-installation.sh && bash apb-installation.sh`

This will download the installation file and then run it, it will ask you for various inputs which will require your interaction. Once it has completed you will be then ready to run your first backup.

***

### Operating The Script
#### Performing A Manual Backup
At any time, you can perform a manual backup by initiating the script yourself; to do this as the root user you call the script in its current location and then use the -r flag, which runs a backup immediately. For example `/opt/ap-backups/ap-backups.sh -r`

#### Set Up Automatic Backups

To easiest way to run automatic backups is to use the inbuilt cron deamon as part of your operating system. An example below of a cron job task to run the backup at 10PM server time every night is below;

`0 20 * * * /opt/ap-backups/ap-backups.sh -r`

#### Getting Help From The Script
If you need some help with remembering options for the script you can get help with the available options as well as a short description of what the option does by running the script with "-h" flag: `bash ap-backups.sh -h`

Example Output:
```
Usage:
        apbackups.sh -[shortoption] --[longoption]
Options:
        Either long or short options are allowed.
        --runbackup       -r            Perform A Backup Based Off The Parameters In The Configuration File
        --sync            -s            Performed A Manual Sync Of Previous Backups To The Remote Host Defined In The Configuration File
        --updatevhosts    -u            Update The Vhost To Backup In The Config File
        --version         -v            Get Script Information & Version
        --help            -h            Display The Help
```
