# End-to-End Java CI/CD Pipeline Setup Guide

For an overview of the project architecture and implementation, see [README.md](README.md).

---

# 1. Introduction

This document provides a step-by-step guide for deploying and configuring the end-to-end Java CI/CD pipeline presented in this repository.

The implementation provisions four dedicated Amazon EC2 instances, each responsible for a specific stage of the software delivery lifecycle. Jenkins orchestrates the complete pipeline, integrating GitHub for source code management, Apache Maven for project build and packaging, SonarQube for static code analysis, Nexus Repository Manager for artifact storage, Apache Tomcat for application deployment, Nginx as a reverse proxy, and Slack for build notifications.

The pipeline is implemented using a **Jenkins Freestyle Job**, which is automatically triggered by a GitHub Webhook whenever changes are pushed to the configured repository.

Following this guide will result in a fully functional CI/CD environment capable of automatically building, analysing, storing, deploying, and validating a Java web application.

---

# 2. Prerequisites

Before beginning the implementation, ensure the following requirements are available.

## 2.1 AWS Account

An active AWS account with permission to create and manage Amazon EC2 instances.

## 2.2 GitHub Account

A GitHub account for hosting the application source code and configuring GitHub Webhooks.

## 2.3 Slack Workspace

A Slack workspace for receiving Jenkins build notifications.

## 2.4 Local Machine

A Windows, Linux, or macOS machine with:

- Terminal or PowerShell
- SSH client
- Web browser
- Internet connectivity

## 2.5 EC2 Key Pair

Create or use an existing EC2 key pair.

Download the `.pem` file and store it securely, as it will be required when connecting to each server via SSH.

Example:

```text
jenkins.pem
```

---

# 3. Infrastructure Deployment

## 3.1 Amazon EC2 Instances

Launch the following Ubuntu Server 24.04 LTS Amazon EC2 instances.

| Server | Purpose |
|---------|---------|
| Jenkins Server | CI/CD orchestration and build automation |
| SonarQube Server | Static code analysis |
| Nexus Repository Server | Artifact repository |
| Apache Tomcat Server | Application deployment and Nginx reverse proxy |

Use an instance type that provides sufficient resources for each service. SonarQube and Nexus Repository Manager typically require more memory than Jenkins and Tomcat.

---

## 3.2 Security Groups

Configure the required inbound rules before provisioning each server.

| Service | Port |
|---------|-----:|
| SSH | 22 |
| HTTP | 80 |
| Jenkins | 8080 |
| SonarQube | 9000 |
| Nexus Repository | 8081 |
| Tomcat | 8080 |

Restrict access where appropriate based on your environment.

---

## 3.3 Connect to Each Server

Connect to every EC2 instance using SSH.

```bash
ssh -i /path/to/jenkins.pem ubuntu@<PUBLIC_IP_ADDRESS>
```

Example:

```bash
ssh -i jenkins.pem ubuntu@<JENKINS_SERVER_PUBLIC_IP>
```

After connecting, update the package repository.

```bash
sudo apt update
sudo apt upgrade -y
```

Repeat this process for each server before beginning the installation steps.

---

## 3.4 Server Hostnames

Assign a meaningful hostname to each server to simplify administration.

| Server | Hostname |
|---------|----------|
| Jenkins Server | jenkins-server |
| SonarQube Server | sonarqube-server |
| Nexus Repository Server | nexus-server |
| Apache Tomcat Server | tomcat-server |

Example:

```bash
sudo hostnamectl set-hostname jenkins-server
```

Verify the hostname.

```bash
hostnamectl
```

---

# 4. Jenkins Server Setup

This section covers the installation and initial configuration of Jenkins, which serves as the central orchestration server for the CI/CD pipeline.

---

## 4.1 Provision the Jenkins Server

The Jenkins installation script is included in this repository.

**Installation Script**

[`scripts/jenkins.sh`](scripts/jenkins.sh)

On the Jenkins server, create the installation script.

```bash
vi jenkins.sh
```

Copy the contents of `jenkins.sh` into the file, save, and exit.

Grant execute permission to the script.

```bash
chmod +x jenkins.sh
```

Run the installation script.

```bash
./jenkins.sh
```

The script installs and configures Jenkins together with its required dependencies.

---

## 4.2 Verify the Installation

The installation script automatically enables and starts the Jenkins service.

Retrieve the initial Jenkins administrator password.

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Open the Jenkins web interface.

```text
http://<JENKINS_SERVER_PUBLIC_IP>:8080
```

Paste the password to unlock Jenkins.

When prompted, select:

```text
Install suggested plugins
```

After the plugin installation completes, create the administrator account and complete the Jenkins setup wizard.

![Jenkins Dashboard](screenshots/01-jenkins-dashboard.png)

---

## 4.3 Create the Jenkins Freestyle Job

From the Jenkins dashboard, create a new **Freestyle Project**.

Navigate to:

```text
Dashboard
→ New Item
→ Freestyle Project
```

Enter a project name of your choice and click **OK**.

Under **Source Code Management**, select **Git**.

Configure the following:

- Repository URL
- Git Credentials (GitHub Personal Access Token)
- Branch Specifier (e.g. `main`)

The Git plugin enables Jenkins to clone the latest version of the repository whenever a build is triggered.

![Jenkins Job Configuration](screenshots/05-jenkins-job-configuration.png)

---

## 4.4 Jenkins Maven Integration

Return to the Jenkins Freestyle Job configuration page.

Scroll down to the **Build Steps** section and click **Add Build Step**.

Select:

```text
Invoke top-level Maven targets
```

Under **Maven Version**, select the Maven installation configured in Jenkins.

Example:

```text
Maven 3.9.12
```
![Jenkins Global Tool Configuration](screenshots/02-jenkins-global-tool-configuration.png)

In the **Goals** field, enter:

```text
clean package
```

This instructs Maven to clean any previous build artifacts and package the application into a deployable WAR file.

Expand the **Advanced** section.

Under **POM**, specify the full path to the project's `pom.xml` file.

Example:

```text
/var/lib/jenkins/workspace/<JOB_NAME>/pom.xml
```

> **Note:** The exact path depends on your Jenkins workspace and the name of your Freestyle Job.

If Jenkins is unable to locate the `pom.xml` file, you may choose to execute the build using a shell script instead of **Invoke top-level Maven targets**.

Save the job configuration.

Run a build to verify that Maven successfully locates the `pom.xml` file and packages the application.

![Maven Build Success](screenshots/06-maven-build-success.png)

---

# 5. SonarQube Server Setup

This section covers the provisioning of the SonarQube server and its integration with Jenkins for automated static code analysis.

---

## 5.1 Provision the SonarQube Server

The SonarQube installation script is included in this repository.

**Installation Script**

[`scripts/sonarqube.sh`](scripts/sonarqube.sh)

On the SonarQube server, create the installation script.

```bash
vi sonarqube.sh
```

Copy the contents of `sonarqube.sh` into the file, save, and exit.

Grant execute permission to the script.

```bash
chmod +x sonarqube.sh
```

Run the installation script.

```bash
./sonarqube.sh
```

---

## 5.2 Verify the Installation

The installation script automatically installs and starts SonarQube.

Open the SonarQube web interface.

```text
http://<SONARQUBE_SERVER_PUBLIC_IP>:9000
```

Log in using the default credentials.

```text
Username: admin
Password: admin
```

You will be prompted to change the default password after the first login.


![SonarQube Dashboard](screenshots/08-sonarqube-dashboard.png)

---

## 5.3 Integrate SonarQube with Maven (Current Project Implementation)

Open your project's [`configuration/pom.xml`](configuration/pom.xml) file.

Add the SonarQube properties.

```xml
<sonar.host.url>http://<SONARQUBE_SERVER_IP>:9000</sonar.host.url>
<sonar.login><SONAR_USERNAME></sonar.login>
<sonar.password><SONAR_PASSWORD></sonar.password>
```

If authentication using the username and password is unsuccessful, replace the above properties with a SonarQube authentication token.
You can get this by logging in and navigating to your:

```text
User > My Account > Security (SonarQube) or My Account > Access Tokens (SonarCloud) page.  
```

Name your token, select an expiration timeframe, click Generate, and copy the value immediately and insert in the `SONAR_TOKEN` placeholder below:

```xml
<sonar.host.url>http://<SONARQUBE_SERVER_IP>:9000</sonar.host.url>
<sonar.projectKey><PROJECT_KEY></sonar.projectKey>
<sonar.projectName><PROJECT_NAME></sonar.projectName>
<sonar.token><SONAR_TOKEN></sonar.token>
```

> **Note:** This project integrates SonarQube directly through the project's `pom.xml`. This approach was used during the implementation of this project and is suitable for learning and small-scale environments.

---

## 5.4 Alternative Method (Jenkins SonarQube Plugin)

As an alternative to configuring SonarQube through the `pom.xml`, Jenkins can be integrated directly with SonarQube using the **SonarQube Scanner** plugin.

Navigate to:

```text
Manage Jenkins
→ Plugins
→ Available Plugins
```

Search for:

```text
Sonar
```

Install the plugin and restart Jenkins if prompted.

![SonarQube Scanner Plugin](screenshots/16-sonarqube-plugin-installation.png)

Navigate to:

```text
Manage Jenkins
→ System
```

Scroll to the **SonarQube Servers** section.

Click **Add SonarQube** and configure:

- Name
- Server URL
- Authentication Token

Generate an authentication token from SonarQube like in **step 5.3** above and add it to Jenkins as a **Secret Text** credential.

Save the configuration.

---

## 5.5 Run the SonarQube Analysis

Return to the Jenkins Freestyle Job configuration.

Add a new **Build Step**.

Under **Goals**, enter:

```text
sonar:sonar
```

Save the job configuration and run a new build.

After the build completes successfully, open the SonarQube dashboard to verify that the project has been analysed successfully.

![SonarQube Quality Gate](screenshots/09-sonarqube-quality-gate.png)

---

# 6. Nexus Repository Setup

This section covers the provisioning of the Nexus Repository server and its integration with Jenkins for artifact storage and version management.

---

## 6.1 Provision the Nexus Server

The Nexus installation script is included in this repository.

**Installation Script**

[`scripts/nexus.sh`](scripts/nexus.sh)

On the Nexus server, create the installation script.

```bash
vi nexus.sh
```

Copy the contents of `nexus.sh` into the file, save, and exit.

Grant execute permission.

```bash
chmod +x nexus.sh
```

Run the installation script.

```bash
./nexus.sh
```

---

## 6.2 Verify the Installation

Open the Nexus Repository web interface.

```text
http://<NEXUS_SERVER_PUBLIC_IP>:8081
```

Log in using the administrator account.

Retrieve the initial administrator password.

```bash
cat /opt/sonatype-work/nexus3/admin.password
```

After logging in, change the default administrator password when prompted.

![Nexus Dashboard](screenshots/10-nexus-dashboard.png)

---

## 6.3 Create the Maven Repositories

In your Nexus web interface, Create a new hosted Maven repository for release artifacts.

Configure the repository as follows:

| Setting | Value |
|---------|-------|
| Repository Type | Maven2 (Hosted) |
| Repository Name | Java-WebApp-Frontend-Releases |
| Version Policy | Release |

After creating the repository, copy the repository URL.

Example:

```text
http://<NEXUS_SERVER_PUBLIC_IP>:8081/repository/Java-WebApp-frontend-releases/
```

Next, create a second hosted Maven repository for snapshot artifacts.

Configure the repository as follows:

| Setting | Value |
|---------|-------|
| Repository Type | Maven2 (Hosted) |
| Repository Name | Java-WebApp-Snapshots |
| Version Policy | Snapshot |

Copy the Snapshot repository URL.

Example:

```text
http://<NEXUS_SERVER_PUBLIC_IP>:8081/repository/Java-WebApp-Snapshots/
```

---

## 6.4 Configure Maven Deployment

Open the project's [`configuration/pom.xml`](configuration/pom.xml).

Add the following `distributionManagement` section.

```xml
<distributionManagement>
    <repository>
        <id>nexus</id>
        <name>Java-WebApp-Frontend-Releases-Repo</name>
        <url>http://<NEXUS_SERVER_PUBLIC_IP>:8081/repository/Java-WebApp-frontend-releases/</url>
    </repository>

    <snapshotRepository>
        <id>nexus</id>
        <name>Java-WebApp-Snapshots-Repo</name>
        <url>http://<NEXUS_SERVER_PUBLIC_IP>:8081/repository/Java-WebApp-Snapshots/</url>
    </snapshotRepository>
</distributionManagement>
```

> **Note:** Do not commit the changes yet.

---

## 6.5 Configure the Jenkins Build

Return to the Jenkins Freestyle Job configuration.

Add a new **Build Step**.

Select:

```text
Invoke top-level Maven targets
```

Under **Goals**, enter:

```text
deploy
```

Under **Advanced**, specify the project's `pom.xml` file.

Example:

```text
Java-Login-App/pom.xml
```

Save the job configuration.

---

## 6.6 Authenticate Jenkins with Nexus

On the Jenkins server, navigate to the Maven configuration directory.

```bash
cd /var/lib/jenkins
cd tools/hudson.tasks.Maven_MavenInstallation/Maven_3.9.12/conf
```

Open the Maven `settings.xml` file.

```bash
sudo vi settings.xml
```

Add the Nexus server credentials.

```xml
<server>
    <id>nexus</id>
    <username><NEXUS_USERNAME></username>
    <password><NEXUS_PASSWORD></password>
</server>
```

Save the file.

The completed `settings.xml` used for this project is available in this repository:

[`configuration/settings.xml`](configuration/settings.xml)

---

## 6.7 Deploy the Artifact

Commit the changes made to the `pom.xml` file to trigger a new Jenkins build.

Jenkins will automatically:

- Build the application.
- Package the WAR artifact.
- Upload the generated artifact to Nexus Repository.

After the build completes successfully, verify that the artifact has been published to the **Java-WebApp-Frontend-Releases** repository.

![Nexus WAR Artifact](screenshots/11-nexus-war-artifact.png)

---

# 7. Apache Tomcat Setup

This section covers the provisioning of the Apache Tomcat server and its integration with Jenkins for automated application deployment.

---

## 7.1 Provision the Tomcat Server

The Tomcat installation script is included in this repository.

**Installation Script**

[`scripts/tomcat.sh`](scripts/tomcat.sh)

On the Tomcat server, create the installation script.

```bash
vi tomcat.sh
```

Copy the contents of `tomcat.sh` into the file, save, and exit.

Grant execute permission.

```bash
chmod +x tomcat.sh
```

Run the installation script.

```bash
./tomcat.sh
```

---

## 7.2 Verify the Installation

Open the Tomcat web interface.

```text
http://<TOMCAT_SERVER_PUBLIC_IP>:8080
```

Confirm that the Apache Tomcat landing page is accessible from your web browser.

![Apache Tomcat Landing Page](screenshots/17-tomcat-landing-page.png)

---

## 7.3 Configure the Tomcat Manager

To allow Jenkins to deploy applications remotely, the Tomcat Manager application must be accessible.

Navigate to the Manager application's configuration directory.

```bash
cd /opt/tomcat/webapps/manager/META-INF
```

Open the `context.xml` file.

```bash
sudo vi context.xml
```

Comment out the default `RemoteAddrValve`.

```xml
<!--
<Valve className="org.apache.catalina.valves.RemoteAddrValve"
allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />
-->
```

Next, open the Tomcat users configuration file.

```bash
sudo vi /opt/tomcat/conf/tomcat-users.xml
```

Before the closing `</tomcat-users>` tag, add a manager user.

```xml
<user username="<TOMCAT_USERNAME>"
      password="<TOMCAT_PASSWORD>"
      roles="manager-gui,admin-gui,manager-script"/>
```

Save the file.

Restart the Tomcat service.

```bash
sudo systemctl stop tomcat
sudo systemctl start tomcat
```

Verify that the Manager application is now accessible.

```text
http://<TOMCAT_SERVER_PUBLIC_IP>:8080/manager/html
```

![Tomcat Manager](screenshots/12-tomcat-manager.png)

---

## 7.4 Configure Jenkins Deployment

Before configuring the deployment, install the **Deploy to Container** plugin.

From the Jenkins dashboard, navigate to:

```text
Manage Jenkins
→ Plugins
→ Available Plugins
```

Search for:

```text
Deploy to Container
```

Install the plugin and restart Jenkins if prompted.

![Deploy to Container Plugin](screenshots/18-deploy-to-container-plugin.png)

Return to the Jenkins Freestyle Job configuration.

Under **Post-build Actions**, click:

```text
Add Post-build Action
```

Select:

```text
Deploy WAR/EAR to a container
```

Configure the deployment settings.

| Field | Value |
|--------|-------|
| WAR/EAR Files | `**/target/*.war` |
| Context Path | `/Java-login-app-1.0` |

Click **Add Container** and select:

```text
Tomcat 9.x Remote
```

---

## 7.5 Configure Tomcat Credentials

Click **Add Credentials**.

Select:

```text
Username with password
```

Use the same username and password configured in the `tomcat-users.xml` file.

Example:

| Field | Value |
|--------|-------|
| Username | `<TOMCAT_USERNAME>` |
| Password | `<TOMCAT_PASSWORD>` |
| ID | `tomcatcred` |

Save the credentials.

Configure the Tomcat URL.

```text
http://<TOMCAT_SERVER_PUBLIC_IP>:8080
```

Save the Jenkins job configuration.

![Jenkins Post-build Deployment Configuration](screenshots/19-jenkins-post-build-deployment.png)

---

## 7.6 Enable Artifact Redeployment

Open the Nexus Repository Manager.

Navigate to:

```text
Settings
→ Repositories
```

Edit the **Java-WebApp-Frontend-Releases** repository.

Enable:

```text
Allow redeploy
```

Save the repository configuration.

---

## 7.7 Deploy the Application

Return to the Jenkins Freestyle Job.

Click:

```text
Build Now
```

Jenkins will automatically:

- Build the application.
- Deploy the generated WAR file to Apache Tomcat.
- Publish the application using the configured context path.

Verify that the deployment completed successfully by opening the Tomcat Manager application.

![Tomcat Manager](screenshots/12-tomcat-manager.png)

---

# 8. Configure Nginx as a Reverse Proxy

Instead of exposing Apache Tomcat directly on port `8080`, Nginx is configured as a reverse proxy to forward incoming HTTP requests to the deployed application. This provides a cleaner public endpoint while preventing direct access to the Tomcat application server.

---

## 8.1 Install Nginx

The Nginx installation script is included in this repository.

**Installation Script**

[`scripts/nginx.sh`](scripts/nginx.sh)

On the Tomcat server, create the installation script.

```bash
vi nginx.sh
```

Copy the contents of `nginx.sh` into the file, save, and exit.

Grant execute permission.

```bash
chmod +x nginx.sh
```

Run the installation script.

```bash
./nginx.sh
```

---

## 8.2 Verify the Installation

Confirm that the Nginx service is running.

```bash
sudo systemctl status nginx --no-pager
```

Ensure your AWS EC2 Security Group allows inbound HTTP traffic on **TCP Port 80**.

---

## 8.3 Configure the Reverse Proxy

Open the default Nginx site configuration.

```bash
sudo vi /etc/nginx/sites-available/default
```

Replace the default `location /` block with the reverse proxy configuration included in this repository.

**Configuration File**

[`configuration/nginx.conf`](configuration/nginx.conf)

![Nginx Reverse Proxy](screenshots/13-nginx-reverse-proxy.png)

Save the file and exit.

Validate the Nginx configuration.

```bash
sudo nginx -t
```

Restart Nginx.

```bash
sudo systemctl restart nginx
```

Verify that Nginx is listening on port **80**.

```bash
sudo ss -tlnp | grep :80
```

---

## 8.4 Verify the Reverse Proxy

Test the reverse proxy locally.

```bash
curl http://localhost
```

Verify that the Java Login application is accessible directly from Tomcat.

```bash
curl http://localhost:8080/Java-login-app-1.0/login
```

Finally, verify the reverse proxy from your web browser.

```text
http://<PUBLIC-IP>/Java-login-app-1.0/login
```

The Java Login application should load successfully through the Nginx reverse proxy.

---

# 9. Configure Slack Build Notifications

This section configures Slack notifications for Jenkins build events. The names used throughout this section (workspace name, channel name and bot name) are examples based on this project. You are free to use your own names provided they are used consistently throughout the configuration.

---

## 9.1 Create a Slack Workspace

Create a Slack workspace by visiting:

```text
https://slack.com/get-started
```

Create a new workspace.

> **Note:** The workspace name used in this guide is only an example. You may choose any name for your own workspace.

Create a channel for Jenkins build notifications.

Example:

```text
#jenkins-builds
```

> **Note:** The channel name is also a placeholder. You may use any channel name of your choice.

---

## 9.2 Create a Slack App

Navigate to:

```text
https://api.slack.com/apps
```

Create a new Slack App.

Choose:

```text
From an app manifest
```

Select the workspace you created.

Replace the default YAML manifest with the configuration provided below.

```yaml
display_information:
  name: Jenkins
features:
  bot_user:
    display_name: Jenkins
    always_online: true
oauth_config:
  scopes:
    bot:
      - channels:read
      - chat:write
      - chat:write.customize
      - files:write
      - reactions:write
      - users:read
      - users:read.email
      - groups:read
settings:
  org_deploy_enabled: false
  socket_mode_enabled: false
  token_rotation_enabled: false
```

> **Note:** The bot name and display name (`Jenkins`) are examples. You may replace them with any name you prefer. The remaining configuration should remain unchanged.

Review the configuration and create the application.

---

## 9.3 Generate the Bot Token

Open:

```text
OAuth & Permissions
```

Click:

```text
Install to Workspace
```

Approve the requested permissions.

Slack will generate a **Bot User OAuth Token** beginning with:

```text
xoxb-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Save this token. It will be required when configuring Jenkins.

Invite the bot to your notifications channel.

Example:

```text
/invite @Jenkins
```

> **Note:** Replace **Jenkins** with the name assigned to your Slack App.

---

## 9.4 Install the Jenkins Slack Plugin

From Jenkins, navigate to:

```text
Manage Jenkins
→ Plugins
→ Available Plugins
```

Search for:

```text
Slack Notification
```

Install the plugin and restart Jenkins if prompted.

![Slack Notification Plugin](screenshots/20-slack-notification-plugin.png)

---

## 9.5 Configure Slack Credentials

Navigate to:

```text
Manage Jenkins
→ System
```

Next to **Credentials**, click **Add Credentials**.

Select:

```text
Secret Text
```

Configure the credential as follows.

| Field | Value |
|--------|-------|
| Scope | Global |
| Secret | Bot User OAuth Token |
| ID | Slack Bot Token |
| Description | Slack Bot Token |

Save the credential.

---

## 9.6 Configure the Slack Plugin

Continue scrolling until you reach the **Slack** section.

Configure the plugin as follows.

| Field | Value |
|--------|-------|
| Workspace | Your Slack workspace name |
| Credential | Slack Bot Token |
| Default Channel / Member ID | Your notification channel (for example `#jenkins-builds`) |

Enable:

```text
Custom Slack App Bot User
```

Click **Test Connection**.

If the configuration is successful, Jenkins will display a confirmation message indicating that the Slack integration is working correctly.

Save the configuration.

---

## 9.7 Configure Jenkins Build Notifications

Return to the Jenkins Freestyle Job.

Open **Configure**.

Under **Post-build Actions**, add:

```text
Slack Notifications
```

Enable the following notifications.

- Notify Build Start
- Notify Success
- Notify Not Built
- Notify Every Failure
- Notify Back To Normal

> **Note:** These are the notifications used for this project. You may enable additional notification events to suit your own workflow.

Expand **Notification message includes** and select:

```text
Commit list with authors and titles
```

Expand **Advanced** and configure:

| Field | Value |
|--------|-------|
| Workspace | Your Slack workspace name |
| Credential | Slack Bot Token |
| Custom Slack App Bot User | Enabled |
| Icon Emoji | `:ninja:` (or any emoji of your choice) |
| Channel / Member ID | Your notification channel |

Leave all remaining options at their default values.

Save the Jenkins job configuration and run a new build.

A successful configuration will send build start, build success and build failure notifications to your Slack channel.

![Slack Notification](screenshots/15-slack-notification.png)

---

# 10. Common Issues and Troubleshooting

| Issue | Possible Solution |
|-------|-------------------|
| Unable to access Jenkins, SonarQube, Nexus or Tomcat | Verify the EC2 instance is running, the service is active, and the required inbound security group port is open. |
| Jenkins cannot clone the GitHub repository | Confirm the repository URL, branch name, Git credentials, and GitHub Personal Access Token are correct. |
| Maven build fails | Verify the correct Maven installation is selected, the `pom.xml` path is correct, and all project dependencies can be resolved. |
| SonarQube analysis does not run | Confirm the SonarQube server is running and that the configured URL and authentication credentials or token are valid. |
| Artifact is not uploaded to Nexus | Verify the Nexus repository URLs, the `distributionManagement` section in `pom.xml`, and the Maven `settings.xml` server credentials. |
| Jenkins cannot deploy to Tomcat | Confirm the Tomcat Manager application is accessible, the Deploy to Container plugin is installed, and the configured Tomcat credentials are correct. |
| Reverse proxy is not working | Validate the Nginx configuration using `sudo nginx -t`, confirm the proxy configuration is correct, and restart the Nginx service. |
| Slack notifications are not received | Verify the Slack Notification plugin is installed, the Bot User OAuth Token is valid, the workspace and channel are correct, and the Slack bot has been invited to the notification channel. |
| GitHub push does not trigger Jenkins | Confirm the GitHub Webhook is configured correctly, Jenkins is publicly reachable, and the webhook delivery reports a successful response. |
| General troubleshooting | Review the relevant service logs (`systemctl status`, Jenkins Console Output, SonarQube logs, Nexus logs, Tomcat logs, and Nginx logs) to identify the root cause before making configuration changes. |

---

# Final Notes

This guide documents the implementation used for this project and is intended to help you reproduce the same CI/CD pipeline in your own AWS environment.

Depending on the versions of Jenkins, plugins, SonarQube, Nexus Repository Manager, Apache Tomcat, or Ubuntu available at the time of deployment, some interfaces or configuration options may differ slightly. Where applicable, substitute your own server IP addresses, credentials, repository URLs, workspace names, and authentication tokens.

For an overview of the project architecture, implementation details, screenshots, and the completed pipeline, see the [README.md](README.md) file.

