# Logsearch Genesis Kit - Troubleshooting Guide

This guide helps diagnose and resolve common issues encountered when deploying and operating the Logsearch Genesis Kit.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Deployment Issues](#deployment-issues)
- [Elasticsearch Problems](#elasticsearch-problems)
- [Logstash Issues](#logstash-issues)
- [Kibana Problems](#kibana-problems)
- [Authentication Issues](#authentication-issues)
- [Storage Backend Problems](#storage-backend-problems)
- [Performance Issues](#performance-issues)
- [Network and Connectivity](#network-and-connectivity)
- [Certificate and Security](#certificate-and-security)
- [Advanced Diagnostics](#advanced-diagnostics)

## Quick Diagnostics

### Health Check Commands

```bash
# Overall cluster health
genesis do <env> -- es-health

# Index status and statistics
genesis do <env> -- es-indices

# BOSH deployment status
bosh -e <env> deployment

# Instance status
bosh -e <env> instances

# Recent logs
bosh -e <env> logs --recent
```

### Common Status Indicators

| Component | Healthy | Warning | Critical |
|-----------|---------|---------|----------|
| Elasticsearch | Green cluster | Yellow cluster | Red cluster |
| Logstash | Processing events | Slow processing | No events |
| Kibana | UI accessible | Slow responses | Connection errors |

## Deployment Issues

### Genesis Kit Compilation Errors

**Problem**: Kit fails to compile with YAML merge errors.

```
Error: Failed to merge manifest templates
```

**Solutions**:

1. **Check feature compatibility**:
   ```bash
   genesis check <env>
   ```

2. **Validate YAML syntax**:
   ```bash
   spruce merge --skip-eval environments/<env>.yml
   ```

3. **Review parameter requirements**:
   - Ensure all required parameters are defined
   - Check parameter types match expectations
   - Verify credential paths in Vault

**Example Fix**:
```yaml
# environments/prod.yml - Missing required parameter
params:
  base_domain: logs.company.com  # This was missing
  elasticsearch_instances: 3
```

### BOSH Deployment Failures

**Problem**: Deployment fails during instance creation or job execution.

**Diagnostic Steps**:

1. **Check BOSH events**:
   ```bash
   bosh -e <env> events --recent=50
   ```

2. **Review instance logs**:
   ```bash
   bosh -e <env> logs elasticsearch/0
   bosh -e <env> logs logstash/0
   bosh -e <env> logs kibana/0
   ```

3. **Verify cloud resources**:
   - VM quotas and limits
   - Storage availability
   - Network security groups

### Resource Allocation Problems

**Problem**: Insufficient resources for deployment.

**Symptoms**:
- Out of memory errors
- Disk space warnings
- CPU throttling

**Solutions**:

1. **Review sizing parameters**:
   ```yaml
   params:
     elasticsearch_heap_size: 4g  # Reduce if needed
     elasticsearch_instances: 2   # Scale down temporarily
   ```

2. **Use small-footprint feature**:
   ```yaml
   kit:
     features:
     - small-footprint  # For development/testing
   ```

## Elasticsearch Problems

### Cluster Health Issues

**Problem**: Elasticsearch cluster shows yellow or red status.

**Diagnostic Commands**:
```bash
# Detailed cluster health
curl -X GET "https://user:pass@es.example.com:9200/_cluster/health?pretty"

# Node information
curl -X GET "https://user:pass@es.example.com:9200/_cat/nodes?v"

# Shard allocation
curl -X GET "https://user:pass@es.example.com:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason"
```

**Common Causes and Solutions**:

1. **Yellow Status (Unassigned Replicas)**:
   ```bash
   # Check if you have enough nodes for replicas
   curl -X PUT "https://user:pass@es.example.com:9200/_settings" -H 'Content-Type: application/json' -d'
   {
     "index": {
       "number_of_replicas": 0
     }
   }'
   ```

2. **Red Status (Missing Primary Shards)**:
   - Check for failed nodes
   - Review disk space on data nodes
   - Examine network connectivity

3. **Split Brain Prevention**:
   ```yaml
   # Ensure proper minimum master nodes
   params:
     minimum_master_nodes: 2  # (total_masters / 2) + 1
   ```

### Out of Memory Errors

**Problem**: Elasticsearch nodes running out of memory.

**Symptoms**:
- `OutOfMemoryError` in logs
- Nodes dropping from cluster
- High GC pressure

**Solutions**:

1. **Increase heap size**:
   ```yaml
   params:
     elasticsearch_heap_size: 8g  # Increase from default
   ```

2. **Add more data nodes**:
   ```yaml
   params:
     elasticsearch_instances: 5  # Scale horizontally
   ```

3. **Optimize JVM settings**:
   ```yaml
   params:
     elasticsearch_jvm_options: |
       -XX:+UseG1GC
       -XX:MaxGCPauseMillis=200
   ```

### Index Management Issues

**Problem**: Indices growing too large or numerous.

**Solutions**:

1. **Implement index rotation**:
   ```yaml
   params:
     logstash_index_template: "logstash-%{+YYYY.MM.dd}"
   ```

2. **Configure curator addon**:
   ```bash
   genesis do <env> -- curator-setup
   ```

3. **Set up index lifecycle policies**:
   ```json
   {
     "policy": {
       "phases": {
         "hot": {
           "actions": {
             "rollover": {
               "max_size": "50gb",
               "max_age": "1d"
             }
           }
         },
         "delete": {
           "min_age": "30d"
         }
       }
     }
   }
   ```

## Logstash Issues

### Pipeline Processing Problems

**Problem**: Logstash not processing logs or experiencing high latency.

**Diagnostic Commands**:
```bash
# Check pipeline stats
curl -X GET "http://logstash.example.com:9600/_node/stats/pipelines"

# Monitor thread pools
curl -X GET "http://logstash.example.com:9600/_node/hot_threads"

# Review pipeline configuration
bosh -e <env> ssh logstash/0 "cat /var/vcap/jobs/logstash/config/logstash.conf"
```

**Common Issues**:

1. **Slow Filter Processing**:
   ```yaml
   params:
     logstash_pipeline_workers: 8      # Increase workers
     logstash_pipeline_batch_size: 250 # Optimize batch size
   ```

2. **Grok Pattern Failures**:
   - Test patterns with Grok Debugger in Kibana
   - Use conditional processing for different log formats
   - Add error handling for unparseable logs

3. **Memory Pressure**:
   ```yaml
   params:
     logstash_heap_size: 4g  # Increase heap size
   ```

### Input Plugin Issues

**Problem**: Logstash not receiving input data.

**Solutions**:

1. **Check input configuration**:
   ```ruby
   input {
     beats {
       port => 5044
       host => "0.0.0.0"
     }
   }
   ```

2. **Verify network connectivity**:
   ```bash
   # Test port accessibility
   nc -zv logstash.example.com 5044
   ```

3. **Review security groups**:
   - Ensure required ports are open
   - Check firewall rules

## Kibana Problems

### UI Access Issues

**Problem**: Cannot access Kibana web interface.

**Diagnostic Steps**:

1. **Check Kibana service status**:
   ```bash
   bosh -e <env> ssh kibana/0 "monit summary"
   ```

2. **Review Kibana logs**:
   ```bash
   bosh -e <env> logs kibana/0 --recent
   ```

3. **Test connectivity**:
   ```bash
   curl -I https://kibana.example.com
   ```

**Common Solutions**:

1. **Certificate issues**:
   ```bash
   # Regenerate certificates
   genesis rotate-secrets <env>
   genesis deploy <env>
   ```

2. **Elasticsearch connectivity**:
   ```yaml
   # Check elasticsearch_url in manifest
   kibana.elasticsearch.url: "https://elasticsearch.example.com:9200"
   ```

### Authentication Problems

**Problem**: OAuth authentication failing.

**Symptoms**:
- Login redirects failing
- Invalid token errors
- Authorization denied

**Solutions**:

1. **Verify OAuth configuration**:
   ```yaml
   params:
     oauth_provider: github
     oauth_discovery_url: https://github.com  # Correct URL
   ```

2. **Check stored credentials**:
   ```bash
   safe get secret/logsearch/<env>/oauth
   ```

3. **Review authorized domains**:
   ```yaml
   params:
     oauth_authorized_domains:
     - company.com  # Must match user email domain
   ```

## Storage Backend Problems

### S3 Integration Issues

**Problem**: Cannot write to or read from S3 storage.

**Diagnostic Steps**:

1. **Test S3 connectivity**:
   ```bash
   aws s3 ls s3://your-bucket-name --region us-west-2
   ```

2. **Verify credentials**:
   ```bash
   safe get secret/logsearch/<env>/s3
   ```

3. **Check IAM permissions**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": [
         "s3:GetObject",
         "s3:PutObject",
         "s3:DeleteObject",
         "s3:ListBucket"
       ],
       "Resource": [
         "arn:aws:s3:::your-bucket/*",
         "arn:aws:s3:::your-bucket"
       ]
     }]
   }
   ```

### Azure Storage Issues

**Problem**: Azure Blob storage integration failing.

**Solutions**:

1. **Verify storage account settings**:
   ```yaml
   params:
     azure_storage_account: companylogsstorage
     azure_container: logs
   ```

2. **Test storage key**:
   ```bash
   az storage blob list --account-name companylogsstorage --container-name logs
   ```

## Performance Issues

### Slow Search Performance

**Problem**: Kibana searches taking too long to complete.

**Solutions**:

1. **Optimize index patterns**:
   - Use time-based indices
   - Limit search time ranges
   - Create index aliases for common searches

2. **Tune Elasticsearch caching**:
   ```yaml
   params:
     elasticsearch_cache_size: 40%  # Of available memory
   ```

3. **Review field mappings**:
   - Use keyword fields for exact matches
   - Avoid wildcard queries on analyzed fields

### High Resource Usage

**Problem**: Nodes consuming excessive CPU, memory, or disk.

**Diagnostic Commands**:
```bash
# Node resource usage
curl -X GET "https://user:pass@es.example.com:9200/_cat/nodes?v&h=name,heap.percent,ram.percent,cpu,load_1m"

# Index sizes
curl -X GET "https://user:pass@es.example.com:9200/_cat/indices?v&h=index,store.size,docs.count&s=store.size:desc"
```

**Solutions**:

1. **Implement index lifecycle management**
2. **Optimize mapping templates**
3. **Use appropriate storage classes**
4. **Scale horizontally when needed**

## Network and Connectivity

### SSL/TLS Certificate Issues

**Problem**: Certificate validation errors or expired certificates.

**Solutions**:

1. **Regenerate certificates**:
   ```bash
   genesis rotate-secrets <env>
   ```

2. **Check certificate validity**:
   ```bash
   openssl x509 -in /path/to/cert.pem -text -noout
   ```

3. **Verify certificate chain**:
   ```bash
   openssl verify -CAfile ca.pem cert.pem
   ```

### Network Segmentation

**Problem**: Components cannot communicate due to network restrictions.

**Required Ports**:
- Elasticsearch: 9200 (HTTP), 9300 (Transport)
- Logstash: 5044 (Beats), 5514 (Syslog)
- Kibana: 5601 (HTTP), 443 (HTTPS)

**Solutions**:
1. Review security group rules
2. Check network ACLs
3. Verify routing tables

## Advanced Diagnostics

### Memory Analysis

```bash
# Elasticsearch heap dump
curl -X POST "https://user:pass@es.example.com:9200/_nodes/hot_threads"

# JVM statistics
curl -X GET "https://user:pass@es.example.com:9200/_nodes/stats/jvm"
```

### Thread Dump Analysis

```bash
# Generate thread dumps
kill -3 $(pgrep -f elasticsearch)

# Review in logs
bosh -e <env> logs elasticsearch/0 --recent | grep "Thread dump"
```

### Custom Monitoring Queries

```bash
# Cluster-wide statistics
curl -X GET "https://user:pass@es.example.com:9200/_cluster/stats?pretty"

# Node-specific metrics
curl -X GET "https://user:pass@es.example.com:9200/_nodes/elasticsearch-data-0/stats"

# Index-specific performance
curl -X GET "https://user:pass@es.example.com:9200/logstash-*/_stats?pretty"
```

## Getting Help

### Genesis Community Support

1. **GitHub Issues**: [Genesis Community Issues](https://github.com/genesis-community/logsearch-genesis-kit/issues)
2. **Slack Channel**: #genesis on Cloud Foundry Slack
3. **Documentation**: Check `genesis help` and kit documentation

### Log Collection for Support

```bash
# Collect comprehensive logs
bosh -e <env> logs --all

# Generate deployment manifest
genesis manifest <env> > deployment-manifest.yml

# Export environment configuration
genesis info <env> > environment-info.txt
```

### Emergency Procedures

1. **Complete Cluster Failure**:
   - Restore from backup using Shield integration
   - Redeploy from scratch if necessary
   - Migrate data from storage backend

2. **Data Corruption**:
   - Identify affected indices
   - Restore from backup
   - Reindex from original log sources

3. **Security Breach**:
   - Rotate all credentials immediately
   - Review access logs
   - Update authentication configuration

This troubleshooting guide covers the most common issues encountered with the Logsearch Genesis Kit. For complex problems, combine multiple diagnostic approaches and don't hesitate to reach out to the Genesis community for assistance.