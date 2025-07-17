output "cluster_nodes" {
  description = "K3s cluster node information"
  value = {
    master = {
      name     = "dev-k3s-master-01"
      ip       = module.shared.network.k3s_master
      vm_id    = module.shared.vm_ids.k3s_master
      node     = "pve1"
      ssh      = module.shared.ssh_commands.k3s_master
      cores    = module.shared.vm_configs.k3s_master.cores
      memory   = module.shared.vm_configs.k3s_master.memory
    }
    worker = {
      name     = "dev-k3s-worker-01"
      ip       = module.shared.network.k3s_worker_01
      vm_id    = module.shared.vm_ids.k3s_worker_01
      node     = "pve2"
      ssh      = module.shared.ssh_commands.k3s_worker
      cores    = module.shared.vm_configs.k3s_worker.cores
      memory   = module.shared.vm_configs.k3s_worker.memory
    }
  }
}

output "ansible_config" {
  description = "Ansible inventory configuration"
  sensitive   = true
  value = {
    master_ip     = module.shared.network.k3s_master
    worker_ip     = module.shared.network.k3s_worker_01
    k3s_token     = module.shared.k3s_cluster_token
    cluster_name  = "homelab-k3s"
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    install_k3s   = "cd ../../05_k3s_ansible_bootstrap && ansible-playbook k3s.orchestration.site"
    copy_kubeconfig = "scp ubuntu@${module.shared.network.k3s_master}:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
  }
}

output "troubleshooting" {
  description = "Debug commands"
  value = {
    ping_master = "ping ${module.shared.network.k3s_master}"
    ping_worker = "ping ${module.shared.network.k3s_worker_01}"
    vm_status   = "ssh root@pve1.local 'qm list | grep -E \"${module.shared.vm_ids.k3s_master}|${module.shared.vm_ids.k3s_worker_01}\"'"
    ansible_test = "cd ../../05_k3s_ansible_bootstrap && ansible all -m ping"
  }
}
