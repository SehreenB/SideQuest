/**
 * index.js
 * Express server for SideQuest.
 *
 * Routes
 * ──────
 * POST /navigate      – returns 3 waypoints
 * POST /vault/sign    – returns a presigned upload URL
 * POST /rewards/mint  – mints a cNFT badge
 */

"use strict";
require("dotenv").config();

const express              = require("express");
const { findWaypoints }    = require("./navigator");
const { createPresignedUploadUrl } = require("./vault");
const { mintBadge }        = require("./rewards");

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// ── Health check ────────────────────────────────────────────────────────────
app.get("/health", (_req, res) => res.json({ status: "ok" }));

// ── POST /navigate ───────────────────────────────────────────────────────────
// Body: { lat, lng, theme, travelMode }
app.post("/navigate", async (req, res) => {
  const { lat, lng, theme, travelMode = "walk" } = req.body;

  if (lat === undefined || lng === undefined || !theme) {
    return res.status(400).json({ error: "lat, lng, and theme are required." });
  }

  try {
    const result = await findWaypoints(Number(lat), Number(lng), theme, travelMode);
    res.json(result);
  } catch (err) {
    console.error("[/navigate]", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /vault/sign ─────────────────────────────────────────────────────────
// Body: { filename, contentType, expiresIn? }
app.post("/vault/sign", async (req, res) => {
  const { filename, contentType = "application/octet-stream", expiresIn = 600 } = req.body;

  if (!filename) {
    return res.status(400).json({ error: "filename is required." });
  }

  try {
    const result = await createPresignedUploadUrl(filename, contentType, Number(expiresIn));
    res.json(result);
  } catch (err) {
    console.error("[/vault/sign]", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /rewards/mint ───────────────────────────────────────────────────────
// Body: { recipientAddress, metadata: { name, symbol, uri }, treeAddress? }
app.post("/rewards/mint", async (req, res) => {
  const { recipientAddress, metadata, treeAddress } = req.body;

  if (!recipientAddress || !metadata?.name || !metadata?.uri) {
    return res.status(400).json({ error: "recipientAddress, metadata.name, and metadata.uri are required." });
  }

  try {
    const result = await mintBadge(recipientAddress, metadata, treeAddress);
    res.json(result);
  } catch (err) {
    console.error("[/rewards/mint]", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── Start ────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`✅  SideQuest server running on http://localhost:${PORT}`);
});

module.exports = app; // for testing
