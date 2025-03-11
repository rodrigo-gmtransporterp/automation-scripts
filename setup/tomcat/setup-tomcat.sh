#!/bin/bash

# Check if the version argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <tomcat_version>"
  echo "Example: $0 9.0.71"
  exit 1
fi

TOMCAT_VERSION=$1
TOMCAT_DIR="apache-tomcat-$TOMCAT_VERSION"
BASE_URL="https://downloads.apache.org/tomcat/tomcat-${TOMCAT_VERSION:0:1}"
FILE_NAME="apache-tomcat-$TOMCAT_VERSION.tar.gz"
DEST_DIR="/opt/tomcat-$TOMCAT_VERSION"
DOWNLOAD_URL="$BASE_URL/v$TOMCAT_VERSION/bin/$FILE_NAME"
SERVICE_FILE="/etc/systemd/system/tomcat-$TOMCAT_VERSION.service"

# Check if the directory already exists in /opt
if [ -d "$DEST_DIR" ]; then
  echo "Tomcat version $TOMCAT_VERSION is already installed in $DEST_DIR."
  echo "Skipping the installation process."
  exit 0
fi

# Create a tomcat user with /bin/false shell to restrict access
if ! id "tomcat" &>/dev/null; then
  echo "Creating tomcat user..."
  sudo useradd -r -s /bin/false tomcat
else
  echo "User 'tomcat' already exists."
fi

# Download the specified version of Tomcat
echo "Downloading Tomcat version $TOMCAT_VERSION..."
curl -O $DOWNLOAD_URL

# Check if the download was successful
if [ $? -ne 0 ]; then
  echo "Failed to download Tomcat version $TOMCAT_VERSION."
  echo "Please check the version number and try again."
  exit 1
fi

# Extract the downloaded tarball
echo "Extracting $FILE_NAME..."
tar -xzf $FILE_NAME

# Clean up the tarball file
rm -f $FILE_NAME

echo "Tomcat $TOMCAT_VERSION downloaded and extracted successfully!"

# Move the directory to /opt with the versioned name
if [ -d "$TOMCAT_DIR" ]; then
  echo "Moving $TOMCAT_DIR to $DEST_DIR..."
  sudo mv $TOMCAT_DIR $DEST_DIR
else
  echo "Directory $TOMCAT_DIR does not exist. Please ensure it was extracted correctly".
  exit 1
fi

# Change ownership of the Tomcat directory to the tomcat user
echo "Creating ownership of $DEST_DIR to the tomcat user..."
sudo chown -R tomcat:tomcat $DEST_DIR

# Modify context.xml to comment out the <Valve> section
for CONTEXT_XML in $DEST_DIR/webapps/{manager,host-manager}/META-INF/context.xml; do
  if [ -f "$CONTEXT_XML" ]; then
    echo "Commenting out <Valve> section in $CONTEXT_XML..."
    sudo sed -i 's|<Valve className="org.apache.catalina.valves.RemoteAddrValve".*|<!--&-->|' $CONTEXT_XML
    sudo sed -i '/<Valve className="org.apache.catalina.valves.RemoteAddrValve"/,/\/>/ s|$|-->|' $CONTEXT_XML
  else
    echo "File $CONTEXT_XML not found. Skipping modification."
  fi
done

# Configure tomcat-users.xml
TOMCAT_USERS="$DEST_DIR/conf/tomcat-users.xml"

if [ -f "$TOMCAT_USERS" ]; then
  echo "Configuring $TOMCAT_USERS..."
  sudo cp $TOMCAT_USERS $TOMCAT_USERS.bak # Backup the original file
  sudo bash -c "cat > $TOMCAT_USERS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  <role rolename="manager-gui"/>
  <role rolename="admin-gui"/>
  <user username="admin" password="password" roles="manager-gui,admin-gui"/>
</tomcat-users>
EOL
  echo "Tomcat users configured with admin credentials."
else
  echo "File $TOMCAT_USERS does not exist. Please check your installation."
  exit 1
fi

# Create a systemd service for Tomcat
echo "Creating systemd service file for Tomcat..."
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Apache Tomcat $TOMCAT_VERSION
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment=JAVA_HOME=/usr/lib/jvm/default-java
Environment=CATALINA_PID=$DEST_DIR/temp/tomcat.pid
Environment=CATALINA_HOME=$DEST_DIR
Environment=CATALINA_BASE=$DEST_DIR
ExecStart=$DEST_DIR/bin/startup.sh
ExecStop=$DEST_DIR/bin/shutdown.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd to apply the new service file
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable and start the Tomcat service
echo "Enabling and starting the Tomcat service..."
sudo systemctl enable tomcat-$TOMCAT_VERSION
sudo systemctl start tomcat-$TOMCAT_VERSION

echo "Tomcat $TOMCAT_VERSION successfully installed, configured, and running as a service!"
