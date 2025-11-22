#!/bin/bash

# Get main CPU temperature for display
cpu_temp=$(sensors | awk '/Tctl:/ {gsub(/[+°C]/, "", $2); print int($2)}')

# Build detailed tooltip with all temperatures
tooltip=$(sensors | awk '
    BEGIN {
        printf "System Temperatures\\n"
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\n"
        section = ""
    }

    # Store the line after "Adapter:" as section name
    {
        if (prev_line != "" && /^Adapter:/) {
            section = prev_line
            # Clean up section name
            if (section ~ /k10temp/) section = "CPU"
            else if (section ~ /amdgpu/) section = "GPU"
            else if (section ~ /nvme/) section = "NVMe"
            else if (section ~ /r8169/) section = "Network"
            else if (section ~ /spd5118/) section = "RAM"
            else if (section ~ /hidpp/) section = "Battery"
            else section = "Other"
        }
        prev_line = $0
    }

    # Process temperature lines
    /temp[0-9]*:|Tctl:|Tccd[0-9]*:|edge:|Composite:|Sensor [0-9]*:/ {
        # Extract temperature value
        temp_value = ""
        for (i = 2; i <= NF; i++) {
            if ($i ~ /\+[0-9]+\.[0-9]+°C/) {
                temp_value = $i
                gsub(/[+°C]/, "", temp_value)
                break
            }
        }

        if (temp_value == "" || section == "") next

        # Get sensor name
        sensor_name = $1
        gsub(/:/, "", sensor_name)

        # Format sensor names nicely
        if (sensor_name == "Tctl") sensor_name = "Package"
        else if (sensor_name ~ /Tccd/) sensor_name = "CCD" substr(sensor_name, 5)
        else if (sensor_name == "edge") sensor_name = "Edge"
        else if (sensor_name == "Composite") sensor_name = "Composite"
        else if (sensor_name ~ /Sensor/) sensor_name = $1 " " $2
        else if (sensor_name ~ /temp/) {
            num = sensor_name
            gsub(/temp/, "", num)
            sensor_name = "Sensor " num
        }

        # Build display string
        temp_int = int(temp_value)

        # Color coding based on temperature
        if (section == "CPU" || section == "GPU") {
            if (temp_int >= 80) {
                color = "#FF4040"
            } else if (temp_int >= 70) {
                color = "#FFA500"
            } else {
                color = "#00FF7F"
            }
        } else {
            if (temp_int >= 60) {
                color = "#FF4040"
            } else if (temp_int >= 50) {
                color = "#FFA500"
            } else {
                color = "#00FF7F"
            }
        }
		
		sect_sensor = section " - " sensor_name

        printf "%-20s <span color='\'%s\''>%3d°C</span>\\n", sect_sensor, color, temp_int
    }

    END {
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\n"
    }
')

# Determine urgency class based on CPU temperature
class="temperature"
if [ "$cpu_temp" -gt 85 ]; then
  class="critical"
elif [ "$cpu_temp" -gt 75 ]; then
  class="warning"
fi

# Output JSON for Waybar
printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
  "$cpu_temp" \
  "$tooltip" \
  "$class"
