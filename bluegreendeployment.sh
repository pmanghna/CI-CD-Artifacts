#!bin/bash
deployment='aws ssm get-parameters --names 'DeploymentGroupInUse' --query "Parameters[0].Value"'
echo "$deployment"
#WordPress-A has active deployment
if [ "$deployment" == *"Blue"* ]; then

    echo "SnowballInstance1 (Blue) has the active deployment. Deploying to SnowballInstance2 (Green)"

    #Deploy to SnowballInstance2
    key = 'aws s3 ls codepipeline-us-east-1-012345678910/LightSpeed-Container/BuildArtif/ --profile <profile-name> | sort | tail -n 1 | awk '{print $4}''
    aws deploy create-deployment --application-name --deployment-group-name --s3-location bucket=codepipeline-us-east-1-012345678910/LightSpeed-Container/BuildArtif/,bundleType=zip,key="$key"

    #Check till service WordPress-B is stable
    aws ecs wait services-stable --cluster dodmil-production --services Demo-WordpressB

    echo "Service WordPress-B is now stable "

    #Update the record set in R53
    echo "Swapping the DNS to point to Service B"
    export accesskey=$(aws ssm get-parameters --names ACCESS_KEY --query Parameters[0].Value |sed -e 's/^"//' -e 's/"$//'|sed -e 's/ /\n/g')
    export secretkey=$(aws ssm get-parameters --name SECRET_KEY --query Parameters[0].Value |sed -e 's/^"//' -e 's/"$//'|sed -e 's/ /\n/g')
    export AWS_ACCESS_KEY_ID=$accesskey
    export AWS_SECRET_ACCESS_KEY=$secretkey

    aws route53 change-resource-record-sets --hosted-zone-id ABCDEFGHIJKLM --change-batch file://PointToServiceB.json

    while(true); do
      sleep 5
      aws route53 list-resource-record-sets --hosted-zone-id ABCDEFGHIJKLM --query "ResourceRecordSets[?Name == 'wordpress.lightspeed-demo.com.']" --output text | grep "Wordpress-B"
      if [ $? -eq  1 ]; then
         echo "Record Set updated successfully"
         unset AWS_ACCESS_KEY_ID
         unset AWS_SECRET_ACCESS_KEY
         aws ssm put-parameter --name 'DeploymentID' --value 'Demo-WordpressB' --type 'String' --overwrite --region us-west-2
         break
      fi
    done
#WordPress-B has active deployment
else

    echo "WordPress-B  has the active deployment"

    #Deploy to WordPress-A
    aws ecs update-service --cluster dodmil-production --service Demo-WordpressA --force-new-deployment --region us-west-2

    #Check till service WordPress-A is stable
    aws ecs wait services-stable --cluster dodmil-production --services Demo-WordpressA

    echo "Service WordPress-A is now stable "

    #Update the record set in R53
    echo "Swapping the DNS to point to Service A"
    export accesskey=$(aws ssm get-parameters --names ACCESS_KEY --query Parameters[0].Value|sed -e 's/^"//' -e 's/"$//'|sed -e 's/ /\n/g')
    export secretkey=$(aws ssm get-parameters --name SECRET_KEY --query Parameters[0].Value|sed -e 's/^"//' -e 's/"$//'|sed -e 's/ /\n/g')
    export AWS_ACCESS_KEY_ID=$accesskey
    export AWS_SECRET_ACCESS_KEY=$secretkey

    aws route53 change-resource-record-sets --hosted-zone-id ABCDEFGHIJKLM --change-batch file://PointToServiceA.json

    while(true); do
      sleep 5
      aws route53 list-resource-record-sets --hosted-zone-id ABCDEFGHIJKLM --query "ResourceRecordSets[?Name == 'wordpress.lightspeed-demo.com.']" --output text | grep "Wordpress-B"
      if [ $? -eq  1 ]; then
         echo "Record Set updated successfully"
         unset AWS_ACCESS_KEY_ID
         unset AWS_SECRET_ACCESS_KEY
         aws ssm put-parameter --name 'DeploymentID' --value 'Demo-WordpressA' --type 'String' --overwrite --region us-west-2
         break
      fi
    done
fi
