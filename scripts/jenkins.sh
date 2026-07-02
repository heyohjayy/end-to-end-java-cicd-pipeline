#!/usr/bin/env bash
#
# This script is provided as a manual
# installation guide.
#
# Run each command individually.
# It is intentionally not idempotent.

# Jenkins requires port 8080 by default

#set hostname
sudo hostnamectl set-hostname jenkins
sudo su - ubuntu


#Java requirements (update, install & check jdk version)
sudo apt update
sudo apt install fontconfig openjdk-21-jre -y
java -version


#Download Jenkins onto machine
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins


#enable the Jenkins service to start at boot
sudo systemctl enable jenkins

#start the Jenkins service
sudo systemctl start jenkins

#check the status of the Jenkins service
sudo systemctl status jenkins
sudo systemctl is-active jenkins


#Jenkins Home Directory
cd /var/lib/jenkins


#Access Jenkins UI
curl ifconfig.me
#Output = http://xxx.xxx.xx.xxx:8080
