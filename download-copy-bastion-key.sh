#!/bin/sh

# 1. Configure AWS CLI
echo "1. aws conigure"
# aws configure

# 2. Get key ID from Systems Manager paramater
echo "2. Search KyePair Id from System Manager Parameter"
KeyPairID=`aws ec2 describe-key-pairs --key-names "BastionKeyPair" --query 'KeyPairs[].KeyPairId' --output text`

# 3. Download key from Systems Manager parameter
echo "3. download ssh key from System Manager Parameter using keypair id"
rm -f  bastion-key.pem
echo "$(aws ssm get-parameter --name /ec2/keypair/${KeyPairID} --with-decryption --query Parameter.Value --output text)" > bastion-key.pem

# 4. Set appropriate file mode bits
chmod 400 bastion-key.pem
echo "4. bastion-key.pem to 400"
echo "Bastion key is downloaded as bastion-key.pem" 

# 5. Copy to Bastion server in Public zone ( assume there is only one instance that has public IP)
echo "5. copy ssh key to bation"
PublicIP=`aws ec2 describe-instances | jq -r .Reservations[].Instances[].PublicIpAddress | egrep -v null`
ssh -i ./bastion-key.pem ec2-user@$PublicIP "rm -f  ~/bastion-key.pem"
scp -i ./bastion-key.pem ./bastion-key.pem ec2-user@$PublicIP:~

# 6. Log in to bastion
echo "6. Log in to bastion"
echo "Check if bation-key.pem was copied on this bastion server using ls -l" 
ssh -i ./bastion-key.pem  ec2-user@$PublicIP

