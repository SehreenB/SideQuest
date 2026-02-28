"use strict";

const { Router } = require("express");
const { generateVoice } = require("../controllers/voiceController");

const router = Router();

// POST /api/voice
router.post("/", generateVoice);

module.exports = router;