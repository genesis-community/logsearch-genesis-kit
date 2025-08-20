# Logsearch Genesis Kit - Performance Tuning Guide

This guide provides comprehensive recommendations for optimizing the performance of your Logsearch deployment across different scales and use cases.

## Table of Contents

- [Performance Overview](#performance-overview)
- [Elasticsearch Optimization](#elasticsearch-optimization)
- [Logstash Tuning](#logstash-tuning)
- [Kibana Performance](#kibana-performance)
- [JVM and Memory Management](#jvm-and-memory-management)
- [Storage Optimization](#storage-optimization)
- [Network and I/O Tuning](#network-and-io-tuning)
- [Index Management](#index-management)
- [Monitoring and Metrics](#monitoring-and-metrics)
- [Scale-Specific Recommendations](#scale-specific-recommendations)

## Performance Overview

### Key Performance Indicators

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Search Response Time | < 1s | 1-3s | > 3s |
| Indexing Rate | 10k-50k docs/sec | 5k-10k docs/sec | < 5k docs/sec |
| Cluster Health | Green | Yellow | Red |
| JVM Heap Usage | < 75% | 75-85% | > 85% |
| Disk Usage | < 80% | 80-90% | > 90% |

### Performance Testing

```bash
# Index performance test
curl -X POST "https://es.example.com:9200/_bulk" -H 'Content-Type: application/json' --data-binary @bulk_data.json

# Search performance test
curl -X GET "https://es.example.com:9200/logstash-*/_search" -H 'Content-Type: application/json' -d'{
  "size": 1000,
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h"
      }
    }
  }
}'

# Load testing with Apache Bench
ab -n 1000 -c 10 "https://kibana.example.com/api/search"
```

## Elasticsearch Optimization

### Cluster Architecture

**Small Scale (< 10GB/day)**:
```yaml
params:
  elasticsearch_instances: 3
  elasticsearch_heap_size: 4g
  elasticsearch_disk_size: 200_000  # 200GB
```

**Medium Scale (10-100GB/day)**:
```yaml
params:
  elasticsearch_instances: 6
  elasticsearch_heap_size: 16g
  elasticsearch_disk_size: 1_000_000  # 1TB
```

**Large Scale (> 100GB/day)**:
```yaml
params:
  elasticsearch_instances: 12
  elasticsearch_heap_size: 32g
  elasticsearch_disk_size: 5_000_000  # 5TB
```

### Heap Sizing Guidelines

**Memory Allocation Rules**:
- Heap size = 50% of available RAM
- Never exceed 32GB heap size
- Leave RAM for OS file cache

```yaml
# Example for 64GB RAM node
params:
  elasticsearch_heap_size: 30g  # Leave 2GB buffer under 32GB limit
```

### Thread Pool Configuration

```yaml
params:
  elasticsearch_thread_pool_config: |
    thread_pool:
      search:
        size: 32
        queue_size: 1000
      index:
        size: 8
        queue_size: 200
      bulk:
        size: 8
        queue_size: 200
```

### Node Roles Optimization

**Dedicated Master Nodes**:
```yaml
params:
  elasticsearch_master_nodes: 3
  elasticsearch_master_heap_size: 2g
  elasticsearch_master_disk_size: 50_000
```

**Data Nodes**:
```yaml
params:
  elasticsearch_data_nodes: 6
  elasticsearch_data_heap_size: 32g
  elasticsearch_data_disk_size: 2_000_000
```

**Coordinating Nodes**:
```yaml
params:
  elasticsearch_coord_nodes: 2
  elasticsearch_coord_heap_size: 8g
```

### Index Settings Optimization

```yaml
params:
  elasticsearch_index_settings: |
    index:
      number_of_shards: 5
      number_of_replicas: 1
      refresh_interval: 30s
      translog:
        flush_threshold_size: 1gb
        sync_interval: 5s
      merge:
        policy:
          max_merge_at_once: 10
          segments_per_tier: 10
```

### Query Performance

**Field Data Cache**:
```yaml
params:
  elasticsearch_fielddata_cache_size: 40%
```

**Query Cache**:
```yaml
params:
  elasticsearch_query_cache_size: 10%
```

**Filter Cache**:
```yaml
params:
  elasticsearch_filter_cache_size: 20%
```

## Logstash Tuning

### Pipeline Configuration

**High Throughput Setup**:
```yaml
params:
  logstash_instances: 4
  logstash_heap_size: 8g
  logstash_pipeline_workers: 16
  logstash_pipeline_batch_size: 500
  logstash_pipeline_batch_delay: 50
```

**Low Latency Setup**:
```yaml
params:
  logstash_instances: 2
  logstash_heap_size: 4g
  logstash_pipeline_workers: 8
  logstash_pipeline_batch_size: 125
  logstash_pipeline_batch_delay: 5
```

### Filter Optimization

**Efficient Grok Patterns**:
```ruby
# Use specific patterns instead of generic ones
filter {
  grok {
    match => { "message" => "%{IPORHOST:client_ip} - - \[%{HTTPDATE:timestamp}\]" }
    # Instead of: "%{COMBINEDAPACHELOG}"
  }
}
```

**Conditional Processing**:
```ruby
filter {
  if [type] == "apache" {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
  } else if [type] == "nginx" {
    grok {
      match => { "message" => "%{NGINXACCESS}" }
    }
  }
}
```

**Field Extraction**:
```ruby
filter {
  # Extract only needed fields
  mutate {
    add_field => { "short_message" => "%{[message][0..100]}" }
    remove_field => [ "message" ]  # Remove large original field
  }
}
```

### Output Optimization

**Elasticsearch Output Tuning**:
```ruby
output {
  elasticsearch {
    hosts => ["elasticsearch1:9200", "elasticsearch2:9200"]
    index => "logstash-%{+YYYY.MM.dd}"
    workers => 4
    flush_size => 1000
    idle_flush_time => 10
    template_overwrite => true
  }
}
```

## Kibana Performance

### Configuration Optimization

```yaml
params:
  kibana_instances: 2
  kibana_memory_limit: 4g
  kibana_config: |
    server.maxPayloadBytes: 1048576
    elasticsearch.requestTimeout: 300000
    elasticsearch.shardTimeout: 30000
    map.includeElasticMapsService: false
```

### Dashboard Optimization

**Query Performance**:
- Limit time ranges to necessary periods
- Use filters instead of query strings when possible
- Avoid wildcard queries on analyzed fields
- Use index patterns strategically

**Visualization Efficiency**:
- Reduce bucket counts in aggregations
- Use sampling for large datasets
- Implement dashboard caching

### Browser Performance

**Client-Side Optimization**:
- Enable browser caching
- Compress responses
- Minimize dashboard complexity
- Use time-based index patterns

## JVM and Memory Management

### Garbage Collection Tuning

**G1GC Configuration (Recommended)**:
```yaml
params:
  elasticsearch_jvm_options: |
    -XX:+UseG1GC
    -XX:G1HeapRegionSize=32m
    -XX:+G1UseAdaptiveIHOP
    -XX:G1MixedGCCountTarget=8
    -XX:MaxGCPauseMillis=200
```

**Parallel GC (Alternative)**:
```yaml
params:
  elasticsearch_jvm_options: |
    -XX:+UseParallelGC
    -XX:ParallelGCThreads=8
    -XX:+UseParallelOldGC
```

### Memory Management

**Direct Memory**:
```yaml
params:
  elasticsearch_jvm_options: |
    -XX:MaxDirectMemorySize=4g
```

**Native Memory Tracking**:
```yaml
params:
  elasticsearch_jvm_options: |
    -XX:NativeMemoryTracking=summary
```

### JVM Monitoring

```bash
# GC logging
-XX:+PrintGC
-XX:+PrintGCDetails
-XX:+PrintGCTimeStamps
-Xloggc:/var/log/elasticsearch/gc.log

# Heap dump on OOM
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/log/elasticsearch/
```

## Storage Optimization

### Disk Configuration

**SSD Recommendations**:
```yaml
params:
  elasticsearch_disk_type: gp3  # AWS
  elasticsearch_disk_iops: 3000
  elasticsearch_disk_throughput: 125  # MB/s
```

**RAID Configuration**:
- RAID 0 for performance (with replication)
- RAID 10 for balance of performance and redundancy
- Avoid RAID 5/6 for write-heavy workloads

### Filesystem Optimization

**Mount Options**:
```bash
# /etc/fstab entry
/dev/sdb1 /var/vcap/store ext4 defaults,noatime,nodiratime,discard 0 2
```

**Filesystem Settings**:
```bash
# Increase file descriptor limits
echo "elasticsearch soft nofile 65536" >> /etc/security/limits.conf
echo "elasticsearch hard nofile 65536" >> /etc/security/limits.conf

# Virtual memory settings
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
```

### Compression

**Index Compression**:
```yaml
params:
  elasticsearch_index_settings: |
    index:
      codec: best_compression
      store:
        preload: ["nvd", "dvd"]
```

## Network and I/O Tuning

### Network Configuration

**TCP Settings**:
```bash
# Increase buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# TCP window scaling
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
```

### Elasticsearch Transport

```yaml
params:
  elasticsearch_transport_config: |
    transport:
      tcp:
        no_delay: true
        keep_alive: true
        reuse_address: true
        send_buffer_size: 128mb
        receive_buffer_size: 128mb
```

## Index Management

### Index Lifecycle Management

**Hot-Warm-Cold Architecture**:
```yaml
params:
  elasticsearch_ilm_policy: |
    {
      "policy": {
        "phases": {
          "hot": {
            "actions": {
              "rollover": {
                "max_size": "50gb",
                "max_age": "1d"
              },
              "set_priority": {
                "priority": 100
              }
            }
          },
          "warm": {
            "min_age": "2d",
            "actions": {
              "allocate": {
                "number_of_replicas": 0
              },
              "forcemerge": {
                "max_num_segments": 1
              },
              "set_priority": {
                "priority": 50
              }
            }
          },
          "cold": {
            "min_age": "7d",
            "actions": {
              "allocate": {
                "number_of_replicas": 0,
                "include": {
                  "data_tier": "cold"
                }
              },
              "set_priority": {
                "priority": 0
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

### Template Optimization

**Efficient Mapping**:
```json
{
  "mappings": {
    "properties": {
      "@timestamp": {
        "type": "date"
      },
      "message": {
        "type": "text",
        "norms": false
      },
      "level": {
        "type": "keyword"
      },
      "host": {
        "type": "keyword",
        "doc_values": false
      }
    }
  }
}
```

## Monitoring and Metrics

### Performance Metrics

**Elasticsearch Metrics**:
```bash
# Cluster stats
curl -X GET "http://es.example.com:9200/_cluster/stats"

# Node stats
curl -X GET "http://es.example.com:9200/_nodes/stats"

# Index stats
curl -X GET "http://es.example.com:9200/_stats"
```

**Logstash Metrics**:
```bash
# Pipeline stats
curl -X GET "http://logstash.example.com:9600/_node/stats/pipelines"

# JVM stats
curl -X GET "http://logstash.example.com:9600/_node/stats/jvm"
```

### Alerting Thresholds

```yaml
# Example alerting configuration
params:
  monitoring_thresholds:
    heap_usage_warning: 75
    heap_usage_critical: 85
    disk_usage_warning: 80
    disk_usage_critical: 90
    search_latency_warning: 1000  # ms
    search_latency_critical: 3000  # ms
```

## Scale-Specific Recommendations

### Small Deployment (< 1TB data)

```yaml
params:
  # Single-node or minimal cluster
  elasticsearch_instances: 1
  elasticsearch_heap_size: 4g
  elasticsearch_disk_size: 200_000
  
  logstash_instances: 1
  logstash_heap_size: 2g
  
  kibana_instances: 1
  kibana_memory_limit: 1g
```

### Medium Deployment (1-10TB data)

```yaml
params:
  # Dedicated roles
  elasticsearch_master_nodes: 3
  elasticsearch_data_nodes: 3
  elasticsearch_heap_size: 16g
  elasticsearch_disk_size: 1_000_000
  
  logstash_instances: 2
  logstash_heap_size: 8g
  
  kibana_instances: 2
  kibana_memory_limit: 2g
```

### Large Deployment (> 10TB data)

```yaml
params:
  # Full separation of concerns
  elasticsearch_master_nodes: 3
  elasticsearch_data_nodes: 12
  elasticsearch_coord_nodes: 3
  elasticsearch_heap_size: 32g
  elasticsearch_disk_size: 5_000_000
  
  logstash_instances: 6
  logstash_heap_size: 16g
  
  kibana_instances: 3
  kibana_memory_limit: 4g
```

### Enterprise Deployment

```yaml
params:
  # Multi-region with performance optimization
  features:
  - multi-region
  - performance-optimization
  - monitoring
  
  # High availability configuration
  elasticsearch_master_nodes: 5
  elasticsearch_data_nodes: 18
  elasticsearch_coord_nodes: 6
  minimum_master_nodes: 3
  
  # Cross-region replication
  cross_region_replication: true
  replica_regions: 2
```

## Performance Testing and Validation

### Benchmarking Tools

**Rally (Elasticsearch)**:
```bash
# Install and run Rally
pip install esrally
rally race --track=geonames --target-hosts=es1.example.com:9200
```

**Custom Load Testing**:
```bash
# Create test data
for i in {1..10000}; do
  echo '{"@timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'","message":"Test log entry '$i'","level":"INFO"}' | \
  curl -X POST "http://es.example.com:9200/test-index/_doc" -H 'Content-Type: application/json' -d @-
done
```

### Performance Validation Checklist

1. **Indexing Performance**
   - [ ] Sustained indexing rate meets requirements
   - [ ] No indexing queues building up
   - [ ] Acceptable indexing latency

2. **Search Performance**
   - [ ] Search response times under 1 second
   - [ ] No search queue timeouts
   - [ ] Dashboard loading within acceptable limits

3. **Resource Utilization**
   - [ ] JVM heap usage under 85%
   - [ ] CPU utilization balanced across nodes
   - [ ] Disk I/O not saturated

4. **Cluster Health**
   - [ ] Green cluster status maintained
   - [ ] No unassigned shards
   - [ ] Proper shard distribution

This performance tuning guide provides a foundation for optimizing your Logsearch deployment. Regular monitoring and iterative tuning based on your specific workload patterns will yield the best results.