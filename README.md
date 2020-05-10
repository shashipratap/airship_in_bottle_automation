This repo is tested on a Ubuntu 16.04 LTS t2.micro run in AWS

Setup Ubuntu 16.04 LTS in AWS and then run setup.sh after assigning chmod u+x permissions to it

This repo is to automate https://opendev.org/airship/treasuremap/src/branch/master/tools/deployment/aiabrepo after creating a local chart repo and a local docker registry

All images , charts and apt repo are mentioned in /root/deploy/treasuremap/global/software/config/versions.yaml file in repo.

Charts are mentioned as reference to git repos in versions.yaml , all the git repos are downloaded in a central chart directory and versions.yaml is changed to refer to local git repo in the central chart directory

Similarly all images in versions.yaml are downloaded locally in a local docker registry and then reference in versions.yaml are changed to point to local registry
