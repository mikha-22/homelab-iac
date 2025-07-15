output "web_server_ips" {
  description = "The IP addresses of the created k3s servers."
  value = {
    "dev-k3s-master-01" = proxmox_virtual_environment_vm.master.initialization[0].ip_config[0].ipv4[0].address
    "dev-k3s-worker-01" = proxmox_virtual_environment_vm.worker.initialization[0].ip_config[0].ipv4[0].address
  }
}

output "cluster_info" {
  description = "K3s cluster information for next steps"
  value = {
    master = {
      name     = "dev-k3s-master-01"
      hostname = "dev-k3s-master-01"
      ip       = "192.168.1.181"
      node     = "pve1"
      vmid     = 181
    }
    workers = [
      {
        name     = "dev-k3s-worker-01"
        hostname = "dev-k3s-worker-01"
        ip       = "192.168.1.182"
        node     = "pve2"
        vmid     = 182
      }
    ]
    ssh_command = "ssh ubuntu@192.168.1.181  # Connect to master node"
  }
}
