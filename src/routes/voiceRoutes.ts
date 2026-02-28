import { Router } from "express";
import { generateVoice } from "../controllers/voiceController";

const router = Router();

// POST /api/voice
router.post("/", generateVoice);

export default router;