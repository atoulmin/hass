#!/usr/bin/env node
// Unit tests for Cameras.js. Run: node tests/test_cameras.js

const fs = require("fs");
const path = require("path");

const source = fs
  .readFileSync(path.join(__dirname, "..", "Cameras.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "");

const names = [...source.matchAll(/^function\s+([A-Za-z0-9_]+)/gm)].map((m) => m[1]);
const consts = [...source.matchAll(/^var\s+([A-Z][A-Z0-9_]*)/gm)].map((m) => m[1]);
const Cameras = new Function(`${source}\nreturn {${[...names, ...consts].join(",")}};`)();

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

console.log("camera catalog");
eq("four cameras", Cameras.ids().length, 4);
eq("configured cameras win", Cameras.ids(["camera.garage"]).length, 1);
eq("includes rearyard", Cameras.CAMERAS[3].title, "Rearyard");

const tiles = Cameras.tiles({
  "camera.frontyard": { state: "recording" },
  "camera.driveway": { state: "unavailable" }
});
eq("frontyard available", tiles[0].available, true);
eq("driveway unavailable", tiles[1].available, false);
eq("missing backyard unavailable", tiles[2].available, false);
eq("anyAvailable when one is live", Cameras.anyAvailable({
  "camera.frontyard": { state: "recording" }
}), true);
eq("anyAvailable when none exist", Cameras.anyAvailable({}), false);

eq("file source is cache-busted",
   Cameras.fileSource("/home/aaron/.cache/omarchy/hass/cameras/x.jpg", 7),
   "file:///home/aaron/.cache/omarchy/hass/cameras/x.jpg?r=7");
eq("rejects relative paths", Cameras.fileSource("tmp/x.jpg", 1), "");
eq("rejects parent traversal", Cameras.fileSource("/tmp/../etc/passwd", 1), "");

eq("stream host comes from the HA url",
   Cameras.streamUrl("http://192.168.0.123:8123", "camera.frontyard"),
   "rtsp://192.168.0.123:8554/Frontyard");
eq("unknown camera derives a go2rtc name",
   Cameras.streamUrl("http://192.168.0.123:8123", "camera.other"),
   "rtsp://192.168.0.123:8554/Other");
eq("credentials in the HA url are refused",
   Cameras.streamUrl("http://user:pass@192.168.0.123:8123", "camera.frontyard"), "");

if (failures) {
  console.log("\nFAILED: %d of %d checks", failures, checks);
  process.exit(1);
}
console.log("all %d checks passed", checks);
