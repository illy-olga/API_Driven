# Variables à adapter
ENDPOINT=https://studious-space-bassoon-rvq765455rr2jq9-4566.app.github.dev
API_ID=00sinohvm9
INSTANCE_ID=i-24a15ddce26bd3bd3

status:
	@aws --endpoint-url=$(ENDPOINT) ec2 describe-instances --instance-ids $(INSTANCE_ID) --query "Reservations[*].Instances[*].State.Name" --output text

stop-infra:
	curl "$(ENDPOINT)/_aws/execute-api/$(API_ID)/prod/manage?instance_id=$(INSTANCE_ID)&action=stop"

start-infra:
	curl "$(ENDPOINT)/_aws/execute-api/$(API_ID)/prod/manage?instance_id=$(INSTANCE_ID)&action=start"
