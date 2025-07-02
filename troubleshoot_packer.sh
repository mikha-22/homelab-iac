#!/bin/bash
# Packer Troubleshooting Script
# This script helps diagnose common Packer issues in your homelab setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Packer Integration Troubleshooting ===${NC}\n"

# Configuration
PROXMOX_HOST="pve1.local"
BASE_TEMPLATE_ID="9999"
BASE_TEMPLATE_NAME="ubuntu-2404-cloud-base"
TEST_VM_ID="9998"
SSH_KEY="$HOME/.ssh/id_rsa"
PACKER_DIR="02_packer_homelab"

# Function to print status
print_status() {
    echo -e "${YELLOW}[CHECK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Check Proxmox connectivity
print_status "Testing Proxmox connectivity..."
if ssh -o ConnectTimeout=5 root@$PROXMOX_HOST "echo 'Connected'" >/dev/null 2>&1; then
    print_success "Proxmox SSH connection working"
else
    print_error "Cannot SSH to Proxmox host $PROXMOX_HOST"
    echo "Please ensure:"
    echo "  1. Proxmox host is reachable"
    echo "  2. SSH key is set up for root@$PROXMOX_HOST"
    exit 1
fi

# Step 2: Check base template exists
print_status "Checking if base template exists..."
if ssh root@$PROXMOX_HOST "qm status $BASE_TEMPLATE_ID" >/dev/null 2>&1; then
    print_success "Base template VM $BASE_TEMPLATE_ID exists"
    
    # Check if it's actually a template
    if ssh root@$PROXMOX_HOST "qm config $BASE_TEMPLATE_ID | grep -q 'template: 1'"; then
        print_success "VM is configured as a template"
    else
        print_error "VM $BASE_TEMPLATE_ID exists but is not a template"
        echo "Run: ssh root@$PROXMOX_HOST 'qm template $BASE_TEMPLATE_ID'"
        exit 1
    fi
else
    print_error "Base template VM $BASE_TEMPLATE_ID not found"
    echo "Please ensure the base template was created successfully"
    exit 1
fi

# Step 3: Check SSH key exists
print_status "Checking SSH key..."
if [ -f "$SSH_KEY" ]; then
    print_success "SSH private key found at $SSH_KEY"
    
    # Check if key has passphrase
    if ssh-keygen -y -f "$SSH_KEY" >/dev/null 2>&1; then
        print_success "SSH key can be read without passphrase"
    else
        print_error "SSH key requires passphrase or is invalid"
        echo "If your key has a passphrase, set: export SSH_KEY_PASSPHRASE='your_passphrase'"
    fi
else
    print_error "SSH private key not found at $SSH_KEY"
    echo "Please ensure your SSH key path is correct in packer.auto.pkrvars.hcl"
    exit 1
fi

# Step 4: Test template by cloning and starting
print_status "Testing template by creating a test VM..."

# Clean up any existing test VM
ssh root@$PROXMOX_HOST "qm destroy $TEST_VM_ID --purge" >/dev/null 2>&1 || true

# Clone the template
if ssh root@$PROXMOX_HOST "qm clone $BASE_TEMPLATE_ID $TEST_VM_ID --name test-packer-connectivity"; then
    print_success "Successfully cloned template to test VM $TEST_VM_ID"
else
    print_error "Failed to clone template"
    exit 1
fi

# Start the test VM
print_status "Starting test VM..."
ssh root@$PROXMOX_HOST "qm start $TEST_VM_ID"

# Wait for VM to boot
print_status "Waiting for VM to boot (30 seconds)..."
sleep 30

# Try to get VM IP address
print_status "Getting VM IP address..."
VM_IP=""
for i in {1..10}; do
    VM_IP=$(ssh root@$PROXMOX_HOST "qm guest cmd $TEST_VM_ID network-get-interfaces 2>/dev/null | jq -r '.[]?.\"ip-addresses\"[]?.\"ip-address\"' | grep -E '^192\.' | head -1" || echo "")
    if [ -n "$VM_IP" ]; then
        break
    fi
    echo "Attempt $i: No IP yet, waiting 10 seconds..."
    sleep 10
done

if [ -n "$VM_IP" ]; then
    print_success "VM IP address: $VM_IP"
else
    print_error "Could not get VM IP address"
    echo "VM might not have booted properly or QEMU guest agent not working"
    ssh root@$PROXMOX_HOST "qm destroy $TEST_VM_ID --purge" >/dev/null 2>&1
    exit 1
fi

# Test SSH connectivity
print_status "Testing SSH connectivity to test VM..."
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$VM_IP "echo 'SSH connection successful'" >/dev/null 2>&1; then
    print_success "SSH connection to VM successful"
else
    print_error "Cannot SSH to VM at $VM_IP"
    echo "This suggests an issue with:"
    echo "  1. SSH key configuration in the base template"
    echo "  2. Cloud-init setup"
    echo "  3. Network connectivity"
    
    # Try to show VM console log for debugging
    print_status "Showing VM console output for debugging..."
    ssh root@$PROXMOX_HOST "qm terminal $TEST_VM_ID" || true
fi

# Clean up test VM
print_status "Cleaning up test VM..."
ssh root@$PROXMOX_HOST "qm stop $TEST_VM_ID" >/dev/null 2>&1 || true
sleep 5
ssh root@$PROXMOX_HOST "qm destroy $TEST_VM_ID --purge" >/dev/null 2>&1 || true

# Step 5: Check Packer configuration
print_status "Checking Packer configuration files..."
if [ -d "$PACKER_DIR" ]; then
    print_success "Packer directory exists"
    
    if [ -f "$PACKER_DIR/k3s-template.pkr.hcl" ]; then
        print_success "Packer template file exists"
    else
        print_error "Packer template file not found"
    fi
    
    if [ -f "$PACKER_DIR/secrets.auto.pkrvars.hcl" ]; then
        print_success "Packer secrets file exists"
    else
        print_error "Packer secrets file not found"
    fi
    
    if [ -f "$PACKER_DIR/packer.auto.pkrvars.hcl" ]; then
        print_success "Packer variables file exists"
    else
        print_error "Packer variables file not found"
    fi
else
    print_error "Packer directory $PACKER_DIR not found"
fi

# Step 6: Validate Packer syntax
if command -v packer >/dev/null 2>&1; then
    print_status "Validating Packer configuration..."
    cd "$PACKER_DIR"
    if packer validate k3s-template.pkr.hcl; then
        print_success "Packer configuration is valid"
    else
        print_error "Packer configuration has syntax errors"
    fi
    cd - >/dev/null
else
    print_error "Packer is not installed or not in PATH"
fi

echo -e "\n${GREEN}=== Troubleshooting Complete ===${NC}"
echo -e "\nIf all checks passed, try running Packer with debug mode:"
echo -e "${YELLOW}cd $PACKER_DIR && PACKER_LOG=1 packer build k3s-template.pkr.hcl${NC}\n"
