#!/bin/bash

# Załaduj zmienne z pliku
source ./variables.sh

# Utworzenie grupy zasobów
az group create --name $resourceGroup --location $locationFrontend

# Utworzenie wirtualnej siec Frontendu
az network vnet create \
  --resource-group $resourceGroup \
  --name $vnetFrontend \
  --address-prefix 10.0.0.0/16 \
  --location $locationFrontend \
  --subnet-name $subnetFrontend \
  --subnet-prefix 10.0.0.0/23

# Utworzenie wirtualnej sieci dla Backendu
az network vnet create \
  --resource-group $resourceGroup \
  --name $vnetBackend \
  --address-prefix 192.168.0.0/16 \
  --location $locationBackend \
  --subnet-name $subnetBackend \
  --subnet-prefix 192.168.0.0/23

# Usunięcie domyślnej podsieci,aby uniknąć konfliktów
az network vnet subnet delete \
  --resource-group $resourceGroup \
  --vnet-name $vnetFrontend \
  --name "default"

az network vnet subnet delete \
  --resource-group $resourceGroup \
  --vnet-name $vnetBackend \
  --name "default"

# NSG dla sieci Frontend oraz dodanie reguł dla SSH, HTTP, HTTPS
az network nsg create --resource-group $resourceGroup --name $nsgFrontend --location $locationFrontend
az network nsg rule create --resource-group $resourceGroup --nsg-name $nsgFrontend --name AllowSSH --protocol tcp --priority 1000 --destination-port-range 22 --access allow
az network nsg rule create --resource-group $resourceGroup --nsg-name $nsgFrontend --name AllowHTTP --protocol tcp --priority 1001 --destination-port-range 80 --access allow
az network nsg rule create --resource-group $resourceGroup --nsg-name $nsgFrontend --name AllowHTTPS --protocol tcp --priority 1002 --destination-port-range 443 --access allow

# Powiązanie NSG z podsiecią Frontend
az network vnet subnet update --vnet-name $vnetFrontend --name $subnetFrontend --resource-group $resourceGroup --network-security-group $nsgFrontend

# Utworzenie Grupy Zabezpieczeń Sieciowych (NSG) dla sieci Backend oraz dodanie reguł dla SSH
az network nsg create --resource-group $resourceGroup --name $nsgBackend --location $locationBackend
az network nsg rule create --resource-group $resourceGroup --nsg-name $nsgBackend --name AllowSSH --protocol tcp --priority 1000 --destination-port-range 22 --access allow

# Utworzenie publicznego adresu IP tylko dla serwera Frontend
az network public-ip create --resource-group $resourceGroup --name $publicIpFrontend --location $locationFrontend

# Utworzenie interfejsów sieciowych (NIC) dla serwerów
nicFrontend=$(az network nic create --resource-group $resourceGroup --name NIC_Frontend --location $locationFrontend --vnet-name $vnetFrontend --subnet $subnetFrontend --network-security-group $nsgFrontend --public-ip-address $publicIpFrontend --query 'NewNIC.id' -o tsv)
nicBackend=$(az network nic create --resource-group $resourceGroup --name NIC_Backend --location $locationBackend --vnet-name $vnetBackend --subnet $subnetBackend --network-security-group $nsgBackend --query 'NewNIC.id' -o tsv)

# Utworzenie serwera Frontend z podanym kluczem SSH i publicznym IP
az vm create \
  --resource-group $resourceGroup \
  --name $vmFrontend \
  --location $locationFrontend \
  --nics $nicFrontend \
  --image $frontendImage \
  --size Standard_B1s \
  --admin-username $sshUser \
  --ssh-key-values $sshKeyPath

# Utworzenie serwera Backend z dostępem SSH, bez publicznego IP
az vm create \
  --resource-group $resourceGroup \
  --name $vmBackend \
  --location $locationBackend \
  --nics $nicBackend \
  --image $backendImage \
  --size Standard_B1s \
  --admin-username $sshUser \
  --ssh-key-values $sshKeyPath

# Utworzenie połączenia Peering między VNetFrontend i VNetBackend
az network vnet peering create \
  --name PeerFrontendToBackend \
  --resource-group $resourceGroup \
  --vnet-name $vnetFrontend \
  --remote-vnet $(az network vnet show --resource-group $resourceGroup --name $vnetBackend --query id -o tsv) \
  --allow-vnet-access

az network vnet peering create \
  --name PeerBackendToFrontend \
  --resource-group $resourceGroup \
  --vnet-name $vnetBackend \
  --remote-vnet $(az network vnet show --resource-group $resourceGroup --name $vnetFrontend --query id -o tsv) \
  --allow-vnet-access

echo "==== Deployment zakończony ==="