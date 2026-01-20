# Azure Chaos Engineering Starter Kit

A comprehensive, production-grade Chaos Engineering toolkit designed specifically for Azure environments. This starter kit provides pre-built chaos scenarios, hypothesis templates, and learning capture systems to help organizations implement chaos testing practices and improve system resilience.

## Overview

Chaos Engineering is the discipline of experimenting on a system to build confidence in its capability to withstand turbulent conditions in production. This starter kit provides a structured approach to implementing chaos testing in Azure environments with safety guardrails, comprehensive monitoring, and detailed reporting.

## Features

### Pre-built Chaos Scenarios
- **Pod Kill**: Simulates pod termination failures in Azure Kubernetes Service (AKS)
- **Network Latency**: Introduces network delays to test timeout and retry mechanisms
- **Region Outage**: Simulates regional Azure service outages to test failover capabilities

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

#### Pod Kill Scenario
```powershell
cd scenarios/pod-kill
.\pod-kill-script.ps1 -ResourceGroup "my-rg" -ClusterName "my-aks" -Namespace "default" -LabelSelector "app=myapp"
```

#### Network Latency Scenario
```powershell
cd scenarios/network-latency
.\network-latency-script.ps1 -ResourceGroup "my-rg" -TargetVMs "vm1,vm2" -LatencyMs 100
```

#### Region Outage Scenario
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
│   └── region-outage/
│       ├── region-outage-experiment.yaml
│       ├── region-outage-script.ps1
│       └── hypothesis.md
├── templates/
│   ├── hypothesis/
│   │   └── hypothesis-template.md
│   └── results/
│       └── results-template.md
├── scripts/
├── docs/
├── examples/
├── logs/                          # Generated during execution
└── reports/                       # Generated experiment reports
```

## Chaos Scenarios

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
Integrate chaos experiments into your CI/CD pipeline:
```yaml
# Example Azure DevOps Pipeline
- stage: Chaos_Testing
  displayName: 'Chaos Engineering Tests'
  jobs:
  - job: Pod_Kill_Test
    displayName: 'Pod Kill Resilience Test'
    steps:
    - task: AzurePowerShell@5
      inputs:
        azureSubscription: 'ServiceConnection'
        scriptType: 'FilePath'
        scriptPath: 'scenarios/pod-kill/pod-kill-script.ps1'
        arguments: '-ResourceGroup "$(ResourceGroup)" -ClusterName "$(AKSCluster)" -Namespace "staging" -LabelSelector "app=$(AppName)"'
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

- **v1.0.0**: Initial release with three core chaos scenarios
- Future versions will include additional scenarios and enhanced monitoring

---

**Note**: Always ensure you have proper authorization before running chaos experiments in production environments. Start with non-production environments and gradually increase scope as you gain confidence in your systems' resilience.
