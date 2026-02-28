/**
 * voiceController.js
 * Sentient Tour Guide — streams ElevenLabs audio based on Navigator Mode.
 */

"use strict";

const elevenlabs     = require("elevenlabs");
const ElevenLabsClient = elevenlabs.ElevenLabsClient;
const { Readable }   = require("stream");

// ─── Voice ID Mapping ─────────────────────────────────────────────────────────

const modeVoiceMap = {
  Adventure: "IKne3meq5aSn9XLyUdCD", // Charlie  — Deep, Confident, Energetic
  Foodie:    "cgSgspJ2msm6clMCkdW9", // Jessica  — Playful, Bright, Warm
  Nature:    "SAz9YHcvj6GT2YYXdXww", // River    — Relaxed, Neutral, Informative
  Culture:   "XrExE9yKIg1WjnnlVkGX", // Matilda  — Knowledgeable, Professional
  Social:    "TX3LPaxmHKxFdv7VOQHJ", // Liam     — Energetic, Social Media Creator
  Mystery:   "N2lVS1w4EtoT3dr4eOWO", // Callum   — Husky Trickster
};

// ─── Emotional Prompt Tags ────────────────────────────────────────────────────

const modeEmotionTagMap = {
  Adventure: "<excited> ",
  Foodie:    "<happy> ",
  Nature:    "<calm> ",
  Culture:   "<curious> ",
  Social:    "<cheerful> ",
  Mystery:   "<whisper> ",
};

// ─── Controller ───────────────────────────────────────────────────────────────

const generateVoice = async (req, res) => {
  const { text, mode, travelType } = req.body;

  if (!text || !mode || !travelType) {
    return res.status(400).json({ error: "Missing required fields: text, mode, travelType" });
  }

  const validModes       = ["Adventure", "Foodie", "Nature", "Culture", "Social", "Mystery"];
  const validTravelTypes = ["Walking", "Driving"];

  if (!validModes.includes(mode)) {
    return res.status(400).json({ error: `Invalid mode. Must be one of: ${validModes.join(", ")}` });
  }

  if (!validTravelTypes.includes(travelType)) {
    return res.status(400).json({ error: `Invalid travelType. Must be 'Walking' or 'Driving'` });
  }

  const apiKey = process.env.ELEVEN_LABS_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: "Missing ELEVEN_LABS_API_KEY in environment" });
  }

  try {
    const client = new ElevenLabsClient({ apiKey });

    // Driving = clear GPS-like, Walking = conversational
    const voiceSettings = travelType === "Driving"
      ? { stability: 0.75, similarity_boost: 0.85 }
      : { stability: 0.45, similarity_boost: 0.65 };

    const enrichedText = `${modeEmotionTagMap[mode]}${text}`;
    const voiceId      = modeVoiceMap[mode];

    const audioStream = await client.textToSpeech.convertAsStream(voiceId, {
      text:           enrichedText,
      model_id:       "eleven_turbo_v2_5",
      voice_settings: voiceSettings,
    });

    res.setHeader("Content-Type",      "audio/mpeg");
    res.setHeader("Transfer-Encoding", "chunked");
    res.setHeader("Cache-Control",     "no-cache");

    const readable = Readable.from(audioStream);
    readable.pipe(res);

    readable.on("error", (err) => {
      console.error("[VoiceController] Stream error:", err);
      res.end();
    });

  } catch (error) {
    console.error("[VoiceController] Error:", error);
    const message = error instanceof Error ? error.message : "Unknown error occurred";
    res.status(500).json({ error: "Failed to generate voice audio", details: message });
  }
};

module.exports = { generateVoice };
