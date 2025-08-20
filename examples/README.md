# Logsearch Genesis Kit - Example Deployments

This directory contains example deployment configurations for the Logsearch Genesis Kit, demonstrating various deployment scenarios and best practices.

## Available Examples

### Basic Deployments

#### [basic-deployment.yml](basic-deployment.yml)
- **Use Case**: Development and testing environments
- **Features**: Small footprint deployment with minimal resources
- **Scaling**: Single instance of each component
- **Resource Usage**: Low (suitable for development)

#### [production-deployment.yml](production-deployment.yml)
- **Use Case**: Production environments with standard requirements
- **Features**: S3 storage, monitoring, OAuth authentication
- **Scaling**: Multiple instances for high availability
- **Resource Usage**: Medium to high (production-ready)

### Advanced Deployments

#### [enterprise-deployment.yml](enterprise-deployment.yml)
- **Use Case**: Large-scale enterprise environments
- **Features**: All advanced features including multi-region, performance optimization, Shield integration
- **Scaling**: Highly available with cross-region replication
- **Resource Usage**: High (enterprise-grade)

### Cloud-Specific Deployments

#### [aws-deployment.yml](aws-deployment.yml)
- **Use Case**: AWS-optimized production deployment
- **Features**: S3 storage, AWS instance types, CloudWatch integration
- **Cloud**: Amazon Web Services
- **Optimizations**: AWS-specific VM types, storage, and networking

#### [azure-deployment.yml](azure-deployment.yml)
- **Use Case**: Azure-optimized production deployment
- **Features**: Azure Blob Storage, Azure instance types, Azure Monitor integration
- **Cloud**: Microsoft Azure
- **Optimizations**: Azure-specific VM types, storage, and monitoring

#### [gcp-deployment.yml](gcp-deployment.yml)
- **Use Case**: Google Cloud Platform optimized deployment
- **Features**: Google Cloud Storage, GCP instance types, Stackdriver integration
- **Cloud**: Google Cloud Platform
- **Optimizations**: GCP-specific VM types, storage, and logging

## How to Use These Examples

### 1. Choose an Example
Select the example that best matches your requirements:
- For development: Use `basic-deployment.yml`
- For production: Use `production-deployment.yml`
- For enterprise: Use `enterprise-deployment.yml`
- For cloud-specific: Use the appropriate cloud example

### 2. Copy and Customize
```bash
# Copy the example to your deployment directory
cp examples/production-deployment.yml environments/my-environment.yml

# Edit the configuration
vi environments/my-environment.yml
```

### 3. Set Up Required Secrets
Each example includes comments about required Vault secrets. Set them up before deployment:

```bash
# Example for production deployment
safe set secret/logsearch/my-environment/s3:access_key_id "AKIA..."
safe set secret/logsearch/my-environment/s3:secret_access_key "..."
safe set secret/logsearch/my-environment/oauth:client_id "oauth_client_id"
safe set secret/logsearch/my-environment/oauth:client_secret "oauth_secret"
```

### 4. Deploy
```bash
genesis new my-environment
genesis deploy my-environment
```

## Customization Guidelines

### Domain Configuration
Update the `base_domain` parameter to match your DNS setup:
```yaml
params:
  base_domain: logs.your-domain.com
```

### Scaling Configuration
Adjust instance counts based on your requirements:
```yaml
params:
  elasticsearch_instances: 3  # Number of Elasticsearch nodes
  logstash_instances: 2       # Number of Logstash instances
  kibana_instances: 2         # Number of Kibana instances
```

### Memory Allocation
Configure JVM heap sizes based on available memory:
```yaml
params:
  elasticsearch_heap_size: 16g  # 50% of available RAM, max 32g
  logstash_heap_size: 4g        # Based on available RAM
  kibana_memory_limit: 2g       # Based on available RAM
```

### Storage Configuration
Configure storage backends based on your cloud provider:

**AWS S3:**
```yaml
params:
  s3_bucket: my-bucket-name
  s3_region: us-west-2
```

**Azure Blob:**
```yaml
params:
  azure_storage_account: mystorageaccount
  azure_container: logsearch-snapshots
```

**Google Cloud Storage:**
```yaml
params:
  gcs_bucket: my-bucket-name
  gcs_region: us-west1
```

## Feature Combinations

### Common Feature Combinations

**Development:**
- `small-footprint`

**Production:**
- `s3-storage` (or `azure-storage`/`gcs-storage`)
- `monitoring`
- `oauth-authentication`

**Enterprise:**
- `multi-region`
- `performance-optimization`
- `shield-integration`
- `oauth-authentication`
- `monitoring`
- `s3-storage`

**Cloud Foundry Integration:**
- `cf-integration`
- `monitoring`
- `s3-storage`

### Feature Dependencies

Some features have dependencies or work better together:

- **OAuth Authentication**: Requires HTTPS/TLS certificates
- **Shield Integration**: Requires Shield deployment and agent configuration
- **Multi-Region**: Works best with `performance-optimization`
- **CF Integration**: Requires Cloud Foundry deployment details

## Resource Sizing Recommendations

### Small (Development)
- **Elasticsearch**: 1 instance, 2-4GB heap
- **Logstash**: 1 instance, 1-2GB heap
- **Kibana**: 1 instance, 512MB-1GB memory
- **Total RAM**: 8-16GB
- **Storage**: 50-200GB

### Medium (Production)
- **Elasticsearch**: 3 instances, 8-16GB heap each
- **Logstash**: 2 instances, 4-8GB heap each
- **Kibana**: 2 instances, 2-4GB memory each
- **Total RAM**: 60-120GB
- **Storage**: 500GB-2TB per Elasticsearch node

### Large (Enterprise)
- **Elasticsearch**: 6+ instances, 16-32GB heap each
- **Logstash**: 4+ instances, 8-16GB heap each
- **Kibana**: 3+ instances, 4-8GB memory each
- **Total RAM**: 200GB+
- **Storage**: 2TB+ per Elasticsearch node

## Security Considerations

### Secrets Management
- Store all credentials in Vault or Credhub
- Rotate secrets regularly
- Use strong, unique passwords
- Follow principle of least privilege for cloud IAM

### Network Security
- Configure appropriate security groups/firewalls
- Use TLS for all communications
- Implement proper network segmentation
- Monitor network traffic

### Authentication
- Enable OAuth/OIDC for user authentication
- Configure appropriate user groups and permissions
- Implement audit logging
- Regular access reviews

## Monitoring and Alerting

### Key Metrics to Monitor
- Cluster health status
- JVM heap usage
- Disk usage and I/O
- Search and indexing performance
- Network latency

### Recommended Alerts
- Cluster status red or yellow
- JVM heap usage > 85%
- Disk usage > 90%
- Search latency > 3 seconds
- Failed authentication attempts

## Support and Documentation

For additional help:
- Review the main [MANUAL.md](../MANUAL.md)
- Check [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
- Consult [PERFORMANCE-TUNING.md](../docs/PERFORMANCE-TUNING.md)
- Visit the Genesis Community repository

These examples provide a solid foundation for deploying Logsearch in various environments. Adapt them to your specific requirements and infrastructure constraints.