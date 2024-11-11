#!/bin/bash

# Załaduj zmienne z pliku
source ./variables.sh

echo "==== Raport implementacji ===="

# Sprawdzenie grupy zasobów
echo -n "Grupa zasobów ($resourceGroup): "
az group show --name $resourceGroup --query "name" --output tsv || echo "Grupa nie istnieje"

echo ""
echo "=== Sieci wirtualne i podsieci ==="
# Informacje o sieciach wirtualnych i podsieciach
for vnet in "$vnetFrontend" "$vnetBackend"; do
    echo "Sieć wirtualna ($vnet):"
    az network vnet show --resource-group $resourceGroup --name $vnet --query "{Name:name, AddressSpace:addressSpace.addressPrefixes}" --output table
    echo "Podsieci w sieci $vnet:"
    az network vnet subnet list --resource-group $resourceGroup --vnet-name $vnet --query "[].{Name:name, AddressPrefix:addressPrefix}" --output table
    echo ""
done

echo "=== Maszyny wirtualne i adresy IP ==="
# Adresy IP maszyn wirtualnych
for vm in "$vmFrontend" "$vmBackend"; do
    echo "Maszyna wirtualna ($vm):"
    az vm show --resource-group $resourceGroup --name $vm --query "{Name:name, PrivateIP:privateIps, PublicIP:publicIps}" --output table
    echo ""
done

echo "=== Grupy Zabezpieczeń Sieciowych (NSG) i otwarte porty ==="
# Wyświetlanie otwartych portów w NSG
for nsg in "$nsgFrontend" "$nsgBackend"; do
    echo "Grupa Zabezpieczeń Sieciowych ($nsg):"
    az network nsg rule list --resource-group $resourceGroup --nsg-name $nsg --query "[].{RuleName:name, Protocol:protocol, Direction:direction, SourcePort:sourcePortRange, DestinationPort:destinationPortRange, Access:access, Priority:priority}" --output table
    echo ""
done

echo "=== Połączenia Peering między sieciami wirtualnymi ==="
for vnet in "$vnetFrontend" "$vnetBackend"; do
    echo "Połączenia Peering dla sieci wirtualnej ($vnet):"

    # Nagłówki tabeli
    printf "%-25s %-25s %-20s %-20s %-20s\n" "Name" "RemoteNetwork" "AllowForwardedTraffic" "AllowGatewayTransit" "UseRemoteGateways"
    echo "---------------------------------------------------------------------------------------------------------------"

    # Pobieranie i formatowanie danych peeringu
    az network vnet peering list \
      --resource-group $resourceGroup \
      --vnet-name $vnet \
      --query "[].{Name:name, RemoteNetwork:remoteVirtualNetwork.id, AllowForwardedTraffic:allowForwardedTraffic, AllowGatewayTransit:allowGatewayTransit, UseRemoteGateways:useRemoteGateways}" \
      --output tsv | \
      awk '{
        for (i=1; i<=NF; i++) {
          # Jeśli kolumna zawiera "/", przytnij tylko do części po ostatnim "/"
          if ($i ~ /\//) {
            sub(".*/", "", $i)
          }
        }
        # Wydrukuj przetworzoną linię z wyrównaniem kolumn
        printf "%-25s %-25s %-20s %-20s %-20s\n", $1, $2, $3, $4, $5
      }'
    echo ""
done

# Testowanie połączenia między maszynami
echo "=== Testowanie połączenia między maszynami frontend i backend ==="
# Pobranie prywatnego adresu IP maszyny backendowej
privateIpBackend=$(az vm list-ip-addresses --resource-group $resourceGroup --name $vmBackend --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)

if [ -z "$privateIpBackend" ]; then
    echo "Nie udało się uzyskać prywatnego adresu IP maszyny backendowej. Upewnij się, że maszyna istnieje."
    exit 1
fi

echo "Prywatny adres IP maszyny backendowej: $privateIpBackend"

# Pobranie publicznego adresu IP maszyny frontendowej
publicIpFrontend=$(az vm list-ip-addresses --resource-group $resourceGroup --name $vmFrontend --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)

if [ -z "$publicIpFrontend" ]; then
    echo "Nie udało się uzyskać publicznego adresu IP maszyny frontendowej. Upewnij się, że maszyna istnieje i ma przypisany publiczny adres IP."
    exit 1
fi

echo "Publiczny adres IP maszyny frontendowej: $publicIpFrontend"

# Test połączenia (ping) z maszyny frontendowej do backendowej
echo "Testowanie połączenia z maszyny frontendowej do backendowej..."

ssh -i $sshPrivKeyPath $sshUser@$publicIpFrontend "ping -c 4 $privateIpBackend"

if [ $? -eq 0 ]; then
    echo "Połączenie między maszynami zostało pomyślnie nawiązane."
else
    echo "Błąd połączenia: nie udało się osiągnąć maszyny backendowej z frontendowej."
fi

# Zapytanie o usunięcie zasobów
read -p "Czy chcesz usunąć wszystkie zasoby w grupie $resourceGroup? (t/n): " confirm
if [[ $confirm == "t" || $confirm == "T" ]]; then
    echo "Usuwanie grupy zasobów $resourceGroup..."
    az group delete --name $resourceGroup --yes --no-wait
    echo "Grupa zasobów $resourceGroup została zaplanowana do usunięcia."
else
    echo "Usunięcie grupy zasobów zostało anulowane."
fi
