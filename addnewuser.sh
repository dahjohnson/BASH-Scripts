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

#If argument provided, create new user(s) and skip the rest of BASH script
if
	[ $# -ge 1 ] && id -u $@ &>/dev/null;
then
	echo "=====================================" 
	echo "User(s) $@ already exists!!!"
	echo "====================================="
	echo "$(id $@)"
        echo
      	exit	
elif
	
	[ $# -ge 1 ]
then
	echo
	for user in $@;
	do
		useradd -m $user;
		echo -e "Username:$user\thome_dir:$(getent passwd $user | cut -d: -f6)";
	done
	echo
	echo "You have successfully created your new user(s) 👍";
	echo
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
	useradd -m $user_name
	echo 
	echo "User $user_name has been created and their home dir is $(getent passwd $user_name | cut -d: -f6)👍"
	echo 
fi
