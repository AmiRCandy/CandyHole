
#!/bin/bash

# CandyHole - Paqet Tunnel Setup Script

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}=====================================${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${CYAN}=====================================${NC}"
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    # Trim whitespace
    ip=$(echo "$ip" | xargs)
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Function to validate port
validate_port() {
    local port=$1
    # Trim whitespace
    port=$(echo "$port" | xargs)
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    fi
    return 1
}

# Function to show progress
show_progress() {
    echo -e "${BLUE}[PROGRESS]${NC} $1..."
}

# Function to uninstall Paqet
uninstall_paqet() {
    echo ""
    print_header "Uninstalling Paqet"

    # Stop and disable service
    show_progress "Stopping Paqet service"
    systemctl stop paqet 2>/dev/null
    systemctl disable paqet 2>/dev/null

    # Remove systemd service file
    if [ -f "/etc/systemd/system/paqet.service" ]; then
        show_progress "Removing systemd service"
        rm -f /etc/systemd/system/paqet.service
        systemctl daemon-reload
        print_success "Systemd service removed"
    fi

    # Remove configuration files
    if [ -d "/etc/paqet" ]; then
        show_progress "Removing configuration files"
        rm -rf /etc/paqet
        print_success "Configuration files removed"
    fi

    # Remove Paqet binary
    if [ -f "/usr/local/bin/paqet" ]; then
        show_progress "Removing Paqet binary"
        rm -f /usr/local/bin/paqet
        print_success "Paqet binary removed"
    fi

    # Remove iptables rules (if netfilter-persistent is available)
    show_progress "Removing firewall rules"
    # Try to remove the rules we added
    iptables -t raw -D PREROUTING -p tcp --dport 8080 -j NOTRACK 2>/dev/null || true
    iptables -t raw -D OUTPUT -p tcp --sport 8080 -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D OUTPUT -p tcp --sport 8080 --tcp-flags RST RST -j DROP 2>/dev/null || true

    # Save iptables rules if netfilter-persistent is available
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save 2>/dev/null || true
    fi

    # Remove UFW rules
    if command -v ufw >/dev/null 2>&1; then
        ufw delete allow 8080 2>/dev/null || true
    fi

    print_success "Firewall rules cleaned up"

    # Remove libpcap symlink if it exists
    if [ -L "/usr/lib/x86_64-linux-gnu/libpcap.so.0.8" ]; then
        show_progress "Removing libpcap symlink"
        rm -f /usr/lib/x86_64-linux-gnu/libpcap.so.0.8
        ldconfig
        print_success "Libpcap symlink removed"
    fi

    # Ask about removing packages
    echo ""
    echo -e "${YELLOW}Note: The following packages were installed by this script:${NC}"
    echo "  - curl, wget, git, nano, vim, htop, net-tools, unzip, zip"
    echo "  - software-properties-common, libpcap-dev, iptables-persistent"
    echo ""
    read -p "Do you want to remove these packages as well? (y/n): " remove_packages

    if [[ $remove_packages =~ ^[Yy]$ ]]; then
        show_progress "Removing installed packages"
        apt remove -y curl wget git nano vim htop net-tools unzip zip software-properties-common libpcap-dev iptables-persistent 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
        print_success "Packages removed"
    else
        print_info "Keeping packages installed"
    fi

    echo ""
    print_header "Uninstallation Complete!"
    print_success "Paqet has been completely removed from your system"
    echo ""
    echo -e "${BLUE}What was removed:${NC}"
    echo -e "  ✅ Paqet binary (/usr/local/bin/paqet)"
    echo -e "  ✅ Configuration files (/etc/paqet/)"
    echo -e "  ✅ Systemd service (paqet.service)"
    echo -e "  ✅ Firewall rules"
    echo -e "  ✅ Libpcap symlink"
    if [[ $remove_packages =~ ^[Yy]$ ]]; then
        echo -e "  ✅ System packages"
    fi
}

# Main script header
clear
print_header "🍬 CandyHole - Paqet Tunnel Setup 🍬"
echo -e "${WHITE}Setting up Paqet tunnel between Iran and foreign servers${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (sudo ./CandyHole.sh)"
    exit 1
fi

# Update system
print_info "Updating system packages..."
apt update && apt upgrade -y
if [ $? -ne 0 ]; then
    print_error "Failed to update system packages"
    exit 1
fi
print_success "System updated successfully"

# Get setup type from user
echo ""
print_header "Configuration Setup"
while true; do
    echo -e "${WHITE}What would you like to do?${NC}"
    echo "1) Server (Foreign server outside Iran)"
    echo "2) Client (Iran server)"
    echo "3) Uninstall Paqet"
    read -p "Enter your choice (1-3): " setup_choice

    case $setup_choice in
        1)
            client_or_server="s"
            print_success "Setting up as Server"
            break
            ;;
        2)
            client_or_server="c"
            print_success "Setting up as Client"
            break
            ;;
        3)
            print_success "Uninstalling Paqet"
            uninstall_paqet
            exit 0
            ;;
        "")
            print_error "Choice cannot be empty. Please enter 1, 2, or 3."
            ;;
        *)
            print_error "Invalid choice '$setup_choice'. Please enter 1, 2, or 3."
            ;;
    esac
done

# Get configuration based on setup type
if [ "$client_or_server" == "c" ]; then
    # Client setup
    echo ""
    print_header "Client Configuration"
    while true; do
        read -p "Enter the foreign server IP address: " server_ip
        if validate_ip "$server_ip"; then
            break
        else
            print_error "Invalid IP address format '$server_ip'. Please enter a valid IP address (e.g., 192.168.1.1)."
        fi
    done

    while true; do
        read -p "Enter the server port (default: 8080): " server_port_input
        server_port=${server_port_input:-8080}
        if validate_port "$server_port"; then
            break
        else
            print_error "Invalid port number '$server_port'. Please enter a number between 1-65535."
        fi
    done

    while true; do
        read -p "Enter the server secret key: " server_secret_key
        if [ -n "$server_secret_key" ]; then
            break
        else
            print_error "Secret key cannot be empty."
        fi
    done

elif [ "$client_or_server" == "s" ]; then
    # Server setup
    echo ""
    print_header "Server Configuration"
    while true; do
        read -p "Enter your server port (default: 8080): " server_port_input
        server_port=${server_port_input:-8080}
        if validate_port "$server_port"; then
            break
        else
            print_error "Invalid port number '$server_port'. Please enter a number between 1-65535."
        fi
    done
fi
# Install necessary packages
show_progress "Installing required system packages"
apt install -y curl wget git nano vim htop net-tools unzip zip software-properties-common libpcap-dev iptables-persistent
if [ $? -ne 0 ]; then
    print_error "Failed to install system packages"
    exit 1
fi
print_success "System packages installed successfully"

# Install Paqet
echo ""
show_progress "Downloading and installing Paqet"
wget -q https://github.com/hanselime/paqet/releases/download/v1.0.0-alpha.13/paqet-linux-amd64-v1.0.0-alpha.13.tar.gz
if [ $? -ne 0 ]; then
    print_error "Failed to download Paqet"
    exit 1
fi

tar -xzf paqet-linux-amd64-v1.0.0-alpha.13.tar.gz
if [ $? -ne 0 ]; then
    print_error "Failed to extract Paqet archive"
    exit 1
fi

mv paqet_linux_amd64 /usr/local/bin/paqet
chmod +x /usr/local/bin/paqet

# Fix libpcap library link
ln -sf /usr/lib/x86_64-linux-gnu/libpcap.so /usr/lib/x86_64-linux-gnu/libpcap.so.0.8
ldconfig

# Test Paqet installation
print_info "Testing Paqet installation..."
paqet --help > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "Paqet installation successful"
else
    print_error "Paqet installation failed"
    exit 1
fi

# Generate secret key for server
if [ "$client_or_server" == "s" ]; then
    echo ""
    show_progress "Generating server secret key"
    secret_key=$(paqet secret 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$secret_key" ]; then
        print_success "Secret key generated: $secret_key"
        print_warning "Please save this secret key! You'll need it for client configuration."
    else
        print_error "Failed to generate secret key"
        exit 1
    fi
fi

# Create configuration directory
mkdir -p /etc/paqet

# Get network information
echo ""
print_header "Network Configuration"
show_progress "Detecting network interface and gateway information"

# Get gateway and interface name
default_route=$(ip route | grep default)
if [ -z "$default_route" ]; then
    print_error "No default route found. Check your network configuration."
    exit 1
fi

iface_name=$(echo "$default_route" | awk '{print $5}')
gateway=$(echo "$default_route" | awk '{print $3}')
this_server_ip=$(ip route get "$gateway" | grep -oP 'src \K\S+' | head -1)

# Fallback method if the above didn't work
if [ -z "$this_server_ip" ] || [ "$this_server_ip" = "0" ]; then
    this_server_ip=$(ip addr show "$iface_name" | grep -oP 'inet \K[\d.]+' | head -1)
fi

# Another fallback using hostname
if [ -z "$this_server_ip" ] || [ "$this_server_ip" = "0" ]; then
    this_server_ip=$(hostname -I | awk '{print $1}')
fi

print_info "Interface: $iface_name"
print_info "Gateway: $gateway"
print_info "Local IP: $this_server_ip"

# Confirm detected local IP address
echo ""
print_header "IP Address Confirmation"
while true; do
    read -p "Is this local IP address correct ($this_server_ip)? (y/n): " confirm_ip
    case $confirm_ip in
        [Yy]|[Yy][Ee][Ss])
            print_success "Using detected IP address: $this_server_ip"
            break
            ;;
        [Nn]|[Nn][Oo])
            while true; do
                read -p "Enter the correct local IP address: " user_ip
                if validate_ip "$user_ip"; then
                    this_server_ip="$user_ip"
                    print_success "Using custom IP address: $this_server_ip"
                    break
                else
                    print_error "Invalid IP address format '$user_ip'. Please enter a valid IP address."
                fi
            done
            break
            ;;
        *)
            print_error "Please answer 'y' for yes or 'n' for no."
            ;;
    esac
done

# Test gateway connectivity
print_info "Testing gateway connectivity..."
ping -c 3 -W 2 "$gateway" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "Gateway is reachable"
else
    print_warning "Gateway ping failed, but continuing... (may be normal for some networks)"
fi

# Get MAC address of gateway
# First try to populate ARP table by pinging
ping -c 1 -W 1 "$gateway" > /dev/null 2>&1

# Try to get MAC from ARP table
mac_address=$(arp -n "$gateway" 2>/dev/null | grep -v '^Address' | awk '{print $3}' | grep -E '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$' | head -1)

# Fallback: try to get from ip neigh command (more modern)
if [ -z "$mac_address" ]; then
    mac_address=$(ip neigh show "$gateway" 2>/dev/null | awk '{print $5}' | head -1)
fi

if [ -z "$mac_address" ] || [ "$mac_address" == "(incomplete)" ]; then
    print_warning "Could not get gateway MAC address. Using default (this may affect performance)."
    mac_address="00:00:00:00:00:00"
else
    print_info "Gateway MAC: $mac_address"
fi

# Generate YAML configuration
echo ""
show_progress "Generating Paqet configuration file"

if [ "$client_or_server" == "c" ]; then
    # Generate client configuration
    cat > /etc/paqet/client.yaml << EOF
role: "client"
log:
  level: "info"
socks5:
  - listen: "127.0.0.1:1404"
    username: "candyhole"
    password: "candyhole"
network:
  interface: "$iface_name"
  ipv4:
    addr: "$this_server_ip:0"
    router_mac: "$mac_address"
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]
server:
  addr: "$server_ip:$server_port"
transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "$server_secret_key"
EOF

    if [ $? -eq 0 ]; then
        print_success "Client configuration generated successfully"
        print_info "Configuration saved to: /etc/paqet/client.yaml"
    else
        print_error "Failed to generate client configuration"
        exit 1
    fi

elif [ "$client_or_server" == "s" ]; then
    # Generate server configuration
    cat > /etc/paqet/server.yaml << EOF
role: "server"
log:
  level: "info"
listen:
  addr: "0.0.0.0:$server_port"
network:
  interface: "$iface_name"
  ipv4:
    addr: "$this_server_ip:$server_port"
    router_mac: "$mac_address"
  ipv6:
    addr: "[::1]:$server_port"
    router_mac: "$mac_address"
  tcp:
    local_flag: ["PA"]
transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "$secret_key"
EOF

    if [ $? -eq 0 ]; then
        print_success "Server configuration generated successfully"
        print_info "Configuration saved to: /etc/paqet/server.yaml"
    else
        print_error "Failed to generate server configuration"
        exit 1
    fi
fi

# Show configuration to user
echo ""
print_header "Generated Configuration"
if [ "$client_or_server" == "c" ]; then
    echo -e "${CYAN}Client Configuration:${NC}"
    cat /etc/paqet/client.yaml
else
    echo -e "${CYAN}Server Configuration:${NC}"
    cat /etc/paqet/server.yaml
fi

echo ""
read -p "Do you want to edit the configuration file? (y/n): " edit_config
if [[ $edit_config =~ ^[Yy]$ ]]; then
    if [ "$client_or_server" == "c" ]; then
        nano /etc/paqet/client.yaml
    else
        nano /etc/paqet/server.yaml
    fi
fi

# Firewall setup
echo ""
print_header "Firewall Configuration"
show_progress "Configuring iptables rules"

# Configure iptables for both client and server
iptables -t raw -A PREROUTING -p tcp --dport "$server_port" -j NOTRACK
iptables -t raw -A OUTPUT -p tcp --sport "$server_port" -j NOTRACK
iptables -t mangle -A OUTPUT -p tcp --sport "$server_port" --tcp-flags RST RST -j DROP

# Save iptables rules
netfilter-persistent save
if [ $? -eq 0 ]; then
    print_success "Iptables rules configured and saved"
else
    print_warning "Failed to save iptables rules permanently"
fi

# Configure UFW
print_info "Configuring UFW firewall..."
ufw --force enable > /dev/null 2>&1
ufw allow "$server_port" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "UFW configured to allow port $server_port"
else
    print_warning "UFW configuration may have failed"
fi

# Create systemd service
echo ""
print_header "System Service Setup"
show_progress "Creating Paqet systemd service"

# Determine config file path
if [ "$client_or_server" == "c" ]; then
    config_file="/etc/paqet/client.yaml"
    service_desc="Paqet Client"
else
    config_file="/etc/paqet/server.yaml"
    service_desc="Paqet Server"
fi

# Create service file
cat > /etc/systemd/system/paqet.service << EOF
[Unit]
Description=$service_desc
After=network.target

[Service]
ExecStart=/usr/local/bin/paqet run -c $config_file
Restart=always
User=root
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [ $? -eq 0 ]; then
    print_success "Systemd service file created"
else
    print_error "Failed to create systemd service file"
    exit 1
fi

# Start the service
show_progress "Starting Paqet service"
systemctl daemon-reload

systemctl enable paqet
if [ $? -eq 0 ]; then
    print_success "Paqet service enabled to start on boot"
else
    print_warning "Failed to enable Paqet service"
fi

systemctl start paqet
if [ $? -eq 0 ]; then
    print_success "Paqet service started successfully"
else
    print_error "Failed to start Paqet service"
    exit 1
fi

# Check service status
echo ""
print_header "Service Status"
systemctl status paqet --no-pager -l

# Final information
echo ""
print_header "Setup Complete! 🎉"
if [ "$client_or_server" == "s" ]; then
    echo -e "${GREEN}Server setup completed successfully!${NC}"
    echo -e "${YELLOW}Important:${NC}"
    echo -e "  - Server IP: ${WHITE}$this_server_ip${NC}"
    echo -e "  - Server Port: ${WHITE}$server_port${NC}"
    echo -e "  - Secret Key: ${WHITE}$secret_key${NC}"
    echo ""
    echo -e "${CYAN}Share these details with your client setup:${NC}"
    echo -e "  Server IP: $this_server_ip"
    echo -e "  Server Port: $server_port"
    echo -e "  Secret Key: $secret_key"
else
    echo -e "${GREEN}Client setup completed successfully!${NC}"
    echo -e "${CYAN}SOCKS5 proxy is now available at:${NC}"
    echo -e "  ${WHITE}127.0.0.1:1404${NC}"
    echo -e "  Username: candyhole"
    echo -e "  Password: candyhole"
fi

echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  Check status: ${WHITE}sudo systemctl status paqet${NC}"
echo -e "  View logs: ${WHITE}sudo journalctl -u paqet -f${NC}"
echo -e "  Restart service: ${WHITE}sudo systemctl restart paqet${NC}"
echo ""
echo -e "${GREEN}Happy tunneling! 🌐${NC}"
