# Logsearch Genesis Kit Manual

The **Logsearch Genesis Kit** deploys a complete ELK (Elasticsearch, Logstash, Kibana) stack
for centralized log aggregation and analytics. This manual provides detailed deployment 
instructions, configuration options, and operational procedures.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Getting Started](#getting-started)
3. [Configuration](#configuration)
4. [Features](#features)
5. [Deployment Scenarios](#deployment-scenarios)
6. [Day-2 Operations](#day-2-operations)
7. [Troubleshooting](#troubleshooting)
8. [Migration](#migration)

## Prerequisites

Before deploying Logsearch, ensure you have:

- A working BOSH Director (v270+)
- Genesis CLI (v2.8.12+)
- A Genesis Vault or Credhub instance for secrets
- Cloud config with appropriate VM types, networks, and disk types
- DNS configuration for your base domain

### Required Cloud Config Resources

#### VM Types
- `small` - For Kibana instances (2 CPU, 4GB RAM)
- `medium` - For Logstash instances (2 CPU, 8GB RAM)  
- `large` - For Elasticsearch instances (4 CPU, 16GB RAM)

#### Disk Types
- `small` - For OS disks (10GB)
- `large` - For Elasticsearch data (500GB+)

#### Networks
- A network for Logsearch deployment with appropriate IP ranges

## Getting Started

### 1. Initialize Repository

```bash
genesis init --kit logsearch
cd logsearch-deployments
```

### 2. Create Cloud Config

Ensure your BOSH Director has the required VM types, networks, and disk types configured.

### 3. Create Environment

```bash
genesis new production
```

This will prompt you through the environment setup wizard.

### 4. Configure Environment

Edit your environment file (e.g., `production.yml`) with site-specific parameters:

```yaml
kit:
  name:    logsearch
  version: 1.0.0
  features:
    - s3-blobstore
    - prometheus-monitoring

params:
  base_domain: logs.example.com
  elasticsearch_instances: 3
  logstash_instances: 2
  kibana_instances: 1
  
  # Storage configuration
  s3_bucket: my-logsearch-snapshots
  s3_region: us-west-2
```

### 5. Deploy

```bash
genesis deploy production
```

### 6. Post-Deployment Setup

```bash
# Check cluster health
genesis do production -- es-health

# Import dashboards
genesis do production -- import-dashboards

# Open Kibana
genesis do production -- visit-kibana
```

## Configuration

### Base Parameters

#### Required Parameters

- **`base_domain`** - Base domain for all Logsearch components
  ```yaml
  params:
    base_domain: logs.example.com
  ```

#### Optional Parameters

- **`elasticsearch_instances`** - Number of Elasticsearch nodes (default: 3)
- **`logstash_instances`** - Number of Logstash instances (default: 2)
- **`kibana_instances`** - Number of Kibana instances (default: 1)
- **`elasticsearch_heap_size`** - JVM heap size for ES nodes (default: "2g")
- **`logstash_heap_size`** - JVM heap size for Logstash (default: "1g")
- **`vault`** - Vault path for secrets (default: "secret/logsearch")

### VM and Disk Types

Override default VM and disk types:

```yaml
params:
  elasticsearch_vm_type: large
  elasticsearch_disk_type: elasticsearch-ssd
  logstash_vm_type: medium
  kibana_vm_type: small
```

### Network Configuration

```yaml
params:
  logsearch_network: logsearch
  availability_zones:
    - z1
    - z2
    - z3
```

## Features

### Cloud Storage Features

#### S3 Blobstore

Configure AWS S3 for Elasticsearch snapshots:

```yaml
kit:
  features:
    - s3-blobstore

params:
  s3_bucket: my-logsearch-snapshots
  s3_region: us-west-2
  s3_access_key_id: ((vault_path))/aws:access_key_id)
  s3_secret_access_key: ((vault_path))/aws:secret_access_key)
```

#### Azure Blobstore

Configure Azure Blob Storage:

```yaml
kit:
  features:
    - azure-blobstore

params:
  azure_storage_account: mylogstorageacct
  azure_container: logsearch-snapshots
  azure_access_key: ((vault_path))/azure:access_key)
```

#### GCS Blobstore

Configure Google Cloud Storage:

```yaml
kit:
  features:
    - gcs-blobstore

params:
  gcs_bucket: my-logsearch-snapshots
  gcs_service_account_json: ((vault_path))/gcp:service_account_json)
```

### Monitoring Features

#### Prometheus Monitoring

Enable Prometheus exporters:

```yaml
kit:
  features:
    - prometheus-monitoring

params:
  prometheus_elasticsearch_exporter_port: 9114
  prometheus_logstash_exporter_port: 9198
```

#### Shield Integration

Enable backup/restore via Shield:

```yaml
kit:
  features:
    - shield-integration

params:
  shield_endpoint: https://shield.example.com
  shield_agent_key: ((vault_path))/shield:agent_key)
```

### Authentication Features

#### OAuth Authentication

Configure OAuth/OIDC for Kibana:

```yaml
kit:
  features:
    - oauth-authentication

params:
  oauth_provider: https://auth.example.com
  oauth_client_id: kibana-client
  oauth_client_secret: ((vault_path))/oauth:client_secret)
```

### Log Source Integration

#### CloudFoundry Integration

Parse CloudFoundry logs and import dashboards:

```yaml
kit:
  features:
    - cf-integration

params:
  cf_system_domain: system.cf.example.com
```

#### BOSH Integration  

Parse BOSH director logs:

```yaml
kit:
  features:
    - bosh-integration

params:
  bosh_director_url: https://bosh.example.com
```

### Deployment Sizing

#### Small Footprint

Minimal resource deployment for development:

```yaml
kit:
  features:
    - small-footprint
```

This reduces resource requirements and deploys single instances.

### External Services

#### External Elasticsearch

Use an external Elasticsearch cluster:

```yaml
kit:
  features:
    - external-elasticsearch

params:
  external_elasticsearch_hosts:
    - es-node1.example.com:9200
    - es-node2.example.com:9200
    - es-node3.example.com:9200
  external_elasticsearch_username: elastic
  external_elasticsearch_password: ((vault_path))/external-es:password)
```

## Deployment Scenarios

### Development Environment

```yaml
kit:
  name: logsearch
  version: 1.0.0
  features:
    - small-footprint

params:
  base_domain: logs.dev.example.com
  elasticsearch_instances: 1
  logstash_instances: 1
  kibana_instances: 1
  elasticsearch_heap_size: "1g"
  logstash_heap_size: "512m"
```

### Production Environment

```yaml
kit:
  name: logsearch
  version: 1.0.0
  features:
    - s3-blobstore
    - prometheus-monitoring
    - oauth-authentication
    - cf-integration

params:
  base_domain: logs.example.com
  elasticsearch_instances: 6
  logstash_instances: 4
  kibana_instances: 2
  elasticsearch_heap_size: "16g"
  logstash_heap_size: "4g"
  
  # Storage
  s3_bucket: prod-logsearch-snapshots
  s3_region: us-west-2
  
  # Auth
  oauth_provider: https://auth.example.com
  oauth_client_id: kibana-prod
```

### Multi-Region Setup

For cross-region replication, deploy separate environments per region:

```yaml
# us-west.yml
params:
  base_domain: logs-west.example.com
  availability_zones: [us-west-1a, us-west-1b, us-west-1c]

# us-east.yml  
params:
  base_domain: logs-east.example.com
  availability_zones: [us-east-1a, us-east-1b, us-east-1c]
```

## Day-2 Operations

### Scaling Operations

#### Scale Elasticsearch Cluster

1. Update environment configuration:
   ```yaml
   params:
     elasticsearch_instances: 6  # increased from 3
   ```

2. Deploy changes:
   ```bash
   genesis deploy production
   ```

3. Verify cluster health:
   ```bash
   genesis do production -- es-health
   ```

#### Scale Logstash Instances

Similar process - update `logstash_instances` parameter and redeploy.

### Backup and Restore

#### Create Snapshot

```bash
# Manual snapshot
genesis do production -- backup

# Check snapshots
curl -X GET "elasticsearch.logs.example.com:9200/_snapshot/backup_repository/_all?pretty"
```

#### Restore Snapshot

```bash
genesis do production -- restore snapshot_name
```

### Certificate Rotation

```bash
# Rotate all certificates
genesis do production -- rotate-certs

# Redeploy to apply new certificates
genesis deploy production
```

### Index Management

#### List Indices

```bash
genesis do production -- es-indices
```

#### Configure Index Templates

Create custom index templates via Kibana or API:

```bash
curl -X PUT "elasticsearch.logs.example.com:9200/_index_template/logs-template" \
  -H 'Content-Type: application/json' \
  -d @index-template.json
```

### Monitoring

#### Check Cluster Health

```bash
genesis do production -- es-health
```

#### View Cluster Stats

```bash
curl -X GET "elasticsearch.logs.example.com:9200/_cluster/stats?pretty"
```

#### Monitor via Prometheus

Access Prometheus metrics at:
- Elasticsearch: `http://elasticsearch-exporter.logs.example.com:9114/metrics`
- Logstash: `http://logstash-exporter.logs.example.com:9198/metrics`

## Troubleshooting

### Common Issues

#### Elasticsearch Cluster Red Status

1. Check cluster health:
   ```bash
   genesis do production -- es-health
   ```

2. Check unassigned shards:
   ```bash
   curl -X GET "elasticsearch.logs.example.com:9200/_cluster/allocation/explain?pretty"
   ```

3. Common solutions:
   - Increase available disk space
   - Adjust replica settings
   - Add more data nodes

#### Logstash Not Processing Logs

1. Check Logstash logs:
   ```bash
   bosh -d logsearch-production logs logstash
   ```

2. Common issues:
   - Parsing configuration errors
   - Elasticsearch connectivity problems
   - Input configuration issues

#### Kibana Unreachable

1. Check Kibana status:
   ```bash
   bosh -d logsearch-production instances
   ```

2. Check Kibana logs:
   ```bash
   bosh -d logsearch-production logs kibana
   ```

3. Verify Elasticsearch connectivity from Kibana.

### Performance Tuning

#### Elasticsearch

- Adjust heap size based on available RAM (max 32GB)
- Configure appropriate shard counts
- Use SSD storage for better performance
- Tune JVM garbage collection settings

#### Logstash

- Increase batch size for better throughput
- Add more worker threads
- Optimize filter configurations
- Use persistent queues for reliability

#### Kibana

- Enable response caching
- Optimize dashboard queries
- Use index patterns efficiently

### Log Analysis

#### Access Logs

```bash
# Elasticsearch logs
bosh -d logsearch-production logs elasticsearch-master
bosh -d logsearch-production logs elasticsearch-data

# Logstash logs  
bosh -d logsearch-production logs logstash

# Kibana logs
bosh -d logsearch-production logs kibana
```

#### Check Configuration

```bash
# View current deployment manifest
genesis manifest production

# Check generated certificates
genesis info production
```

## Migration

### From Standalone Logsearch

If migrating from a standalone logsearch-boshrelease deployment:

1. **Backup Data**: Create Elasticsearch snapshots of existing data
2. **Deploy Kit**: Deploy the Genesis kit in parallel 
3. **Migrate Data**: Restore snapshots to new cluster
4. **Update Clients**: Point log shippers to new endpoints
5. **Decommission**: Remove old deployment after verification

### Version Upgrades

#### Kit Version Upgrades

1. Update kit version in environment file:
   ```yaml
   kit:
     version: 1.1.0
   ```

2. Review release notes for breaking changes
3. Test in non-production environment first
4. Deploy with `genesis deploy production`

#### Elasticsearch Version Upgrades

Major Elasticsearch upgrades require careful planning:

1. Review Elasticsearch upgrade compatibility
2. Test upgrade path in development
3. Create full backup before upgrade
4. Follow rolling upgrade procedures
5. Verify cluster health after upgrade

This manual provides comprehensive guidance for deploying and operating Logsearch using the Genesis kit. For additional support, consult the kit's GitHub repository or Genesis community resources.