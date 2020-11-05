#!bin/bash
deployment=`aws ssm get-parameters --names 'DeploymentGroupInUse'  --query "Parameters[0].Value" --region us-east-1 --output text`
echo "$deployment"
#SnowballInstance1 has active deployment
if [ "$deployment" == "Blue" ]; then

    echo "SnowballInstance1 (Blue) has the active deployment. Deploying to SnowballInstance2 (Green)"

    #Deploy to SnowballInstance2
    buildartifact=`aws s3 ls codepipeline-us-east-1-012345678910/LightSpeed-Container/BuildArtif/  --region us-east-1 | sort | tail -n 1 | awk '{print $4}'`
    key="LightSpeed-Container/BuildArtif/$buildartifact"
    echo "KEY = $key"
    deploymentId=`aws deploy create-deployment --application-name CodeDeploy_Containers --deployment-group-name Snowball-Green --s3-location bucket=codepipeline-us-east-1-012345678910,bundleType=zip,key="$key" --region us-east-1  --query "deploymentId" | sed -e "s/\"//g"`


    #Check till service SnowballInstance2 is stable
    aws deploy wait deployment-successful --deployment-id "$deploymentId"

    echo "Deployment to SnowballInstance2 is now stable"

    #Update the record set in R53 to point to SnowballInstance2 (Green)
    echo "Swapping the DNS to point to SnowballInstance2 (Green)"
    export accesskey=$(aws ssm get-parameters --names ACCESS_KEY_ID --query Parameters[0].Value |sed -e 's/^"//' -e 's/"$//'|sed -e 's/ /\n/g')
    export secretkey=$(aws ssm get-parameters --name SECRET_ACCESS_KEY --query Parameters[0].Value |sed -e 's/^"//' -e 's/"$//'|sed -e 's/ /\n/g')
    export AWS_ACCESS_KEY_ID=$accesskey
    export AWS_SECRET_ACCESS_KEY=$secretkey

    aws route53 change-resource-record-sets --hosted-zone-id ABCDEFGHIJKLM --change-batch file://PointToSnowballInstance2-green.json

    echo "Record Set updated successfully"

    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY

    ## Deploy to Snowball

    aws ssm put-parameter --name 'DeploymentGroupInUse' --value 'Green'   --type 'String' --overwrite --region us-east-1

#SnowballInstance2 has active deployment
else

    echo "SnowballInstance1 (Green) has the active deployment. Deploying to SnowballInstance2 (Blue)"

    #Deploy to SnowballInstance2
    buildartifact=`aws s3 ls codepipeline-us-east-1-012345678910/LightSpeed-Container/BuildArtif/  --region us-east-1 | sort | tail -n 1 | awk '{print $4}'`
    key="LightSpeed-Container/BuildArtif/$buildartifact"
    echo "KEY = $key"
    deploymentId=`aws deploy create-deployment --application-name CodeDeploy_Containers --deployment-group-name Snowball-Blue --s3-location bucket=codepipeline-us-east-1-012345678910,bundleType=zip,key="$key"  --region us-east-1  --query "deploymentId" | sed -e "s/\"//g"`

    #Check till service SnowballInstance1 is stable
    aws deploy wait deployment-successful --deployment-id "$deploymentId"

    echo "Deployment to SnowballInstance2 is now stable"

    #Update the record set in R53 to point to SnowballInstance1 (Blue)
    echo "Swapping the DNS to point to SnowballInstance2 (Green)"
    export accesskey=$(aws ssm get-parameters --names ACCESS_KEY_ID --query Parameters[0].Value |sed -e 's/^"//' -e 's/"$//'|sed -e 's/ /\n/g')
    export secretkey=$(aws ssm get-parameters --name SECRET_ACCESS_KEY --query Parameters[0].Value |sed -e 's/^"//' -e 's/"$//'|sed -e 's/ /\n/g')
    export AWS_ACCESS_KEY_ID=$accesskey
    export AWS_SECRET_ACCESS_KEY=$secretkey

    echo "Record Set updated successfully"

    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY

    aws route53 change-resource-record-sets --hosted-zone-id ABCDEFGHIJKLM --change-batch file://PointToSnowballInstance1-blue.json

    aws ssm put-parameter --name 'DeploymentGroupInUse' --value 'Blue'   --type 'String' --overwrite --region us-east-1
fi
