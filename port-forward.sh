#!/bin/bash

if [ $# != 1 ]; then
   echo "[Error] Specify 1 or 2 as an argument to claim which Terminal"
   echo "[Error] How to use:  double-port-forward.sh 1|2"
   exit 1
fi
if [ $1 = "1" ]; then
   TERMINAL="1"
   echo "[Log] Set up as Terminal 1. This will log in public bation." 
elif [ $1 = "2" ]; then
   TERMINAL="2"
   echo "[Log] set up as Terminal 2 (assuming you alread have another seesion by Terminal 1) This will login in private bastion" 
else
   echo "[Error] Specify 1 or 2 as an argument to claim which Terminal"
   echo "[Error] How to use:  double-port-forward.sh  1|2"
   exit 1
fi

# -----------------------------------------------------------------------
# Get private key from AWS
# 1. Configure AWS CLI
echo "[Log] 1. aws conigure"
# aws configure

# 2. Get key ID from Systems Manager paramater
echo "[Log] 2. Search KyePair Id from System Manager Parameter"
KeyPairID=`aws ec2 describe-key-pairs --key-names "BastionKeyPair" --query 'KeyPairs[].KeyPairId' --output text`

# 3. Download key from Systems Manager parameter
echo "[Log] 3. download ssh key from System Manager Parameter using keypair id"
rm -f  bastion-key.pem
echo "$(aws ssm get-parameter --name /ec2/keypair/${KeyPairID} --with-decryption --query Parameter.Value --output text)" > bastion-key.pem

# 4. Set appropriate file mode bits
chmod 400 bastion-key.pem
echo "[Log] 4. bastion-key.pem to 400"
echo "Bastion key is downloaded as bastion-key.pem" 

# 5. Copy to Bastion server in Public zone ( assume there is only one instance that has public IP)
echo "[Log] 5. copy ssh key to bation"
PublicIP=`aws ec2 describe-instances | jq -r .Reservations[].Instances[].PublicIpAddress | egrep -v null`
ssh -i ./bastion-key.pem ec2-user@$PublicIP "rm -f  ~/bastion-key.pem"
scp -i ./bastion-key.pem ./bastion-key.pem ec2-user@$PublicIP:~

# echo "6. Log in to bastion"
# echo "Check if bation-key.pem was copied on this bastion server using ls -l" 
# ssh -i ./bastion-key.pem  ec2-user@$PublicIP

# Get Bastion IPS
export PUBLIC_BASTION=`aws ec2 describe-instances | jq -r '.Reservations[] | [.Instances[].InstanceType, .Instances[].PrivateIpAddress, .Instances[].PublicIpAddress, .Instances[].Tags[]?.Value ]  | @csv' | egrep "Public" | awk -F'[,]' '{print $3}'  |  grep -v -e '^\s*$' | sed 's/"//g'`
echo "[Log] Public Bastion IP is $PUBLIC_BASTION"
export PRIVATE_BASTION=`aws ec2 describe-instances | jq -r '.Reservations[] | [.Instances[].InstanceType, .Instances[].PrivateIpAddress, .Instances[].PublicIpAddress, .Instances[].Tags[]?.Value ]  | @csv' | grep "Private" | awk -F'[,]' '{print $2}' | grep -v -e '^\s*$' | sed 's/"//g'`
echo "[Log] Private Bastion IP is $PRIVATE_BASTION"

# ---------------------------------------------------------------------------------- 
if [ $TERMINAL = "1" ]; then
  # Terminal 1
  echo "[Log] Login as Terminal 1" 
  ssh -i bastion-key.pem -p 22 ec2-user@$PUBLIC_BASTION -L 10022:$PRIVATE_BASTION:22
else 
  # Terminal 2
  echo "[Log] Login as Terminal 2 (assuming you already have Terminal 1 session)"
  ssh-keygen -f "/home/yuhki/.ssh/known_hosts" -R "[localhost]:10022"
  ssh -i bastion-key.pem -p 10022 ec2-user@localhost -D 10044
  echo "[Log] You need to add your VPC to Route53 zone as a related VPC so that you can resolve domain names created by ROSA from this bastion."
fi

# Local /etc/hosts
# console-openshift-console..... = console
# oauth-openshift.... = OAuth server
# The IP is private IP. Find the IP in the private network using "dig <domain name> +short"
# 10.0.1.214    console-openshift-console.apps.singleaz.dzfa.p1.openshiftapps.com
# 10.0.1.214    oauth-openshift.apps.singleaz.dzfa.p1.openshiftapps.com
