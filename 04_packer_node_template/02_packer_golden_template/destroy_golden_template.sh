#!/bin/bash
# destroy-golden-templates.sh
# Destroys all golden image templates for clean testing

set -e

# Configuration
SSH_KEY="$HOME/.ssh/proxmox_key"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

GOLDEN_TEMPLATES=(
    "pve1:9000:ubuntu-2404-k3s-template"
    "pve2:9010:ubuntu-2404-k3s-template-pve2"
)

echo "🗑️  Destroying golden image templates for clean testing..."

# Function to safely destroy a template
destroy_template() {
    local node=$1
    local template_id=$2
    local template_name=$3
    
    echo ""
    echo "🔍 Checking template $template_id on $node..."
    
    if ssh $SSH_OPTS root@${node}.local "qm status $template_id" >/dev/null 2>&1; then
        echo "📋 Found template $template_id ($template_name) on $node"
        
        # Check if it's actually a template
        if ssh $SSH_OPTS root@${node}.local "qm config $template_id | grep -q 'template: 1'"; then
            echo "🎯 Confirmed: VM $template_id is a template"
        else
            echo "⚠️  Warning: VM $template_id exists but is not a template"
        fi
        
        echo "🗑️  Destroying template $template_id on $node..."
        ssh $SSH_OPTS root@${node}.local "qm destroy $template_id --purge"
        
        # Verify destruction
        if ! ssh $SSH_OPTS root@${node}.local "qm status $template_id" >/dev/null 2>&1; then
            echo "✅ Template $template_id successfully destroyed on $node"
        else
            echo "❌ Failed to destroy template $template_id on $node"
            return 1
        fi
    else
        echo "ℹ️  Template $template_id not found on $node (already clean)"
    fi
}

# Destroy all templates
for template_info in "${GOLDEN_TEMPLATES[@]}"; do
    IFS=':' read -r node template_id template_name <<< "$template_info"
    destroy_template "$node" "$template_id" "$template_name"
done

echo ""
echo "🧹 Cleaning up any temporary files..."
rm -f /tmp/template_config_*.txt

echo ""
echo "✅ Golden template cleanup complete!"
echo ""
echo "📋 Current template status:"
for template_info in "${GOLDEN_TEMPLATES[@]}"; do
    IFS=':' read -r node template_id template_name <<< "$template_info"
    echo "  $node (ID $template_id): $(ssh $SSH_OPTS root@${node}.local "qm status $template_id 2>/dev/null || echo 'Not found ✅'")"
done

echo ""
echo "🚀 Ready for clean testing! You can now run:"
echo "  1. Packer: cd 02_packer_homelab && packer build ."
echo "  2. Template distribution: cd 02_terraform_template_distribution && terraform apply"
echo "  3. VM deployment: cd 01_create_vm && terraform apply"
