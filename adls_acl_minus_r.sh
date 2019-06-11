#!/bin/sh
#
#

# This script will recurse through a path in Azure Data Lake Storage v2 and add a particular AAD object (user/group/sp) to the ACL for read, write, and execute access. 
#   I've only gotten it to work with a service principal (SP) but if you're good with AAD maybe you'll get it to work with regular user.  
#
#   Set up your variables first

############# User-modifiable variables start here #############

# This must be a service principal for some reason.  See "az ad sp create-for-rbac"
CLIENT_ID1="00000000-0000-0000-0000-000000000000"
CLIENT_SECRET1="00000000-0000-0000-0000-000000000000"

# This is the directory name that you're a member of - not your subscription GUID
TENANT_NAME="00000000-0000-0000-0000-000000000000"

# Set the path of the of top level here that you'd like to start with, EXCLUDING leading or trailing slash! eg. "defaultfolder/childfolder" - NOT "/defaultfolder/childfolder/"
STARTPATH="defaultfolder"

# This is the name of the storage account where your ADLS gen2 blob storage is
STORAGE_ACCOUNT_NAME="myadlsblob"

# Azure AD Object ID of user, group, or SP to receive permissions on file
AAD_OBJECT="00000000-0000-0000-0000-000000000000"

############## You shouldn't need to edit anything below here, but see the comments for specific permission tweaks  ###############
# Get an access token

ACCESS_TOKEN=$(curl -X POST -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "client_id=$CLIENT_ID1" --data-urlencode  "client_secret=$CLIENT_SECRET1" --data-urlencode  "scope=https://storage.azure.com/.default" --data-urlencode  "grant_type=client_credentials" "https://login.microsoftonline.com/$TENANT_NAME/oauth2/v2.0/token" | jq -r '.access_token')

# Recurse through directory

curl -X GET -H "x-ms-version: 2018-11-09" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/$STARTPATH?recursive=true&resource=filesystem" | jq '.paths[].name' |sed "s/\"//g" | while read ADLSPATH
do
    echo "$AAD_OBJECT will receive rwx on $STARTPATH/$ADLSPATH"
    #  If you know what you're doing, go ahead and adjust the permissions being set in the x-ms-acl header.  
    #  See https://docs.microsoft.com/en-us/rest/api/storageservices/datalakestoragegen2/path/update#request-headers for a reference of what's going on here
    curl -i -X PATCH -H "x-ms-version: 2018-11-09" -H "content-length: 0" -H "x-ms-acl: user::rwx,user:$AAD_OBJECT:rwx,group::rw-,other::---" -H "Authorization: Bearer $ACCESS_TOKEN" "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net/$STARTPATH/$ADLSPATH?action=setAccessControl"
done
