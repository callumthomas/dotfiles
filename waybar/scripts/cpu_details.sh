#!/bin/bash

# Get CPU usage percentage
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
cpu_usage_int=$(printf "%.0f" "$cpu_usage")

# Build detailed tooltip with CPU info
if [ "$cpu_usage_int" -ge 90 ]; then
    color="#FF4040"
elif [ "$cpu_usage_int" -ge 75 ]; then
    color="#FF9F0A"
elif [ "$cpu_usage_int" -ge 60 ]; then
    color="#FFA500"
elif [ "$cpu_usage_int" -ge 45 ]; then
    color="#FFFF00"
else
    color="#00FF7F"
fi

tooltip=$(printf "CPU Usage\n━━━━━━━━━━━━━━━━━━━━━━━━━\nTotal  <span color='%s'>%3d%%</span>" "$color" "$cpu_usage_int")

# Determine class based on CPU usage
if [ "$cpu_usage_int" -gt 90 ]; then
  class="critical"
elif [ "$cpu_usage_int" -gt 75 ]; then
  class="warning"
elif [ "$cpu_usage_int" -gt 60 ]; then
  class="high"
elif [ "$cpu_usage_int" -gt 45 ]; then
  class="moderate"
else
  class="normal"
fi

# Output JSON for Waybar
printf '{"text":"%s%%","tooltip":"%s","class":"cpu-%s","percentage":%s}\n' \
  "$cpu_usage_int" \
  "$tooltip" \
  "$class" \
  "$cpu_usage_int"
