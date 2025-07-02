      
# Set your Proxmox API Token
set -x TF_VAR_pm_api_token "terraform@pve!terraform-admin=d9d9deb7-852c-4914-9a95-2b195c8aa8fc"

# Set the SSH password for the Proxmox nodes
# This is the password for the 'root' user on pve1.
set -x TF_VAR_pm_ssh_password "ikantuna11"

    
