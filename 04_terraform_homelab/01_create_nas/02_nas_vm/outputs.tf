# ===================================================================
#  PROJECT: NAS VIRTUAL MACHINE OUTPUTS
#  Outputs information about the provisioned VM.
# ===================================================================

output "nas_server_ip" {
  description = "The static IP address of the NFS server VM."
  value       = "192.168.1.70" # We can hardcode this since it's static in the VM config
}
