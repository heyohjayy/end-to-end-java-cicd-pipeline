#!/usr/bin/env bash

#=========================================
#       Nexus Repository Installation
#=========================================
#
# Target OS:
# Ubuntu 22.04 / 24.04
#
# This script installs:
# - OpenJDK 21
# - Nexus Repository OSS
#
# Nexus is installed into: /opt/Nexus
#
# Default Port: 8081

set -euo pipefail

#===========================
# Prevent execution as root.
#===========================

if [ "$EUID" -eq 0 ]; then
    echo "❌ DO NOT RUN THIS SCRIPT WITH SUDO."
    echo "❌ RUN: ./nexus.sh"
    exit 1
fi

NEXUS_VERSION="3.87.1-01"
NEXUS_ARCHIVE="nexus-${NEXUS_VERSION}-linux-x86_64.tar.gz"
NEXUS_URL="https://download.sonatype.com/nexus/3/${NEXUS_ARCHIVE}"
INSTALL_DIR="/opt/Nexus"

echo "🚀========== NEXUS INSTALLATION =========="

#==================================
# Configure hostname.
#==================================

CURRENT_HOSTNAME=$(hostname)

if [ "${CURRENT_HOSTNAME}" = "Nexus" ]; then
    echo "✅ HOSTNAME ALREADY CONFIGURED."
else
    echo "⚙️  SETTING HOSTNAME TO NEXUS..."
    sudo hostnamectl set-hostname Nexus
fi

#==========================
# Update package metadata.
#==========================

echo "📦 UPDATING PACKAGE REPOSITORIES..."
sudo apt update -y

#==========================
# Install Java 21.
#==========================

if dpkg -s openjdk-21-jdk >/dev/null 2>&1; then

    echo "✅ OPENJDK 21 ALREADY INSTALLED."

else

    echo "☕ INSTALLING OPENJDK 21..."

    sudo apt install -y openjdk-21-jdk curl

fi

echo "======================================"
echo "☕ JAVA VERSION"
echo "======================================"

java -version

#==================================
# Create Nexus user.
#==================================

if id nexus >/dev/null 2>&1; then

    echo "✅ NEXUS USER ALREADY EXISTS."

else

    echo "👤 CREATING NEXUS USER..."

    sudo useradd --system --create-home nexus

    echo "nexus:Adogcft111!" | sudo chpasswd

fi

#==================================
# Configure passwordless sudo.
#==================================

if [ -f /etc/sudoers.d/nexus ]; then

    echo "✅ NEXUS SUDO CONFIGURATION EXISTS."

else

    echo "⚙️  CONFIGURING PASSWORDLESS SUDO..."

    echo "nexus ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/nexus >/dev/null

    sudo chmod 440 /etc/sudoers.d/nexus

fi

#==================================
# Download Nexus.
#==================================

if [ -d "${INSTALL_DIR}" ]; then

    echo "✅ NEXUS ALREADY INSTALLED."

else

    echo "⬇️  DOWNLOADING NEXUS ${NEXUS_VERSION}..."

    cd /opt

    sudo curl -L -O "${NEXUS_URL}"

        if [ -f "${NEXUS_ARCHIVE}" ]; then

        echo "✅ NEXUS DOWNLOAD COMPLETED."

    else

        echo "❌ NEXUS DOWNLOAD FAILED."

        exit 1

    fi

    echo "📦 EXTRACTING NEXUS..."

    sudo tar -xzf "${NEXUS_ARCHIVE}"

    echo "📁 RENAMING INSTALLATION DIRECTORY..."

    sudo mv "nexus-${NEXUS_VERSION}" Nexus

    echo "🗑️ REMOVING ARCHIVE..."

    sudo rm -f "${NEXUS_ARCHIVE}"

fi

#==================================
# Configure permissions.
#==================================

echo "🔐 CONFIGURING PERMISSIONS..."

sudo chown -R nexus:nexus "${INSTALL_DIR}"
sudo chown -R nexus:nexus /opt/sonatype-work

#============================================
# # Configure Nexus to run as the nexus user.
#============================================

echo "⚙️  CONFIGURING NEXUS USER..."

sudo sed -i "s/^run_as_user=''/run_as_user='nexus'/" /opt/Nexus/bin/nexus

#==================================
# Create systemd service.
#==================================

if [ -f /etc/systemd/system/nexus.service ]; then

    echo "✅ NEXUS SYSTEMD SERVICE ALREADY EXISTS."

else

    echo "⚙️  CREATING SYSTEMD SERVICE..."

    sudo tee /etc/systemd/system/nexus.service >/dev/null <<EOF
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/Nexus/bin/nexus start
ExecStop=/opt/Nexus/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload

fi

#==================================
# Enable Nexus service.
#==================================

if sudo systemctl is-enabled nexus >/dev/null 2>&1; then

    echo "✅ NEXUS SERVICE ALREADY ENABLED."

else

    echo "⚙️  ENABLING NEXUS SERVICE..."

    sudo systemctl enable nexus

fi

#==================================
# Start Nexus service.
#==================================

if sudo systemctl is-active nexus >/dev/null 2>&1; then

    echo "✅ NEXUS SERVICE ALREADY RUNNING."

else

    echo "▶️  STARTING NEXUS SERVICE..."

    sudo systemctl start nexus

fi

#==================================
# Verify installation.
#==================================

echo "======================================"
echo "🔍 NEXUS SERVICE STATUS"
echo "======================================"

sudo systemctl is-active nexus

echo "======================================"
echo "📋 DETAILED SERVICE STATUS"
echo "======================================"

sudo systemctl status nexus --no-pager

#==================================
# Wait for Nexus log initialization.
#==================================

echo "⏳ WAITING FOR NEXUS LOG FILE..."

for i in {1..30}; do

    if [ -f /opt/sonatype-work/nexus3/log/nexus.log ]; then

        echo "✅ NEXUS LOG FILE DETECTED."
        break

    fi

    sleep 1

done

echo "======================================"
echo "📄 LAST 20 LOG ENTRIES"
echo "======================================"

sudo tail -20 /opt/sonatype-work/nexus3/log/nexus.log

echo "======================================"
echo "🌍 PUBLIC IP"
echo "======================================"

PUBLIC_IP=$(curl -s ifconfig.me)

echo "${PUBLIC_IP}"

echo "======================================"
echo "🌐 ACCESS NEXUS"
echo "======================================"

echo "http://${PUBLIC_IP}:8081"

echo "======================================"
echo "🔐 DEFAULT LOGIN"
echo "======================================"

echo "Username : admin"
echo ""
echo "Run the following command to retrieve the initial admin password:"
echo ""
echo "cat /opt/sonatype-work/nexus3/admin.password"

echo "======================================"
echo "⚠️  AWS SECURITY GROUP REMINDER"
echo "======================================"

echo "Allow inbound TCP port 8081"
echo "in your EC2 Security Group."

echo "======================================"
echo "✅ NEXUS INSTALLATION COMPLETED"
echo "Version      : ${NEXUS_VERSION}"
echo "Install Path : ${INSTALL_DIR}"
echo "Service      : nexus"
echo "======================================"
