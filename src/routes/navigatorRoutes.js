"use strict";
const { Router }         = require("express");
const { navigate, demo } = require("../controllers/navigatorController");
const router = Router();
router.get("/demo", demo);
router.post("/",    navigate);
module.exports = router;
