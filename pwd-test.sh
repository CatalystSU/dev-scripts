#!/bin/bash

PWM_ENABLE="/sys/devices/platform/asus-nb-wmi/hwmon/hwmon6/pwm1_enable"

echo "Current PWM enable value:"
cat $PWM_ENABLE

echo -e "\nTesting PWM modes:"

# Test mode 0 (off)
echo "Testing mode 0 (off)..."
echo 0 | sudo tee $PWM_ENABLE
echo "Result: $(cat $PWM_ENABLE)"
sleep 2

# Test mode 1 (manual)
echo "Testing mode 1 (manual)..."
echo 1 | sudo tee $PWM_ENABLE
echo "Result: $(cat $PWM_ENABLE)"
sleep 2

# Test mode 2 (auto)
echo "Testing mode 2 (auto)..."
echo 2 | sudo tee $PWM_ENABLE
echo "Result: $(cat $PWM_ENABLE)"

echo -e "\nFan RPM during test:"
cat /sys/devices/platform/asus-nb-wmi/hwmon/hwmon6/fan1_input
