import boto3
import json
import os

def lambda_handler(event, context):
    # LocalStack fournit dynamiquement le nom d'hôte correct
    host = os.environ.get('LOCALSTACK_HOSTNAME', 'localhost')
    endpoint_url = f"http://{host}:4566"
    
    ec2 = boto3.client('ec2', endpoint_url=endpoint_url, region_name='us-east-1')
    
    # Sécurité pour récupérer les paramètres
    params = event.get('queryStringParameters') or {}
    action = params.get('action')
    instance_id = params.get('instance_id')

    try:
        if not instance_id:
            raise ValueError("ID d'instance manquant")

        if action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            res = f"Instance {instance_id} lancee"
        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            res = f"Instance {instance_id} stoppee"
        else:
            res = "Action invalide"

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"message": res})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)})
        }
