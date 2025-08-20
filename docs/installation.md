# Installation Guide

This guide walks you through installing and setting up the Logsearch Genesis Kit for deploying ELK stack environments.

## Prerequisites

### System Requirements

#### Minimum System Requirements
- **Operating System**: Linux, macOS, or Windows (with WSL2)
- **RAM**: 8GB minimum (16GB+ recommended for production)
- **Storage**: 20GB free space minimum
- **Network**: Internet connectivity for downloading dependencies

#### Software Dependencies
- **Genesis**: v2.8.12 or later
- **BOSH CLI**: v2+ with cloud-config support
- **Vault or Credhub**: For secrets management
- **Git**: Version control
- **jq**: JSON processing utility

### Cloud Provider Requirements

#### AWS
- AWS CLI configured with appropriate credentials
- IAM permissions for EC2, S3, and related services
- VPC with appropriate networking setup

#### Azure
- Azure CLI with authenticated subscription
- Resource Group with contributor access
- Virtual Network configuration

#### Google Cloud Platform
- Google Cloud SDK with authenticated project
- IAM permissions for Compute Engine and Storage
- VPC network configuration

#### vSphere
- vSphere credentials with VM deployment permissions
- vCenter access for resource management
- Network configuration for VM communication

#### OpenStack
- OpenStack CLI with project credentials
- Nova, Neutron, and Cinder service access
- Network and security group configuration

## Installing Genesis

### Linux Installation
```bash
# Download and install Genesis
curl -o /usr/local/bin/genesis https://github.com/genesis-community/genesis/releases/latest/download/genesis
chmod +x /usr/local/bin/genesis

# Verify installation
genesis --version
```

### macOS Installation
```bash
# Using Homebrew
brew tap starkandwayne/cf
brew install genesis

# Or manual installation
curl -o /usr/local/bin/genesis https://github.com/genesis-community/genesis/releases/latest/download/genesis
chmod +x /usr/local/bin/genesis

# Verify installation
genesis --version
```

### Windows Installation (WSL2)
```bash
# In WSL2 terminal
curl -o /usr/local/bin/genesis https://github.com/genesis-community/genesis/releases/latest/download/genesis
chmod +x /usr/local/bin/genesis

# Verify installation
genesis --version
```

## Installing BOSH CLI

### Linux/macOS
```bash
# Download BOSH CLI
curl -Lo ./bosh https://github.com/cloudfoundry/bosh-cli/releases/latest/download/bosh-cli-${VERSION}-linux-amd64
chmod +x ./bosh
sudo mv ./bosh /usr/local/bin/bosh

# Verify installation
bosh --version
```

### Package Manager Installation
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install bosh-cli

# CentOS/RHEL
sudo yum install bosh-cli

# macOS with Homebrew
brew install cloudfoundry/tap/bosh-cli
```

## Setting Up Vault

### Option 1: Local Development Vault
```bash
# Download and install Vault
curl -o vault.zip https://releases.hashicorp.com/vault/latest/vault_linux_amd64.zip
unzip vault.zip
sudo mv vault /usr/local/bin/

# Start development server
vault server -dev &

# Set environment variables
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='your-dev-token'

# Test connection
vault status
```

### Option 2: Production Vault Setup
```bash
# Configure Vault with proper storage backend
vault operator init
vault operator unseal # (run 3 times with different keys)

# Configure authentication
vault auth enable userpass
vault write auth/userpass/users/genesis password=secure-password

# Mount secrets engine
vault secrets enable -path=secret kv-v2
```

### Option 3: Using Safe (Vault CLI wrapper)
```bash
# Install Safe
curl -o /usr/local/bin/safe https://github.com/starkandwayne/safe/releases/latest/download/safe-linux-amd64
chmod +x /usr/local/bin/safe

# Target your Vault
safe target dev https://vault.example.com:8200
safe auth

# Test connection
safe tree
```

## Installing the Logsearch Genesis Kit

### Method 1: Genesis Init (Recommended)
```bash
# Create a new deployment repository
mkdir logsearch-deployments
cd logsearch-deployments

# Initialize with Logsearch kit
genesis init --kit logsearch

# This will:
# - Download the latest Logsearch kit
# - Set up the repository structure
# - Configure basic settings
```

### Method 2: Manual Download
```bash
# Create deployment directory
mkdir logsearch-deployments
cd logsearch-deployments

# Download kit manually
curl -Lo logsearch-kit.tar.gz https://github.com/genesis-community/logsearch-genesis-kit/releases/latest/download/logsearch-v1.0.0.tar.gz
tar -xzf logsearch-kit.tar.gz

# Initialize repository
genesis init
genesis kit add logsearch-v1.0.0/
```

### Method 3: Development Installation
```bash
# Clone the kit repository
git clone https://github.com/genesis-community/logsearch-genesis-kit.git
cd logsearch-genesis-kit

# Link for development
mkdir ../logsearch-deployments
cd ../logsearch-deployments
genesis init
genesis kit link ../logsearch-genesis-kit
```

## Cloud Provider Setup

### AWS Configuration
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-west-2
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### Azure Configuration
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Set subscription
az account set --subscription "Your Subscription Name"

# Verify configuration
az account show
```

### Google Cloud Configuration
```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Initialize and authenticate
gcloud init
gcloud auth login

# Set project
gcloud config set project your-project-id

# Verify configuration
gcloud config list
```

## BOSH Director Setup

### Option 1: Using BOSH Bootloader (BBL)
```bash
# Install BBL
curl -Lo ./bbl https://github.com/cloudfoundry/bosh-bootloader/releases/latest/download/bbl-linux
chmod +x ./bbl
sudo mv ./bbl /usr/local/bin/

# Create BOSH director (AWS example)
bbl plan --iaas aws --aws-region us-west-2
bbl up

# Set BOSH environment
eval "$(bbl print-env)"

# Verify BOSH connection
bosh env
```

### Option 2: Manual BOSH Director
```bash
# Create deployment manifest for BOSH director
# (This varies by cloud provider - see BOSH documentation)

# Deploy BOSH director
bosh create-env bosh-deployment/bosh.yml \
  --state=state.json \
  --vars-store=creds.yml \
  -o cloud-provider-ops.yml

# Set environment
export BOSH_ENVIRONMENT=your-director-ip
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(bosh int creds.yml --path /admin_password)

# Login
bosh login

# Verify connection
bosh env
```

## Cloud Config Setup

### Upload Cloud Config
```bash
# Download appropriate cloud config for your provider
curl -Lo cloud-config.yml https://raw.githubusercontent.com/genesis-community/logsearch-genesis-kit/main/spec/cloud_configs/aws.yml

# Customize for your environment
vi cloud-config.yml

# Upload to BOSH director
bosh update-cloud-config cloud-config.yml
```

### Verify Cloud Config
```bash
# Check cloud config
bosh cloud-config

# Verify VM types, networks, and disk types are available
bosh vms
```

## Runtime Config (Optional)

### DNS Runtime Config
```bash
# Add DNS runtime config for service discovery
bosh update-runtime-config --name=dns dns-runtime-config.yml
```

### OS Configuration Runtime Config
```bash
# Add OS-level configurations
bosh update-runtime-config --name=os-conf os-conf-runtime-config.yml
```

## Verification

### Test Your Installation
```bash
# Navigate to your deployment directory
cd logsearch-deployments

# Check Genesis installation
genesis --version

# Check BOSH connection
bosh env

# Check Vault connection (if using Safe)
safe tree

# Verify kit availability
genesis kit list
```

### Create a Test Environment
```bash
# Create a simple test environment
genesis new test-env

# This will:
# - Prompt for basic configuration
# - Create an environment file
# - Validate the setup
```

## Next Steps

After successful installation:

1. **[First Deployment](first-deployment.md)** - Deploy your first Logsearch environment
2. **[Kit Configuration](kit-configuration.md)** - Learn about available features and parameters
3. **[Deployment Scenarios](DEPLOYMENT-SCENARIOS.md)** - Explore different deployment patterns

## Troubleshooting Installation

### Common Issues

#### Genesis Not Found
```bash
# Ensure Genesis is in your PATH
echo $PATH
which genesis

# Re-download if necessary
curl -o /usr/local/bin/genesis https://github.com/genesis-community/genesis/releases/latest/download/genesis
chmod +x /usr/local/bin/genesis
```

#### BOSH Connection Issues
```bash
# Check BOSH environment variables
env | grep BOSH

# Test BOSH connectivity
bosh env
bosh releases

# Re-authenticate if necessary
bosh login
```

#### Vault Connection Issues
```bash
# Check Vault environment variables
env | grep VAULT

# Test Vault connectivity
vault status
safe tree (if using Safe)

# Re-authenticate if necessary
vault auth -method=userpass username=your-username
safe auth (if using Safe)
```

#### Cloud Provider Authentication
```bash
# AWS
aws sts get-caller-identity

# Azure
az account show

# GCP
gcloud auth list
gcloud config list
```

### Getting Help

If you encounter issues during installation:

1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review Genesis and BOSH documentation
3. Ask for help in the Genesis Community Slack
4. Open an issue on the GitHub repository

---

**Next**: [First Deployment Guide](first-deployment.md)