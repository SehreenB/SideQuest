/**
 * server.js
 * SideQuest — unified Express backend
 *
 * Routes
 * ──────
 * GET  /health           – health check
 * GET  /config           – returns Google Maps API key for frontend
 * GET  /demo             – full SideQuest web demo page
 * POST /api/voice        – streams ElevenLabs audio (Sentient Tour Guide)
 * POST /api/routes       – returns Gemini waypoints
 * POST /vault/sign       – presigned Supabase upload URL
 * POST /rewards/mint     – mints cNFT badge on Solana Devnet
 */

"use strict";
require("dotenv").config();

const express        = require("express");
const cors           = require("cors");
const voiceRoutes    = require("./routes/voiceRoutes");
const navigatorRoutes = require("./routes/navigatorRoutes");
const vaultRoutes    = require("./routes/vaultRoutes");
const rewardsRoutes  = require("./routes/rewardsRoutes");

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Health ────────────────────────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// ── Config ────────────────────────────────────────────────────────────────────
app.get("/config", (_req, res) => {
  res.json({ googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY });
});

// ── Feature Routes ────────────────────────────────────────────────────────────
app.use("/api/voice",  voiceRoutes);       // Sehreen  — ElevenLabs voice
app.use("/api/routes", navigatorRoutes);   // Partner  — Gemini navigation
app.use("/vault",      vaultRoutes);       // Partner  — Supabase memory vault
app.use("/rewards",    rewardsRoutes);     // Partner  — Solana badge minting

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n✅  SideQuest backend running on http://localhost:${PORT}`);
  console.log(`🎙️   Voice:      POST http://localhost:${PORT}/api/voice`);
  console.log(`🗺️   Routes:     POST http://localhost:${PORT}/api/routes`);
  console.log(`🌐  Demo:        GET  http://localhost:${PORT}/demo`);
  console.log(`🔒  Vault:       POST http://localhost:${PORT}/vault/sign`);
  console.log(`🏅  Rewards:     POST http://localhost:${PORT}/rewards/mint\n`);
});
