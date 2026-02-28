/**
 * tests/test-gemini.js
 * Logs raw JSON from the navigator for a "Walk" quest in London.
 *
 * Usage:
 *   node tests/test-gemini.js
 */

"use strict";
require("dotenv").config();

const { findWaypoints } = require("../navigator");

(async () => {
  console.log("🧭  Calling Gemini navigator for London (walk, street art theme)…\n");

  try {
    // London centre: 51.5074, -0.1278
    const result = await findWaypoints(51.5074, -0.1278, "street art", "walk");
    console.log("✅  Raw JSON output:\n");
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    console.error("❌  Error:", err.message);
    process.exit(1);
  }
})();
