# Logsearch Genesis Kit

This is a Genesis kit for deploying [Logsearch][1] via the [logsearch-boshrelease][2].
It deploys a complete log aggregation and analytics platform with Elasticsearch, Logstash, 
and Kibana. The kit provides a scalable, highly-available solution for centralized logging
in cloud-native environments.

[1]: https://www.elastic.co/what-is/elk-stack
[2]: https://github.com/cloudfoundry-community/logsearch-boshrelease

## Features

- Deploys a scalable ELK (Elasticsearch, Logstash, Kibana) stack
- Supports multiple cloud providers (AWS, Azure, GCP, vSphere, OpenStack)
- Automatic SSL certificate generation and management
- Configurable cluster sizing from minimal to enterprise-scale
- CloudFoundry and BOSH log parsing integration
- Multiple storage backend options (S3, Azure Blob, GCS)
- Prometheus monitoring integration
- OAuth/OIDC authentication support
- Index lifecycle management with Curator
- Backup and restore capabilities via Shield integration

## Quick Start

To use it, you don't even need to clone this repository! Just run
the following (using Genesis v2.8.12+):

```bash
# create a logsearch-deployments repo using the latest version of the logsearch kit
genesis init --kit logsearch

# create a logsearch-deployments repo using v1.0.0 of the logsearch kit
genesis init --kit logsearch/1.0.0

# create a my-logsearch-configs repo using the latest version of the logsearch kit
genesis init --kit logsearch -d my-logsearch-configs
```

## Deployment

After creating a deployment repository, you can create a new environment:

```bash
# Create a new environment file
genesis new dev

# Deploy Logsearch
genesis deploy dev

# Check cluster health
genesis do dev -- es-health

# Open Kibana in browser
genesis do dev -- visit-kibana
```

## Parameters

The following parameters can be configured in your environment files:

### Required Parameters
- `params.base_domain` - Base domain for Logsearch components (e.g., example.com)

### Optional Parameters
- `params.elasticsearch_instances` - Number of Elasticsearch nodes (default: 3)
- `params.logstash_instances` - Number of Logstash instances (default: 2)
- `params.kibana_instances` - Number of Kibana instances (default: 1)
- `params.elasticsearch_heap_size` - JVM heap size for Elasticsearch (default: "2g")
- `params.logstash_heap_size` - JVM heap size for Logstash (default: "1g")
- `params.vault` - Vault path for secrets storage (default: "secret/logsearch")

## Features

### Cloud Storage Integration
- `s3-blobstore` - Use AWS S3 for Elasticsearch snapshots
- `azure-blobstore` - Use Azure Blob Storage for snapshots
- `gcs-blobstore` - Use Google Cloud Storage for snapshots

### Deployment Sizing
- `small-footprint` - Minimal resource deployment for development

### Monitoring and Management
- `prometheus-monitoring` - Enable Prometheus exporters
- `shield-integration` - Backup and restore with Shield

### Authentication
- `oauth-authentication` - OAuth/OIDC authentication for Kibana

### Log Source Integration
- `cf-integration` - CloudFoundry log parsing and dashboards
- `bosh-integration` - BOSH director log parsing

### External Services
- `external-elasticsearch` - Use external Elasticsearch cluster

## Addon Commands

The following addon commands are available:

- `visit-kibana` - Open Kibana UI in your default browser
- `es-health` - Check Elasticsearch cluster health
- `es-indices` - List Elasticsearch indices
- `import-dashboards` - Import pre-built Kibana dashboards
- `setup-parsers` - Configure Logstash parsing rules
- `rotate-certs` - Rotate SSL certificates
- `backup` - Trigger backup via Shield
- `restore` - Restore from Shield backup

## Resource Requirements

### Minimum (small-footprint)
- 3 VMs (1 ES, 1 Logstash, 1 Kibana)
- 8GB RAM per ES node
- 4GB RAM for Logstash
- 2GB RAM for Kibana
- 50GB persistent disk per ES node

### Production
- 3+ Elasticsearch master nodes
- 3+ Elasticsearch data nodes
- 2+ Logstash nodes
- 2+ Kibana nodes
- 16-32GB RAM per ES node
- 8GB RAM per Logstash node
- 4GB RAM per Kibana node
- 500GB+ persistent disk per ES data node

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for developer guidelines.

## License

This kit is released under the Apache 2.0 license. See [LICENSE](LICENSE) for details.