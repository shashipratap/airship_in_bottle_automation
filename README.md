This repo is tested on a Ubuntu 16.04 LTS t2.micro run in AWS

Setup Ubuntu 16.04 LTS in AWS and then run setup.sh after assigning chmod u+x permissions to it

This repo is to automate https://opendev.org/airship/airship-in-a-bottle repo after creating a local ubuntu repo and a local docker registry

On analysis of https://opendev.org/airship/airship-in-a-bottle ,four ubuntu packages were identified- docker.io ,jq , nmap and curl which 
needed to be installed.
docker.io , jq and nmap are referred in deploy-airship.sh and curl in test_create_heat_stack.sh.

To create an ubuntu repo apache and dpkg-dev is installed on ubuntu machine then all deb files for docker.io , jq, nmap and curl
are downloaded and kept in a directory /var/www/html/debs/amd64.

All deb packages are gzipped using dpkg-scanpackages amd64 | gzip -9c > amd64/Packages.gz

/etc/apt/sources.list is modified to point to local directory /var/www/html/debs/amd64 through apache

local registry is created through registry image and run on port 5000, deploy-airship.sh is using two images pegleg and promenade

Both images are downloaded from quay.io repo and pushed to local repo

deploy-airship.sh is changed to fetch images from local repo

Issues faced-

While creating ubuntu repo trust issues came which were resolved after adding [trusted=yes]  in /etc/apt/sources.list

During download of deb files issues were faced as first approach was to download from online repos which did not work as there were
too many dependencies ,then a new approach was used to download it from locally setup ubuntu repo using "apt-get download" "apt-cache depends"

Airship repo needs high capacity machine with 4vCPU, 20 G RAM and 32 G disk (which needs at least t2.2xlarge machine in AWS) , so to test basic working of deploy-airship.sh, exit 1 for machine capacity was commented in deploy-airship.sh

During promenade build it was failing with below error which was not looked into

Error rendering template (/opt/promenade/promenade/templates/roles/genesis/etc/kubernetes/manifests/bootstrap-armada.yaml): No match found for path HostSystem:images.monitoring_image
+ error 'generating genesis'
