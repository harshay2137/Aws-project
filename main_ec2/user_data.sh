#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

echo "=== 1. Update system ==="
apt update && apt upgrade -y

echo "=== 2. Git ==="
apt install -y git

echo "=== 3. Java (needed for Jenkins) ==="
apt install -y openjdk-21-jdk

echo "=== 4. Jenkins ==="
wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" | \
  tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt update
apt install -y jenkins

echo "=== 5. Terraform ==="
apt install -y gnupg software-properties-common curl unzip
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  tee /etc/apt/sources.list.d/hashicorp.list
apt update
apt install -y terraform

echo "=== 6. Maven ==="
apt install -y maven

echo "=== 7. kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "=== 8. eksctl ==="
curl --silent --location \
  "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
  | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin

echo "=== 9. Helm ==="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "=== 10. Docker ==="
apt install -y docker.io
systemctl enable --now docker
usermod -aG docker ubuntu
usermod -aG docker jenkins

echo "=== 11. Trivy ==="
apt install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
  | tee /etc/apt/sources.list.d/trivy.list
apt update
apt install -y trivy

echo "=== 12. AWS CLI v2 ==="
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
./aws/install
ln -sf /usr/local/bin/aws /usr/bin/aws

echo "=== 13. Enable and restart Jenkins (after docker group added) ==="
systemctl enable jenkins
systemctl restart jenkins
systemctl restart docker

echo ""
echo "================================"
echo "VERIFYING ALL TOOLS"
echo "================================"
git --version
java -version
jenkins --version || true
terraform -version
mvn -v
kubectl version --client
eksctl version
helm version
docker --version
trivy --version
aws --version

echo ""
echo "=== DONE. Jenkins initial admin password: ==="
sleep 20
cat /var/lib/jenkins/secrets/initialAdminPassword || echo "Jenkins password file not ready yet, check /var/log/user-data.log and re-check in a minute"