#LOGIN TO AZURE
az login

#CREATE CONTAINER REGITRY
az acr create --resource-group <group> --name <name> --sku Basic
#OUTPUT:
#{
#  "adminUserEnabled": false,
#  "creationDate": "2020-01-11T05:49:37.615860+00:00",
#  "id": "/subscriptions/636369a7-dc41-434e-8c34-83cca114465d/resourceGroups/sufian/providers/Microsoft.ContainerRegistry/registries/sufian",
#  "location": "eastus",
#  "loginServer": "sufian.azurecr.io",
#  "name": "sufian",
#  "networkRuleSet": null,
#  "policies": {
#    "quarantinePolicy": {
#      "status": "disabled"
#    },
#    "retentionPolicy": {
#      "days": 7,
#      "lastUpdatedTime": "2020-01-11T05:49:38.418797+00:00",
#      "status": "disabled"
#    },
#    "trustPolicy": {
#      "status": "disabled",
#      "type": "Notary"
#    }
#  },
#  "provisioningState": "Succeeded",
#  "resourceGroup": "sufian",
#  "sku": {
#    "name": "Basic",
#    "tier": "Basic"
#  },
#  "status": null,
#  "storageAccount": null,
#  "tags": {},
#  "type": "Microsoft.ContainerRegistry/registries"
#}

#CREATE SERVICE PRINCIPAL
az ad sp create-for-rbac --skip-assignment
#OUTPUT:
#{
#  "appId": "fc37ff08-c027-40c7-a6ba-6e19573756d8",
#  "displayName": "azure-cli-2020-01-11-05-49-55",
#  "name": "http://azure-cli-2020-01-11-05-49-55",
#  "password": "1dfed77e-1eeb-48f5-93cf-bbf953b623c8",
#  "tenant": "81c1faa9-793e-4a7a-bc9c-ebbb216c44c1"
#}

# GET ACR ID
az acr show --resource-group <group> --name <name> --query "id" --output tsv
#OUTPUT:
#/subscriptions/636369a7-dc41-434e-8c34-83cca114465d/resourceGroups/sufian/providers/Microsoft.ContainerRegistry/registries/sufian

#ASSIGN 'acrpull' ROLE to SP
az role assignment create --assignee <spId> --scope <acrId> --role acrpull
#OUTPUT:
#{
#  "canDelegate": null,
#  "id": "/subscriptions/636369a7-dc41-434e-8c34-83cca114465d/resourceGroups/sufian/providers/Microsoft.ContainerRegistry/registries/sufian/providers/Microsoft.Authorization/roleAssignments/4e1d175a-b627-4d44-a6ec-efd37d5910b6",
#  "name": "4e1d175a-b627-4d44-a6ec-efd37d5910b6",
#  "principalId": "f705a37c-0634-488a-b774-519c9b4b1b05",
#  "principalType": "ServicePrincipal",
#  "resourceGroup": "sufian",
#  "roleDefinitionId": "/subscriptions/636369a7-dc41-434e-8c34-83cca114465d/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d",
#  "scope": "/subscriptions/636369a7-dc41-434e-8c34-83cca114465d/resourceGroups/sufian/providers/Microsoft.ContainerRegistry/registries/sufian",
#  "type": "Microsoft.Authorization/roleAssignments"
#}

#CREATE K8S CLUSTER
#NOTE: MANUALLY CREATE CLUSTER FROM PORTAL
#az aks create --resource-group <group> --name <name> --dns-name-prefix <dns prefix> --node-count 2 --service-principal <spId> --client-secret <client secret> --generate-ssh-keys --enable-rbac --enable-addons monitoring --location eastus --node-vm-size Standard_DS1_v2 --workspace-resource-id <subscription id>

#TRY ACCESSING DASHBOARD
az aks get-credentials -g <resource group> -n <name>
az aks browse -g <resource group> -n <name>
#WILL SHOW ERROR IN DASHBOARD, NOW APPLY DASHBOARD ACCESS PERMISSION TO FIX IT
kubectl apply -f .\kube-dashboard-access.yaml

#CONGRATULATION YOU HAVE SUCCESSFULLY SETUP A K8S CLUSTER! TRY BELOW TO INSTALL DEMO APPS TO SEE THEM IN ACTIONS WITH SSL

#WALK THROUGH LINK: https://docs.microsoft.com/en-us/azure/aks/ingress-tls
#INSTALL HELM V3, ADD OFFICIAL HELM STABLE CHARTS
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

#CRATE NAMESPACE ingress-basic
kubectl create ns ingress-basic
#OUTPUT:
#namespace/ingress-basic created

#INSTALL nginx INGRESS CONTROLLER. IT WILL INSTALL TWO INGRESS SERVICEs & ONE DEFAULT BACK-END WHICH RETURNS 'default 404'
helm install stable/nginx-ingress --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux --namespace ingress-basic --generate-name
#OUTPUT:
#NAME: nginx-ingress-1578724556
#LAST DEPLOYED: Sat Jan 11 12:35:59 2020
#NAMESPACE: ingress-basic
#STATUS: deployed
#REVISION: 1
#...
#...
#type: kubernetes.io/tls

#TO SEE THE INSTALLED RESOURCES
kubectl get service -l app=nginx-ingress --namespace ingress-basic
helm list -n ingress-basic

#GET EXTERNAL IP
kubectl get service -l app=nginx-ingress --namespace ingress-basic
$IP='<external ip from above command>'
$DNSNAME='sufian'
$PUBLICIPID=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[id]" --output tsv)
#ASSIGN DNS
az network public-ip update --ids $PUBLICIPID --dns-name $DNSNAME

#INSTALL AZURE SAMPLES
helm repo add azure-samples https://azure-samples.github.io/helm-charts/
helm repo update

#INSTALL FIRST SERVICE
helm install azure-samples/aks-helloworld --namespace ingress-basic --generate-name
#INSTALL 2ND SERVICE
helm install azure-samples/aks-helloworld --namespace ingress-basic  --generate-name --set title="AKS Ingress Demo" --set serviceName="ingress-demo"

#ADD INGRESS
kubectl apply -f .\cluster-ingress.yaml

#INSTALL CERTIFICATE: https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html
# CREATE A NAMESPACE TO RUN CERT-MANAGER IN
kubectl create namespace cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.11.0/cert-manager.yaml --validate=false

#SEE CLUSTER ISSUER STATUS
kubectl get all -n cert-manager

#SETUP CLUSTER ISSUER, https://docs.cert-manager.io/en/latest/tasks/issuers/setup-acme/index.html
kubectl apply -f .\cluster-issuer.yaml
kubectl get all -n cert-manager

#CREATE CERTIFICATE
kubectl apply -f .\certificates.yaml

# SEE CERTIFICATE DETAILS
kubectl get certificates -n ingress-basic
kubectl get secret -n ingress-basic

#UPDATE INGRESS TO USE CERTIFICATE
kubectl apply -f .\cluster-ingress.yaml


#########################################
#########################################
#CLEAN UP
#########################################
#########################################
kubectl delete namespace ingress-basic
kubectl delete namespace cert-manager
#DELETE THE CLUSTER
az aks delete --name <name> --resource-group <group>
