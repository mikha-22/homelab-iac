# ===================================================================
#  CENTRALIZED INFRASTRUCTURE CONFIGURATION
#  Single source of truth for all hardcoded values
# ===================================================================

locals {
  # Proxmox cluster configuration
  proxmox = {
    # Node configuration
    nodes = {
      primary   = "pve1"
      secondary = "pve2"
    }
    
    # Endpoints
    endpoints = {
      pve1 = "https://pve1.local:8006"
      pve2 = "https://pve2.local:8006"
    }
    
    # Template VM IDs
    template_ids = {
      base_template   = 9999  # Base Ubuntu cloud image template
      master_template = 9000  # K3s master template (on pve1)
      worker_template = 9010  # K3s worker template (on pve2)
    }
    
    # Storage configuration
    storage = {
      local_lvm      = "local-lvm"      # Local LVM storage
      shared_nfs     = "cluster-shared-nfs"  # Shared NFS storage
      iso_storage    = "local"          # ISO/image storage
      template_store = "cluster-shared-nfs"   # Template storage
    }
    
    # Network configuration
    network = {
      bridge = "vmbr0"  # Default network bridge
    }
    
    # Default VM settings
    defaults = {
      agent_enabled = true
      boot_order   = ["scsi0"]
      scsi_hardware = "virtio-scsi-pci"
      network_model = "virtio"
    }
  }
  
  # Kubernetes cluster configuration
  kubernetes = {
    # Cluster settings
    cluster = {
      name    = "homelab-k3s"
      version = "v1.29.5+k3s1"
    }
    
    # Network CIDRs
    networking = {
      cluster_cidr = "10.42.0.0/16"  # Pod network
      service_cidr = "10.43.0.0/16"  # Service network
      cluster_dns  = "10.43.0.10"    # CoreDNS
    }
    
    # Node configurations
    nodes = {
      master = {
        hostname = "dev-k3s-master-01"
        role     = "server"
        node     = "pve1"
      }
      worker_01 = {
        hostname = "dev-k3s-worker-01"
        role     = "agent"
        node     = "pve2"
      }
    }
    
    # Kubeconfig
    config = {
      path    = "~/.kube/config"
      context = "default"
    }
  }
  
  # Application configuration
  applications = {
    # ArgoCD
    argocd = {
      namespace    = "argocd"
      chart_version = "7.7.8"
      insecure_mode = true  # Required for Cloudflare tunnel
      redis_ha      = false # Disabled for homelab
    }
    
    # External Secrets Operator
    external_secrets = {
      namespace     = "external-secrets"
      chart_version = "0.15.1"
      store_name    = "gcp-secret-manager"
    }
    
    # Cloudflare Tunnel
    cloudflare_tunnel = {
      name           = "homelab-k3s-tunnel"
      replicas       = 2
      traefik_service = "traefik"
      traefik_namespace = "kube-system"
    }
    
    # External DNS
    external_dns = {
      namespace     = "external-dns"
      chart_version = "1.14.3"
      provider      = "cloudflare"
    }
  }
  
  # File and template locations
  file_locations = {
    # Cloud-init templates
    cloud_init = {
      base_template = "base-template-init.yaml"
      master_init   = "master-init.yaml"
      worker_init   = "worker-init.yaml"
      nas_init      = "nas-cloud-init.yaml"
    }
    
    # Helm values
    helm_values = {
      argocd = "values/argocd-values.yaml"
    }
  }
  
  # Timeouts and retries
  operations = {
    timeouts = {
      vm_boot        = 120  # seconds
      template_clone = 300  # seconds
      helm_install   = 900  # seconds
      ssh_retry      = 60   # seconds
    }
    
    retries = {
      ssh_attempts     = 3
      api_calls        = 3
      health_checks    = 12
      template_ready   = 12
    }
    
    intervals = {
      retry_delay    = 5   # seconds
      health_check   = 10  # seconds
      poll_interval  = 5   # seconds
    }
  }
  
  # Resource naming conventions
  naming = {
    # VM naming
    vms = {
      nas_server = "nfs-server-01"
      k3s_master = "dev-k3s-master-01"
      k3s_worker = "dev-k3s-worker-01"
    }
    
    # Template naming
    templates = {
      base   = "ubuntu-2404-cloud-base"
      master = "ubuntu-2404-cloud-base-pve1"
      worker = "ubuntu-2404-cloud-base-pve2"
    }
    
    # Storage naming
    storage = {
      nfs_export = "/export/proxmox-storage"
    }
  }
  
  # Standard descriptions
  descriptions = {
    vms = {
      nas_server = "NFS server for Proxmox cluster shared storage"
      k3s_master = "K3s master node for homelab cluster"
      k3s_worker = "K3s worker node for homelab cluster"
    }
    
    templates = {
      base = "Base cloud-image template for VM deployment - no Packer needed!"
    }
  }
}

# ===================================================================
#  COMPUTED VALUES BASED ON CONFIGURATION
# ===================================================================

# Merge infrastructure config with existing shared config
locals {
  # Enhanced VM configurations with centralized values
  enhanced_vm_configs = {
    for role, config in local.vm_configs : role => merge(config, {
      # Add standard settings
      agent = { enabled = local.proxmox.defaults.agent_enabled }
      boot_order = local.proxmox.defaults.boot_order
      scsi_hardware = local.proxmox.defaults.scsi_hardware
      network_device = {
        bridge = local.proxmox.network.bridge
        model  = local.proxmox.defaults.network_model
      }
    })
  }
  
  # Enhanced VM IDs with infrastructure config
  enhanced_vm_ids = merge(local.vm_ids, {
    # Template IDs from infrastructure config
    base_template   = local.proxmox.template_ids.base_template
    master_template = local.proxmox.template_ids.master_template
    worker_template = local.proxmox.template_ids.worker_template
  })
  
  # Storage configuration
  storage_config = local.proxmox.storage
  
  # Application configurations
  app_configs = local.applications
  
  # Operational settings
  timeouts = local.operations.timeouts
  retries = local.operations.retries
  intervals = local.operations.intervals
}
