#!/bin/bash
set -x
export PKGDIR=${PKGDIR:-"/var/debs/amd64"}
export KUBE_BIN_DIR=${KUBE_BIN_DIR:-/var/www/html/kubedir}
export PACKAGES=${PACKAGES:-"docker.io jq nmap curl nfs-common ceph-common"}
export REPOS=${REPOS:-"quay.io docker.io gcr.io"}
export VERSION_FILE=/root/deploy/treasuremap/global/software/config/versions.yaml
export CHART_DIR=/var/charts

######Taking backup of versions.yaml file#####
cp ${VERSION_FILE} ${VERSION_FILE}.bkp

#### Installing common packages ######
apt update
apt install dpkg-dev -y
apt install docker.io -y
apt install apache2 -y
apt install wcstools -y
systemctl enable apache2
systemctl start apache2

error() {
  set +x
  echo "Error when $1."
  set -x
  exit 1
}


setup_charts_repo()
{

if [ ! -d ${CHART_DIR} ]
then
 mkdir -p ${CHART_DIR}
fi
grep location ${VERSION_FILE} | awk -F "location: " '{print $2}' | sort -n | uniq > /tmp/charts

echo "#####downloading chart git repos and changing versions.yaml to refer to local chart git####"
cd ${CHART_DIR}
for var in `cat /tmp/charts`
do
 ###removing trailing backslash if any###"
 var=`echo ${var%/}`
 chart=`echo $var | awk -F "/" '{print $NF}'`
 
 sed  -i "s@location: *.*${chart}@location: ${CHART_DIR}/${chart}@g" ${VERSION_FILE}

 if [ -d $chart ]
 then
    echo "Skipping, Chart already exists , please remove old chart"
    continue
 fi
 git clone $var
 
done


}



setup_local_registry()
{

############Setting local registry
echo "#####configuring local registry on port 5000 and putting pegleg and promenade image in it#####"

docker run -d -p 5000:5000 --restart=always --name registry registry:2


echo "##############downloading public repo images mentioned in ${VERSION_FILE} and making changes to refer to local repo###############"



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
                echo $localimage;
         done < /tmp/versions.$repo;

         echo "########changing ${VERSION_FILE} to refer to locarepo######"
         sed -i "s@${repo}/@localhost:5000/@g" ${VERSION_FILE}

done

}

setup_local_repo()
{
echo "###########Setting up local ubuntu repo with docker.io , jq and nmap package deb files , other packages can be added as needed##########"

if [ ! -d $PKGDIR ]
then
 mkdir -p $PKGDIR
fi

export PKGDIRNAME=`filename $(realpath $PKGDIR)`
echo "         #####Downloading docker.io jq nmap curl deb files#####"
cd ${PKGDIR}
sudo apt-get download $(sudo apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $PACKAGES | grep "^\w" | sort -u)
cd $PKGDIR/..

echo "         #####Configuring local apt#####"
dpkg-scanpackages $PKGDIRNAME | gzip -9c > $PKGDIRNAME/Packages.gz
cp /etc/apt/sources.list /etc/apt/sources.list.bkp && echo "deb [trusted=yes] file:////$PKGDIR/.. $PKGDIRNAME/" > /etc/apt/sources.list
apt update
apt install docker.io -y
### optional to test working of script
for pkg in $PACKAGES
do
 apt install $pkg -y
done

}





mkdir -p /root/deploy && cd "$_"
git clone https://opendev.org/airship/treasuremap/

#setup_local_repo || error "setting up local ubuntu repo"
setup_charts_repo || error "setting chart repo"
setup_local_registry || error "setting local docker registry"

cd /root/deploy/treasuremap/tools/deployment/aiab/
./airship-in-a-bottle.sh


