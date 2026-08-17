#!/usr/bin/env node
// Unit tests for Assist.js. Run: node tests/test_assist.js

const fs = require("fs");
const path = require("path");

const source = fs
  .readFileSync(path.join(__dirname, "..", "Assist.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "");

const names = [...source.matchAll(/^function\s+([A-Za-z0-9_]+)/gm)].map((m) => m[1]);
const consts = [...source.matchAll(/^var\s+([A-Z][A-Z0-9_]*)/gm)].map((m) => m[1]);
const Assist = new Function(`${source}\nreturn {${[...names, ...consts].join(",")}};`)();

let failures = 0;
let checks = 0;

function eq(label, actual, expected) {
  checks++;
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    failures++;
    console.log(`  FAIL ${label}\n       got      ${JSON.stringify(actual)}` +
                `\n       expected ${JSON.stringify(expected)}`);
  }
}

console.log("assist text and conversation id sanitization");
eq("trims user text", Assist.normalizeText("  turn off the lamp  "), "turn off the lamp");
eq("rejects blank text", Assist.normalizeText("   "), "");
eq("rejects non-strings", Assist.normalizeText(12), "");
eq("truncates long text", Assist.normalizeText("x".repeat(Assist.MAX_TEXT + 20)).length,
   Assist.MAX_TEXT);
eq("keeps a normal conversation id", Assist.sanitizeConversationId("conv-1"), "conv-1");
eq("drops control characters", Assist.sanitizeConversationId("conv\u0001id"), "");
eq("drops oversized ids", Assist.sanitizeConversationId("c".repeat(200)), "");
eq("drops non-string ids", Assist.sanitizeConversationId({ id: "x" }), "");

console.log("assist result projection");
eq("reads speech from a successful result",
   Assist.projectResult({
     ok: true,
     speech: "  Turned off the lamp  ",
     conversation_id: "conv-9",
     continue_conversation: true,
     response_type: "action_done"
   }),
   {
     ok: true,
     speech: "Turned off the lamp",
     conversationId: "conv-9",
     continueConversation: true,
     responseType: "action_done",
     error: "Assist could not complete that request."
   });
eq("falls back when speech is missing",
   Assist.projectResult({ ok: true }).speech, "Done.");
eq("keeps a failed result's error",
   Assist.projectResult({ ok: false, error: "pipeline missing" }).error,
   "pipeline missing");
eq("does not treat a non-string speech as text",
   Assist.speechFromResult({ speech: { html: "<b>hi</b>" } }), "");
eq("labels user and assist rows",
   Assist.messageFor("user", "hello"), { speaker: "user", body: "hello" });
eq("unknown speakers become assist",
   Assist.messageFor("system", "x").speaker, "assist");
eq("idle timeout is one minute", Assist.IDLE_MS, 60000);

if (failures) {
  console.log("\nFAILED: %d of %d checks", failures, checks);
  process.exit(1);
}
console.log("all %d checks passed", checks);
