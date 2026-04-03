import { createPoll } from "ags/time"
import { execAsync } from "ags/process"

export interface TlpState {
  mode: string         // AC | BAT
  governor: string     // performance | powersave | etc.
  boost: boolean
  platform: string     // performance | balanced | low-power
  chargeStart: number  // e.g. 75
  chargeStop: number   // e.g. 80
}

const EMPTY: TlpState = {
  mode: "unknown",
  governor: "unknown",
  boost: false,
  platform: "unknown",
  chargeStart: 75,
  chargeStop: 80,
}

async function readTlp(): Promise<TlpState> {
  try {
    const script = [
      `echo "MODE=$(tlp-stat -s 2>/dev/null | grep 'Mode' | awk '{print $NF}')"`,
      `echo "GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"`,
      `echo "BOOST=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null)"`,
      `echo "PLATFORM=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)"`,
      `echo "START=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null || echo 75)"`,
      `echo "STOP=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo 80)"`,
    ].join(" && ")

    const out = await execAsync(["bash", "-c", script])
    const map: Record<string, string> = {}
    for (const line of out.split("\n")) {
      const eq = line.indexOf("=")
      if (eq > 0) {
        map[line.slice(0, eq)] = line.slice(eq + 1).trim()
      }
    }

    return {
      mode: map["MODE"] || "unknown",
      governor: map["GOV"] || "unknown",
      boost: map["BOOST"] === "1",
      platform: map["PLATFORM"] || "unknown",
      chargeStart: parseInt(map["START"] || "75", 10),
      chargeStop: parseInt(map["STOP"] || "80", 10),
    }
  } catch {
    return EMPTY
  }
}

export const tlpState = createPoll<TlpState>(EMPTY, 5000, readTlp)

export async function setFullCharge(full: boolean): Promise<void> {
  const [start, stop] = full ? [95, 100] : [75, 80]
  await execAsync([
    "bash", "-c",
    `echo ${start} | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold && ` +
    `echo ${stop} | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold`,
  ]).catch(console.error)
}
