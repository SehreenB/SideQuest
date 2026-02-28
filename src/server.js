"use strict";
require("dotenv").config();

const express     = require("express");
const voiceRoutes = require("./routes/voiceRoutes");

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// POST /api/voice
app.use("/api/voice", voiceRoutes);

app.listen(PORT, () => {
  console.log(`🚀 SideQuest backend running on http://localhost:${PORT}`);
});