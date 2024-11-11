# variables.sh
resourceGroup="RGorderManagement"
locationFrontend="westeurope" #holandia
locationBackend="northeurope" #irlandia
vnetFrontend="VNetFrontend"
vnetBackend="VNetBackend"
subnetFrontend="SubnetFrontend"
subnetBackend="SubnetBackend"
nsgFrontend="NSGFrontend"
nsgBackend="NSGBackend"
vmFrontend="FrontendServer"
vmBackend="BackendServer"
publicIpFrontend="PublicIP_Frontend"
frontendImage="Debian:debian-10:10:latest"
backendImage=$frontendImage
sshUser="azureuser"
sshKeyPath="$HOME/wit/ppc/.ssh/id_ed25519.pub"  # Ścieżka do klucza SSH
sshPrivKeyPath="$HOME/wit/ppc/.ssh/id_ed25519"  # Ścieżka do klucza SSH
