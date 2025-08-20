# Logsearch Genesis Kit - Migration Guide

This guide provides step-by-step instructions for migrating from various log management solutions to the Logsearch Genesis Kit.

## Table of Contents

- [Migration Overview](#migration-overview)
- [From ELK Stack](#from-elk-stack)
- [From Splunk](#from-splunk)
- [From Fluentd/Fluent Bit](#from-fluentdfluent-bit)
- [From Graylog](#from-graylog)
- [From CloudWatch Logs](#from-cloudwatch-logs)
- [From Syslog Solutions](#from-syslog-solutions)
- [Data Migration Strategies](#data-migration-strategies)
- [Configuration Migration](#configuration-migration)
- [Testing and Validation](#testing-and-validation)
- [Rollback Planning](#rollback-planning)

## Migration Overview

### Pre-Migration Checklist

1. **Assessment Phase**
   - [ ] Document current log volume and retention requirements
   - [ ] Identify log sources and formats
   - [ ] Map existing dashboards and alerts
   - [ ] Assess storage and performance requirements
   - [ ] Plan migration timeline and rollback strategy

2. **Infrastructure Preparation**
   - [ ] Provision Genesis environment
   - [ ] Set up storage backends (S3, Azure, GCS)
   - [ ] Configure network connectivity
   - [ ] Set up monitoring and alerting
   - [ ] Prepare backup and recovery procedures

3. **Migration Planning**
   - [ ] Choose migration strategy (big bang vs. phased)
   - [ ] Plan data migration approach
   - [ ] Prepare configuration mappings
   - [ ] Set up parallel environments for testing
   - [ ] Train operations team on Genesis/ELK

### Migration Strategies

**Big Bang Migration**:
- Complete cutover in single maintenance window
- Higher risk but faster completion
- Suitable for smaller deployments

**Phased Migration**:
- Gradual migration by log source or application
- Lower risk with ability to validate each phase
- Suitable for large, complex environments

**Parallel Running**:
- Run both systems simultaneously
- Compare outputs and validate functionality
- Highest confidence but highest resource usage

## From ELK Stack

### Self-Managed Elasticsearch Migration

**Assessment**:
```bash
# Gather current cluster information
curl -X GET "http://current-es:9200/_cluster/health?pretty"
curl -X GET "http://current-es:9200/_cat/indices?v"
curl -X GET "http://current-es:9200/_cat/nodes?v"
```

**Configuration Mapping**:

| Current ELK | Genesis Kit Equivalent |
|-------------|------------------------|
| elasticsearch.yml | manifests/base.yml elasticsearch properties |
| logstash.conf | Custom filter configurations |
| kibana.yml | manifests/base.yml kibana properties |

**Migration Steps**:

1. **Export existing configuration**:
   ```bash
   # Export index templates
   curl -X GET "http://current-es:9200/_index_template" > templates.json
   
   # Export index patterns
   curl -X GET "http://current-kibana:5601/api/saved_objects/_export" \
     -H "Content-Type: application/json" \
     -d '{"type": "index-pattern"}' > index-patterns.json
   
   # Export dashboards
   curl -X GET "http://current-kibana:5601/api/saved_objects/_export" \
     -H "Content-Type: application/json" \
     -d '{"type": "dashboard"}' > dashboards.json
   ```

2. **Deploy Genesis Kit**:
   ```yaml
   # environments/prod.yml
   kit:
     name: logsearch
     version: 1.0.0
     features:
     - s3-storage  # Match your current storage
   
   params:
     base_domain: logs.company.com
     elasticsearch_instances: 3  # Match current cluster size
     elasticsearch_heap_size: 16g
   ```

3. **Migrate index templates**:
   ```bash
   # Import templates to new cluster
   curl -X PUT "http://new-es:9200/_index_template/logstash" \
     -H "Content-Type: application/json" \
     -d @logstash-template.json
   ```

4. **Data migration using reindex**:
   ```bash
   # Set up remote cluster reference
   curl -X PUT "http://new-es:9200/_cluster/settings" \
     -H "Content-Type: application/json" \
     -d '{
       "persistent": {
         "cluster.remote.old_cluster.seeds": ["old-es:9300"]
       }
     }'
   
   # Reindex data
   curl -X POST "http://new-es:9200/_reindex" \
     -H "Content-Type: application/json" \
     -d '{
       "source": {
         "remote": {
           "host": "http://old-es:9200"
         },
         "index": "logstash-*"
       },
       "dest": {
         "index": "logstash-migrated"
       }
     }'
   ```

### Elastic Cloud Migration

**Export from Elastic Cloud**:
```bash
# Use Elasticsearch dump tool
npm install -g elasticdump

# Export mappings
elasticdump \
  --input=https://user:pass@cloud-cluster:9200/logstash-* \
  --output=http://new-es:9200/logstash-migrated \
  --type=mapping

# Export data
elasticdump \
  --input=https://user:pass@cloud-cluster:9200/logstash-* \
  --output=http://new-es:9200/logstash-migrated \
  --type=data \
  --limit=1000
```

## From Splunk

### Configuration Analysis

**Splunk to Logstash Filter Mapping**:

| Splunk Function | Logstash Equivalent |
|----------------|-------------------|
| `eval` | `mutate` filter |
| `rex` | `grok` or `ruby` filter |
| `stats` | Elasticsearch aggregations |
| `lookup` | `translate` filter |

**Example Conversion**:

Splunk SPL:
```spl
index=app_logs | rex field=message "status=(?<status_code>\d+)" | stats count by status_code
```

Logstash equivalent:
```ruby
filter {
  if [index] == "app_logs" {
    grok {
      match => { "message" => "status=(?<status_code>\d+)" }
    }
  }
}
```

### Migration Process

1. **Data Export from Splunk**:
   ```bash
   # Export search results to CSV
   splunk search 'index=* earliest=-30d' -output csv > splunk_data.csv
   ```

2. **Convert to Elasticsearch format**:
   ```python
   #!/usr/bin/env python3
   import csv
   import json
   from datetime import datetime
   
   with open('splunk_data.csv', 'r') as csvfile:
       reader = csv.DictReader(csvfile)
       for row in reader:
           doc = {
               '@timestamp': row['_time'],
               'message': row['_raw'],
               'source': row['source'],
               'sourcetype': row['sourcetype']
           }
           print(json.dumps(doc))
   ```

3. **Import to Elasticsearch**:
   ```bash
   # Bulk import
   curl -X POST "http://new-es:9200/_bulk" \
     -H "Content-Type: application/json" \
     --data-binary @converted_data.json
   ```

### Dashboard Migration

**Splunk Dashboard XML to Kibana**:
```xml
<!-- Splunk dashboard -->
<dashboard>
  <panel>
    <title>Error Rate</title>
    <search>
      <query>index=app_logs level=ERROR | timechart count</query>
    </search>
  </panel>
</dashboard>
```

**Equivalent Kibana visualization**:
```json
{
  "title": "Error Rate",
  "type": "histogram",
  "params": {
    "grid": {"categoryLines": false, "style": {"color": "#eee"}},
    "categoryAxes": [{"id": "CategoryAxis-1", "type": "category"}],
    "valueAxes": [{"id": "ValueAxis-1", "type": "value"}],
    "seriesParams": [{"data": {"id": "1"}, "type": "histogram"}]
  },
  "aggs": [
    {
      "id": "1",
      "type": "count",
      "schema": "metric",
      "params": {}
    },
    {
      "id": "2",
      "type": "date_histogram",
      "schema": "segment",
      "params": {
        "field": "@timestamp",
        "interval": "auto"
      }
    }
  ]
}
```

## From Fluentd/Fluent Bit

### Configuration Conversion

**Fluentd to Logstash Input Mapping**:

| Fluentd | Logstash |
|---------|----------|
| `in_tail` | `file` input |
| `in_forward` | `tcp` input |
| `in_http` | `http` input |
| `in_syslog` | `syslog` input |

**Example Conversion**:

Fluentd config:
```ruby
<source>
  @type tail
  path /var/log/nginx/access.log
  pos_file /var/log/fluentd/nginx.log.pos
  tag nginx.access
  format nginx
</source>

<match nginx.**>
  @type elasticsearch
  host elasticsearch.example.com
  port 9200
  index_name nginx
</match>
```

Logstash equivalent:
```ruby
input {
  file {
    path => "/var/log/nginx/access.log"
    tags => ["nginx", "access"]
    type => "nginx"
  }
}

filter {
  if "nginx" in [tags] {
    grok {
      match => { "message" => "%{NGINXACCESS}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch.example.com:9200"]
    index => "nginx-%{+YYYY.MM.dd}"
  }
}
```

### Migration Steps

1. **Deploy Genesis Kit with custom parsers**:
   ```yaml
   kit:
     features:
     - custom-parsers
   
   params:
     custom_logstash_config: |
       # Your converted Logstash configuration
   ```

2. **Update log shippers**:
   ```yaml
   # For Filebeat
   output.logstash:
     hosts: ["logstash.example.com:5044"]
   
   # For Fluent Bit
   [OUTPUT]
       Name forward
       Match *
       Host logstash.example.com
       Port 24224
   ```

## From Graylog

### Data Export

**Graylog API data extraction**:
```bash
# Export indices
curl -X GET "http://graylog:9000/api/system/indices" \
  -H "Authorization: Basic $(echo -n admin:password | base64)" > indices.json

# Export streams configuration
curl -X GET "http://graylog:9000/api/streams" \
  -H "Authorization: Basic $(echo -n admin:password | base64)" > streams.json

# Export dashboards
curl -X GET "http://graylog:9000/api/dashboards" \
  -H "Authorization: Basic $(echo -n admin:password | base64)" > dashboards.json
```

### Configuration Migration

**Graylog Streams to Logstash Filters**:

Graylog stream rule:
```json
{
  "field": "source",
  "type": 1,
  "value": "web-server",
  "inverted": false
}
```

Logstash equivalent:
```ruby
filter {
  if [source] == "web-server" {
    # Processing for web server logs
    mutate {
      add_tag => ["web-server"]
    }
  }
}
```

## From CloudWatch Logs

### AWS CloudWatch Logs Migration

**Export CloudWatch Logs**:
```bash
# Install AWS CLI and configure credentials
aws configure

# Export log groups
aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output table

# Export log data
aws logs start-export-task \
  --log-group-name "/aws/lambda/my-function" \
  --from 1609459200000 \
  --to 1612137600000 \
  --destination "my-s3-bucket" \
  --destination-prefix "exported-logs/"
```

**Configure Logstash S3 input**:
```ruby
input {
  s3 {
    bucket => "my-s3-bucket"
    prefix => "exported-logs/"
    region => "us-west-2"
    type => "cloudwatch"
  }
}

filter {
  if [type] == "cloudwatch" {
    json {
      source => "message"
    }
    date {
      match => [ "timestamp", "UNIX_MS" ]
    }
  }
}
```

### Migration Configuration

```yaml
# environments/aws-migration.yml
kit:
  features:
  - s3-storage
  - cloudwatch-integration

params:
  s3_bucket: "my-log-storage-bucket"
  cloudwatch_log_groups:
  - "/aws/lambda/my-function"
  - "/aws/apigateway/my-api"
  - "/aws/ecs/my-service"
```

## From Syslog Solutions

### Traditional Syslog Migration

**Configure syslog input**:
```ruby
input {
  syslog {
    port => 5514
    type => "syslog"
  }
  
  udp {
    port => 5514
    type => "syslog-udp"
  }
}

filter {
  if [type] == "syslog" {
    grok {
      match => { 
        "message" => "%{SYSLOGTIMESTAMP:timestamp} %{IPORHOST:host} %{DATA:program}(?:\[%{POSINT:pid}\])?: %{GREEDYDATA:message}" 
      }
      overwrite => [ "message" ]
    }
    date {
      match => [ "timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
  }
}
```

**Update syslog clients**:
```bash
# rsyslog configuration
echo "*.* @@logstash.example.com:5514" >> /etc/rsyslog.conf
systemctl restart rsyslog

# syslog-ng configuration
echo 'destination d_logstash { tcp("logstash.example.com" port(5514)); };' >> /etc/syslog-ng/syslog-ng.conf
echo 'log { source(s_src); destination(d_logstash); };' >> /etc/syslog-ng/syslog-ng.conf
systemctl restart syslog-ng
```

## Data Migration Strategies

### Snapshot and Restore

**Create snapshot**:
```bash
# Register snapshot repository
curl -X PUT "http://old-es:9200/_snapshot/backup_repo" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "s3",
    "settings": {
      "bucket": "my-backup-bucket",
      "region": "us-west-2"
    }
  }'

# Create snapshot
curl -X PUT "http://old-es:9200/_snapshot/backup_repo/migration_snapshot" \
  -H "Content-Type: application/json" \
  -d '{
    "indices": "logstash-*",
    "ignore_unavailable": true,
    "include_global_state": false
  }'
```

**Restore to new cluster**:
```bash
# Register same repository on new cluster
curl -X PUT "http://new-es:9200/_snapshot/backup_repo" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "s3",
    "settings": {
      "bucket": "my-backup-bucket",
      "region": "us-west-2"
    }
  }'

# Restore snapshot
curl -X POST "http://new-es:9200/_snapshot/backup_repo/migration_snapshot/_restore" \
  -H "Content-Type: application/json" \
  -d '{
    "indices": "logstash-*",
    "rename_pattern": "(.+)",
    "rename_replacement": "migrated-$1"
  }'
```

### Streaming Migration

**Real-time data streaming**:
```ruby
# Logstash configuration for dual output
output {
  if [@metadata][migrate] {
    elasticsearch {
      hosts => ["old-cluster:9200"]
      index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
    }
    elasticsearch {
      hosts => ["new-cluster:9200"]
      index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
    }
  }
}
```

### Batch Processing

**Using Elasticsearch reindex API**:
```bash
# Reindex with query
curl -X POST "http://new-es:9200/_reindex" \
  -H "Content-Type: application/json" \
  -d '{
    "source": {
      "remote": {
        "host": "http://old-es:9200"
      },
      "index": "logstash-*",
      "query": {
        "range": {
          "@timestamp": {
            "gte": "2023-01-01",
            "lt": "2023-02-01"
          }
        }
      }
    },
    "dest": {
      "index": "migrated-logstash"
    }
  }'
```

## Testing and Validation

### Functional Testing

**Data Integrity Checks**:
```bash
# Compare document counts
OLD_COUNT=$(curl -s "http://old-es:9200/logstash-*/_count" | jq .count)
NEW_COUNT=$(curl -s "http://new-es:9200/migrated-*/_count" | jq .count)
echo "Old: $OLD_COUNT, New: $NEW_COUNT"

# Sample data comparison
curl -s "http://old-es:9200/logstash-*/_search?size=10&sort=@timestamp:desc" > old_sample.json
curl -s "http://new-es:9200/migrated-*/_search?size=10&sort=@timestamp:desc" > new_sample.json
```

**Performance Testing**:
```bash
# Search performance comparison
time curl -s "http://old-es:9200/logstash-*/_search" -d '{"query":{"match":{"level":"ERROR"}}}'
time curl -s "http://new-es:9200/migrated-*/_search" -d '{"query":{"match":{"level":"ERROR"}}}'

# Indexing performance test
genesis do prod -- es-health
```

### User Acceptance Testing

**Dashboard Validation**:
1. Recreate critical dashboards in Kibana
2. Compare visualizations with original system
3. Validate alert functionality
4. Test user access and permissions

**Query Validation**:
```bash
# Test common search patterns
curl -X GET "http://new-es:9200/migrated-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"range": {"@timestamp": {"gte": "now-1h"}}},
          {"match": {"level": "ERROR"}}
        ]
      }
    }
  }'
```

## Rollback Planning

### Rollback Preparation

**Pre-migration backup**:
```bash
# Document current configuration
kubectl get configmaps -o yaml > current-config.yaml
cp -r /etc/elasticsearch/ /backup/elasticsearch-config/
cp -r /etc/logstash/ /backup/logstash-config/
```

**Rollback procedures**:
```bash
# DNS cutover plan
# Switch DNS from new-cluster.com back to old-cluster.com
# Update load balancer configurations
# Restore log shipping configurations
```

### Monitoring During Migration

**Key metrics to monitor**:
- Data ingestion rates
- Search response times
- Error rates and failed requests
- Disk usage and performance
- Network traffic patterns

**Alerting configuration**:
```yaml
params:
  migration_alerts:
    ingestion_rate_drop: 50%  # Alert if below 50% of baseline
    error_rate_increase: 5%   # Alert if errors increase by 5%
    response_time_degradation: 200%  # Alert if 2x slower
```

### Post-Migration Cleanup

**After successful migration**:
1. Monitor new system for 30 days minimum
2. Gradually decommission old infrastructure
3. Update documentation and runbooks
4. Train operations team on new procedures
5. Archive old configuration and data as needed

This migration guide provides a comprehensive framework for moving from various log management solutions to the Logsearch Genesis Kit. Adapt the specific steps based on your current environment and requirements.