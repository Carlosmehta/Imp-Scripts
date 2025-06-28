#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "🔒 Please run this script as root or with sudo."
    exit 1
fi

# Detect OS and Version
OS=""
VERSION_ID=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "❌ Unsupported OS. Exiting."
    exit 1
fi

# Install common dependencies
install_deps() {
    echo -e "\n🔧 Installing common dependencies..."
    case $OS in
        "debian"|"ubuntu")
            apt update -y
            apt install -y apt-transport-https ca-certificates curl gnupg software-properties-common
            ;;
        "centos"|"rhel")
            yum install -y yum-utils device-mapper-persistent-data lvm2
            ;;
        "macos")
            # Handled in main installer
            ;;
    esac
}

# Install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "\n🐳 Installing Docker..."
        case $OS in
            "debian"|"ubuntu")
                curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                apt update -y
                apt install -y docker-ce docker-ce-cli containerd.io
                ;;
            "centos"|"rhel")
                yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                yum install -y docker-ce docker-ce-cli containerd.io
                ;;
        esac
        systemctl enable docker
        systemctl start docker
    fi
}

# Install HashiCorp Vault
install_vault() {
    if ! command -v vault &> /dev/null; then
        echo -e "\n🏦 Installing HashiCorp Vault..."
        VAULT_VERSION="1.15.2"
        case $OS in
            "debian"|"ubuntu"|"centos"|"rhel")
                wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
                unzip vault_${VAULT_VERSION}_linux_amd64.zip -d /usr/local/bin
                rm vault_${VAULT_VERSION}_linux_amd64.zip
                setcap cap_ipc_lock=+ep /usr/local/bin/vault
                ;;
            "macos")
                brew tap hashicorp/tap
                brew install hashicorp/tap/vault
                ;;
        esac
        
        # Create minimal dev server config
        mkdir -p /etc/vault.d
        cat > /etc/vault.d/config.hcl <<EOF
storage "file" {
  path = "/var/lib/vault"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://0.0.0.0:8200"
ui = true
EOF

        # Create systemd service (Linux)
        if [[ $OS != "macos" ]]; then
            useradd -r -s /bin/false vault
            mkdir -p /var/lib/vault
            chown -R vault:vault /var/lib/vault
            
            cat > /etc/systemd/system/vault.service <<EOF
[Unit]
Description=Vault
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
ProtectSystem=full
Capabilities=CAP_IPC_LOCK+ep
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/config.hcl
ExecReload=/bin/kill -HUP \$MAINPID
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload
            systemctl enable vault
            systemctl start vault
        fi
    fi
}

# Install Falco
install_falco() {
    if ! command -v falco &> /dev/null; then
        echo -e "\n🔍 Installing Falco Runtime Security..."
        case $OS in
            "debian"|"ubuntu")
                curl -s https://falco.org/repo/falcosecurity-$(lsb_release -rs).key | apt-key add -
                echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
                apt update -y
                apt install -y linux-headers-$(uname -r) falco
                ;;
            "centos"|"rhel")
                rpm --import https://falco.org/repo/falcosecurity-$(rpm -E %rhel).key
                curl -s -o /etc/yum.repos.d/falcosecurity.repo https://falco.org/repo/falcosecurity-rpm.repo
                yum install -y kernel-devel-$(uname -r) falco
                ;;
            "macos")
                brew install falcosecurity/falco/falco
                ;;
        esac
        
        if [[ $OS != "macos" ]]; then
            systemctl enable falco
            systemctl start falco
        fi
    fi
}

# Install Security Tools
install_security_tools() {
    echo -e "\n🔐 Installing Core Security Tools..."

    # Common tools for all platforms
    case $OS in
        "debian"|"ubuntu")
            apt install -y \
                lynis \
                wpscan \
                zaproxy \
                git \
                python3-pip \
                jq
            ;;
        "centos"|"rhel")
            yum install -y \
                lynis \
                git \
                python3-pip \
                jq
            ;;
        "macos")
            brew install \
                lynis \
                wpscan \
                git \
                jq
            ;;
    esac

    # Install Trivy (container scanning)
    if ! command -v trivy &> /dev/null; then
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    fi

    # Install Semgrep (SAST)
    python3 -m pip install -U semgrep

    # Install Snyk
    if ! command -v snyk &> /dev/null; then
        curl -s https://static.snyk.io/cli/latest/snyk-linux -o /usr/local/bin/snyk
        chmod +x /usr/local/bin/snyk
    fi

    # Install Checkov (IaC scanning)
    python3 -m pip install -U checkov

    # Install Grype (SBOM)
    if ! command -v grype &> /dev/null; then
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
    fi

    # Install Terrascan
    if ! command -v terrascan &> /dev/null; then
        curl -L "$(curl -s https://api.github.com/repos/tenable/terrascan/releases/latest | grep -o -E "https://.+?_Linux_x86_64.tar.gz")" -o terrascan.tar.gz
        tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz
        install terrascan /usr/local/bin && rm terrascan
    fi
}

# Main installer
main() {
    install_deps
    install_docker
    install_vault
    install_falco
    install_security_tools
}

# Execute based on OS
case $OS in
    "macos") 
        if ! command -v brew &> /dev/null; then
            echo -e "\n🍺 Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            source ~/.zshrc
        fi
        main
        ;;
    "debian"|"ubuntu"|"centos"|"rhel") 
        main 
        ;;
    *) 
        echo "❌ Unsupported OS"
        exit 1
        ;;
esac

# Post-install summary
echo -e "\n\033[1;35m============================"
echo "🏰 DevSecOps Fortress Complete!"
echo "============================\033[0m"

echo -e "\n\033[1;33m🔑 Secrets Management:"
echo "  - Vault: http://localhost:8200 (UI enabled)"
echo "    Run 'vault operator init' to initialize"

echo -e "\n\033[1;33m🛡️  Runtime Security:"
echo "  - Falco: Monitoring system calls"
if [[ $OS != "macos" ]]; then
    echo "    Logs: journalctl -u falco"
fi

echo -e "\n\033[1;33m🔍 Security Tools:"
echo "  - Trivy: trivy image <image-name>"
echo "  - Semgrep: semgrep --config=auto ."
echo "  - Snyk: snyk test"
echo "  - Checkov: checkov -d /path/to/iac"
echo "  - Grype: grype <image-or-directory>"

echo -e "\n\033[1;33m🚀 Quick Start:"
echo "  1. Initialize Vault: vault server -config=/etc/vault.d/config.hcl"
echo "  2. Monitor runtime: journalctl -u falco -f"
echo "  3. Scan containers: trivy image nginx:latest"

echo -e "\n\033[1;32m✅ DevSecOps toolchain ready! Use '--help' with any tool to learn more.\033[0m"
