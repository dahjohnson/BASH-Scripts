#!/bin/bash

# BASH script for deploying an Amazon Linux EC2 instance with Apache preinstalled

#####################################################
############       Define Variables      ############
#####################################################

# Define Script Text Formating
blue="\033[34m"
red="\033[4;31m"
none="\033[0m"

#####################################################
###########          Functions         ##############
#####################################################

# Verify AWS CLI installed

verifyAWSCLI(){
    aws --version > /dev/null 2>&1
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo; echo -e $red'Error'$none': Missing AWS CLI package!'; echo
        echo 'For installation instructions go to:' 
        echo 'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'; echo
        exit
    fi
}

# Verify AWS Configure has a Profile

verifyAWSConfigure(){
if [ -z $(aws configure list-profiles) ]; then
    echo; echo -e $red'Error'$none': AWS CLI not Configured!'; echo
    echo 'For configuration instructions go to:'
    echo 'https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html'
fi
}


verifyAWSCLI 

verifyAWSConfigure

