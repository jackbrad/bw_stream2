#!/bin/sh


#repo the git repository
mkdir POC
cd POC 
git clone https://github.com/jackbrad/bw_stream2
cd 'bw_stream2/POC v2'

#start the deployment
bash deploy.sh