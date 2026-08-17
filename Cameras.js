.pragma library

// The four Frigate cameras shown above Powerwall. Still frames only.

var CAMERAS = [
  { id: "camera.frontyard", title: "Frontyard", stream: "Frontyard" },
  { id: "camera.driveway", title: "Driveway", stream: "Driveway" },
  { id: "camera.backyard", title: "Backyard", stream: "Backyard" },
  { id: "camera.rear", title: "Rearyard", stream: "Rear" }
]

function defaultIds() {
  var out = []
  for (var i = 0; i < CAMERAS.length; i++) out.push(CAMERAS[i].id)
  return out
}

function ids(configured, states) {
  if (Array.isArray(configured) && configured.length)
    return configured.slice(0, 6)
  var defaults = defaultIds()
  if (!states) return defaults
  for (var i = 0; i < defaults.length; i++) {
    if (!isMissing(states[defaults[i]])) return defaults
  }
  return []
}

function titleFor(entityId, entity) {
  for (var i = 0; i < CAMERAS.length; i++) {
    if (CAMERAS[i].id === entityId) return CAMERAS[i].title
  }
  if (entity && entity.attributes && typeof entity.attributes.friendly_name === "string"
      && entity.attributes.friendly_name.trim()) {
    return entity.attributes.friendly_name.trim()
  }
  var slug = String(entityId || "")
  var dot = slug.indexOf(".")
  slug = dot === -1 ? slug : slug.slice(dot + 1)
  if (!slug) return "Camera"
  return slug.charAt(0).toUpperCase() + slug.slice(1).replace(/_/g, " ")
}

function isMissing(entity) {
  if (!entity) return true
  var state = typeof entity.state === "string" ? entity.state : ""
  return state === "" || state === "unavailable" || state === "unknown"
}

function tiles(states, configured) {
  var map = states && typeof states === "object" ? states : {}
  var chosen = ids(configured)
  var out = []
  for (var i = 0; i < chosen.length; i++) {
    var id = chosen[i]
    out.push({
      entityId: id,
      title: titleFor(id, map[id]),
      available: !isMissing(map[id])
    })
  }
  return out
}

function anyAvailable(states, configured) {
  var list = tiles(states, configured)
  for (var i = 0; i < list.length; i++) {
    if (list[i].available) return true
  }
  return false
}

function hostOf(baseUrl) {
  var text = String(baseUrl || "")
  var scheme = text.indexOf("://")
  if (scheme < 0) return ""
  var rest = text.slice(scheme + 3)
  var cut = rest.search(/[\/?#]/)
  var authority = cut === -1 ? rest : rest.slice(0, cut)
  if (!authority || authority.indexOf("@") !== -1) return ""
  if (authority.charAt(0) === "[") {
    var close = authority.indexOf("]")
    if (close <= 1) return ""
    return authority.slice(0, close + 1)
  }
  var colon = authority.lastIndexOf(":")
  return colon === -1 ? authority : authority.slice(0, colon)
}

function streamName(entityId, entity) {
  for (var i = 0; i < CAMERAS.length; i++) {
    if (CAMERAS[i].id === entityId) return CAMERAS[i].stream
  }
  if (entity && entity.attributes && typeof entity.attributes.camera_name === "string"
      && /^[A-Za-z0-9_]+$/.test(entity.attributes.camera_name)) {
    return entity.attributes.camera_name
  }
  var slug = String(entityId || "")
  var dot = slug.indexOf(".")
  slug = dot === -1 ? slug : slug.slice(dot + 1)
  if (!slug) return ""
  return slug.charAt(0).toUpperCase() + slug.slice(1)
}

function streamUrl(baseUrl, entityId, entity) {
  var name = streamName(entityId, entity)
  var host = hostOf(baseUrl)
  if (!name || !host) return ""
  if (!/^[A-Za-z0-9_]+$/.test(name)) return ""
  return "rtsp://" + host + ":8554/" + name
}

function fileSource(path, revision) {
  if (typeof path !== "string" || path.indexOf("/") !== 0) return ""
  if (path.indexOf("..") !== -1) return ""
  var rev = typeof revision === "number" ? revision : 0
  return "file://" + path + "?r=" + rev
}
