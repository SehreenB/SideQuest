"use strict";
const { Router }    = require("express");
const { vaultSign } = require("../controllers/vaultController");
const router = Router();
router.post("/sign", vaultSign);
module.exports = router;
