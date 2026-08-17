#!/usr/bin/env node
// Unit tests for Powerwall.js. Run: node tests/test_powerwall.js

const fs = require("fs");
const path = require("path");

const source = fs
  .readFileSync(path.join(__dirname, "..", "Powerwall.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "");

const names = [...source.matchAll(/^function\s+([A-Za-z0-9_]+)/gm)].map((m) => m[1]);
const consts = [...source.matchAll(/^var\s+([A-Z][A-Z0-9_]*)/gm)].map((m) => m[1]);
const Powerwall = new Function(`${source}\nreturn {${[...names, ...consts].join(",")}};`)();

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

function states(charge, battery, load) {
  const map = {};
  if (charge !== undefined) map[Powerwall.CHARGE_ID] = { state: String(charge) };
  if (battery !== undefined) map[Powerwall.BATTERY_POWER_ID] = { state: String(battery) };
  if (load !== undefined) map[Powerwall.LOAD_POWER_ID] = { state: String(load) };
  return map;
}

console.log("powerwall formatting");
eq("rounds percent", Powerwall.formatPercent(32.706), "33%");
eq("formats kilowatts", Powerwall.formatKw(-1.981), "2.0 kW");
eq("formats small load", Powerwall.formatKw(0.521), "0.5 kW");
eq("missing number is an em dash", Powerwall.formatKw(null), "—");

console.log("powerwall projection");
eq("missing charge hides the card", Powerwall.project({}).available, false);

const charging = Powerwall.project(states("32.7067669172932", "-1.981", "0.521"));
eq("charging is available", charging.available, true);
eq("charging percent text", charging.percentText, "33%");
eq("charging fraction", Math.round(charging.fraction * 100), 33);
eq("charging subtitle", charging.subtitle, "Home 0.5 kW · Charging 2.0 kW");
eq("charging flag", charging.charging, true);
eq("charging not discharging", charging.discharging, false);

const discharging = Powerwall.project(states("80", "1.2", "1.8"));
eq("discharging subtitle", discharging.subtitle, "Home 1.8 kW · Using 1.2 kW");
eq("discharging flag", discharging.discharging, true);

const idle = Powerwall.project(states("50", "0.01", "0.3"));
eq("near-zero battery power is idle", idle.flowLabel, "Idle");
eq("idle subtitle", idle.subtitle, "Home 0.3 kW · Idle");

const gone = Powerwall.project({
  [Powerwall.CHARGE_ID]: { state: "unavailable" }
});
eq("unavailable charge hides the card", gone.available, false);

if (failures) {
  console.log("\nFAILED: %d of %d checks", failures, checks);
  process.exit(1);
}
console.log("all %d checks passed", checks);
