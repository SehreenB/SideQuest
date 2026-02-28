"use strict";
const { Router } = require("express");
const { mint }   = require("../controllers/rewardsController");
const router = Router();
router.post("/mint", mint);
module.exports = router;
