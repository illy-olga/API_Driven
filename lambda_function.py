import boto3
import json
import os

def lambda_handler(event, context):
    """
    Orchestration EC2 via API Gateway.
    Respect de la consigne : Aucune dépendance 'hardcoded' au localhost.
    """
    
    # On récupère l'URL de l'endpoint via les variables d'environnement.
    # 'LOCALSTACK_HOSTNAME' est injecté automatiquement par LocalStack.
    # Si on est sur le vrai AWS, endpoint_url restera None et boto3 utilisera les serveurs réels.
    ls_host = os.environ.get('LOCALSTACK_HOSTNAME')
    endpoint_url = f"http://{ls_host}:4566" if ls_host else None
    
    # Initialisation du client EC2
    ec2 = boto3.client('ec2', endpoint_url=endpoint_url, region_name='us-east-1')
    
    # Récupération sécurisée des paramètres de la requête HTTP
    params = event.get('queryStringParameters') or {}
    action = params.get('action')
    instance_id = params.get('instance_id')

    try:
        if not instance_id:
            raise ValueError("ID d'instance manquant dans la requête")

        if action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            res = f"Instance {instance_id} lancee avec succes"
        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            res = f"Instance {instance_id} stoppee avec succes"
        else:
            res = "Action invalide. Utilisez 'start' ou 'stop'."

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*" # Bonne pratique pour les API
            },
            "body": json.dumps({
                "status": "success",
                "message": res,
                "environment": "LocalStack" if ls_host else "AWS Real"
            })
        }
        
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "status": "error",
                "error": str(e)
            })
        }