/**
 * vaultController.js
 * Generates Supabase Storage presigned upload URLs.
 */

"use strict";

const { createClient } = require("@supabase/supabase-js");
const { v4: uuidv4 }   = require("uuid");

function buildClient() {
  return createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY
  );
}

// ─── Core function ────────────────────────────────────────────────────────────

async function createPresignedUploadUrl(filename, contentType = "application/octet-stream", expiresIn = 600) {
  const ext    = filename.includes(".") ? filename.split(".").pop() : "bin";
  const key    = `uploads/${uuidv4()}.${ext}`;
  const bucket = process.env.SUPABASE_BUCKET || "sidequest-uploads";

  const supabase = buildClient();

  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUploadUrl(key);

  if (error) throw new Error(`Supabase error: ${error.message}`);

  const { data: { publicUrl } } = supabase.storage
    .from(bucket)
    .getPublicUrl(key);

  return {
    uploadUrl: data.signedUrl,
    token:     data.token,
    key,
    publicUrl,
    expiresIn,
  };
}

// ─── Express handler ──────────────────────────────────────────────────────────

const vaultSign = async (req, res) => {
  const { filename, contentType = "application/octet-stream", expiresIn = 600 } = req.body;

  if (!filename) {
    return res.status(400).json({ error: "filename is required." });
  }

  try {
    const result = await createPresignedUploadUrl(filename, contentType, Number(expiresIn));
    res.json(result);
  } catch (error) {
    console.error("[vault/sign]", error.message);
    res.status(500).json({ error: error.message });
  }
};

module.exports = { vaultSign, createPresignedUploadUrl };
