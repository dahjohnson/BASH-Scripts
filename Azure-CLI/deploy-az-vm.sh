#!/bin/bash

#Script to deploy Azure Virtual Machine

#####################################################
###########  Define Variables/Functions  ############
#####################################################

#Define Script Text Formating
blue="\033[34m"
red="\033[4;31m"
none="\033[0m"

#Define Region Location for Resources
loc="eastus"
image="Win2022Datacenter"

#Obtain User's Local Public ip
pip=$(curl -s -4 icanhazip.com)

#Define Log file
log_date=$(date +"%Y_%m_%d")
error_log=""$log_date"_az_deployment_error.log"

#Deploy New Resource Group Function
deployRG(){
  read -ep "Define a Resource Group name: " -i "MyRG" rg_name
  az group create --name $rg_name --location $loc 2>> $error_log
}

#Use Existing Resource Group Function
existingRG(){
  az group list --output table
  read -p "Enter the name of the Resource Group you wish to use: " rg_name
}

#Deploy New VNET Function
deployVNET(){
  local vnet_cidr
  local new_subnet_cidr
  read -ep "Define a Virtual Network name: " -i "MyVNET" vnet_name
  read -ep "Define the Virtual Network CIDR: " -i "172.16.0.0/16" vnet_cidr
  read -ep "Define a Subnet name: " -i "MySubnet" new_subnet_name
  read -ep "Define a Subnet CIDR: " -i "172.16.0.0/24" subnet_cidr
  az network vnet create --name $vnet_name --resource-group $rg_name \
  --location $loc --address-prefix $vnet_cidr \
  --subnet-name $new_subnet_name --subnet-prefix $subnet_cidr 2>> $error_log
}

#Use Existing VNET Function
existingVNET(){
  az network vnet list --resource-group $rg_name \
  --query "[].{Address_Space:addressSpace.addressPrefixes[0],Name:name}" --output table
  read -p "Enter the name of the Virtual Network you wish to use: " vnet_name
  echo
  az network vnet subnet list --resource-group $rg_name \
  --vnet-name $vnet_name \
  --query "[].{Address_Space:addressPrefix,Name:name}" --output table
  read -p "Enter the name of the Subnet you wish to use: " subnet_name
}

#Deploy and Assign NSG rules Function
deployNSGrules(){
  read -ep "Define Network Security Group Name: " -i "MyNSG" nsg_name
  az network nsg create --name $nsg_name --resource-group $rg_name 
  az network nsg rule create --name "Allow RDP" --nsg-name $nsg_name \
  --resource-group $rg_name --priority 300 \
  --access allow --direction Inbound --protocol TCP \
  --destination-address-prefixes '*' --destination-port-ranges 3389 \
  --source-address-prefixes $pip --source-port-ranges '*' 
  az network nsg rule create --name "Allow Web" --nsg-name $nsg_name \
  --resource-group $rg_name --priority 500 \
  --access allow --direction Inbound --protocol TCP \
  --destination-address-prefixes '*' --destination-port-ranges 80 \
  --source-address-prefixes '*' --source-port-ranges '*' 
  az network vnet subnet update --name $new_subnet_name \
  --resource-group $rg_name --vnet-name $vnet_name \
  --network-security-group $nsg_name 
}

#Deploy Windows VM Function
deployVM(){
  #Gather input from user for Windows VM deployment
  read -ep "Define Windows VM name: " -i "WindowsVM" vm_name
  read -ep "Define Windows VM admin user name: " -i "azureuser" user_name
  echo "Define Windows VM admin user password: "
  echo "Once you are done typing hit enter"
  read -s user_pass
  #Create VM
  az vm create --resource-group $rg_name --name $vm_name \
  --subnet $subnet_name --vnet-name $vnet_name \
  --nsg "" --image $image --public-ip-sku Standard \
  --admin-username $user_name --admin-password $user_pass 2>> $error_log
  local exit_status=$?
  local vm_pip=$(az vm show -d -g $rg_name -n $vm_name --query publicIps -o tsv)
  if [[ $exit_status -eq 0 ]]; then
    echo -e "\n""Success!😊"
    echo -e "Your VM Public IP: "$blue""$vm_pip""$none""
    echo -e "Now installing IIS on $vm_name...One Moment...""\n"
  elif [[ ! $exit_status -eq 0 ]]; then
    echo -e "\n""Troubleshoot errors and Try Again 😔""\n"
  fi
  [[ $exit_status -eq 0 ]] || return 2 
}

#Install IIS on Windows VM Function
installIIS(){
  az vm run-command invoke --resource-group $rg_name \
  --name $vm_name --command-id RunPowerShellScript \
  --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools" \
  2>> $error_log
}

logMessage(){
  echo -e "\n"$red"Error"$none": View deployment details in "$blue"$error_log"$none"\n"
  exit
}

#####################################################
##########   Confirm Azure Subscription    ##########
#####################################################


#List default Azure Subscription Selected
#Verify you have the correct subscription/tenant ID selected
echo
az account show  --query "{Environment:environmentName,SubscriptionId:id,Name:name}" --output table
echo
echo -e "If wrong Subscription is selected exit script by entering \"$blue"Ctrl + C"$none\" and choose the correct subscription"
echo
echo "For instructions on changing the active Subscription >>> https://learn.microsoft.com/en-us/cli/azure/manage-azure-subscriptions-azure-cli#change-the-active-subscription"
echo

#####################################################
##########    Define Resource Group        ##########
#####################################################

#Prompt user to create a new RG or define an existing RG
echo
echo "Would you like to deploy the VM to a new or existing Resource Group?"
echo

#Present option to create new or select existing Resource Group
new_rg="New Resource Group"
old_rg="Existing Resource Group"

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
##########    Define Virtual Network        #########
#####################################################

echo -e "\n""Would you like to deploy a VM to a new or existing Virtual Network?""\n"

#Present option to create new or select existing Virtual Network/Subnet
new_vnet="New Virtual Network"
old_vnet="Existing Virtual Network"

select vnet_option in "$new_vnet" "$old_vnet";
do
  echo
  case $vnet_option in
    $new_vnet) 
      deployVNET || logMessage
      break;;
	$old_vnet)
	  existingVNET
	  break;;
  esac
done

#####################################################
####### Define/Assign Network Security Group  #######
#####################################################

#Create new NSG and rules, and attach to new subnet 
[ $new_subnet_name ] && deployNSGrules || logMessage

#####################################################
##########    Create Virtual Machine        #########
#####################################################

#Change New Subnet name variable to $subnet_name
[ $new_subnet_name ] && subnet_name=$new_subnet_name

#Deploy VM and Install IIS Web Services
deployVM && installIIS || logMessage

#####################################################
##########       Helpful Commands          ##########
#####################################################

#Retrieve VM image list (urnAlias)
#az vm image list --query [].urnAlias

#Retrieve available region list
#az account list-locations \
#--query "[].{DisplayName:displayName, Name:name,region:regionalDisplayName}" --output table
