.pragma library

// Stateless Assist helpers. The bridge already strips Home Assistant's
// conversation payload down to speech / ids; this module validates what the
// shell still touches: the user's sentence, the conversation id we send back,
// and the bounded transcript ListModel.

var MAX_TEXT = 1000
var MAX_SPEECH = 4000
var MAX_CONVERSATION_ID = 128
var MAX_MESSAGES = 20
var IDLE_MS = 60000

function normalizeText(text) {
  if (typeof text !== "string") return ""
  var trimmed = text.trim()
  if (!trimmed) return ""
  return trimmed.length > MAX_TEXT ? trimmed.slice(0, MAX_TEXT) : trimmed
}

function sanitizeConversationId(value) {
  if (typeof value !== "string") return ""
  var id = value.trim()
  if (!id || id.length > MAX_CONVERSATION_ID) return ""
  for (var i = 0; i < id.length; i++) {
    if (id.charCodeAt(i) < 32) return ""
  }
  return id
}

function speechFromResult(event) {
  if (!event || typeof event !== "object") return ""
  if (typeof event.speech !== "string") return ""
  var speech = event.speech.trim()
  if (!speech) return ""
  return speech.length > MAX_SPEECH ? speech.slice(0, MAX_SPEECH) : speech
}

function projectResult(event) {
  var ok = !!(event && event.ok === true)
  var speech = speechFromResult(event)
  return {
    ok: ok,
    speech: ok ? (speech || "Done.") : "",
    conversationId: sanitizeConversationId(event && event.conversation_id),
    continueConversation: !!(event && event.continue_conversation),
    responseType: (event && typeof event.response_type === "string")
      ? event.response_type : "",
    error: (!ok && event && typeof event.error === "string" && event.error)
      ? event.error : "Assist could not complete that request."
  }
}

function messageFor(speaker, body) {
  var allowed = speaker === "user" || speaker === "assist" || speaker === "error"
  return {
    speaker: allowed ? speaker : "assist",
    body: typeof body === "string" ? body : ""
  }
}
