#!/bin/bash
# Scoped Sudo Bridge Installation Script
#
# This script deploys the sudo-bridge to /opt/uncaged with proper permissions
# and auditd rule installation.
#
# Usage: sudo ./install-sudo-bridge.sh
#        or: sudo ~/.openclaw/sudo-bridge/install-sudo-bridge.sh

set -e

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Scoped Sudo Bridge Installation                           ║"
echo "║  Layer 3b: Agent Power Without Root Risk                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "✗ ERROR: This script must be run as root"
    echo "   Usage: sudo $0"
    exit 1
fi

# Determine source directory
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

echo "→ Source directory: $SCRIPT_DIR"
echo ""

# ============================================================================
# Step 1: Create /opt/uncaged directory structure
# ============================================================================

echo "=== STEP 1: Creating /opt/uncaged directory structure ==="

mkdir -p /opt/uncaged/config
mkdir -p /opt/uncaged/docs
mkdir -p /opt/uncaged/systemd

echo "✓ Directory structure created"
echo ""

# ============================================================================
# Step 2: Copy daemon scripts
# ============================================================================

echo "=== STEP 2: Deploying daemon scripts ==="

# Copy wrapper
cp "$SCRIPT_DIR/sudo-bridge.sh" /opt/uncaged/
chmod 755 /opt/uncaged/sudo-bridge.sh
echo "✓ Deployed: /opt/uncaged/sudo-bridge.sh"

# Copy daemon
cp "$SCRIPT_DIR/sudo-bridge-daemon.sh" /opt/uncaged/
chmod 700 /opt/uncaged/sudo-bridge-daemon.sh
chown root:root /opt/uncaged/sudo-bridge-daemon.sh
echo "✓ Deployed: /opt/uncaged/sudo-bridge-daemon.sh"

echo ""

# ============================================================================
# Step 3: Deploy configuration
# ============================================================================

echo "=== STEP 3: Deploying configuration ==="

# Copy whitelist
cp "$SCRIPT_DIR/config/whitelist.json" /opt/uncaged/config/
chmod 644 /opt/uncaged/config/whitelist.json
echo "✓ Deployed: /opt/uncaged/config/whitelist.json"

# Initialize log file
touch /opt/uncaged/config/sudo-bridge.log
chmod 640 /opt/uncaged/config/sudo-bridge.log
chown root:root /opt/uncaged/config/sudo-bridge.log
echo "✓ Initialized: /opt/uncaged/config/sudo-bridge.log"

echo ""

# ============================================================================
# Step 4: Install auditd rules
# ============================================================================

echo "=== STEP 4: Installing auditd rules ==="

if command -v auditctl &>/dev/null; then
    mkdir -p /etc/audit/rules.d

    # Install auditd rules
    cp "$SCRIPT_DIR/config/auditd.rules" /etc/audit/rules.d/sudo-bridge.rules
    chmod 644 /etc/audit/rules.d/sudo-bridge.rules
    echo "✓ Installed: /etc/audit/rules.d/sudo-bridge.rules"

    # Load the new rules
    if augenrules --load 2>/dev/null; then
        echo "✓ Auditd rules loaded successfully"
    else
        echo "⚠ Warning: Could not load auditd rules"
        echo "  Run manually: sudo augenrules --load"
    fi
else
    echo "⚠ auditd not installed, skipping audit rules"
    echo "  Install with: sudo pacman -S audit"
fi

echo ""

# ============================================================================
# Step 5: Install systemd service
# ============================================================================

echo "=== STEP 5: Installing systemd service ==="

# Install service file
mkdir -p /etc/systemd/system
cp "$SCRIPT_DIR/systemd/sudo-bridge.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/sudo-bridge.service
echo "✓ Installed: /etc/systemd/system/sudo-bridge.service"

# Reload systemd
systemctl daemon-reload
echo "✓ Systemd reloaded"

# Enable and start service
if systemctl enable sudo-bridge.service; then
    echo "✓ Service enabled (will start on boot)"
fi

if systemctl start sudo-bridge.service; then
    echo "✓ Service started"
else
    echo "⚠ Warning: Could not start sudo-bridge service"
    echo "  Check status with: sudo systemctl status sudo-bridge.service"
fi

echo ""

# ============================================================================
# Step 6: Create wrapper symlink for easy access
# ============================================================================

echo "=== STEP 6: Creating convenient access method ==="

# Create a simple wrapper that agent can call
cat > /usr/local/bin/uncaged-sudo << 'EOF'
#!/bin/bash
# Convenience wrapper for Scoped Sudo Bridge
exec /opt/uncaged/sudo-bridge.sh "$@"
EOF

chmod 755 /usr/local/bin/uncaged-sudo
echo "✓ Created: /usr/local/bin/uncaged-sudo"
echo "   Usage: uncaged-sudo systemctl restart nginx"

echo ""

# ============================================================================
# Step 7: Verify installation
# ============================================================================

echo "=== STEP 7: Verifying installation ==="

checks_passed=0
checks_total=0

# Check daemon script
checks_total=$((checks_total + 1))
if [ -x /opt/uncaged/sudo-bridge-daemon.sh ]; then
    echo "✓ Daemon script is executable"
    checks_passed=$((checks_passed + 1))
else
    echo "✗ Daemon script is not executable"
fi

# Check whitelist
checks_total=$((checks_total + 1))
if [ -f /opt/uncaged/config/whitelist.json ] && command -v jq &>/dev/null; then
    if jq . /opt/uncaged/config/whitelist.json >/dev/null 2>&1; then
        echo "✓ Whitelist is valid JSON"
        checks_passed=$((checks_passed + 1))
    else
        echo "✗ Whitelist is invalid JSON"
    fi
else
    echo "⚠ Warning: jq not installed (needed for validation)"
fi

# Check auditd rules
checks_total=$((checks_total + 1))
if [ -f /etc/audit/rules.d/sudo-bridge.rules ]; then
    echo "✓ Auditd rules installed"
    checks_passed=$((checks_passed + 1))
else
    echo "⚠ Auditd rules not installed"
fi

# Check systemd service
checks_total=$((checks_total + 1))
if [ -f /etc/systemd/system/sudo-bridge.service ]; then
    echo "✓ Systemd service installed"
    checks_passed=$((checks_passed + 1))
else
    echo "✗ Systemd service not installed"
fi

echo ""

# ============================================================================
# Final Summary
# ============================================================================

echo "╔════════════════════════════════════════════════════════════╗"
if [ "$checks_passed" -eq "$checks_total" ]; then
    echo "║  ✓ INSTALLATION COMPLETE ($checks_passed/$checks_total checks)         ║"
else
    echo "║  ⚠ INSTALLATION PARTIAL ($checks_passed/$checks_total checks)          ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "Scoped Sudo Bridge installed successfully!"
echo ""
echo "NEXT STEPS:"
echo "1. Verify it works:"
echo "   $ uncaged-sudo systemctl status auditd"
echo ""
echo "2. Update whitelist if needed:"
echo "   $ sudo nano /opt/uncaged/config/whitelist.json"
echo ""
echo "3. Monitor operations:"
echo "   $ sudo tail -f /opt/uncaged/config/sudo-bridge.log"
echo ""
echo "4. Check auditd logs:"
echo "   $ sudo ausearch -k sudo-bridge -i"
echo ""
echo "Documentation: See docs/sudo-bridge.md for detailed guide"
echo ""
