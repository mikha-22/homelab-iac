# This output makes the static IP address of the NAS server readable
# by other Terraform projects.
output "nas_server_ip" {
  description = "The static IP address of the NFS server VM."
  value       = "192.168.1.70" # We can hardcode this since it's static in the VM
}
