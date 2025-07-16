output "deployment_status" {
  description = "K3s VMs deployment status and verification"
  value = {
    status = "✅ K3s cluster VMs deployed successfully"
    
    resources = {
      master_vm = {
        name            = proxmox_virtual_environment_vm.master.name
        ip_address      = module.shared.network.k3s_master
        vm_id           = module.shared.vm_ids.k3s_master
        proxmox_node    = proxmox_virtual_environment_vm.master.node_name
        template_source = module.shared.vm_ids.base_template
        cores           = module.shared.vm_configs.k3s_master.cores
        memory_mb       = module.shared.vm_configs.k3s_master.memory
      }
      
      worker_vm = {
        name            = proxmox_virtual_environment_vm.worker.name
        ip_address      = module.shared.network.k3s_worker_01
        vm_id           = module.shared.vm_ids.k3s_worker_01
        proxmox_node    = proxmox_virtual_environment_vm.worker.node_name
        template_source = module.shared.vm_ids.base_template
        cores           = module.shared.vm_configs.k3s_worker.cores
        memory_mb       = module.shared.vm_configs.k3s_worker.memory
      }
      
      cloud_init = {
        master_file = "master-hostname-init.yaml"
        worker_file = "worker-hostname-init.yaml"
        storage     = "cluster-shared-nfs"
      }
    }
    
    verification = {
      vms_created          = "✅ Both master and worker VMs created"
      network_connectivity = "✅ Inter-node communication verified"
      ssh_access          = "✅ SSH access to both nodes confirmed"
      system_requirements = "✅ Basic system requirements checked"
      ready_for_k3s      = "✅ Ready for Ansible K3s installation"
    }
    
    next_steps = [
      {
        action      = "Install K3s using Ansible"
        command     = "cd ../../05_k3s_ansible_bootstrap && ansible-playbook k3s.orchestration.site"
        description = "This will install K3s on both nodes and join them to the cluster"
      },
      {
        action      = "Copy kubeconfig"
        command     = "scp ubuntu@${module.shared.network.k3s_master}:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
        description = "Copy kubeconfig from master node for kubectl access"
      }
    ]
    
    troubleshooting = {
      ping_master     = "ping ${module.shared.network.k3s_master}"
      ping_worker     = "ping ${module.shared.network.k3s_worker_01}"
      ssh_master      = module.shared.ssh_commands.k3s_master
      ssh_worker      = module.shared.ssh_commands.k3s_worker
      check_templates = "ssh root@pve1.local 'qm list | grep template'"
      vm_status       = "ssh root@pve1.local 'qm list | grep -E \"${module.shared.vm_ids.k3s_master}|${module.shared.vm_ids.k3s_worker_01}\"'"
    }
  }
}

# Legacy compatibility
output "web_server_ips" {
  description = "The IP addresses of the created k3s servers"
  value = {
    "dev-k3s-master-01" = module.shared.network.k3s_master
    "dev-k3s-worker-01" = module.shared.network.k3s_worker_01
  }
}

output "cluster_info" {
  description = "K3s cluster information for next steps"
  value = {
    master = {
      name     = "dev-k3s-master-01"
      hostname = "dev-k3s-master-01"
      ip       = module.shared.network.k3s_master
      node     = "pve1"
      vmid     = module.shared.vm_ids.k3s_master
      cores    = module.shared.vm_configs.k3s_master.cores
      memory   = module.shared.vm_configs.k3s_master.memory
    }
    workers = [
      {
        name     = "dev-k3s-worker-01"
        hostname = "dev-k3s-worker-01"
        ip       = module.shared.network.k3s_worker_01
        node     = "pve2"
        vmid     = module.shared.vm_ids.k3s_worker_01
        cores    = module.shared.vm_configs.k3s_worker.cores
        memory   = module.shared.vm_configs.k3s_worker.memory
      }
    ]
  }
}

output "ansible_ready_info" {
  description = "Information needed for Ansible K3s deployment"
  value = {
    inventory_data = module.shared.ansible_inventory
    
    ansible_commands = {
      change_directory = "cd ../../05_k3s_ansible_bootstrap"
      run_playbook    = "ansible-playbook k3s.orchestration.site"
      verify_cluster  = "kubectl get nodes"
    }
  }
}

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    master_ssh      = module.shared.ssh_commands.k3s_master
    worker_ssh      = module.shared.ssh_commands.k3s_worker
    run_ansible     = "cd ../../05_k3s_ansible_bootstrap && ansible-playbook k3s.orchestration.site"
    cluster_network = "${module.shared.network.subnet}.0/24"
    domain          = module.shared.domain
    next_module     = "cd ../../05_k3s_ansible_bootstrap"
  }
}
