#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# Detect OS
OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "Unsupported OS. Exiting."
    exit 1
fi

# Function to install on macOS
install_macos() {
    # Install Homebrew if not already installed
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        source ~/.zshrc
    fi

    # Install core tools
    echo "Installing DevOps tools with Homebrew..."
    brew install \
        git \
        docker \
        docker-compose \
        kubernetes-cli \
        helm \
        terraform \
        ansible \
        awscli \
        azure-cli \
        google-cloud-sdk \
        kubectx \
        jq \
        htop \
        tmux \
        vim \
        wget \
        curl \
        gnupg \
        openssl

    # Install monitoring tools via Docker
    echo "Pulling monitoring containers..."
    docker pull prom/prometheus
    docker pull grafana/grafana
    docker pull prom/node-exporter

    echo "DevOps tools installed successfully on macOS!"
}

# Function to install on Debian/Ubuntu
install_debian_ubuntu() {
    # Update and install dependencies
    apt update -y

    # Install core tools
    apt install -y \
        git \
        docker.io \
        docker-compose \
        kubectl \
        helm \
        terraform \
        ansible \
        awscli \
        azure-cli \
        google-cloud-sdk \
        jq \
        htop \
        tmux \
        vim \
        wget \
        curl \
        gnupg \
        openssl \
        python3 \
        python3-pip

    # Install Prometheus + Grafana
    mkdir -p /etc/prometheus /etc/grafana /var/lib/grafana
    curl -s https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/examples/prometheus.yml -o /etc/prometheus/prometheus.yml
    docker run -d --name prometheus -p 9090:9090 -v /etc/prometheus:/etc/prometheus prom/prometheus
    docker run -d --name grafana -p 3000:3000 -v /etc/grafana:/etc/grafana -v /var/lib/grafana:/var/lib/grafana grafana/grafana

    # Install Node Exporter
    wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
    tar xvfz node_exporter-* && cd node_exporter-* && cp node_exporter /usr/local/bin/
    useradd -rs /bin/false node_exporter
    cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter

    # Enable Docker
    systemctl enable docker
    systemctl start docker

    echo "DevOps + Observability tools installed successfully on Debian/Ubuntu!"
}

# Function to install on CentOS/RHEL
install_centos_rhel() {
    # Install EPEL repo if not already present
    if ! rpm -q epel-release &> /dev/null; then
        yum install -y epel-release
    fi

    # Install core tools
    yum install -y \
        git \
        docker \
        docker-compose \
        kubectl \
        helm \
        terraform \
        ansible \
        awscli \
        azure-cli \
        google-cloud-sdk \
        jq \
        htop \
        tmux \
        vim \
        wget \
        curl \
        gnupg \
        openssl \
        python3 \
        python3-pip

    # Install Prometheus + Grafana
    mkdir -p /etc/prometheus /etc/grafana /var/lib/grafana
    curl -s https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/examples/prometheus.yml -o /etc/prometheus/prometheus.yml
    docker run -d --name prometheus -p 9090:9090 -v /etc/prometheus:/etc/prometheus prom/prometheus
    docker run -d --name grafana -p 3000:3000 -v /etc/grafana:/etc/grafana -v /var/lib/grafana:/var/lib/grafana grafana/grafana

    # Install Node Exporter
    wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
    tar xvfz node_exporter-* && cd node_exporter-* && cp node_exporter /usr/local/bin/
    useradd -rs /bin/false node_exporter
    cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter

    # Enable Docker
    systemctl enable docker
    systemctl start docker

    echo "DevOps + Observability tools installed successfully on CentOS/RHEL!"
}

# Main installation
case $OS in
    "macos")
        install_macos
        ;;
    "debian"|"ubuntu")
        install_debian_ubuntu
        ;;
    "centos"|"rhel")
        install_centos_rhel
        ;;
    *)
        echo "Unsupported OS. Exiting."
        exit 1
        ;;
esac

# Post-install notes
echo -e "\n\e[1m=== Access Instructions ===\e[0m"
echo "Prometheus:    http://localhost:9090"
echo "Grafana:      http://localhost:3000 (admin/admin)"
echo "Node Exporter: http://localhost:9100/metrics"
echo -e "\nRun \`docker ps\` to check container status.\n"
