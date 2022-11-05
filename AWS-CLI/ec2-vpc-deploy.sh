#!/bin/bash

# BASH script for deploying an Amazon Linux EC2 instance with Apache preinstalled
# Also creates a new VPC and other essential network dependencies


# Define Variables

#Define VPC Name
read -ep "Define Name of VPC: " -i "MyVPC" vpc_name

#Define VPC CIDR Block
read -ep "Define $vpc_name CIDR block: " -i "192.168.0.0/16" vpc_cidr

#Define Subnet Name
read -ep "Define Name of subnet in $vpc_name: " -i "MySubnet" subnet_name

#Define VPC Subnet CIDR Block
read -ep "Define CIDR block for subnet in $vpc_name: " -i "192.168.0.0/24" subnet_cidr

#Define Internet Gateway
read -ep "Define Name of Internet Gateway: " -i "MyGateway" gateway_name


#Define SSH Key Pair name for remote access (Default=ssh_key_pair)
read -ep "Define name for SSH Key Pair: " -i "ssh_key_pair" key_pair

#Define Amazon Linux server name
read -ep "Define Amazon Linux Server name: " -i "Linux-VM" server_name

########################################################################

#Create VPC
aws ec2 create-vpc --cidr-block $vpc_cidr --tag-specification "ResourceType=vpc,Tags=[{Key=Name,Value=$vpc_name}]" > /dev/null

#Get VPC Id
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$vpc_name" --query "Vpcs[*].VpcId" --output text)

#Create Subnet

aws ec2 create-subnet --vpc-id $vpc_id  --cidr-block $subnet_cidr --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$subnet_name}]" > /dev/null  

#Get Subnet Id
subnet_id=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=$subnet_name --query "Subnets[*].SubnetId" --output text)


#Modify Subnet to allow public IP assignment on associated VM NIC 
aws ec2 modify-subnet-attribute --subnet-id $subnet_id --map-public-ip-on-launch


#Create Internet Gateway and attach to VPC
aws ec2 create-internet-gateway --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$gateway_name}]" > /dev/null

#Get Internet Gateway Id
gateway_id=$(aws ec2 describe-internet-gateways --filters Name=tag:Name,Values=$gateway_name --query "InternetGateways[*].InternetGatewayId" --output text)


#Attach Gateway to VPC
aws ec2 attach-internet-gateway --internet-gateway-id $gateway_id --vpc-id $vpc_id  

#Define Route Table Name
rt_name="rt-$vpc_name"

#Create Route Table
aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$rt_name}]" > /dev/null

#Get Route Table ID
rt_id=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=$rt_name" --query "RouteTables[*].RouteTableId" --output text)

#Associate Route Table
aws ec2 associate-route-table --route-table-id $rt_id --subnet-id $subnet_id > /dev/null

#Create Route for Route Table
aws ec2 create-route --route-table-id $rt_id --destination-cidr-block 0.0.0.0/0 --gateway-id $gateway_id > /dev/null

#Define Security Group Name
sg_name="sg_$vpc_name"

#Create security group
aws ec2 create-security-group --group-name $sg_name --description "My security group" --vpc-id $vpc_id > /dev/null

#Get Security Group ID
sg_id=$(aws ec2 describe-security-groups --filter "Name=group-name
,Values=$sg_name" --output text --query "SecurityGroups[*].GroupId" --output text)

#Get Public IP
pip=$(curl -s icanhazip.com) 

#Define Security Group SSH Ingress Rule
aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr $pip/32 > /dev/null

#Define Security Group HTTP Ingress Rule
aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 80 --cidr $pip/32 > /dev/null

#Create key pair "ssh_key_pair" and dump key material (ssh_key_pair.pem) in text file in current directory
aws ec2 create-key-pair --key-name $key_pair --query 'KeyMaterial' --output text > $key_pair.pem

#Create EC2 instance
aws ec2 run-instances --image- "ami-09d3b3274b6c5d4aa" --count 1 --instance-type t2.micro --subnet-id $subnet_id --security-group-ids $sg_id --key-name $key_pair --user-data file://install_apache.sh --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$server_name}]" > /dev/null

sleep 3

#Change permissions on SSH key
chmod 400 $key_pair.pem

#Print ec2 deployment info to user
aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Name:Tags[?Key=='Name']|[0].Value,Type:InstanceType,Status:State.Name,VpcId:VpcId}" --output table

#Get VM IP
vm_ip=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].PublicIpAddress" --filters "Name=tag:Name,Values=$server_name" --output text)

# Echo Public IP of EC2 instance and how to SSH
echo 
echo "If no errors reported, execute the following to SSH into your EC2 instance:"
echo
echo "ssh -i $key_pair.pem ec2-user@$vm_ip"
echo

