#!/bin/bash
#set -x
if [ "$#" -ne "1" ]
 then
 echo "Invalid Usage, Please pass valid app_name"
 echo "deploy.sh <app_name>"
 exit 1
fi
#Assign name for Blue and Green App
blue=$1
green="$blue"-green
#Check for CF CLI binary
cf -v 
if [ "$?" -ne "0" ]
then
   echo "Please install cf cli"
fi
cf a | awk -F " " '{print $1}' | grep ^"$blue"$ 
if [ "$?" -ne "0" ]
then
   echo "Deploying  $blue app"
   cf push -f "$blue"_manifest.yml
   exit 1
else
echo "Redeploying $green  app"
cf d -r -f green
cp "$blue"_manifest.yml "$green"_manifest.yml
cat "$blue"_manifest.yml | grep ^"- " | awk -F ":" '{print $2}'  > routes 
cf push $green -f "$green"_manifest.yml --no-route
#Adding route to $green app
for i in `cat routes`
do
host=`echo $i | awk -F "." '{print $1}'` 
echo $host
cfpath=`echo $i | cut -d "/" -f 2-` 
echo $cfpath
domain=`echo $i | awk -F "/" '{print $1}' | cut -d "." -f 2-`
echo $domain
cf map-route $green $domain --hostname $host --path "$cfpath"_green  
cf map-route $green $domain --hostname $host --path "$cfpath"
done
# Removing route from $blue app
for i in `cat routes`
do
host=`echo $i | awk -F "." '{print $1}'`
echo $host
cfpath=`echo $i | cut -d "/" -f 2-`
echo $cfpath
domain=`echo $i | awk -F "/" '{print $1}' | cut -d "." -f 2-`
echo $domain
cf unmap-route $blue $domain --hostname $host --path "$cfpath"
cf unmap-route $green $domain --hostname $host --path "$cfpath"_green
done
cf d -r -f $blue
cf rename $green $blue
#rm -rf "$green"_manifest.yml
cf delete-orphaned-routes -f
cf restage $blue
fi
