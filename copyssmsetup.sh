#!/bin/sh

usage ()
{
  echo 'Usage : copyssmsetup.sh -profile <iam-profile> -fromregion <region> -toregion <region>'
  exit
}

if [ "$#" -ne 6 ]
then
  usage
fi

documentlist=$(aws ssm list-documents --document-filter-list key=Owner,value=Self  --profile $2 --region $4 --query DocumentIdentifiers[].Name --output text)

#Create documents
for  i in ${documentlist[@]} ; do
  outputjson=$(aws ssm get-document --name "$i" --document-format JSON --profile $2 --region $4 --query Content --output text)
  echo $outputjson > contents.json 
  echo "============Startin Document Creation================="
  aws ssm create-document --content file://contents.json --name "$i"  --document-type "Command" --region $6 --profile $2 --document-format JSON
  echo "============Document Creation Complete==============="
  rm contents.json
done  




