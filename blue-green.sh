#!/bin/bash

#set -x

if [ "$#" -ne "3" ]
 then
 echo "Invalid Usage, Please provide app_name and environment_name"
 echo ""
 echo "deploy.sh <app_name> <environment> <pcf_space_name>"
 echo ""
 echo "environment : dev, pre1, pre2, pro1, pro2"
 echo ""
 echo "pcf_space_name: development, experience, sandbox, hub-pro1, hub-pro2, hub-pre1, hub-pre2, hub-mirror"
 echo ""
 echo "**************************************************"
 echo ""
 echo "Example : deploy.sh bank_emitter dev experience "
 echo ""
 echo "**************************************************"
 exit 1
fi

#Assign name for Blue and Green App
blue=$1
green="$blue"-green
CF_ORG=hub-org
env=$2
space=$3
case $env in
   dev)
	echo "PCF Development Environemnt"
        CF_API='<ENDPOINT>' 
	;;
   pre1)
	echo "PCF Pre1 Environment"
	CF_API='<ENDPOINT>'
	;;
   pre2)
	echo "PCF Pre2 Environment"
	CF_API='<ENDPOINT>'
	;;
   pro1)
	echo "PCF Prod1 Environment"
	CF_API='<ENDPOINT>'
	;;
   pro2)
	echo "PCF Prod2 Environment"
	CF_API='<ENDPOINT>'
	;; 
   *)
	echo "Invalid PCF Environment, Please check the usage"
	;;
esac

if [ $space = "sandbox" ]
 then
    manifest=manifest-aws-caps-sandbox.yml
elif [ $space = "uat" ]
 then
    manifest=manifest-aws-caps-uat.yml
else
    manifest=manifest-aws-caps-"$env"*.yml
fi
echo $manifest

#Check for CF CLI binary
cf -v 
if [ "$?" -ne "0" ]
then
   echo "Please install cf cli"
fi

#adding route to $green app
function map() {
for i in `cat $1`
do
host=`echo $i | awk -F "." '{print $1}'` 
echo $host
cfpath=`echo $i | cut -d "/" -f 2-` 
echo $cfpath
domain=`echo $i | awk -F "/" '{print $1}' | cut -d "." -f 2-`
echo $domain
cf map-route $green $domain --hostname $host --path "$cfpath"_green  
#cf map-route $green $domain --hostname $host --path "$cfpath"
done
}

# Removing route from $blue app
function unmap() {
for i in `cat $1`
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
}



#PCF login
cf login --skip-ssl-validation -a $CF_API -o $CF_ORG -s $space -u <username> -p <password>

cf a | awk -F " " '{print $1}' | grep ^"$blue"$ 
if [ "$?" -ne "0" ]
then
   echo "Deploying  $blue app"
   cf push -f "$manifest"
   exit 1
else

echo "Redeploying $green  app"
cf d -r -f green
cp "$manifest" green_"$manifest"

cat "$blue"_manifest.yml | grep ^"- " | awk -F ":" '{print $2}'  > routes 
cf push $green -f "$green"_manifest.yml --no-route

echo "Mapping rotues to $green"
map routes
echo "mapping routes to $green done"

echo "unmapping routes on $blue and $green"
unmap routes
echo "unmapping routes on $blue and $green done"

cf d -r -f $blue
cf rename $green $blue


#rm -rf "$green"_manifest.yml
cf delete-orphaned-routes -f
cf restage $blue

fi

