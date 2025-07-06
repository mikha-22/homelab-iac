
# Set your Proxmox API Token
set -x TF_VAR_pm_api_token "terraform@pve!admin=15b3b928-488e-4a60-b471-ccb971aa8bc7"

# Set the SSH password for the Proxmox nodes
# This is the password for the 'root' user on pve1.
set -x TF_VAR_pm_ssh_password ikantuna11
