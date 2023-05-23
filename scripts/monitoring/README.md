# Monitoring scripts
send_message.sh  		contains the send message function for yout telegram bot (needs some preliminary steps to be performed, see https://www.cytron.io/tutorial/how-to-create-a-telegram-bot-get-the-api-key-and-chat-id)
check_zfs_status.sh		check status of zfs pool and sends a notification
check_backup_status.sh		check the backup tasks status ended in the last n seconds (default 3600) and sends a notification for each one
check_vm_status.sh		check if the status ofthe vm and report any that is not running
check_services_status.sh	check the status of the node services and reports any enabled service which is not running
