---
k3s_cluster:
  children:
    server:
      hosts:
        # Master node - IP from Terraform shared config
        ${master_ip}:
          ansible_user: ubuntu
          # Set the K3s node name to match the hostname
          k3s_node_name: dev-k3s-master-01
          # VM info for reference
          vm_id: ${master_vm_id}
          proxmox_node: pve1
          
    agent:
      hosts:
        # Worker node - IP from Terraform shared config
        ${worker_ip}:
          ansible_user: ubuntu
          # Set the K3s node name to match the hostname
          k3s_node_name: dev-k3s-worker-01
          # VM info for reference
          vm_id: ${worker_vm_id}
          proxmox_node: pve2

  vars:
    # K3s configuration
    k3s_version: "v1.29.5+k3s1"
    
    # API endpoint - uses master IP from Terraform
    api_endpoint: "${master_ip}"
    
    # Cluster token - securely managed in Google Secret Manager
    k3s_token: "${k3s_token}"
    
    # Network configuration (matches Terraform shared config)
    cluster_cidr: "10.42.0.0/16"      # K3s default pod network
    service_cidr: "10.43.0.0/16"      # K3s default service network
    cluster_dns: "10.43.0.10"         # K3s default CoreDNS
    
    # Disable components we don't need in homelab
    k3s_server_config:
      kube-controller-manager-arg:
        - "bind-address=0.0.0.0"
      kube-proxy-arg:
        - "metrics-bind-address=0.0.0.0"
      kube-scheduler-arg:
        - "bind-address=0.0.0.0"
      etcd-expose-metrics: true
    
    k3s_agent_config:
      kube-proxy-arg:
        - "metrics-bind-address=0.0.0.0"

# ===================================================================
#  AUTO-GENERATED CONFIGURATION NOTES
# ===================================================================

# Network Layout (from Terraform shared config):
# - Host network: ${subnet}.0/24
# - NAS server: ${nas_ip}
# - K3s master: ${master_ip}
# - K3s worker: ${worker_ip}
# - Gateway: ${gateway}
# - DNS: 1.1.1.1, 8.8.8.8
# - Domain: ${domain}

# K3s Internal Networks:
# - Pod CIDR: 10.42.0.0/16 (default)
# - Service CIDR: 10.43.0.0/16 (default)  
# - CoreDNS: 10.43.0.10 (default)

# After K3s Installation:
# 1. Kubeconfig will be at: /etc/rancher/k3s/k3s.yaml (on master)
# 2. Copy to your local machine: ~/.kube/config
# 3. Update server URL to: https://${master_ip}:6443
# 4. Test with: kubectl get nodes

# Troubleshooting:
# - SSH to master: ssh ubuntu@${master_ip}
# - SSH to worker: ssh ubuntu@${worker_ip}
# - Check K3s logs: sudo journalctl -u k3s -f
# - Restart K3s: sudo systemctl restart k3s

# SECURITY NOTE: This file contains the K3s cluster token.
# The token is managed securely in Google Secret Manager.
# Do not commit this generated file to version control.
