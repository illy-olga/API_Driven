# Projet API-Driven Infrastructure – AWS Orchestration

## Présentation générale
Ce projet a été réalisé dans le cadre de l’Atelier API-Driven Infrastructure. Il illustre la mise en œuvre complète d’une architecture API-driven permettant de piloter dynamiquement une ressource d’infrastructure (instance EC2) à partir d’une requête HTTP, sans aucune utilisation de la console graphique AWS.

L’architecture repose sur les services API Gateway et AWS Lambda, exécutés dans un environnement AWS simulé grâce à LocalStack, le tout hébergé et exécuté dans GitHub Codespaces.

L’objectif principal est de comprendre comment des services serverless peuvent orchestrer des ressources d’infrastructure de manière automatisée, reproductible et pilotée par API.

---

## Objectifs pédagogiques

- Comprendre le principe d’une API-Driven Infrastructure

- Orchestrer des ressources cloud via API Gateway + Lambda

- Utiliser LocalStack pour simuler un environnement AWS complet

- Déployer et piloter une infrastructure sans console graphique

- Automatiser les actions via scripts Bash et Makefile

- Produire une documentation claire et pédagogique

---

## Flux de fonctionnement

1. Une requête HTTP est envoyée par l’utilisateur

2. API Gateway reçoit la requête

3. La requête déclenche une fonction Lambda

4. La fonction Lambda démarre ou arrête une instance EC2

## Composants utilisés

- GitHub Codespaces : Environnement de développement cloud

- LocalStack : Émulateur de services AWS

- AWS API Gateway : Exposition de l’API HTTP

- AWS Lambda (Python) : Logique d’orchestration

- EC2 : Ressource d’infrastructure pilotée

---

## Séquence 1 – GitHub Codespaces

### Objectif

=> Créer un environnement de travail cloud prêt à l’emploi.

### Étapes

* Ouvrir le repository GitHub du projet

* Cliquer sur Code → Codespaces → Create new Codespace

* Attendre le démarrage de l’environnement

* Accéder au terminal intégré

---

## Séquence 2 – Création de l'environnement AWS simulé (LocalStack)

### Installation de LocalStack

```bash
sudo -i mkdir rep_localstack
sudo -i python3 -m venv ./rep_localstack
sudo -i pip install --upgrade pip && python3 -m pip install localstack && export S3_SKIP_SIGNATURE_VALIDATION=0
localstack start -d
```

[image]


### Vérification des services

```bash
localstack status services
```

[image]

### Récupération de l’endpoint AWS LocalStack

1. Aller dans l’onglet PORTS du Codespace

2. Rendre le port 4566 public

3. Copier l’URL générée


```bash
https://studious-space-bassoon-rvq765455rr2jq9-4510.app.github.dev/
```

[image]

_Il est normal qu’aucune page web ne s’affiche : il s’agit d’une API AWS, pas d’une application web._


## Séquence 3 – Développement de l’infrastructure API-driven
### Objectif

=> Piloter une instance EC2 via une API HTTP.

### Installation AWS

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Version AWS

[image]

XXX
```bash
aws configure set aws_access_key_id test
aws configure set aws_secret_access_key test
aws configure set region us-east-1
```

[image]

### Fonction Lambda – lambda_function.py

Cette fonction reçoit une requête HTTP contenant des paramètres (action et instance_id) et déclenche le démarrage ou l’arrêt d’une instance EC2.

#### Points clés

- Aucune dépendance hardcodée à localhost

- Utilisation de la variable d’environnement LOCALSTACK_HOSTNAME

- Compatible LocalStack / AWS réel

```python
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

```

### Packaging Lambda – function.zip

AWS Lambda nécessite un fichier ZIP pour le déploiement.

```bash
zip function.zip lambda_function.py
```

Ce fichier est utilisé par les scripts de déploiement.

### Déploiement manuel – deploy.sh

Ce script automatise :

* La création de l’instance EC2

* Le déploiement de la fonction Lambda

* La création et l’exposition de l’API Gateway


```bash
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

```

### Pilotage via Makefile

Le Makefile simplifie les actions courantes.

```bash
# --- Configuration Dynamique ---
# Récupère l'URL publique du port 4566 dans Codespaces
ENDPOINT=https://$(CODESPACE_NAME)-4566.app.github.dev

# Récupère automatiquement les IDs depuis LocalStack (évite les erreurs de copier-coller)
API_ID=$(shell aws --endpoint-url=http://localhost:4566 apigateway get-rest-apis --query "items[0].id" --output text)
INSTANCE_ID=$(shell aws --endpoint-url=http://localhost:4566 ec2 describe-instances --query "Reservations[0].Instances[0].InstanceId" --output text)

# --- Commandes ---

help:
	@echo "Commandes disponibles :"
	@echo "  make health       : Vérifier la santé de LocalStack"
	@echo "  make status       : Voir l'état de l'instance EC2"
	@echo "  make start-infra  : Démarrer l'instance via l'API"
	@echo "  make stop-infra   : Arrêter l'instance via l'API"

health:
	@curl -s $(ENDPOINT)/_localstack/health | jq .

status:
	@echo "État de l'instance $(INSTANCE_ID) :"
	@aws --endpoint-url=http://localhost:4566 ec2 describe-instances \
		--instance-ids $(INSTANCE_ID) \
		--query "Reservations[*].Instances[*].State.Name" --output text

start-infra:
	@echo "Envoi de la requête START..."
	@curl -s "$(ENDPOINT)/_aws/execute-api/$(API_ID)/prod/manage?instance_id=$(INSTANCE_ID)&action=start"
	@echo "\nFait."

stop-infra:
	@echo "Envoi de la requête STOP..."
	@curl -s "$(ENDPOINT)/_aws/execute-api/$(API_ID)/prod/manage?instance_id=$(INSTANCE_ID)&action=stop"
	@echo "\nFait."
```








