#!/bin/bash

#Script to deploy Azure Virtual Machine

#####################################################
###########       Define Variables        ###########
#####################################################

#Define Script Text Formating
blue="\033[34m"
none="\033[0m"

#Define Region Location for Resources
loc="eastus"
image="Win2022Datacenter"

#Obtain Local Public ip
pip=$(curl -s -4 icanhazip.com)

#Public Ip of Azure VM (Not in Use)
#vm_pip=$(az vm show -d -g $rg_name -n $vm_name --query publicIps -o tsv)

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

#Present options to users
new_rg="New Resource Group"
old_rg="Existing Resource Group"

select rg_option in "$new_rg" "$old_rg";
do
	echo
	case $rg_option in
		$new_rg) 
			read -ep "Define a Resource Group name: " -i "MyRG" new_rg_name
			az group create --name $new_rg_name --location $loc > /dev/null
			break;;
		$old_rg)
			az group list --output table
			read -p "Enter the name of the Resource Group you wish to use: " old_rg_name
			break;;
	esac
done

#Change New or Existing RG name variable to $rg_name
if
    [ $old_rg_name ]
then
    rg_name=$old_rg_name
elif
    [ $new_rg_name ]
then
    rg_name=$new_rg_name
fi

#####################################################
##########    Define Virtual Network        #########
#####################################################

echo
echo "Would you like to deploy a VM to a new or existing Virtual Network?"
echo

#Present options to users
new_vnet="New Virtual Network"
old_vnet="Existing Virtual Network"

#Case/Select statement for new and existing VNET
select vnet_option in "$new_vnet" "$old_vnet";
do
	echo
	case $vnet_option in
		$new_vnet) 
			read -ep "Define a Virtual Network name: " -i "MyVNET" new_vnet_name
			read -ep "Define the Virtual Network CIDR: " -i "172.16.0.0/16" new_vnet_cidr
			read -ep "Define a Subnet name: " -i "MySubnet" new_subnet_name
			read -ep "Define a Subnet CIDR: " -i "172.16.0.0/24" new_subnet_cidr
			az network vnet create --name $new_vnet_name --resource-group $rg_name \
			--location $loc --address-prefix $new_vnet_cidr \
			--subnet-name $new_subnet_name --subnet-prefix $new_subnet_cidr > /dev/null
			break;;
		$old_vnet)
			az network vnet list --resource-group $rg_name \
			--query "[].{Address_Space:addressSpace.addressPrefixes[0],Name:name}" --output table
			read -p "Enter the name of the Virtual Network you wish to use: " old_vnet_name
			echo
			az network vnet subnet list --resource-group $rg_name \
			--vnet-name $old_vnet_name \
			--query "[].{Address_Space:addressPrefix,Name:name}" --output table
			read -p "Enter the name of the Subnet you wish to use: " old_subnet_name
			break;;
	esac
done

#####################################################
####### Define/Assign Network Security Group  #######
#####################################################

#Define NSG and NSG rules for Inbound 
if 
	[ $new_subnet_name ]
then
	read -ep "Define Network Security Group Name: " -i "MyNSG" nsg_name
	az network nsg create --name $nsg_name --resource-group $rg_name > /dev/null
	az network nsg rule create --name "Allow RDP" --nsg-name $nsg_name \
	--resource-group $rg_name --priority 300 \
	--access allow --direction Inbound --protocol TCP \
	--destination-address-prefixes '*' --destination-port-ranges 3389 \
	--source-address-prefixes $pip --source-port-ranges '*' > /dev/null
	az network nsg rule create --name "Allow Web" --nsg-name $nsg_name \
	--resource-group $rg_name --priority 500 \
	--access allow --direction Inbound --protocol TCP \
	--destination-address-prefixes '*' --destination-port-ranges 80 \
	--source-address-prefixes '*' --source-port-ranges '*' > /dev/null
	az network vnet subnet update --name $new_subnet_name \
	--resource-group $rg_name --vnet-name $new_vnet_name \
	--network-security-group $nsg_name > /dev/null
fi

#####################################################
##########    Create Virtual Machine        #########
#####################################################

read -ep "Define Windows VM name: " -i "WindowsVM" vm_name
read -ep "Define Windows VM admin user name: " -i "azureuser" user_name
echo "Define Windows VM admin user password: "
echo "Once you are done typing hit enter"
read -s user_pass

#Change New or Existing VNET name variables to $vnet_name
if
    [ $old_vnet_name ]
then
	vnet_name=$old_vnet_name
	subnet_name=$old_subnet_name
elif
    [ $new_vnet_name ]
then
	vnet_name=$new_vnet_name
	subnet_name=$new_subnet_name
fi

#Create VM
az vm create --resource-group $rg_name --name $vm_name \
--subnet $subnet_name --vnet-name $vnet_name \
--nsg "" --image $image --public-ip-sku Standard \
--admin-username $user_name --admin-password $user_pass
vm_exit_status=$?
az vm run-command invoke --resource-group $rg_name \
--name $vm_name --command-id RunPowerShellScript \
--scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools"

if
[ $vm_exit_status -eq 0 ]
then
echo
echo "Success!😊"
#echo -e "Your VM Public IP: $blue$vm_pip$none"
echo
elif
[ ! $vm_exit_status -eq 0 ]
then
echo
echo "Troubleshoot errors and Try Again 😔"
echo
fi

#####################################################
##########       Helpful Commands          ##########
#####################################################

#Retrieve VM image list (urnAlias)
#az vm image list --query [].urnAlias

#Retrieve available region list
#az account list-locations \
#--query "[].{DisplayName:displayName, Name:name,region:regionalDisplayName}" --output table
