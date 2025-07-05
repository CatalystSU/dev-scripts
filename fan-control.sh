#!/bin/bash

# Fixed ASUS laptop fan control setup script
# This version works with laptops that only support PWM modes 0 (off) and 2 (auto)

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PWM_ENABLE="/sys/devices/platform/asus-nb-wmi/hwmon/hwmon6/pwm1_enable"
FAN_CONTROL_SCRIPT="/usr/local/bin/fan-control.sh"
SERVICE_FILE="/etc/systemd/system/custom-fan-control.service"
LOG_FILE="/var/log/fan-control.log"

# Function to print colored output
print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
  echo -e "${BLUE}[SETUP]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  print_error "This script must be run as root (use sudo)"
  exit 1
fi

print_header "ASUS Laptop Fan Control Setup (Fixed Version)"
echo "This script will:"
echo "1. Detect your thermal zones"
echo "2. Create a custom fan control script (using only OFF/AUTO modes)"
echo "3. Set up a systemd service for automatic startup"
echo "4. Configure temperature thresholds for fan on/off"
echo ""

# Check if PWM control is available
if [[ ! -f "$PWM_ENABLE" ]]; then
  print_error "PWM control not found at $PWM_ENABLE"
  print_error "This script is designed for ASUS laptops with asus-nb-wmi driver"
  exit 1
fi

print_status "PWM control found at $PWM_ENABLE"

# Test PWM modes
print_header "Testing PWM modes..."
echo "Current PWM mode: $(cat $PWM_ENABLE)"

# Test mode 0
echo 0 >"$PWM_ENABLE" 2>/dev/null
if [[ $(cat "$PWM_ENABLE") -eq 0 ]]; then
  print_status "Mode 0 (OFF) - supported"
else
  print_error "Mode 0 (OFF) - not supported"
fi

# Test mode 2
echo 2 >"$PWM_ENABLE" 2>/dev/null
if [[ $(cat "$PWM_ENABLE") -eq 2 ]]; then
  print_status "Mode 2 (AUTO) - supported"
else
  print_error "Mode 2 (AUTO) - not supported"
fi

# Test mode 1 (we know it fails, but let's confirm)
echo 1 >"$PWM_ENABLE" 2>/dev/null
if [[ $(cat "$PWM_ENABLE") -eq 1 ]]; then
  print_status "Mode 1 (MANUAL) - supported"
  MANUAL_MODE_SUPPORTED=true
else
  print_warning "Mode 1 (MANUAL) - not supported (this is normal for ASUS laptops)"
  MANUAL_MODE_SUPPORTED=false
fi

# Reset to auto mode
echo 2 >"$PWM_ENABLE"

# Detect thermal zones
print_header "Detecting thermal zones..."
CPU_THERMAL_ZONE=""
for zone in /sys/class/thermal/thermal_zone*/; do
  if [[ -f "$zone/type" ]]; then
    zone_type=$(cat "$zone/type" 2>/dev/null || echo "unknown")
    zone_temp=$(cat "$zone/temp" 2>/dev/null || echo "0")
    zone_temp_c=$((zone_temp / 1000))

    echo "  $(basename $zone): $zone_type (${zone_temp_c}°C)"

    # Try to identify CPU thermal zone
    if [[ "$zone_type" == *"cpu"* ]] || [[ "$zone_type" == *"x86_pkg_temp"* ]] || [[ "$zone_type" == *"coretemp"* ]]; then
      CPU_THERMAL_ZONE="$zone/temp"
      print_status "CPU thermal zone detected: $zone ($zone_type)"
    fi
  fi
done

# Fallback to thermal_zone0 if no CPU-specific zone found
if [[ -z "$CPU_THERMAL_ZONE" ]]; then
  CPU_THERMAL_ZONE="/sys/class/thermal/thermal_zone0/temp"
  print_warning "No CPU-specific thermal zone found, using thermal_zone0"
fi

# Create the fan control script
print_header "Creating fan control script..."
cat >"$FAN_CONTROL_SCRIPT" <<'EOF'
#!/bin/bash

# Custom ASUS laptop fan control script
# This version works with laptops that only support OFF (0) and AUTO (2) modes

# Configuration
PWM_ENABLE="/sys/devices/platform/asus-nb-wmi/hwmon/hwmon6/pwm1_enable"
THERMAL_ZONE="__THERMAL_ZONE__"
LOG_FILE="/var/log/fan-control.log"

# Temperature thresholds (in Celsius)
TEMP_FAN_OFF=55      # Fan off below this temperature
TEMP_FAN_ON=58       # Fan on above this temperature (hysteresis)

# Fan control modes (only 0 and 2 are supported)
FAN_OFF=0        # Fan disabled
FAN_AUTO=2       # Automatic control

# Current state tracking
current_mode=""
last_temp=0

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to get CPU temperature
get_cpu_temp() {
    if [[ -f "$THERMAL_ZONE" ]]; then
        local temp_raw=$(cat "$THERMAL_ZONE")
        echo $((temp_raw / 1000))
    else
        echo 0
    fi
}

# Function to set fan mode
set_fan_mode() {
    local mode=$1
    local description=$2
    
    if [[ "$current_mode" != "$mode" ]]; then
        echo "$mode" > "$PWM_ENABLE" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            current_mode="$mode"
            log_message "Fan mode changed to: $description (mode $mode)"
        else
            log_message "ERROR: Failed to set fan mode $mode"
        fi
    fi
}

# Function to determine fan setting based on temperature
control_fan() {
    local temp=$1
    
    # Use hysteresis to prevent rapid switching
    if [[ "$current_mode" == "$FAN_OFF" ]]; then
        # Fan is currently off, turn on when temp reaches TEMP_FAN_ON
        if [[ $temp -ge $TEMP_FAN_ON ]]; then
            set_fan_mode $FAN_AUTO "AUTO (temp: ${temp}°C >= ${TEMP_FAN_ON}°C)"
        fi
    else
        # Fan is currently on (auto mode), turn off when temp drops below TEMP_FAN_OFF
        if [[ $temp -lt $TEMP_FAN_OFF ]]; then
            set_fan_mode $FAN_OFF "OFF (temp: ${temp}°C < ${TEMP_FAN_OFF}°C)"
        fi
    fi
}

# Function to handle cleanup on exit
cleanup() {
    log_message "Fan control script stopping - restoring automatic control"
    set_fan_mode $FAN_AUTO "AUTO (script exit)"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Initialize fan to auto mode
set_fan_mode $FAN_AUTO "AUTO (script startup)"

# Main monitoring loop
log_message "Starting custom fan control (PID: $$)"
log_message "Temperature thresholds: Fan OFF<${TEMP_FAN_OFF}°C, Fan ON>=${TEMP_FAN_ON}°C"

while true; do
    temp=$(get_cpu_temp)
    
    if [[ $temp -gt 0 ]]; then
        control_fan $temp
        
        # Log temperature every minute or when significant change
        if [[ $(($(date +%s) % 60)) -eq 0 ]] || [[ $((temp - last_temp)) -gt 5 ]] || [[ $((last_temp - temp)) -gt 5 ]]; then
            log_message "Temperature: ${temp}°C, Fan mode: $current_mode"
        fi
        
        last_temp=$temp
    else
        log_message "ERROR: Could not read temperature"
    fi
    
    sleep 5  # Check every 5 seconds
done
EOF

# Replace the thermal zone placeholder
sed -i "s|__THERMAL_ZONE__|$CPU_THERMAL_ZONE|g" "$FAN_CONTROL_SCRIPT"

# Make script executable
chmod +x "$FAN_CONTROL_SCRIPT"
print_status "Fan control script created at $FAN_CONTROL_SCRIPT"

# Create systemd service
print_header "Creating systemd service..."
cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Custom Fan Control Service
After=multi-user.target

[Service]
Type=simple
ExecStart=$FAN_CONTROL_SCRIPT
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

print_status "Systemd service created at $SERVICE_FILE"

# Create log file with proper permissions
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Stop existing service if running
if systemctl is-active --quiet custom-fan-control.service; then
  print_status "Stopping existing service..."
  systemctl stop custom-fan-control.service
fi

# Reload systemd and enable service
print_header "Enabling and starting service..."
systemctl daemon-reload
systemctl enable custom-fan-control.service
systemctl start custom-fan-control.service

# Wait a moment for service to start
sleep 2

# Check service status
if systemctl is-active --quiet custom-fan-control.service; then
  print_status "Service started successfully!"
else
  print_error "Service failed to start. Check logs with: journalctl -u custom-fan-control.service"
fi

print_header "Setup Complete!"
echo ""
echo "Your fan control is now configured with these thresholds:"
echo "  • Fan OFF: Below 55°C"
echo "  • Fan ON (AUTO): Above 58°C"
echo "  • Uses hysteresis to prevent rapid on/off cycling"
echo ""
echo "Note: Your laptop only supports OFF and AUTO modes, not manual speed control."
echo "This setup prevents the rapid cycling you were experiencing."
echo ""
echo "Useful commands:"
echo "  • Check service status: systemctl status custom-fan-control.service"
echo "  • View logs: tail -f $LOG_FILE"
echo "  • Stop service: systemctl stop custom-fan-control.service"
echo "  • Start service: systemctl start custom-fan-control.service"
echo "  • Disable service: systemctl disable custom-fan-control.service"
echo ""
echo "To modify temperature thresholds, edit: $FAN_CONTROL_SCRIPT"
echo "Then restart the service: systemctl restart custom-fan-control.service"
echo ""
print_warning "Monitor your temperatures for the first few hours!"
echo "Current temperature: $(cat $CPU_THERMAL_ZONE 2>/dev/null | awk '{print $1/1000}')°C"
