/**
 * tests/test-vault.js
 */

"use strict";
require("dotenv").config();

const { createPresignedUploadUrl } = require("../vault");

(async () => {
  console.log("🔐  Generating Supabase presigned upload URL...\n");

  try {
    const { uploadUrl, key, publicUrl } = await createPresignedUploadUrl(
      "test-photo.jpg",
      "image/jpeg"
    );

    console.log("✅  Signed Upload URL:");
    console.log(uploadUrl);
    console.log();
    console.log(`📦  Object key  : ${key}`);
    console.log(`🌐  Public URL  : ${publicUrl}`);
    console.log();
    console.log("🧪  Test with curl:");
    console.log(
      `curl -X PUT "${uploadUrl}" \\\n` +
      `  -H "Content-Type: image/jpeg" \\\n` +
      `  --upload-file /path/to/file.jpg`
    );
  } catch (err) {
    console.error("❌  Error:", err.message);
    process.exit(1);
  }
})();