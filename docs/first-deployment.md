# Your First Logsearch Deployment

This guide walks you through deploying your first ELK stack using the Logsearch Genesis Kit. We'll create a simple development environment that you can use for testing and learning.

## Prerequisites

Before starting, ensure you have completed the [Installation Guide](installation.md) and have:

- ✅ Genesis v2.8.12+ installed
- ✅ BOSH CLI v2+ installed and configured
- ✅ Vault or Credhub deployed and accessible
- ✅ BOSH director deployed with cloud-config
- ✅ Logsearch Genesis Kit installed

## Step 1: Initialize Your Deployment Repository

If you haven't already set up a deployment repository:

```bash
# Create and enter your deployment directory
mkdir my-logsearch-deployments
cd my-logsearch-deployments

# Initialize the repository with the Logsearch kit
genesis init --kit logsearch

# Verify the setup
ls -la
```

You should see:
```
.genesis/           # Genesis configuration
deployments/        # Future environment files
.gitignore          # Git ignore rules
README.md           # Repository documentation
```

## Step 2: Create Your First Environment

Let's create a simple development environment:

```bash
# Create a new environment
genesis new dev

# Follow the interactive prompts:
# 1. Select your target BOSH director
# 2. Choose deployment features
# 3. Configure basic parameters
```

### Interactive Configuration

The `genesis new` command will prompt you for:

#### BOSH Director Selection
```
Please select a BOSH director:
[1] bosh-lite (192.168.50.6)
[2] aws-west (bosh.aws.example.com)
[3] azure-east (bosh.azure.example.com)

Which BOSH director would you like to target? 1
```

#### Kit Features Selection
```
What features would you like to enable?

[1] small-footprint - Minimal resource deployment for development
[2] s3-blobstore - AWS S3 storage for snapshots
[3] azure-blobstore - Azure Blob Storage for snapshots  
[4] gcs-blobstore - Google Cloud Storage for snapshots
[5] monitoring - Prometheus exporters for monitoring
[6] cf-integration - CloudFoundry log processing

Select features (comma-separated, e.g., 1,5): 1
```

#### Basic Parameters
```
Base domain for Logsearch components (e.g., example.com): dev.local

Number of Elasticsearch nodes [3]: 1
Number of Logstash instances [2]: 1  
Number of Kibana instances [1]: 1

Elasticsearch JVM heap size [2g]: 1g
Logstash JVM heap size [1g]: 512m
```

## Step 3: Review the Generated Environment File

The wizard creates an environment file at `deployments/dev.yml`:

```bash
# Review the generated configuration
cat deployments/dev.yml
```

Example generated file:
```yaml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
    - small-footprint

genesis:
  env: dev

params:
  base_domain: dev.local
  elasticsearch_instances: 1
  logstash_instances: 1
  kibana_instances: 1
  elasticsearch_heap_size: 1g
  logstash_heap_size: 512m
```

## Step 4: Set Up Secrets

Before deploying, we need to generate the required secrets:

```bash
# Generate certificates and credentials
genesis add-secrets dev

# This will create:
# - TLS certificates for secure communication
# - Admin credentials for Elasticsearch
# - System credentials for Kibana and Logstash
# - Internal authentication tokens
```

### Verify Secrets
```bash
# Check that secrets were created
genesis check-secrets dev

# You should see output like:
# All 12 secrets successfully found.
```

## Step 5: Deploy Your Environment

Now we're ready to deploy:

```bash
# Deploy the environment
genesis deploy dev

# The deployment process will:
# 1. Generate the final manifest
# 2. Upload necessary releases
# 3. Deploy all VMs and configure services
# 4. Run post-deployment validation
```

### Monitor the Deployment

The deployment typically takes 10-15 minutes. You'll see output like:

```
[dev/logsearch] determining manifest fragments for merging...
[dev/logsearch] merging manifests...
[dev/logsearch] downloading releases...
[dev/logsearch] deploying...

Task 123456

Task 123456 | 14:32:15 | Preparing deployment: Preparing deployment (00:00:02)
Task 123456 | 14:32:17 | Preparing package compilation: Finding packages to compile (00:00:00)
Task 123456 | 14:32:17 | Creating missing vms: elasticsearch/0 (0) (00:01:45)
Task 123456 | 14:32:17 | Creating missing vms: kibana/0 (0) (00:01:45)
Task 123456 | 14:32:17 | Creating missing vms: logstash/0 (0) (00:01:45)
...
```

## Step 6: Verify Your Deployment

After successful deployment, verify everything is working:

### Check Deployment Status
```bash
# Show deployment information
genesis info dev

# Expected output:
# Environment: dev
# Elasticsearch URL: https://elasticsearch.dev.local:9200
# Kibana URL: https://kibana.dev.local:5601
# Admin credentials: stored in Vault at secret/logsearch/dev/
```

### Health Checks
```bash
# Check Elasticsearch cluster health
genesis do dev -- es-health

# List Elasticsearch indices
genesis do dev -- es-indices

# Open Kibana in your browser
genesis do dev -- visit-kibana
```

### Manual Verification

#### Test Elasticsearch
```bash
# Get admin credentials from Vault
ELASTIC_USER=$(safe get secret/logsearch/dev/elasticsearch:admin_username)
ELASTIC_PASS=$(safe get secret/logsearch/dev/elasticsearch:admin_password)

# Test Elasticsearch API
curl -u "$ELASTIC_USER:$ELASTIC_PASS" -k "https://elasticsearch.dev.local:9200/_cluster/health?pretty"

# Expected response:
{
  "cluster_name" : "logsearch",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 1,
  "number_of_data_nodes" : 1,
  ...
}
```

#### Access Kibana
```bash
# Get Kibana URL
echo "https://kibana.dev.local:5601"

# Or use the helper command
genesis do dev -- visit-kibana
```

Login with the Elasticsearch admin credentials from Vault.

## Step 7: Send Test Logs

Let's send some test data to verify log processing:

### Using Logstash API
```bash
# Send a test log entry
curl -X POST "https://logstash.dev.local:5044" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "This is a test log entry",
    "level": "INFO",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
    "application": "test-app"
  }'
```

### Using Filebeat (if available)
```bash
# Configure Filebeat to send to your Logstash
# Edit filebeat.yml:
output.logstash:
  hosts: ["logstash.dev.local:5044"]

# Start Filebeat
sudo filebeat -e -c filebeat.yml
```

### Verify Data in Kibana

1. Open Kibana in your browser
2. Navigate to "Discover" 
3. Create an index pattern for `logstash-*`
4. You should see your test logs appearing

## Step 8: Basic Operations

### Backup and Restore
```bash
# Create a snapshot backup
genesis do dev -- backup

# The backup will be stored according to your storage configuration
```

### Scale Your Cluster
```bash
# Edit the environment file to scale up
vi deployments/dev.yml

# Change instance counts:
params:
  elasticsearch_instances: 3
  logstash_instances: 2

# Redeploy with new configuration
genesis deploy dev
```

### Update Configuration
```bash
# Modify any parameters in the environment file
vi deployments/dev.yml

# Apply changes
genesis deploy dev
```

## Common First-Time Issues

### DNS Resolution
If you're using `.local` domains, ensure your system can resolve them:

```bash
# Add entries to /etc/hosts for development
echo "10.244.0.10  elasticsearch.dev.local" | sudo tee -a /etc/hosts
echo "10.244.0.11  kibana.dev.local" | sudo tee -a /etc/hosts
echo "10.244.0.12  logstash.dev.local" | sudo tee -a /etc/hosts
```

### Certificate Warnings
Since we're using self-signed certificates, you'll see browser warnings. You can:

1. Accept the certificate warnings in your browser
2. Add the CA certificate to your trust store
3. Use `curl -k` to skip certificate verification

### Resource Constraints
If deployment fails due to resource constraints:

```bash
# Check BOSH director resources
bosh vms

# Reduce resource requirements in your environment file
params:
  elasticsearch_heap_size: 512m
  logstash_heap_size: 256m
```

## Next Steps

Congratulations! You now have a working Logsearch deployment. Here's what to explore next:

### Explore Features
1. **[Kit Configuration](kit-configuration.md)** - Learn about all available features
2. **[Monitoring Setup](operations/monitoring.md)** - Set up comprehensive monitoring
3. **[Security Configuration](operations/security.md)** - Enhance security settings

### Production Deployment
1. **[Production Deployment](scenarios/production.md)** - Set up a production-ready environment
2. **[Performance Tuning](PERFORMANCE-TUNING.md)** - Optimize for your workload
3. **[Backup Strategies](operations/backup-restore.md)** - Implement robust backup solutions

### Integration
1. **[CloudFoundry Integration](integrations/cloudfoundry.md)** - Process CF application logs
2. **[Custom Log Parsing](advanced/custom-parsing.md)** - Handle your specific log formats
3. **[OAuth Authentication](advanced/oauth-authentication.md)** - Integrate with your identity provider

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review deployment logs: `bosh logs -d dev`
3. Join the Genesis Community Slack
4. Open an issue on GitHub

---

**Next**: [Kit Configuration Guide](kit-configuration.md)