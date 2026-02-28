import { Request, Response } from "express";
import { ElevenLabsClient } from "elevenlabs";

// ─── Types ────────────────────────────────────────────────────────────────────

type NavigatorMode =
    | "Adventure"
    | "Foodie"
    | "Nature"
    | "Culture"
    | "Social"
    | "Mystery";

type TravelType = "Walking" | "Driving";

interface VoiceRequestBody {
    text: string;
    mode: NavigatorMode;
    travelType: TravelType;
}

// ─── Voice ID Mapping ─────────────────────────────────────────────────────────

const modeVoiceMap: Record<NavigatorMode, string> = {
    Adventure: "21m00Tcm4TlvDq8ikWAM",
    Foodie: "21m00Tcm4TlvDq8ikWAM",
    Nature: "21m00Tcm4TlvDq8ikWAM",
    Culture: "21m00Tcm4TlvDq8ikWAM",
    Social: "21m00Tcm4TlvDq8ikWAM",
    Mystery: "21m00Tcm4TlvDq8ikWAM",
};

// ─── Emotional Prompt Tags ────────────────────────────────────────────────────

const modeEmotionTagMap: Record<NavigatorMode, string> = {
    Adventure: "<excited> ",
    Foodie: "<happy> ",
    Nature: "<calm> ",
    Culture: "<curious> ",
    Social: "<cheerful> ",
    Mystery: "<whisper> ",
};

// ─── Controller ───────────────────────────────────────────────────────────────

export const generateVoice = async (
    req: Request<{}, {}, VoiceRequestBody>,
    res: Response
): Promise<void> => {
    const { text, mode, travelType } = req.body;

    // Validation
    if (!text || !mode || !travelType) {
        res.status(400).json({ error: "Missing required fields: text, mode, travelType" });
        return;
    }

    const validModes: NavigatorMode[] = ["Adventure", "Foodie", "Nature", "Culture", "Social", "Mystery"];
    const validTravelTypes: TravelType[] = ["Walking", "Driving"];

    if (!validModes.includes(mode)) {
        res.status(400).json({ error: `Invalid mode. Must be one of: ${validModes.join(", ")}` });
        return;
    }

    if (!validTravelTypes.includes(travelType)) {
        res.status(400).json({ error: `Invalid travelType. Must be 'Walking' or 'Driving'` });
        return;
    }

    const apiKey = process.env.ELEVEN_LABS_API_KEY;
    if (!apiKey) {
        res.status(500).json({ error: "Missing ELEVEN_LABS_API_KEY in environment" });
        return;
    }

    try {
        const client = new ElevenLabsClient({ apiKey });

        const voiceSettings =
            travelType === "Driving"
                ? { stability: 0.75, similarity_boost: 0.85 }
                : { stability: 0.45, similarity_boost: 0.65 };

        const enrichedText = `${modeEmotionTagMap[mode]}${text}`;
        const voiceId = modeVoiceMap[mode];

        const audioStream = await client.textToSpeech.convertAsStream(voiceId, {
            text: enrichedText,
            model_id: "eleven_turbo_v2_5",
            voice_settings: voiceSettings,
        });

        res.setHeader("Content-Type", "audio/mpeg");
        res.setHeader("Transfer-Encoding", "chunked");
        res.setHeader("Cache-Control", "no-cache");

        const { Readable } = await import("stream");
        const readable = Readable.from(audioStream);
        readable.pipe(res);

        readable.on("error", (err: Error) => {
            console.error("[VoiceController] Stream error:", err);
            res.end();
        });

    } catch (error: unknown) {
        console.error("[VoiceController] Full error:", error);
        console.error("[VoiceController] Error type:", typeof error);
        if (error instanceof Error) {
            console.error("[VoiceController] Message:", error.message);
            console.error("[VoiceController] Stack:", error.stack);
        }
        const message = error instanceof Error ? error.message : "Unknown error occurred";
        res.status(500).json({
            error: "Failed to generate voice audio",
            details: message,
        });
    }
};