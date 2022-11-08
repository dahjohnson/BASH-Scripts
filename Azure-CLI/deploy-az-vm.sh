#!/bin/bash

# BASH Script to deploy Windows Virtual Machine in Azure
# Has the following capabilities:
## Ability to change active AZ subscription
## Uses New/Existing Resource Groups, VNETs, and Subnets
## Creates and Assigns NSG rules to new subnet
### NSG rules allow HTTP inbound from 0.0.0.0/0
### NSG rules allow RDP from user's local Public IP
## Installs IIS on Azure VM

#####################################################
############       Define Variables      ############
#####################################################

# Define Script Text Formating
blue="\033[34m"
red="\033[4;31m"
none="\033[0m"

# Define Region Location and Image for VM
loc="eastus"
image="Win2022Datacenter"

# Obtain User's Local Public ip
pip=$(curl -s -4 icanhazip.com)

# Define Error Log file
log_date=$(date +"%Y_%m_%d")
error_log=""$log_date"_az_deployment_error.log"

# Used in Select statement to define RG option
new_rg="New Resource Group"
old_rg="Existing Resource Group"

# Used in Select statement to define VNET option
new_vnet="New Virtual Network"
old_vnet="Existing Virtual Network"

#####################################################
###########          Functions         ##############
#####################################################

# Verify AZ Subscription Function
verifySub(){
  local default_sub=$(az account show  --query "id" --output tsv)
  local sub_id 
  echo
  # List default AZ Subscription Selected
  az account show  --query "{Environment:environmentName,SubscriptionId:id,Name:name}" \
    --output table
  echo -e "\n""Is the correct subscription you wish to deploy in selected above?""\n"
  # Select statement that allows user to change the active AZ subscription
  select sub_option in yes no; do
    echo
    case $sub_option in
      yes)
        echo; echo "You have chosen subscription $default_sub!"; echo
        break;;
      no)
        # List available AZ subscriptions
        az account list --all --query "[].{Name:name,SubscriptionID:id}" \
          --output table
        # Prompt user to enter desired Sub Id
        read -p "Enter the the preffered Subscription ID from the list above: " \
          sub_id
        # Set new AZ subscription
        az account set --subscription $sub_id 2>> $error_log
        [[ $? -ne 0 ]] && exit 200
        echo; echo "You have chosen subscription $sub_id!"; echo
        break;;
    esac
  done
}

#Deploy New Resource Group Function
deployRG(){
  #Prompt user to define new Resource Group name
  read -ep "Define a Resource Group name: " \
    -i "MyRG" rg_name

  # Create new Resource Group
  az group create --name $rg_name \
    --location $loc 2>> $error_log
  local exit_code=$?
  [[ $exit_code -eq 0 ]] || return 200
  new_rg="1"
}

#Use Existing Resource Group Function
existingRG(){
  # List available Resource Grups
  az group list --output table 2>> $error_log
  local exit_code=$?
  [[ $exit_code -eq 0 ]] || return 200
  
  # Prompt user to enter existing RG name
  read -p "Enter the NAME of the Resource Group you wish to use: " \
    rg_name
  old_rg="1"
}

# Deploy New VNET Function
deployVNET(){
  local vnet_cidr
  local subnet_cidr
  
  # Prompt user for input regarding new VNET/Subnet
  read -ep "Define a Virtual Network Name: " \
    -i "MyVNET" vnet_name
  read -ep "Define the Virtual Network CIDR: " \
    -i "172.16.0.0/16" vnet_cidr
  read -ep "Define a Subnet Name: " \
    -i "MySubnet" subnet_name
  read -ep "Define a Subnet CIDR: " \
    -i "172.16.0.0/24" subnet_cidr
  
  # Create AZ VNET
  az network vnet create \
    --resource-group $rg_name --location $loc \
    --name $vnet_name --address-prefix $vnet_cidr \
    --subnet-name $subnet_name --subnet-prefix $subnet_cidr \
    2>> $error_log
    local exit_code=$?
    [[ $exit_code -eq 0 ]] || return 200
}

# Use Existing VNET/Subnet Function
existingVNET(){
  az network vnet list --resource-group $rg_name \
    --query "[].{Name:name,Address_Space:addressSpace.addressPrefixes[0]}" \
    --output table 2>> $error_log
  local exit_code=$?
  [[ $exit_code -eq 0 ]] || return 200

  # Prompt user to select existing VNET
  read -p "Enter the NAME of the Virtual Network you wish to use: " \
    vnet_name
  echo

  # List available subnets based on VNET chosen
  az network vnet subnet list --resource-group $rg_name \
    --vnet-name $vnet_name \
    --query "[].{Name:name,Address_Space:addressPrefix}" \
    --output table 2>> $error_log
  local exit_code=$?
  [[ $exit_code -eq 0 ]] || return 200

  # Prompt user to select existing subnet
  read -p "Enter the NAME of the Subnet you wish to use: " \
    subnet_name
}

# Deploy and Assign NSG rules Function
deployNSGrules(){
  read -ep "Define Network Security Group Name: " \
    -i "MyNSG" nsg_name
  
  # Create NSG resource object
  az network nsg create --name $nsg_name \
    --resource-group $rg_name 
  
  # Create NSG rule to allow RDP for User IP
  az network nsg rule create --name "Allow RDP" \
    --nsg-name $nsg_name --resource-group $rg_name \
    --priority 300 --access allow --direction Inbound \
    --protocol TCP --source-port-ranges '*' \
    --source-address-prefixes $pip \
    --destination-address-prefixes '*' --destination-port-ranges 3389 
      
  # Create NSG rule to allow HTTP from 0.0.0.0/0
  az network nsg rule create --name "Allow Web" \
    --nsg-name $nsg_name --resource-group $rg_name \
    --priority 500 --access allow --direction Inbound \
    --protocol TCP --source-port-ranges '*' \
    --source-address-prefixes '*' \
    --destination-address-prefixes '*' --destination-port-ranges 80 
    
  # Assign NSG to VM subnet
  az network vnet subnet update --name $subnet_name \
    --resource-group $rg_name --vnet-name $vnet_name \
    --network-security-group $nsg_name 
}

# Deploy Windows VM Function
deployVM(){
  # Gather input from user for Windows VM deployment
  read -ep "Define Windows VM name: " \
    -i "WindowsVM" vm_name
  read -ep "Define Windows VM admin user name: " \
    -i "azureuser" user_name
  echo "Define Windows VM admin user password: "
  echo "Once you are done typing hit enter"
  read -s user_pass

  # Create VM
  az vm create --resource-group $rg_name --name $vm_name \
    --subnet $subnet_name --vnet-name $vnet_name \
    --nsg "" --image $image --public-ip-sku Standard \
    --admin-username $user_name \
    --admin-password $user_pass 2>> $error_log
  local exit_code=$?
  [[ $exit_code -eq 0 ]] || return 200

  local vm_pip=$(az vm show -d -g $rg_name -n $vm_name \
    --query publicIps -o tsv)

  if [[ $exit_code -eq 0 ]]; then
    echo -e "\n""Success!😊"
    echo -e "Your VM Public IP: "$blue""$vm_pip""$none""
    echo -e "Now installing IIS on $vm_name...One Moment...""\n"
  fi
}

# Install IIS on Windows VM Function
installIIS(){
  az vm run-command invoke --resource-group $rg_name \
    --name $vm_name --command-id RunPowerShellScript \
    --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools" \
    2>> $error_log
  local exit_code=$?
  [[ $exit_code -eq 0 ]] || return 200
}

# Error log message when Functions fail
logMessage(){
  echo
  echo -e "$red""Error""$none": View deployment details in "$blue""$error_log""$none😔"
  echo 
  exit
}

#####################################################
#########    Confirm AZ Subscription        #########
#####################################################       

verifySub || logMessage

#####################################################
#########     Define Resource Group         #########
#####################################################         

# Prompt user to create a new RG or define an existing RG
echo
echo "Would you like to deploy the VM to a new or existing Resource Group?"
echo

# Select statement to choose new/existing RG
select rg_option in "$new_rg" "$old_rg"; do
  echo
    case $rg_option in
	  $new_rg) 
	    deployRG || logMessage
	    break;;
	  $old_rg)
	    existingRG
            break;;
    esac
done

#####################################################
##########      Define VNET/Subnet         ##########
#####################################################

echo -e "\n""Would you like to deploy the VM to a new or existing Virtual Network?""\n"

#Present option to create new or select existing Virtual Network/Subnet

# If/else based on user selection of new/existing RG
# Select statement to choose new/existing VNET/Subnet
if [[ $old_rg = 1 ]]; then
  select vnet_option in "$new_vnet" "$old_vnet";
  do
    echo
    case $vnet_option in
      $new_vnet) 
        deployVNET && deployNSGrules || logMessage
        break;;
      $old_vnet)
	existingVNET || logMessage
	break;;
    esac
  done
elif [[ $new_rg = 1 ]]; then
  deployVNET && deployNSGrules || logMessage
fi


#####################################################
##########    Create Virtual Machine        #########
#####################################################

#Deploy VM and Install IIS Web Services
deployVM && installIIS || logMessage

#####################################################
##########       Helpful Commands          ##########
#####################################################

#Retrieve VM image list (urnAlias)
#az vm image list --query [].urnAlias

#Retrieve available region list
#az account list-locations \
  #--query "[].{DisplayName:displayName, Name:name,region:regionalDisplayName}" \
  #--output table 
