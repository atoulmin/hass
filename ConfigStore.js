.pragma library

var KEYS = [
  "baseUrl", "localUrl", "remoteUrl", "demoMode", "favorites", "demoFavorites", "groupByArea",
  "showEntityIcons", "selectedTab", "displayNameOverrides", "iconOverrides",
  "cameraIds", "chargeEntityId", "batteryPowerEntityId", "loadPowerEntityId",
  "assistPipelineId"
]

function stringList(value, fallback) {
  if (!Array.isArray(value)) return fallback.slice()
  var out = []
  var seen = {}
  for (var i = 0; i < value.length; i++) {
    if (typeof value[i] === "string"
        && /^[a-z0-9_]+\.[a-z0-9_]+$/.test(value[i])
        && !seen[value[i]]) {
      seen[value[i]] = true
      out.push(value[i])
    }
  }
  return out
}

function entityId(value) {
  if (typeof value !== "string") return ""
  return /^[a-z0-9_]+\.[a-z0-9_]+$/.test(value) ? value : ""
}

function pipelineId(value) {
  if (typeof value !== "string") return ""
  var id = value.trim()
  if (!id || id.length > 128) return ""
  return /^[A-Za-z0-9_-]+$/.test(id) ? id : ""
}

function plainMap(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {}
  var out = {}
  for (var key in value) {
    if (key === "__proto__" || key === "constructor" || key === "prototype") continue
    if (typeof value[key] === "string") out[key] = value[key]
  }
  return out
}

function parse(text, demoDefaults) {
  var raw = {}
  var error = ""
  try {
    raw = text ? JSON.parse(text) : {}
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
      raw = {}
      error = "config.json must contain a JSON object"
    }
  } catch (exception) {
    raw = {}
    error = "config.json is not valid JSON"
  }

  return {
    error: error,
    config: {
      baseUrl: typeof raw.localUrl === "string" && raw.localUrl
        ? raw.localUrl
        : (typeof raw.baseUrl === "string" ? raw.baseUrl : ""),
      localUrl: typeof raw.localUrl === "string" && raw.localUrl
        ? raw.localUrl
        : (typeof raw.baseUrl === "string" ? raw.baseUrl : ""),
      remoteUrl: typeof raw.remoteUrl === "string" ? raw.remoteUrl : "",
      demoMode: raw.demoMode === true,
      favorites: stringList(raw.favorites, []),
      demoFavorites: stringList(raw.demoFavorites,
                                Array.isArray(demoDefaults) ? demoDefaults : []),
      groupByArea: raw.groupByArea === true,
      showEntityIcons: raw.showEntityIcons !== false,
      selectedTab: typeof raw.selectedTab === "string" && raw.selectedTab
        ? raw.selectedTab : "favorites",
      displayNameOverrides: plainMap(raw.displayNameOverrides),
      iconOverrides: plainMap(raw.iconOverrides),
      cameraIds: stringList(raw.cameraIds, []).filter(function(id) {
        return id.indexOf("camera.") === 0
      }).slice(0, 6),
      chargeEntityId: entityId(raw.chargeEntityId),
      batteryPowerEntityId: entityId(raw.batteryPowerEntityId),
      loadPowerEntityId: entityId(raw.loadPowerEntityId),
      assistPipelineId: pipelineId(raw.assistPipelineId)
    }
  }
}

function merge(current, patch) {
  var result = {}
  for (var i = 0; i < KEYS.length; i++) {
    var key = KEYS[i]
    result[key] = current[key]
  }
  for (var p = 0; p < KEYS.length; p++) {
    var patchKey = KEYS[p]
    if (Object.prototype.hasOwnProperty.call(patch || {}, patchKey)) {
      result[patchKey] = patch[patchKey]
    }
  }
  return result
}

function serialize(config) {
  return JSON.stringify(config, null, 2) + "\n"
}
