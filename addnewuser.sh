#!/bin/bash

#Add new user script

#Checking for Root/sudo privileges
if [ "$EUID" -ne 0 ]
then 
	echo "====================================="
        echo "Permission Error: Elevate permissions using sudo"
	echo "Example: \"sudo bash <path_to_script>\" 🤓"
        echo "====================================="
	exit
fi

#Prompt user to input name of new user
read -p "Enter the login name of the user you wish to create: " user_name

#If-Else statement that creates user if the user doesn't already exist
if
	id -u $user_name &>/dev/null;
then
	echo "======================="
	echo "User already exists!!!"
	echo "======================="
	exit
else
	useradd -m $user_name 2> /dev/null
	echo 
	echo "User $user_name has been created and their home dir is $(getent passwd $user_name | cut -d: -f6)👍"
	echo 
fi
