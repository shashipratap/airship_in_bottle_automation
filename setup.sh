#!/bin/bash
set -x
echo "#####downloading kubelet,kuebadm and kubectl#####"
wget https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl
wget https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubelet
wget https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubeadm
chmod +x kubectl kubelet kubeadm
sudo mv kubectl kubelet kubeadm /usr/local/bin/


echo "###########Setting up local ubuntu repo with docker.io , jq and nmap package deb files , other packages can be added as needed##########"
echo "         #####Installing apache2 and dpkg#####"
apt update
apt install apache2 -y
systemctl enable apache2
systemctl start apache2
apt install dpkg-dev -y

echo "         #####Downloading docker.io jq nmap curl deb files#####"
mkdir -p /var/www/html/debs/amd64
cd /var/www/html/debs/amd64
PACKAGES="docker.io jq nmap curl"

sudo apt-get download $(sudo apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $PACKAGES | grep "^\w" | sort -u)
cd /var/www/html/debs

echo "         #####Configuring Apache for apt#####"
dpkg-scanpackages amd64 | gzip -9c > amd64/Packages.gz
cp /etc/apt/sources.list /etc/apt/sources.list.bkp && echo "deb [trusted=yes] http://localhost/debs/ amd64/" > /etc/apt/sources.list
apt update
apt install docker.io -y
### optional to test working of script 
apt install jq -y
apt install curl -y
apt install nmap -y


############Setting local registry
echo "#####configuring local registry on port 5000 and putting pegleg and promenade image in it#####"

docker run -d -p 5000:5000 --restart=always --name registry registry:2
docker pull quay.io/airshipit/pegleg:ac6297eae6c51ab2f13a96978abaaa10cb46e3d6
docker tag quay.io/airshipit/pegleg:ac6297eae6c51ab2f13a96978abaaa10cb46e3d6 localhost:5000/pegleg
docker push localhost:5000/pegleg
docker rmi quay.io/airshipit/pegleg:ac6297eae6c51ab2f13a96978abaaa10cb46e3d6 localhost:5000/pegleg

docker pull quay.io/airshipit/promenade:master
docker tag quay.io/airshipit/promenade:master localhost:5000/promenade
docker push localhost:5000/promenade
docker rmi quay.io/airshipit/promenade:master localhost:5000/promenade


echo "#############Cloning the airship repo and making changes in deploy-airship.sh to fetch images from local repository##########"
mkdir -p /root/deploy && cd "$_"
git clone https://opendev.org/airship/airship-in-a-bottle
cd /root/deploy/airship-in-a-bottle
git checkout HEAD^1
sed -i 's/PEGLEG_IMAGE=${PEGLEG_IMAGE:-"quay.io\/airshipit\/pegleg:ac6297eae6c51ab2f13a96978abaaa10cb46e3d6"}/PEGLEG_IMAGE=${PEGLEG_IMAGE:-"localhost:5000\/pegleg"}/' /root/deploy/airship-in-a-bottle/manifests/common/deploy-airship.sh 
sed -i 's/PROMENADE_IMAGE=${PROMENADE_IMAGE:-"quay.io\/airshipit\/promenade:master"}/PROMENADE_IMAGE=${PROMENADE_IMAGE:-"localhost:5000\/promenade"}/' /root/deploy/airship-in-a-bottle/manifests/common/deploy-airship.sh
cd /root/deploy/airship-in-a-bottle/manifests/dev_single_node
./airship-in-a-bottle.sh
