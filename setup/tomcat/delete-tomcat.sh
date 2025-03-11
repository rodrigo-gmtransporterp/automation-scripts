#!/bin/bash

# Check if the version argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <tomcat_version>"
  echo "Example: $0 10.9.100"
  exit 1
fi

TOMCAT_VERSION=$1
DEST_DIR="/opt/tomcat-$TOMCAT_VERSION"
SERVICE_FILE="/etc/systemd/system/tomcat-$TOMCAT_VERSION.service"

# Check if the directory exists
if [ -d "$DEST_DIR" ]; then
  echo "Stopping and removing Tomcat service..."
  # Stop the systemd service if it's running
  if systemctl is-active --quiet tomcat-$TOMCAT_VERSION; then
    sudo systemctl stop tomcat-$TOMCAT_VERSION
  fi

  # Disable the service to prevent it from starting on boot
  sudo systemctl disable tomcat-$TOMCAT_VERSION

  # Remove the service file
  if [ -f "$SERVICE_FILE" ]; then
    echo "Removing service file $SERVICE_FILE..."
    sudo rm -f $SERVICE_FILE
  else
    echo "Service file $SERVICE_FILE not found. Skipping removal."
  fi

  # Reload systemd to reflect the service removal
  echo "Reloading systemd daemon..."
  sudo systemctl daemon-reload

  # Remove the Tomcat directory
  echo "Removing Tomcat directory $DEST_DIR..."
  sudo rm -rf $DEST_DIR

  echo "Tomcat version $TOMCAT_VERSION has been successfully removed."
else
  echo "Tomcat directory $DEST_DIR does not exist. Nothing to remove."
fi
