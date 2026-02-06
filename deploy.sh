#!/bin/bash
# Remplace par ton URL récupérée dans l'onglet PORTS (port 4566)
ENDPOINT="https://studious-space-bassoon-rvq765455rr2jq9-4510.app.github.dev/" 

echo "--- 1. Création de l'instance EC2 ---"
INSTANCE_ID=$(aws --endpoint-url=$ENDPOINT ec2 run-instances --image-id ami-df56ef98 --count 1 --instance-type t2.micro --query 'Instances[0].InstanceId' --output text)
echo "Instance créée : $INSTANCE_ID"

echo "--- 2. Packaging et envoi de la Lambda ---"
zip function.zip lambda_function.py
aws --endpoint-url=$ENDPOINT lambda create-function \
    --function-name Ec2Controller \
    --runtime python3.9 \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --role arn:aws:iam::000000000000:role/service-role

echo "--- 3. Création de l'API Gateway ---"
API_ID=$(aws --endpoint-url=$ENDPOINT apigateway create-rest-api --name 'MyAPI' --query 'id' --output text)
PARENT_ID=$(aws --endpoint-url=$ENDPOINT apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text)

# On crée la ressource /manage
RES_ID=$(aws --endpoint-url=$ENDPOINT apigateway create-resource --rest-api-id $API_ID --parent-id $PARENT_ID --path-part manage --query 'id' --output text)

# On lie la méthode GET à la Lambda
aws --endpoint-url=$ENDPOINT apigateway put-method --rest-api-id $API_ID --resource-id $RES_ID --http-method GET --authorization-type "NONE"
aws --endpoint-url=$ENDPOINT apigateway put-integration --rest-api-id $API_ID --resource-id $RES_ID --http-method GET --type AWS_PROXY --integration-http-method POST --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:Ec2Controller/invocations

# Déploiement
aws --endpoint-url=$ENDPOINT apigateway create-deployment --rest-api-id $API_ID --stage-name prod

echo "------------------------------------------------"
echo "TERMINÉ !"
echo "ID Instance : $INSTANCE_ID"
echo "URL API : $ENDPOINT/restapis/$API_ID/prod/_user_request_/manage?instance_id=$INSTANCE_ID&action=start"
