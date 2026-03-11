#!/bin/bash

# --- Core Configuration (BLE & LED) ---
INSTALL_TARGET="/opt/moonboard"
BLE_SERVICE="com.moonboard.service"
LED_SERVICE="moonboard_led.service"

# --- Web Configuration ---
WEB_APP_NAME="moonboard_web"
WEB_TARGET="/home/moonboard_web"
WEB_SERVICE="moonboard_web"
WEB_PORT=3000
# Determine the user for the web service. Prioritize the user running the script via sudo,
# then the primary user (UID 1000), and finally default to 'pi'.
WEB_USER="${SUDO_USER:-$(id -nu 1000 2>/dev/null || echo "pi")}"

# Note: automated-install determines the core user dynamically (usually 'pi'),
# while web-install previously defaulted to 'admin'. This change aligns the user logic.