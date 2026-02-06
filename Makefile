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