#!/bin/sh

# 1. Configure AWS CLI
aws configure

# 2. Get key ID from Systems Manager paramater
KeyPairID=`aws ec2 describe-key-pairs --key-names "BastionKeyPair" --query 'KeyPairs[].KeyPairId' --output text`

# 3. Download key from Systems Manager parameter
echo "$(aws ssm get-parameter --name /ec2/keypair/${KeyPairID} --with-decryption --query Parameter.Value --output text)" > bastion-key.pem

# 4. Set appropriate file mode bits
chmod 400 bastion-key.pem
echo "Bastion key is downloaded as bastion-key.pem" 

# 5. Copy to Bastion server in Public zone ( assume there is only one instance that has public IP)
PublicIP=`aws ec2 describe-instances | jq -r .Reservations[].Instances[].PublicIpAddress | egrep -v null`
scp -i ./bastion-key.pem ./bastion-key.pem ec2-user@$PublicIP:~
