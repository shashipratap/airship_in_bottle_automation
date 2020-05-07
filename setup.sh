#!/bin/bash
set -x
export PKGDIR=${PKGDIR:-"/var/debs/amd64"}
export KUBE_BIN_DIR=${KUBE_BIN_DIR:-/var/www/html/kubedir}
export PACKAGES=${PACKAGES:-"docker.io jq nmap curl nfs-common ceph-common"}
export REPOS=${REPOS:-"quay.io docker.io gcr.io"}
export VERSION_FILE=/root/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/config/versions.yaml

if [ ! -d $PKGDIR ]
then
 mkdir -p $PKGDIR
fi

export PKGDIRNAME=`filename $(realpath $PKGDIR)`


setup_local_repo()
{
echo "###########Setting up local ubuntu repo with docker.io , jq and nmap package deb files , other packages can be added as needed##########"
echo "         #####Installing apache2 and dpkg#####"
apt update
apt install dpkg-dev -y
apt install apache2 -y
apt install wcstools -y
systemctl enable apache2
systemctl start apache2

echo "         #####Downloading docker.io jq nmap curl deb files#####"
cd ${PKGDIR}
sudo apt-get download $(sudo apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $PACKAGES | grep "^\w" | sort -u)
cd $PKGDIR/..

echo "         #####Configuring Apache for apt#####"
dpkg-scanpackages $PKGDIRNAME | gzip -9c > $PKGDIRNAME/Packages.gz
cp /etc/apt/sources.list /etc/apt/sources.list.bkp && echo "deb [trusted=yes] file:////$PKGDIR/.. $PKGDIRNAME/" > /etc/apt/sources.list
apt update
apt install docker.io -y
### optional to test working of script
for pkg in $PACKAGES
do
 apt install $pkg -y
done
exit 0

}


setup_local_registry()
{
############Setting local registry
echo "#####configuring local registry on port 5000 and putting pegleg and promenade image in it#####"

docker run -d -p 5000:5000 --restart=always --name registry registry:2
echo "#########Pulling pegleg and promenade images to local repo###############"
docker pull quay.io/airshipit/pegleg:ac6297eae6c51ab2f13a96978abaaa10cb46e3d6
docker tag quay.io/airshipit/pegleg:ac6297eae6c51ab2f13a96978abaaa10cb46e3d6 localhost:5000/pegleg
docker push localhost:5000/pegleg
docker rmi quay.io/airshipit/pegleg:ac6297eae6c51ab2f13a96978abaaa10cb46e3d6 localhost:5000/pegleg

docker pull quay.io/airshipit/promenade:master
docker tag quay.io/airshipit/promenade:master localhost:5000/promenade
docker push localhost:5000/promenade
docker rmi quay.io/airshipit/promenade:master localhost:5000/promenade

echo "######making changes to deploy_airship.sh for local repo#########3"
sed -i 's/PEGLEG_IMAGE=${PEGLEG_IMAGE:-"quay.io\/airshipit\/pegleg:ac6297eae6c51ab2f13a96978abaaa10cb46e3d6"}/PEGLEG_IMAGE=${PEGLEG_IMAGE:-"localhost:5000\/pegleg"}/' /root/deploy/airship-in-a-bottle/manifests/common/deploy-airship.sh
sed -i 's/PROMENADE_IMAGE=${PROMENADE_IMAGE:-"quay.io\/airshipit\/promenade:master"}/PROMENADE_IMAGE=${PROMENADE_IMAGE:-"localhost:5000\/promenade"}/' /root/deploy/airship-in-a-bottle/manifests/common/deploy-airship.sh


echo "##############downloading public repo images mentioned in /root/deploy/airship-in-a-bottle/deployment_files/global/v1.0demo/software/config/versions.yaml and making changes to refer to local repo###############"



for repo in $REPOS;
do
        grep "$repo/" ${VERSION_FILE} | grep -v "^ *#" > /tmp/versions.$repo;
        while read line;
        do
                echo "######yamlline: $line#######"
                image=""
                localrepo="localhost:5000"
                image=$(echo $line | awk -F$repo -v VAR=$repo   '{print VAR$2}');
                localimage=$(echo $line | awk -F$repo -v VAR=$localrepo  '{print VAR$2}');
                echo "#############image: $image#########"
                echo "###########localimage: $localimage##########"
                docker pull $image
                docker tag $image $localimage
                docker push $localimage
                docker rmi $image $localimage
                echo $localimage; done < /tmp/versions.$repo;
                echo "########changing ${VERSION_FILE} to refer to locarepo######"
         sed -i "s@${repo}/@localhost:5000/@g" ${VERSION_FILE}

done

}

download_kubernetes_packages()
{

echo "###########downloading kubernetes binaries locally#################"
if [ ! -d ${KUBE_BIN_DIR} ]
then
 mkdir ${KUBE_BIN_DIR}
fi
wget https://dl.k8s.io/v1.10.2/kubernetes-node-linux-amd64.tar.gz ${KUBE_BIN_DIR}/kubernetes-node-linux-amd64.tar.gz
echo "###########making local changes in $VERSION_FILE to point to local kubelet#################"
sed -i "s@kubelet: https*.*@kubelet https://localhost/kubedir/kubernetes-node-linux-amd64.tar.gz@g" ${VERSION_FILE}
}





mkdir -p /root/deploy && cd "$_"
git clone https://opendev.org/airship/airship-in-a-bottle
cd /root/deploy/airship-in-a-bottle
git checkout HEAD^1

#setup_local_repo || error "setting up local ubuntu repo"
setup_local_registry || error "setting local docker registry"
download_kubernetes_packages || error "downloading kubernetes binaries"

cd /root/deploy/airship-in-a-bottle/manifests/dev_single_node
./airship-in-a-bottle.sh

