/**
 * vault.js
 * Generates Supabase Storage presigned upload URLs.
 */

"use strict";
require("dotenv").config();

const { createClient } = require("@supabase/supabase-js");
const { v4: uuidv4 } = require("uuid");

function buildClient() {
  return createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY
  );
}

/**
 * Generate a presigned upload URL.
 *
 * @param {string} filename    - Original filename (used to derive extension)
 * @param {string} contentType - MIME type, e.g. "image/jpeg"
 * @param {number} expiresIn   - Seconds until URL expires (default 600)
 * @returns {Promise<{ uploadUrl: string, key: string, publicUrl: string }>}
 */
async function createPresignedUploadUrl(filename, contentType = "application/octet-stream", expiresIn = 600) {
  const ext = filename.includes(".") ? filename.split(".").pop() : "bin";
  const key = `uploads/${uuidv4()}.${ext}`;
  const bucket = process.env.SUPABASE_BUCKET || "sidequest-uploads";

  const supabase = buildClient();

  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUploadUrl(key);

  if (error) throw new Error(`Supabase error: ${error.message}`);

  // Public URL (readable after upload since bucket is public)
  const { data: { publicUrl } } = supabase.storage
    .from(bucket)
    .getPublicUrl(key);

  return {
    uploadUrl: data.signedUrl,
    token: data.token,
    key,
    publicUrl,
    expiresIn,
  };
}

module.exports = { createPresignedUploadUrl };