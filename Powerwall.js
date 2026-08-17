.pragma library

// Live Powerwall projection. Entity ids are this house's Tesla Energy site;
// the panel only renders what project() returns.

var CHARGE_ID = "sensor.home_percentage_charged"
var BATTERY_POWER_ID = "sensor.home_battery_power"
var LOAD_POWER_ID = "sensor.home_load_power"

// Below this, treat the battery as idle rather than flickering Charging/Using.
var IDLE_KW = 0.05

function parseNumber(state) {
  if (typeof state === "number" && isFinite(state)) return state
  if (typeof state !== "string") return null
  var value = parseFloat(state)
  return isFinite(value) ? value : null
}

function isMissing(entity) {
  if (!entity) return true
  var state = typeof entity.state === "string" ? entity.state : ""
  return state === "" || state === "unavailable" || state === "unknown"
}

function formatKw(value) {
  if (value === null || value === undefined || !isFinite(value)) return "—"
  var mag = Math.abs(value)
  if (mag >= 10) return mag.toFixed(1) + " kW"
  return mag.toFixed(1) + " kW"
}

function formatPercent(value) {
  if (value === null || value === undefined || !isFinite(value)) return "—"
  return Math.round(value) + "%"
}

function batteryIcon(percent, charging) {
  if (charging) return "󰂄"                 // md-battery-charging
  if (percent === null || percent === undefined) return "󰂎"  // md-battery-outline
  if (percent >= 90) return "󰁹"
  if (percent >= 70) return "󰂂"
  if (percent >= 50) return "󰁿"
  if (percent >= 30) return "󰁽"
  if (percent >= 15) return "󰁻"
  return "󰂎"
}

function resolvedId(configured, fallback, map) {
  if (configured) return configured
  if (map && map[fallback]) return fallback
  return ""
}

function project(states, chargeId, batteryId, loadId) {
  var map = states && typeof states === "object" ? states : {}
  var chargeEntity = map[resolvedId(chargeId, CHARGE_ID, map)]
  var batteryEntity = map[resolvedId(batteryId, BATTERY_POWER_ID, map)]
  var loadEntity = map[resolvedId(loadId, LOAD_POWER_ID, map)]
  if (isMissing(chargeEntity)) {
    return {
      available: false,
      percent: null,
      fraction: 0,
      percentText: "—",
      usageText: "—",
      flowLabel: "",
      subtitle: "",
      charging: false,
      discharging: false,
      icon: batteryIcon(null, false)
    }
  }

  var percent = parseNumber(chargeEntity.state)
  var batteryKw = isMissing(batteryEntity) ? null : parseNumber(batteryEntity.state)
  var loadKw = isMissing(loadEntity) ? null : parseNumber(loadEntity.state)
  var charging = batteryKw !== null && batteryKw < -IDLE_KW
  var discharging = batteryKw !== null && batteryKw > IDLE_KW

  var flowLabel = "Idle"
  if (charging) flowLabel = "Charging " + formatKw(batteryKw)
  else if (discharging) flowLabel = "Using " + formatKw(batteryKw)

  var usageText = formatKw(loadKw)
  var subtitle = "Home " + usageText
  if (flowLabel) subtitle += " · " + flowLabel

  return {
    available: true,
    percent: percent,
    fraction: percent === null ? 0 : Math.max(0, Math.min(1, percent / 100)),
    percentText: formatPercent(percent),
    usageText: usageText,
    flowLabel: flowLabel,
    subtitle: subtitle,
    charging: charging,
    discharging: discharging,
    icon: batteryIcon(percent, charging)
  }
}
