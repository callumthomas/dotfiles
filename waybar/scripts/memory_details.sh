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

# Get top memory-consuming processes for tooltip (grouped by process name)
# Note: We need to escape backslashes and quotes for JSON
tooltip=$(ps aux | awk '
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

        # Accumulate memory (RSS in KB) for each process name
        mem[cmd] += $6
    }
    END {
        # Print header
        printf "Memory Usage\\n"
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━\\n"

        # Sort by memory usage and get top 15
        PROCINFO["sorted_in"] = "@val_num_desc"
        count = 0
        for (cmd in mem) {
            if (count >= 15) break
            count++

            # Truncate process name if too long
            display_cmd = cmd
            if (length(display_cmd) > 25) {
                display_cmd = substr(display_cmd, 0, 22) "..."
            }

            # Format memory
            if (mem[cmd] > 1048576) {
                mem_str = sprintf("%.1fG", mem[cmd]/1048576)
            } else if (mem[cmd] > 1024) {
                mem_str = sprintf("%.1fM", mem[cmd]/1024)
            } else {
                mem_str = sprintf("%dK", mem[cmd])
            }

            printf "%-25s %7s\\n", display_cmd, mem_str
        }

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
