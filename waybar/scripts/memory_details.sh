#!/bin/bash

# Get memory usage percentage for main display
mem_info=$(free -b | grep Mem)
mem_used=$(echo $mem_info | awk '{print $3}')
mem_total=$(echo $mem_info | awk '{print $2}')
mem_percent=$(echo "$mem_used $mem_total" | awk '{printf "%.1f", $1/$2 * 100.0}')
mem_percent_int=$(echo "$mem_used $mem_total" | awk '{printf "%d", $1/$2 * 100.0}')

# Convert to human-readable for display
mem_used_h=$(echo $mem_used | awk '{printf "%.1fG", $1/1024/1024/1024}')
mem_total_h=$(echo $mem_total | awk '{printf "%.1fG", $1/1024/1024/1024}')

# Get top memory-consuming processes for tooltip
# Note: We need to escape backslashes and quotes for JSON
tooltip=$(ps aux --sort=-%mem | head -n 16 | awk '
    BEGIN {
        printf "Memory Usage\\n"
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
        # Remove brackets (like [kworker/0:2])
        gsub(/[\[\]]/, "", cmd)
        # Truncate if too long
        if (length(cmd) > 25) {
            cmd = substr(cmd, 0, 22) "..."
        }
        
        # Format memory
        if ($6 > 1048576) {
            mem_str = sprintf("%.1fG", $6/1048576)
        } else if ($6 > 1024) {
            mem_str = sprintf("%.1fM", $6/1024)
        } else {
            mem_str = sprintf("%dK", $6)
        }
        
        # Create a bar graph
        bar_filled = int($4 * 15 / 100)
        if (bar_filled > 15) bar_filled = 15
        if (bar_filled < 0) bar_filled = 0
        
        bar = ""
        for (i = 0; i < bar_filled; i++) {
            bar = bar "▓"
        }
        for (i = bar_filled; i < 15; i++) {
            bar = bar "░"
        }
        
        printf "%-15s %7s\\n", cmd, mem_str
    }
    END {
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━\\n"
    }
')

# Add summary to tooltip
tooltip="${tooltip}Total: ${mem_used_h} / ${mem_total_h}"

# Determine urgency class based on usage (using integer comparison)
class="memory"
if [ "$mem_percent_int" -gt 90 ]; then
  class="critical"
elif [ "$mem_percent_int" -gt 70 ]; then
  class="warning"
fi

# Output JSON for Waybar - proper escaping is critical here
printf '{"text":"%s","alt":"%s%%","tooltip":"%s","class":"%s","percentage":%s}\n' \
  "$mem_percent" \
  "$mem_percent" \
  "$tooltip" \
  "$class" \
  "$mem_percent"
