#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Installing Docker
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


#Installing Terraform
TERRAFORM_VERSION="1.8.5"  
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
apt-get install -y unzip
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
mv terraform /usr/local/bin/
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

#Installing Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y openjdk-21-jdk jenkins

# Enable and start Jenkins
systemctl enable jenkins
systemctl start jenkins

usermod -aG docker jenkins
systemctl restart jenkins

# Installing kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Installing gcloud for accessing the gcp resources through cli
GCLOUD_VERSION=471.0.0 
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz
tar -xzf google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh --quiet
rm google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz

# Add gcloud to PATH for the current session and Jenkins
echo 'export PATH=$PATH:/root/google-cloud-sdk/bin' >> ~/.bashrc
export PATH=$PATH:/root/google-cloud-sdk/bin



