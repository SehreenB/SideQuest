"use strict";
const { Router }        = require("express");
const { generateVoice } = require("../controllers/voiceController");
const router = Router();
router.post("/", generateVoice);
module.exports = router;
