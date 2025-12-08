#!/bin/bash
set -e

echo "Updating packages..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y curl wget git apt-transport-https ca-certificates gnupg lsb-release bash sudo

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install k3d
echo "Installing k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "All installations are complete."
echo "You may need to log out and back in for Docker permissions to take effect."
echo "Please restart your terminal or run 'newgrp docker' to apply Docker group changes."