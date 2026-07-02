#!/usr/bin/env bash
#
# Description : Installs and enables Nginx for use as a reverse proxy
#  to the Apache Tomcat application server.
#
# This script is provided as a manual
# installation guide.
#
# Run each command individually.
# It is intentionally not idempotent.


# Update package index

sudo apt update -y



# Install Nginx

sudo apt install nginx -y



# Enable Nginx to start on boot

sudo systemctl enable nginx



# Start Nginx

sudo systemctl start nginx



# Verify Nginx is running

sudo systemctl status nginx --no-pager
