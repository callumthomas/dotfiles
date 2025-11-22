#!/bin/bash

# Get CPU usage percentage
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
cpu_usage_int=$(printf "%.0f" "$cpu_usage")

# Build detailed tooltip with top CPU-consuming processes
tooltip=$(ps aux --sort=-%cpu | head -n 16 | awk '
    BEGIN {
        printf "CPU Usage\\n"
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━\\n"
    }
    NR==1 {next}  # Skip header
    {
        # Get clean process name
        cmd = $11
        # Remove path if present
        gsub(/.*\//, "", cmd)
        # Remove arguments
        gsub(/ .*/, "", cmd)
        # Remove brackets
        gsub(/[\[\]]/, "", cmd)
        # Truncate if too long
        if (length(cmd) > 25) {
            cmd = substr(cmd, 0, 22) "..."
        }

        # Get CPU percentage
        cpu_pct = int($3 + 0.5)

        # Color coding based on CPU usage
        if (cpu_pct >= 80) color = "#FF4040"
        else if (cpu_pct >= 60) color = "#FF9F0A"
        else if (cpu_pct >= 40) color = "#FFA500"
        else if (cpu_pct >= 20) color = "#FFFF00"
        else color = "#00FF7F"

        printf "%-25s <span color='\'%s\''>%3d%%</span>\\n", cmd, color, cpu_pct
    }
    END {
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━\\n"
    }
' | sed 's/'\''/\\"/g')

# Determine color for total CPU
if [ "$cpu_usage_int" -ge 90 ]; then
    total_color="#FF4040"
elif [ "$cpu_usage_int" -ge 75 ]; then
    total_color="#FF9F0A"
elif [ "$cpu_usage_int" -ge 60 ]; then
    total_color="#FFA500"
elif [ "$cpu_usage_int" -ge 45 ]; then
    total_color="#FFFF00"
else
    total_color="#00FF7F"
fi

# Add total to tooltip
tooltip="${tooltip}Total  <span color='${total_color}'>${cpu_usage_int}%</span>"

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
