# Monitoring scripts
telegram.bot.conf  		contains variables for the telegram.bot script (see https://www.cytron.io/tutorial/how-to-create-a-telegram-bot-get-the-api-key-and-chat-id)
check_zfs_status.sh		check status of zfs pool and sends a notification
check_backup_status.sh		check the backup tasks status ended in the last n seconds (default 3600) and sends a notification for each one
check_vm_status.sh		check if the status ofthe vm and report any that is not running
check_datastore_status.sh	check if the datastores are available
check_services_status.sh	check the status of the node services and reports any enabled service which is not running

Requirements:
https://github.com/beep-projects/telegram.bot
placed in the same folder of the monitoring scripts
