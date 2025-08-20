# Logsearch Genesis Kit - Deployment Scenarios

This document provides practical deployment scenarios for the Logsearch Genesis Kit, covering common use cases and best practices for different environments.

## Table of Contents

- [Basic Development Environment](#basic-development-environment)
- [Production Single-Region Deployment](#production-single-region-deployment)
- [High-Availability Multi-Region Setup](#high-availability-multi-region-setup)
- [Cloud-Specific Deployments](#cloud-specific-deployments)
- [Integration Scenarios](#integration-scenarios)
- [Performance-Optimized Deployments](#performance-optimized-deployments)

## Basic Development Environment

Perfect for testing and development work with minimal resource requirements.

### Environment Configuration

```yaml
# environments/dev.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - small-footprint

genesis:
  env: dev

params:
  base_domain: logsearch.dev.example.com
  timezone: America/New_York
  
  # Minimal resource allocation
  elasticsearch_instances: 1
  elasticsearch_disk_size: 20_000
  logstash_instances: 1
  kibana_instances: 1
```

### Deployment Commands

```bash
# Initialize the deployment repository
genesis init --kit logsearch

# Create the development environment
genesis new dev

# Deploy the environment
genesis deploy dev

# Access Kibana
genesis do dev -- visit-kibana
```

## Production Single-Region Deployment

Robust production setup with monitoring and storage backends for a single region.

### Environment Configuration

```yaml
# environments/prod.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - s3-storage
  - monitoring
  - oauth-authentication

genesis:
  env: prod

params:
  base_domain: logs.company.com
  timezone: UTC
  
  # Production sizing
  elasticsearch_instances: 3
  elasticsearch_disk_size: 500_000
  logstash_instances: 2
  kibana_instances: 2
  
  # S3 storage configuration
  s3_bucket: company-logs-storage
  s3_region: us-west-2
  
  # OAuth authentication
  oauth_provider: okta
  oauth_discovery_url: https://company.okta.com
  oauth_authorized_domains:
  - company.com
  oauth_admin_groups:
  - platform-team
  - security-team
```

### Storage Backend Setup

```bash
# Ensure S3 bucket exists and credentials are stored
safe set secret/logsearch/prod/s3:access_key_id "AKIA..."
safe set secret/logsearch/prod/s3:secret_access_key "..."

# Store OAuth credentials
safe set secret/logsearch/prod/oauth:client_id "oauth_client_id"
safe set secret/logsearch/prod/oauth:client_secret "oauth_secret"
```

## High-Availability Multi-Region Setup

Enterprise-grade deployment spanning multiple regions with cross-region replication.

### Primary Region Configuration

```yaml
# environments/prod-primary.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - multi-region
  - performance-optimization
  - shield-integration
  - monitoring

genesis:
  env: prod-primary

params:
  base_domain: logs.company.com
  timezone: UTC
  
  # Multi-region configuration
  primary_region: us-west-2
  regions:
  - us-west-2
  - us-east-1
  availability_zones:
  - us-west-2a
  - us-west-2b
  - us-west-2c
  cross_region_replication: true
  minimum_master_nodes: 3
  
  # Performance optimization
  elasticsearch_heap_size: 16g
  logstash_heap_size: 8g
  elasticsearch_thread_pool_size: 32
  
  # Shield backup integration
  shield_endpoint: https://shield.company.com
  shield_retention_policy: monthly
  shield_backup_schedule: "daily 3am"
```

### Secondary Region Configuration

```yaml
# environments/prod-secondary.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - multi-region
  - performance-optimization

genesis:
  env: prod-secondary

params:
  base_domain: logs-east.company.com
  timezone: UTC
  
  # Multi-region configuration (secondary)
  primary_region: us-west-2
  regions:
  - us-west-2
  - us-east-1
  availability_zones:
  - us-east-1a
  - us-east-1b
  cross_region_replication: true
  minimum_master_nodes: 3
  replica_region: true
  
  # Performance optimization
  elasticsearch_heap_size: 16g
  logstash_heap_size: 8g
```

## Cloud-Specific Deployments

### AWS Deployment

```yaml
# environments/aws-prod.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - s3-storage
  - monitoring

genesis:
  env: aws-prod
  iaas: aws

params:
  base_domain: logs.aws.company.com
  
  # AWS-specific configuration
  s3_bucket: company-aws-logs
  s3_region: us-west-2
  availability_zone: us-west-2a
  
  # Instance sizing for AWS
  elasticsearch_vm_type: m5.2xlarge
  logstash_vm_type: m5.large
  kibana_vm_type: m5.medium
```

### Azure Deployment

```yaml
# environments/azure-prod.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - azure-storage
  - monitoring

genesis:
  env: azure-prod
  iaas: azure

params:
  base_domain: logs.azure.company.com
  
  # Azure-specific configuration
  azure_storage_account: companylogsstorage
  azure_container: logs
  azure_storage_key: ((azure-storage-key))
  
  # Instance sizing for Azure
  elasticsearch_vm_type: Standard_D4s_v3
  logstash_vm_type: Standard_D2s_v3
  kibana_vm_type: Standard_D2s_v3
```

### Google Cloud Deployment

```yaml
# environments/gcp-prod.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - gcs-storage
  - monitoring

genesis:
  env: gcp-prod
  iaas: gcp

params:
  base_domain: logs.gcp.company.com
  
  # GCP-specific configuration
  gcs_bucket: company-gcp-logs
  gcs_region: us-west1
  
  # Instance sizing for GCP
  elasticsearch_vm_type: n1-standard-4
  logstash_vm_type: n1-standard-2
  kibana_vm_type: n1-standard-1
```

## Integration Scenarios

### Cloud Foundry Integration

```yaml
# environments/cf-logs.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - cf-integration
  - monitoring

genesis:
  env: cf-logs

params:
  base_domain: logs.cf.company.com
  
  # Cloud Foundry integration
  cf_api_endpoint: https://api.cf.company.com
  cf_system_domain: cf.company.com
  cf_apps_domain: apps.company.com
  doppler_shared_secret: ((cf-doppler-secret))
  
  # Syslog drain configuration
  syslog_port: 5514
  syslog_transport: tcp
```

### BOSH Integration

```yaml
# environments/bosh-logs.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - bosh-integration
  - monitoring

genesis:
  env: bosh-logs

params:
  base_domain: logs.bosh.company.com
  
  # BOSH integration
  bosh_director_url: https://bosh.company.com:25555
  bosh_log_retention_days: 90
  bosh_metrics_enabled: true
  
  # Custom log parsing rules
  bosh_postgres_logs: true
  bosh_nats_logs: true
  bosh_director_logs: true
```

## Performance-Optimized Deployments

### High-Throughput Environment

```yaml
# environments/high-throughput.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - performance-optimization
  - s3-storage

genesis:
  env: high-throughput

params:
  base_domain: logs.ht.company.com
  
  # High-performance configuration
  elasticsearch_instances: 6
  elasticsearch_heap_size: 32g
  elasticsearch_disk_size: 2_000_000
  elasticsearch_thread_pool_size: 64
  elasticsearch_bulk_queue_size: 1000
  
  logstash_instances: 4
  logstash_heap_size: 16g
  logstash_pipeline_workers: 16
  logstash_pipeline_batch_size: 500
  
  # JVM optimizations
  elasticsearch_jvm_options: |
    -XX:+UseG1GC
    -XX:G1HeapRegionSize=32m
    -XX:+UnlockExperimentalVMOptions
    -XX:+UseCGroupMemoryLimitForHeap
  
  # Storage optimization
  s3_multipart_threshold: 64MB
  s3_storage_class: STANDARD_IA
```

### Memory-Optimized Configuration

```yaml
# environments/memory-optimized.yml
---
kit:
  name: logsearch
  version: 1.0.0
  features:
  - performance-optimization

genesis:
  env: memory-optimized

params:
  base_domain: logs.mem.company.com
  
  # Memory-focused optimization
  elasticsearch_heap_size: 64g
  elasticsearch_vm_type: r5.4xlarge
  elasticsearch_cache_size: 40%
  
  logstash_heap_size: 32g
  logstash_vm_type: r5.2xlarge
  
  kibana_memory_limit: 8g
  kibana_vm_type: r5.large
  
  # Index optimization for memory usage
  elasticsearch_index_refresh_interval: 30s
  elasticsearch_merge_policy: tiered
```

## Deployment Best Practices

### Pre-Deployment Checklist

1. **Infrastructure Requirements**
   - Verify cloud resources and quotas
   - Ensure network connectivity and security groups
   - Validate DNS configuration

2. **Credentials and Secrets**
   - Store all credentials in Vault/Credhub
   - Test authentication mechanisms
   - Rotate default passwords

3. **Storage Configuration**
   - Create and configure storage backends
   - Set appropriate retention policies
   - Test backup and restore procedures

4. **Performance Planning**
   - Size instances based on expected load
   - Configure JVM heap sizes appropriately
   - Plan for index growth and rotation

### Post-Deployment Verification

```bash
# Health checks
genesis do <env> -- es-health
genesis do <env> -- es-indices

# Access verification
genesis do <env> -- visit-kibana

# Backup testing (if Shield integration enabled)
genesis do <env> -- backup

# Performance monitoring
curl -X GET "https://logs.company.com:9200/_cluster/health?pretty"
curl -X GET "https://logs.company.com:9200/_cat/indices?v"
```

### Scaling Recommendations

- **Horizontal Scaling**: Add more Elasticsearch data nodes for increased storage and search performance
- **Vertical Scaling**: Increase heap sizes and CPU allocation for individual nodes
- **Index Management**: Implement index lifecycle policies for automatic cleanup and optimization
- **Load Balancing**: Use multiple Kibana instances behind a load balancer for high availability

This document provides a foundation for deploying the Logsearch Genesis Kit in various scenarios. Adapt the configurations to meet your specific requirements and environment constraints.