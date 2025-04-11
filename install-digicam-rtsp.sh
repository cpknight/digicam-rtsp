#!/bin/bash

# Paths
SCRIPT_NAME="digicam-rtsp.sh"
INSTALL_PATH="/usr/local/bin/$SCRIPT_NAME"
SERVICE_NAME="digicam-rtsp.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)."
    exit 1
fi

# Check if main script exists in current directory
if [ ! -f "$SCRIPT_NAME" ]; then
    echo "Error: $SCRIPT_NAME not found in current directory."
    exit 1
fi

# Install the main script
echo "Installing $SCRIPT_NAME to $INSTALL_PATH..."
cp "$SCRIPT_NAME" "$INSTALL_PATH"
chmod 755 "$INSTALL_PATH"
if [ $? -eq 0 ]; then
    echo "Main script installed successfully."
else
    echo "Error: Failed to install main script."
    exit 1
fi

# Create the systemd service file
echo "Creating systemd service at $SERVICE_PATH..."
cat > "$SERVICE_PATH" << 'EOF'
[Unit]
Description=Digital Camera RTSP Streaming Service
After=network.target systemd-udev-settle.service
Wants=systemd-udev-settle.service

[Service]
ExecStart=/usr/local/bin/digicam-rtsp.sh
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
User=root
Group=root
WorkingDirectory=/tmp
KillMode=process
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

if [ $? -eq 0 ]; then
    echo "Systemd service file created successfully."
else
    echo "Error: Failed to create systemd service file."
    exit 1
fi

# Set service file permissions
chmod 644 "$SERVICE_PATH"

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reload
if [ $? -eq 0 ]; then
    echo "Systemd daemon reloaded successfully."
else
    echo "Error: Failed to reload systemd daemon."
    exit 1
fi

# Enable the service
echo "Enabling $SERVICE_NAME..."
systemctl enable "$SERVICE_NAME"
if [ $? -eq 0 ]; then
    echo "Service enabled successfully."
else
    echo "Error: Failed to enable service."
    exit 1
fi

# Start the service (optional, comment out if you want to start manually)
echo "Starting $SERVICE_NAME..."
systemctl start "$SERVICE_NAME"
if [ $? -eq 0 ]; then
    echo "Service started successfully."
else
    echo "Error: Failed to start service."
    exit 1
fi

echo "Installation complete! You can manage the service with:"
echo "  sudo systemctl start $SERVICE_NAME"
echo "  sudo systemctl stop $SERVICE_NAME"
echo "  sudo systemctl status $SERVICE_NAME"
