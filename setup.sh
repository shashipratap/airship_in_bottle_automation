#!/bin/bash
set -x
export PKGDIR=${PKGDIR:-"/var/debs/amd64"}
export KUBE_BIN_DIR=${KUBE_BIN_DIR:-/var/www/html/kubedir}
export PACKAGES=${PACKAGES:-"docker.io jq nmap curl nfs-common ceph-common"}
export REPOS=${REPOS:-"quay.io docker.io gcr.io"}
export VERSION_FILE=/root/deploy/treasuremap/global/software/config/versions.yaml
export CHART_DIR=/var/charts



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






mkdir -p /root/deploy && cd "$_"
git clone https://opendev.org/airship/treasuremap/

######Taking backup of versions.yaml file#####
cp ${VERSION_FILE} ${VERSION_FILE}.bkp

setup_charts_repo || error "setting chart repo"
setup_local_registry || error "setting local docker registry"

cd /root/deploy/treasuremap/tools/deployment/aiab/
./airship-in-a-bottle.sh


