#!/bin/bash
# Safe Unshackled Agent — Automated Installation
# This script sets up all 8 layers of the resilience stack
#
# Usage: sudo ./scripts/install.sh
# or:    ./scripts/install.sh (will prompt for sudo when needed)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
USER="${SUDO_USER:-$USER}"
USER_HOME="$(eval echo ~$USER)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}→${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script requires Linux"
        exit 1
    fi

    # Check if Btrfs
    if ! mount | grep -q "btrfs"; then
        log_warning "Btrfs not detected. Snapshots will be skipped."
        SKIP_BTRFS=1
    fi

    # Check if auditd installed
    if ! command -v auditctl &>/dev/null; then
        log_warning "auditd not installed. Run: sudo pacman -S audit (Arch) or apt install auditd (Debian)"
    fi

    # Check if inotify-tools installed
    if ! command -v inotifywait &>/dev/null; then
        log_warning "inotify-tools not installed. Run: sudo pacman -S inotify-tools (Arch) or apt install inotify-tools (Debian)"
    fi

    log_success "Prerequisites check complete"
    echo ""
}

# Phase 1: Btrfs Snapshots + Git
phase1_recovery() {
    log_info "PHASE 1: Recovery (Btrfs Snapshots + Git)"

    if [[ ! "$SKIP_BTRFS" ]]; then
        log_info "  Creating Btrfs snapshot directories..."
        sudo btrfs subvolume create /.snapshots 2>/dev/null || log_warning "  /.snapshots may already exist"
        sudo btrfs subvolume create /home/.snapshots 2>/dev/null || log_warning "  /home/.snapshots may already exist"
        sudo chown "$USER:$USER" /home/.snapshots
        log_success "  Btrfs snapshots ready"
    fi

    log_info "  Initializing Git repo for agent config..."
    if [ ! -d "$USER_HOME/.openclaw/.git" ]; then
        cd "$USER_HOME/.openclaw" 2>/dev/null || log_warning "  ~/.openclaw not found yet"
        git init --quiet
        cat > "$USER_HOME/.openclaw/.gitignore" << 'EOF'
agents/*/sessions/
agents/*/agent/*.jsonl
*.log
credentials/
.env
EOF
        git add .gitignore 2>/dev/null || true
        git commit -m "chore: initialize repo with gitignore" --quiet 2>/dev/null || true
        log_success "  Git repo initialized"
    else
        log_warning "  Git repo already exists"
    fi

    echo ""
}

# Phase 2: Immutable Files
phase2_immutability() {
    log_info "PHASE 2: Immutability (chattr +i)"

    log_info "  Locking SSH keys..."
    sudo chattr +i "$USER_HOME/.ssh/authorized_keys" 2>/dev/null || log_warning "    authorized_keys not found"
    sudo chattr +i "$USER_HOME/.ssh/id_ed25519" 2>/dev/null || log_warning "    id_ed25519 not found"
    sudo chattr +i "$USER_HOME/.ssh/id_rsa" 2>/dev/null || log_warning "    id_rsa not found"
    log_success "  SSH keys locked"

    log_info "  Locking boot configuration..."
    sudo chattr +i /boot/loader/loader.conf 2>/dev/null || log_warning "    loader.conf not found"
    sudo chattr +i /boot/loader/entries/*.conf 2>/dev/null || log_warning "    boot entries not found"
    log_success "  Boot config locked"

    log_info "  Locking system authentication..."
    sudo chattr +i /etc/fstab 2>/dev/null || log_warning "    fstab not found"
    sudo chattr +i /etc/sudoers 2>/dev/null || log_warning "    sudoers not found"
    sudo chattr +i /etc/sudoers.d/* 2>/dev/null || log_warning "    sudoers.d not found"
    log_success "  System auth locked"

    log_info "  Locking agent credentials..."
    sudo chattr +i "$USER_HOME/.openclaw/.env" 2>/dev/null || log_warning "    .env not found"
    sudo chattr +i "$USER_HOME/.openclaw/agents/main/agent/auth-profiles.json" 2>/dev/null || log_warning "    auth-profiles.json not found"
    log_success "  Agent credentials locked"

    echo ""
}

# Phase 3: Resource Limits
phase3_limits() {
    log_info "PHASE 3: Resource Limits (Circuit Breakers)"

    log_info "  Applying systemd resource limits..."
    mkdir -p "$USER_HOME/.config/systemd/user/openclaw.service.d"

    cat > "$USER_HOME/.config/systemd/user/openclaw.service.d/limits.conf" << 'EOF'
[Service]
CPUQuota=80%
MemoryMax=6G
MemoryHigh=5G
LimitNOFILE=8192
LimitNPROC=4096
Restart=on-failure
RestartSec=10
StartLimitBurst=5
StartLimitInterval=60
EOF

    systemctl --user --quiet daemon-reload 2>/dev/null || log_warning "  Could not reload systemd (not in user session)"

    log_success "  Resource limits configured"
    echo ""
}

# Phase 4: Auditd
phase4_auditd() {
    log_info "PHASE 4: Observability (Auditd Kernel Monitoring)"

    if ! command -v auditctl &>/dev/null; then
        log_warning "  auditd not installed, skipping"
        echo ""
        return
    fi

    log_info "  Creating audit rules..."
    sudo mkdir -p /etc/audit/rules.d

    cat | sudo tee /etc/audit/rules.d/openclaw.rules > /dev/null << 'EOF'
-w /etc/passwd -p wa -k agent-etc
-w /etc/shadow -p wa -k agent-etc
-w /etc/sudoers -p wa -k agent-etc
-w /home -p rwa -k agent-home
-w /usr/bin/pacman -p x -k agent-pacman
-w /usr/bin/yay -p x -k agent-pacman
-w /usr/bin/npm -p x -k agent-npm
-w /usr/bin/pip -p x -k agent-pip
EOF

    sudo augenrules --load 2>/dev/null || log_warning "  Could not load auditd rules"
    sudo systemctl --quiet enable auditd 2>/dev/null || true
    sudo systemctl --quiet start auditd 2>/dev/null || true

    log_success "  Auditd rules loaded"
    echo ""
}

# Phase 5: Watchdog
phase5_watchdog() {
    log_info "PHASE 5: Circuit Breaker (Behavioral Watchdog)"

    log_info "  Installing watchdog service..."
    mkdir -p "$USER_HOME/.config/systemd/user"
    mkdir -p "$USER_HOME/.mcp-memory"

    cat > "$USER_HOME/.config/systemd/user/openclaw-watchdog.service" << 'EOF'
[Unit]
Description=Safe Unshackled Agent Behavioral Watchdog
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/openclaw-watchdog.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user --quiet daemon-reload 2>/dev/null || true

    log_success "  Watchdog service installed"
    echo ""
}

# Phase 6: Canary Trap
phase6_canary() {
    log_info "PHASE 6: Intrusion Detection (Canary Trap)"

    if ! command -v inotifywait &>/dev/null; then
        log_warning "  inotify-tools not installed, skipping"
        echo ""
        return
    fi

    log_info "  Creating honeypot files..."
    mkdir -p "$USER_HOME/.secrets-canary"
    chmod 700 "$USER_HOME/.secrets-canary"

    cat > "$USER_HOME/.secrets-canary/.env" << 'EOF'
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE999
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

    cat > "$USER_HOME/.secrets-canary/passwords.txt" << 'EOF'
root_password: hunter2-canary-trap-do-not-use
database_password: admin123-fake-canary
api_token: sk-fake-canary-trap-AbCdEf123456
EOF

    chmod 600 "$USER_HOME/.secrets-canary"/*

    cat > "$USER_HOME/.config/systemd/user/canary-monitor.service" << 'EOF'
[Unit]
Description=Safe Unshackled Agent Honeypot Monitor
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/canary-monitor.sh
Restart=on-failure

[Install]
WantedBy=default.target
EOF

    systemctl --user --quiet daemon-reload 2>/dev/null || true

    log_success "  Canary trap deployed"
    echo ""
}

# Phase 7: Nftables (Network Jail)
phase7_network() {
    log_info "PHASE 7: Network Isolation (Nftables)"

    if ! command -v nft &>/dev/null; then
        log_warning "  nftables not installed, skipping"
        echo ""
        return
    fi

    log_info "  Configuring network rules..."
    sudo mkdir -p /etc/nftables.d

    cat | sudo tee /etc/nftables.d/agent-network-jail.nft > /dev/null << 'EOF'
# Block private networks and AWS metadata service
table inet agent_jail {
  chain output {
    type filter hook output priority mangle

    # Block private networks (RFC 1918)
    ip daddr 10.0.0.0/8 drop comment "block private"
    ip daddr 172.16.0.0/12 drop comment "block private"
    ip daddr 192.168.0.0/16 drop comment "block private"

    # Block AWS metadata service
    ip daddr 169.254.169.254 drop comment "block AWS metadata"

    # Block link-local
    ip daddr 169.254.0.0/16 drop comment "block link-local"
  }
}
EOF

    # Add include if not already present
    if ! grep -q "agent-network-jail.nft" /etc/nftables.conf; then
        sudo sed -i '/^table inet filter/i include "/etc/nftables.d/agent-network-jail.nft"' /etc/nftables.conf
    fi

    sudo systemctl --quiet enable nftables 2>/dev/null || true
    sudo systemctl --quiet restart nftables 2>/dev/null || log_warning "  Could not restart nftables"

    log_success "  Network isolation configured"
    echo ""
}

# Main installation flow
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  SAFE UNSHACKLED AGENT — 8-Layer Resilience Stack          ║"
    echo "║  Installation Script                                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    check_prerequisites
    phase1_recovery
    phase2_immutability
    phase3_limits
    phase4_auditd
    phase5_watchdog
    phase6_canary
    phase7_network

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  ✓ INSTALLATION COMPLETE                                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "8 LAYERS CONFIGURED:"
    echo "  1. ✓ Recovery (Btrfs snapshots + Git)"
    echo "  2. ✓ Immutability (chattr +i)"
    echo "  3. ✓ Resource Limits (CPU/Memory/FDs)"
    echo "  4. ✓ Auditd Monitoring (kernel-level)"
    echo "  5. ✓ Watchdog (behavioral monitoring)"
    echo "  6. ✓ Canary Trap (honeypot detection)"
    echo "  7. ✓ Network Jail (nftables filtering)"
    echo ""
    echo "NEXT STEPS:"
    echo "  • Copy scripts from ./scripts/ to ~/.local/bin/"
    echo "  • systemctl --user daemon-reload"
    echo "  • systemctl --user start openclaw-watchdog.service"
    echo "  • systemctl --user start canary-monitor.service"
    echo ""
    echo "Docs: See ./docs/ for detailed guides"
    echo ""
}

main "$@"
