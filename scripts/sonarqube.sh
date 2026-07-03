#!/usr/bin/env bash

#=========================================
#     SonarQube Installation Script
#=========================================
#
# Target OS:
# Amazon Linux 2023
#
#==============================
# Package Manager Notes:
# Ubuntu/Debian  -> apt
# Amazon Linux   -> dnf
# RHEL/CentOS    -> yum or dnf
#==============================
#
# This script installs:
# - Amazon Corretto JDK 21
# - SonarQube Community Edition
#
# SonarQube is installed in:
# /opt/sonarqube
#
# The script is designed to be idempotent
# and may be executed multiple times safely.

set -euo pipefail

# Prevent execution as root.
# The script already uses sudo where required.

if [ "$EUID" -eq 0 ]; then
    echo "❌ DO NOT RUN THIS SCRIPT WITH SUDO."
    echo "❌ RUN 👉🏾 ./sonarqube.sh"
    exit 1
fi

SONAR_VERSION="26.4.0.121862"
SONAR_ARCHIVE="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ARCHIVE}"
INSTALL_DIR="/opt/sonarqube"

echo "🚀========== SONARQUBE INSTALLATION =========="

#==================================
# Configure hostname if necessary.
#==================================

CURRENT_HOSTNAME=$(hostname)

if [ "${CURRENT_HOSTNAME}" = "SonarQube" ]; then
    echo "✅ HOSTNAME ALREADY CONFIGURED."
else
    echo "⚙️  SETTING HOSTNAME TO SONARQUBE..."
    sudo hostnamectl set-hostname SonarQube
fi

#=========================
# Update package metadata.
#=========================

echo "📦 UPDATING PACKAGE REPOSITORIES..."
sudo dnf update -y

#====================================
# Install required utility packages.
#====================================

echo "📦 INSTALLING REQUIRED UTILITIES..."
sudo dnf install -y wget unzip git curl

#==========================================
# Create sonar service account if required.
#==========================================

if id sonar >/dev/null 2>&1; then

    echo "✅ SONAR USER ALREADY EXISTS."

else

    echo "👤 CREATING SONAR USER..."

    sudo useradd --system --create-home sonar

    echo "sonar:Adogcft111!" | sudo chpasswd

fi

#==================================
# Configure passwordless sudo.
#==================================

if sudo test -f /etc/sudoers.d/sonar; then

    echo "✅ SONAR SUDO CONFIGURATION EXISTS."

else

    echo "⚙️  CONFIGURING PASSWORDLESS SUDO..."

    echo "sonar ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/sonar >/dev/null

    sudo chmod 440 /etc/sudoers.d/sonar

fi

#=========================================
# Enable SSH password authentication.
#=========================================

if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then

    echo "✅ PASSWORD AUTHENTICATION ALREADY ENABLED."

else

    echo "🔐 ENABLING PASSWORD AUTHENTICATION..."

    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

    sudo systemctl restart sshd

fi

#=========================================
# Configure Amazon Corretto repository.
#=========================================

if rpm -q java-21-amazon-corretto-devel >/dev/null 2>&1; then

    echo "✅ AMAZON CORRETTO JDK 21 ALREADY INSTALLED."

else

    echo "☕ CONFIGURING AMAZON CORRETTO REPOSITORY..."

    sudo rpm --import https://yum.corretto.aws/corretto.key

    sudo curl -fsSL \
        -o /etc/yum.repos.d/corretto.repo \
        https://yum.corretto.aws/corretto.repo

    sudo dnf clean all

    echo "☕ INSTALLING AMAZON CORRETTO JDK 21..."

    sudo dnf install -y java-21-amazon-corretto-devel

fi

#=========================
# Verify Java version.
#=========================

echo "======================================"
echo "☕ JAVA VERSION"
echo "======================================"

java -version

#====================================
# Download SonarQube if not present.
#====================================

if [ -d "${INSTALL_DIR}" ]; then

    echo "✅ SONARQUBE ALREADY INSTALLED."

else

    echo "⬇️  DOWNLOADING SONARQUBE ${SONAR_VERSION}..."

    cd /tmp

    wget -q "${SONAR_URL}"

    if [ ! -f "${SONAR_ARCHIVE}" ]; then
        echo "❌ SONARQUBE DOWNLOAD FAILED."
        exit 1
    fi

    echo "📦 EXTRACTING SONARQUBE..."

    sudo unzip -q "${SONAR_ARCHIVE}" -d /opt

    sudo mv "/opt/sonarqube-${SONAR_VERSION}" "${INSTALL_DIR}"

    rm -f "${SONAR_ARCHIVE}"

fi


#==========================================
# Configure SonarQube file permissions.
#==========================================

echo "🔐 CONFIGURING FILE PERMISSIONS..."

sudo chown -R sonar:sonar "${INSTALL_DIR}"
sudo chmod -R 775 "${INSTALL_DIR}"

#==========================================
# Create SonarQube systemd service.
#==========================================

if [ -f /etc/systemd/system/sonarqube.service ]; then

    echo "✅ SONARQUBE SYSTEMD SERVICE ALREADY EXISTS."

else

    echo "⚙️  CREATING SONARQUBE SYSTEMD SERVICE..."

    sudo tee /etc/systemd/system/sonarqube.service > /dev/null <<EOF
[Unit]
Description=SonarQube Service
After=network.target

[Service]
Type=forking

User=sonar
Group=sonar

WorkingDirectory=${INSTALL_DIR}

ExecStart=${INSTALL_DIR}/bin/linux-x86-64/sonar.sh start
ExecStop=${INSTALL_DIR}/bin/linux-x86-64/sonar.sh stop
ExecReload=${INSTALL_DIR}/bin/linux-x86-64/sonar.sh restart

Restart=on-failure

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    echo "🔄 RELOADING SYSTEMD..."

    sudo systemctl daemon-reload

fi

#==================================
# Enable SonarQube service.
#==================================

if systemctl is-enabled sonarqube >/dev/null 2>&1; then

    echo "✅ SONARQUBE SERVICE ALREADY ENABLED."

else

    echo "⚙️  ENABLING SONARQUBE SERVICE..."

    sudo systemctl enable sonarqube

fi

#==================================
# Start SonarQube service.
#==================================

if systemctl is-active sonarqube >/dev/null 2>&1; then

    echo "✅ SONARQUBE SERVICE ALREADY RUNNING."

else

    echo "▶️  STARTING SONARQUBE SERVICE..."

    sudo systemctl start sonarqube

fi


#==================================
# Verify SonarQube service.
#==================================

echo "======================================"
echo "🔍 SONARQUBE SERVICE STATUS"
echo "======================================"

systemctl is-active sonarqube

echo "======================================"
echo "📋 DETAILED SERVICE STATUS"
echo "======================================"

systemctl status sonarqube --no-pager


#==================================
# Wait for SonarQube to become available.
#==================================

echo "======================================"
echo "⏳ WAITING FOR SONARQUBE TO START"
echo "======================================"

until curl -s http://localhost:9000 >/dev/null
do
    sleep 5
done

echo "======================================"
echo "🌐 CHECKING PORT 9000"
echo "======================================"

if ss -tulnp | grep -q ":9000"; then

    echo "✅ SONARQUBE IS LISTENING ON PORT 9000."

else

    echo "❌ SONARQUBE IS NOT LISTENING ON PORT 9000."

fi

#==================================
# Retrieve public IP address.
#==================================

PUBLIC_IP=$(curl -s ifconfig.me)

echo "======================================"
echo "🌍 PUBLIC IP ADDRESS"
echo "======================================"

echo "${PUBLIC_IP}"

echo "======================================"
echo "📂 INSTALLATION DIRECTORY"
echo "======================================"

echo "${INSTALL_DIR}"

echo "======================================"
echo "🔐 DEFAULT SONARQUBE LOGIN"
echo "======================================"

echo "Username:  admin"
echo "Password:  admin"

echo "======================================"
echo "⚠️  AWS SECURITY GROUP REMINDER"
echo "======================================"

echo "Before accessing SonarQube,"
echo "allow inbound TCP port 9000"
echo "in your EC2 Security Group."

echo "======================================"
echo "🌐 ACCESS SONARQUBE"
echo "======================================"

echo "http://${PUBLIC_IP}:9000"

echo "======================================"
echo "✅ SONARQUBE INSTALLATION COMPLETED"
echo "Version         : ${SONAR_VERSION}"
echo "Install Path    : ${INSTALL_DIR}"
echo "Service         : sonarqube"
echo "======================================"
