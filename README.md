# Azure Chaos Engineering Starter Kit

A comprehensive, production-grade Chaos Engineering toolkit designed specifically for Azure environments. This starter kit provides pre-built chaos scenarios, hypothesis templates, and learning capture systems to help organizations implement chaos testing practices and improve system resilience.

## Overview

Chaos Engineering is the discipline of experimenting on a system to build confidence in its capability to withstand turbulent conditions in production. This starter kit provides a structured approach to implementing chaos testing in Azure environments with safety guardrails, comprehensive monitoring, and detailed reporting.

## Features

### Pre-built Chaos Scenarios
- **Pod Kill**: Simulates pod termination failures in Azure Kubernetes Service (AKS)
- **Network Latency**: Introduces network delays to test timeout and retry mechanisms
- **Region Outage**: Simulates regional Azure service outages to test failover capabilities
- **Application Transactions**: Tests database transaction integrity and distributed transaction consistency
- **App Service**: Tests Azure App Service resilience, restart behavior, and failover capabilities
- **Service Bus**: Tests messaging reliability, queue behavior, and dead-letter handling
- **Pods**: Comprehensive Kubernetes pod chaos including failures, stress, and network issues
- **Redis Cache**: Tests Redis performance, memory pressure, and data consistency

### Comprehensive Framework
- **Hypothesis Templates**: Structured templates for defining experiment hypotheses
- **Expected vs Actual Results Tracking**: Detailed comparison framework for experiment analysis
- **Learning Capture System**: Systematic approach to capturing and documenting lessons learned
- **Automated Reporting**: JSON-based reports with detailed metrics and analysis

### Production-Grade Features
- **Safety Guardrails**: Automatic rollback mechanisms and blast radius controls
- **Monitoring Integration**: Azure Monitor and Application Insights integration
- **Logging and Auditing**: Comprehensive logging for all chaos experiments
- **Configuration Management**: YAML-based configuration for easy customization

## Prerequisites

### Required Tools
- Azure CLI (latest version)
- PowerShell 7.0 or later
- kubectl (for AKS scenarios)
- Azure subscription with appropriate permissions

### Azure Services
- Azure Monitor (for metrics collection)
- Log Analytics Workspace (for logging)
- Azure Kubernetes Service (for pod kill scenarios)
- Azure Virtual Machines (for network latency scenarios)
- Azure Traffic Manager (for region outage scenarios)

### Permissions
- Contributor role on target resource groups
- Reader role on monitoring resources
- Network Contributor role for network-related experiments

## Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd chaos-engineering-starter-kit
```

### 2. Configure Environment
Copy and modify the configuration file:
```bash
cp config/chaos-config.yaml config/chaos-config.yaml.local
```

Update the configuration with your Azure environment details:
- Subscription ID
- Resource Group names
- Azure regions
- Monitoring workspace IDs

### 3. Run Your First Experiment

#### Using the Orchestration Script (Recommended)
```powershell
# Application Transaction Chaos
.\scripts\run-chaos-experiment.ps1 -ExperimentType "application-transactions" -ResourceGroup "my-rg" -Duration "10m"

# App Service Chaos
.\scripts\run-chaos-experiment.ps1 -ExperimentType "app-service" -ResourceGroup "my-rg" -Duration "5m"

# Service Bus Chaos
.\scripts\run-chaos-experiment.ps1 -ExperimentType "service-bus" -ResourceGroup "my-rg" -Duration "8m"

# Pod Chaos
.\scripts\run-chaos-experiment.ps1 -ExperimentType "pods" -ResourceGroup "my-rg" -Duration "6m"

# Redis Cache Chaos
.\scripts\run-chaos-experiment.ps1 -ExperimentType "redis" -ResourceGroup "my-rg" -Duration "7m"

# Region Outage Chaos
.\scripts\run-chaos-experiment.ps1 -ExperimentType "region-outage" -ResourceGroup "my-rg" -Duration "15m"

# Network Latency Chaos
.\scripts\run-chaos-experiment.ps1 -ExperimentType "network-latency" -ResourceGroup "my-rg" -Duration "5m"
```

#### Individual Scenario Scripts

##### Pod Kill Scenario
```powershell
cd scenarios/pod-kill
.\pod-kill-script.ps1 -ResourceGroup "my-rg" -ClusterName "my-aks" -Namespace "default" -LabelSelector "app=myapp"
```

##### Network Latency Scenario
```powershell
cd scenarios/network-latency
.\network-latency-script.ps1 -ResourceGroup "my-rg" -TargetVMs "vm1,vm2" -LatencyMs 100
```

##### Region Outage Scenario
```powershell
cd scenarios/region-outage
.\region-outage-script.ps1 -PrimaryResourceGroup "primary-rg" -SecondaryResourceGroup "secondary-rg" -TrafficManagerProfile "my-tm" -PrimaryRegion "eastus" -SecondaryRegion "westus"
```

## Project Structure

```
chaos-engineering-starter-kit/
├── config/
│   └── chaos-config.yaml          # Global configuration
├── scenarios/
│   ├── pod-kill/
│   │   ├── pod-kill-experiment.yaml
│   │   ├── pod-kill-script.ps1
│   │   └── hypothesis.md
│   ├── network-latency/
│   │   ├── network-latency-experiment.yaml
│   │   ├── network-latency-script.ps1
│   │   └── hypothesis.md
│   ├── region-outage/
│   │   ├── region-outage-experiment.yaml
│   │   ├── region-outage-script.ps1
│   │   └── hypothesis.md
│   ├── application-transactions/
│   │   ├── application-transaction-experiment.yaml
│   │   ├── transaction-validation-script.ps1
│   │   └── hypothesis.md
│   ├── app-service/
│   │   ├── app-service-chaos-experiment.yaml
│   │   ├── app-service-validation-script.ps1
│   │   └── hypothesis.md
│   ├── service-bus/
│   │   ├── service-bus-chaos-experiment.yaml
│   │   ├── service-bus-validation-script.ps1
│   │   └── hypothesis.md
│   ├── pods/
│   │   ├── pod-chaos-experiment.yaml
│   │   ├── pod-validation-script.ps1
│   │   └── hypothesis.md
│   └── redis/
│       ├── redis-chaos-experiment.yaml
│       ├── redis-validation-script.ps1
│       └── hypothesis.md
├── templates/
│   ├── hypothesis/
│   │   └── hypothesis-template.md
│   └── results/
│       └── results-template.md
├── scripts/
│   └── run-chaos-experiment.ps1   # Master orchestration script
├── monitoring/
│   ├── chaos-monitoring-dashboard.json
│   └── chaos-alert-rules.yaml
├── docs/
├── examples/
├── logs/                          # Generated during execution
└── reports/                       # Generated experiment reports
```

## Chaos Scenarios

### Application Transactions Scenario

**Purpose**: Tests database transaction integrity, distributed transaction consistency, and connection pool behavior under failure conditions.

**What it Tests**:
- Database connection interruption handling
- Transaction rollback mechanisms
- Distributed transaction consistency
- Connection pool exhaustion recovery
- Two-phase commit timeout scenarios

**Key Metrics**:
- Transaction success rate
- Rollback success rate
- Connection pool utilization
- Distributed transaction latency
- Data consistency validation

**Usage**:
```powershell
.\scripts\run-chaos-experiment.ps1 -ExperimentType "application-transactions" -ResourceGroup "rg-name" -Duration "10m"
```

### App Service Scenario

**Purpose**: Tests Azure App Service resilience, restart behavior, scaling capabilities, and configuration changes.

**What it Tests**:
- App Service restart and recovery
- Platform-level failures
- Configuration change impacts
- Auto-scaling behavior
- Slot swap operations
- Network connectivity issues

**Key Metrics**:
- Service availability percentage
- Response time during restart
- Scaling operation success rate
- Configuration change impact
- HTTP error rates

**Usage**:
```powershell
.\scripts\run-chaos-experiment.ps1 -ExperimentType "app-service" -ResourceGroup "rg-name" -Duration "5m"
```

### Service Bus Scenario

**Purpose**: Tests Service Bus messaging reliability, queue behavior, dead-letter handling, and connection resilience.

**What it Tests**:
- Message queue disruption
- Topic publishing failures
- Connection interruption handling
- Dead-letter queue behavior
- Session lock timeout scenarios
- Authentication failures

**Key Metrics**:
- Message throughput rate
- Dead-letter rate percentage
- Connection success rate
- Queue backlog size
- Session lock efficiency

**Usage**:
```powershell
.\scripts\run-chaos-experiment.ps1 -ExperimentType "service-bus" -ResourceGroup "rg-name" -Duration "8m"
```

### Pods Scenario

**Purpose**: Comprehensive Kubernetes pod chaos testing including failures, stress, network issues, and resource exhaustion.

**What it Tests**:
- Pod failure and restart behavior
- Container kill scenarios
- CPU and memory stress
- Network latency and partition
- DNS resolution failures
- Filesystem corruption
- HTTP request failures

**Key Metrics**:
- Pod recreation time
- Restart rate percentage
- Resource utilization levels
- Network connectivity success
- Container health status

**Usage**:
```powershell
.\scripts\run-chaos-experiment.ps1 -ExperimentType "pods" -ResourceGroup "rg-name" -Duration "6m"
```

### Redis Cache Scenario

**Purpose**: Tests Redis cache performance, memory pressure, data consistency, and high availability features.

**What it Tests**:
- Cache restart and failover
- Memory pressure scenarios
- Replication lag handling
- Persistence failures
- Network connectivity issues
- Configuration changes

**Key Metrics**:
- Cache hit rate percentage
- Memory usage levels
- Connection count
- Replication lag time
- Persistence success rate

**Usage**:
```powershell
.\scripts\run-chaos-experiment.ps1 -ExperimentType "redis" -ResourceGroup "rg-name" -Duration "7m"
```

### Pod Kill Scenario

**Purpose**: Tests the resilience of applications running in AKS when pods are terminated unexpectedly.

**What it Tests**:
- Horizontal Pod Autoscaler functionality
- Replica set recovery capabilities
- Application startup time and health checks
- Load balancer failover behavior

**Key Metrics**:
- Pod recreation time
- Service availability during restart
- Request success rate
- Recovery time objective (RTO)

**Usage**:
```powershell
.\pod-kill-script.ps1 -ResourceGroup "rg-name" -ClusterName "aks-name" -Namespace "namespace" -LabelSelector "app=label"
```

### Network Latency Scenario

**Purpose**: Introduces network delays to test timeout handling, retry mechanisms, and circuit breaker patterns.

**What it Tests**:
- Application timeout configurations
- Retry logic and exponential backoff
- Circuit breaker activation and recovery
- User experience under degraded network conditions

**Key Metrics**:
- Response time increase
- Error rate during latency
- Timeout frequency
- Circuit breaker state changes

**Usage**:
```powershell
.\network-latency-script.ps1 -ResourceGroup "rg-name" -TargetVMs "vm1,vm2" -LatencyMs 100 -JitterMs 10
```

### Region Outage Scenario

**Purpose**: Simulates a regional Azure service outage to test disaster recovery and failover capabilities.

**What it Tests**:
- Traffic Manager failover functionality
- Cross-region data replication
- DNS propagation time
- Service availability during failover

**Key Metrics**:
- Failover time
- Data consistency across regions
- Service availability percentage
- User session preservation

**Usage**:
```powershell
.\region-outage-script.ps1 -PrimaryResourceGroup "primary-rg" -SecondaryResourceGroup "secondary-rg" -TrafficManagerProfile "tm-name" -PrimaryRegion "eastus" -SecondaryRegion "westus"
```

## Hypothesis-Driven Approach

Every chaos experiment should start with a clear hypothesis. Use the provided templates to document:

1. **Steady State**: Define normal system behavior
2. **Expected Impact**: Predict what will happen during the experiment
3. **Success Criteria**: Define what constitutes a successful experiment
4. **Rollback Triggers**: Define when to immediately stop the experiment

### Example Hypothesis Structure

```
Hypothesis: When a pod is terminated, the replica set will recreate it within 60 seconds and the service will maintain 99% availability.

Expected Behavior:
- Pod recreation time < 60 seconds
- Service availability > 99%
- No data loss
- Automatic recovery without manual intervention
```

## Monitoring and Observability

### Comprehensive Monitoring Dashboard
The starter kit includes a pre-configured Grafana dashboard (`monitoring/chaos-monitoring-dashboard.json`) that provides real-time visibility into:
- Application transaction health and error rates
- Database connection pool status
- App Service performance metrics
- Service Bus message throughput and dead-letter rates
- Kubernetes pod health and restart counts
- Redis cache performance and hit rates
- System resource utilization
- Chaos experiment status and duration

### Alert Rules
Pre-configured Prometheus alert rules (`monitoring/chaos-alert-rules.yaml`) for:
- Critical system degradation during experiments
- Service availability thresholds
- Resource exhaustion conditions
- Chaos experiment duration limits
- Post-experiment recovery validation

### Pre-Experiment Monitoring
1. Establish baseline metrics for all target systems
2. Verify monitoring endpoints are accessible
3. Set up alert notifications for critical thresholds
4. Document current system performance characteristics

### During Experiment Monitoring
1. Real-time metric collection and analysis
2. Automated alerting for threshold breaches
3. Log aggregation and analysis
4. Performance degradation tracking

### Post-Experiment Analysis
1. Compare actual vs expected results
2. Identify unexpected behaviors
3. Document recovery patterns
4. Update system documentation

## Safety and Guardrails

### Blast Radius Control
- Start with small, isolated experiments
- Gradually increase scope and complexity
- Use canary deployments for new experiment types
- Maintain separate environments for different experiment phases

### Automated Rollback
- Immediate rollback on critical threshold breaches
- Time-based automatic experiment termination
- Health check validation before experiment completion
- Post-experiment cleanup automation

### Approval Process
- Peer review for all experiment hypotheses
- Change management integration for production experiments
- Stakeholder communication before execution
- Post-experiment review and documentation

## Best Practices

### Experiment Design
1. **Start Small**: Begin with low-risk experiments in non-production environments
2. **Document Everything**: Maintain detailed records of hypotheses, results, and learnings
3. **Monitor Continuously**: Never run experiments without comprehensive monitoring
4. **Plan for Rollback**: Always have a clear rollback strategy

### Execution Guidelines
1. **Schedule Appropriately**: Run experiments during low-traffic periods initially
2. **Communicate Clearly**: Inform all stakeholders before running experiments
3. **Monitor Closely**: Watch for unexpected behavior during execution
4. **Document Results**: Capture all outcomes, even unexpected ones

### Learning and Improvement
1. **Regular Reviews**: Conduct post-experiment reviews with all stakeholders
2. **Share Knowledge**: Document and share learnings across teams
3. **Iterate and Improve**: Use learnings to improve system resilience
4. **Expand Scope**: Gradually increase experiment complexity and scope

## Integration with CI/CD

### Automated Chaos Testing
Integrate chaos experiments into your CI/CD pipeline using the orchestration script:
```yaml
# Example Azure DevOps Pipeline
- stage: Chaos_Testing
  displayName: 'Chaos Engineering Tests'
  jobs:
  - job: Application_Transaction_Test
    displayName: 'Application Transaction Resilience Test'
    steps:
    - task: AzurePowerShell@5
      inputs:
        azureSubscription: 'ServiceConnection'
        scriptType: 'FilePath'
        scriptPath: 'scripts/run-chaos-experiment.ps1'
        arguments: '-ExperimentType "application-transactions" -ResourceGroup "$(ResourceGroup)" -Duration "5m" -EnableMonitoring'
  - job: App_Service_Test
    displayName: 'App Service Resilience Test'
    steps:
    - task: AzurePowerShell@5
      inputs:
        azureSubscription: 'ServiceConnection'
        scriptType: 'FilePath'
        scriptPath: 'scripts/run-chaos-experiment.ps1'
        arguments: '-ExperimentType "app-service" -ResourceGroup "$(ResourceGroup)" -Duration "3m" -EnableMonitoring'
  - job: Service_Bus_Test
    displayName: 'Service Bus Resilience Test'
    steps:
    - task: AzurePowerShell@5
      inputs:
        azureSubscription: 'ServiceConnection'
        scriptType: 'FilePath'
        scriptPath: 'scripts/run-chaos-experiment.ps1'
        arguments: '-ExperimentType "service-bus" -ResourceGroup "$(ResourceGroup)" -Duration "4m" -EnableMonitoring'
```

### Gatekeeper for Deployments
Use chaos test results as deployment gates:
- Block deployments if chaos tests fail
- Require minimum resilience scores
- Integrate with deployment approval processes

## Troubleshooting

### Common Issues

#### Azure CLI Authentication
```bash
az login
az account set --subscription "subscription-id"
```

#### kubectl Configuration
```bash
az aks get-credentials --resource-group rg-name --name aks-name
```

#### Permission Errors
Ensure your service principal has:
- Contributor role on target resources
- Reader role on monitoring resources
- Network Contributor role for network experiments

#### Experiment Failures
1. Check logs in the `logs/` directory
2. Verify resource configurations
3. Validate network connectivity
4. Review Azure Monitor metrics

### Debug Mode
Enable debug logging by setting the environment variable:
```powershell
$env:CHAOS_DEBUG = "true"
```

## Contributing

We welcome contributions to improve the Chaos Engineering Starter Kit. Please:

1. Fork the repository
2. Create a feature branch
3. Add your improvements with appropriate documentation
4. Submit a pull request with a clear description of changes

### Contribution Guidelines
- Follow existing code style and patterns
- Add comprehensive documentation for new features
- Include test cases for new functionality
- Update README and other documentation as needed

## Support

For questions, issues, or contributions:

1. Check existing documentation and troubleshooting guides
2. Review experiment logs and reports
3. Consult Azure documentation for specific service issues
4. Create GitHub issues for bugs or feature requests

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

This Chaos Engineering Starter Kit is inspired by industry best practices from:
- Netflix Chaos Engineering
- Gremlin
- Chaos Mesh
- Azure Chaos Studio
- The Principles of Chaos Engineering

## Version History

- **v2.0.0**: Major expansion with 5 new chaos scenarios
  - Application Transactions chaos testing
  - App Service resilience testing
  - Service Bus messaging chaos
  - Comprehensive Pod chaos scenarios
  - Redis cache chaos testing
  - Master orchestration script
  - Enhanced monitoring dashboard and alerting
- **v1.0.0**: Initial release with three core chaos scenarios

---

**Note**: Always ensure you have proper authorization before running chaos experiments in production environments. Start with non-production environments and gradually increase scope as you gain confidence in your systems' resilience.
