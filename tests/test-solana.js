/**
 * tests/test-solana.js
 * Attempts to mint a cNFT badge to a test wallet on Devnet and
 * logs the Solana Explorer URL.
 *
 * Usage:
 *   node tests/test-solana.js
 *
 * Notes:
 *  - SOLANA_PRIVATE_KEY and SOLANA_TREE_ADDRESS must be set in .env
 *  - Recipient defaults to the fee-payer (self-mint for testing)
 */

"use strict";
require("dotenv").config();

const { Keypair }     = require("@solana/web3.js");
const { mintBadge }   = require("../rewards");

(async () => {
  console.log("🎖️   Minting test cNFT badge on Devnet…\n");

  // Derive the fee-payer public key from the private key in .env
  const rawKey    = JSON.parse(process.env.SOLANA_PRIVATE_KEY);
  const feePayer  = Keypair.fromSecretKey(Uint8Array.from(rawKey));
  const recipient = feePayer.publicKey.toBase58();

  console.log(`👛  Recipient : ${recipient}`);
  console.log(`🌳  Tree      : ${process.env.SOLANA_TREE_ADDRESS}\n`);

  const metadata = {
    name:                "SideQuest Pioneer Badge",
    symbol:              "SQB",
    uri:                 "https://arweave.net/YOUR_METADATA_JSON_URI",  // Replace with real URI
    sellerFeeBasisPoints: 0,
  };

  try {
    const { signature, explorerUrl, leafIndex } = await mintBadge(
      recipient,
      metadata,
      process.env.SOLANA_TREE_ADDRESS
    );

    console.log("✅  Mint successful!\n");
    console.log(`🔏  Signature  : ${signature}`);
    console.log(`🌿  Leaf index : ${leafIndex}`);
    console.log(`🔗  Explorer   : ${explorerUrl}`);
  } catch (err) {
    console.error("❌  Mint failed:", err.message);
    if (err.logs) console.error("📋  Program logs:\n", err.logs.join("\n"));
    process.exit(1);
  }
})();
