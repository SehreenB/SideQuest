/**
 * rewards.js
 * Mints a compressed NFT (cNFT) badge on Solana Devnet using
 * Metaplex Bubblegum + UMI.
 *
 * PRE-REQUISITES
 * ─────────────
 * 1. A Merkle tree account must already exist on Devnet.
 *    Create one with:
 *      npx ts-node scripts/create-tree.ts
 *    or use the Metaplex CLI.
 *    Set its address as SOLANA_TREE_ADDRESS in .env
 *
 * 2. SOLANA_PRIVATE_KEY in .env must be the JSON byte array
 *    of the tree authority / fee-payer keypair.
 */

"use strict";
require("dotenv").config();

const { createUmi }                                  = require("@metaplex-foundation/umi-bundle-defaults");
const { keypairIdentity, publicKey, generateSigner } = require("@metaplex-foundation/umi");
const {
  mplBubblegum,
  mintV1,
  parseLeafFromMintV1Transaction,
}                                                    = require("@metaplex-foundation/mpl-bubblegum");
const { Keypair }                                    = require("@solana/web3.js");

const DEVNET_RPC = "https://api.devnet.solana.com";

/**
 * Mint a cNFT badge to a recipient wallet.
 *
 * @param {string} recipientAddress - Base58 Solana public key
 * @param {object} metadata         - { name, symbol, uri, sellerFeeBasisPoints? }
 * @param {string} treeAddress      - Base58 address of the Bubblegum Merkle tree
 * @returns {Promise<{ signature: string, explorerUrl: string, leafIndex: number }>}
 */
async function mintBadge(recipientAddress, metadata, treeAddress) {
  // ── Load fee-payer keypair ──────────────────────────────────────────────────
  const rawKey = JSON.parse(process.env.SOLANA_PRIVATE_KEY);
  const web3KP = Keypair.fromSecretKey(Uint8Array.from(rawKey));

  // ── Build UMI instance ─────────────────────────────────────────────────────
  const umi = createUmi(DEVNET_RPC).use(mplBubblegum());

  const umiKP = umi.eddsa.createKeypairFromSecretKey(web3KP.secretKey);
  umi.use(keypairIdentity(umiKP));

  // ── Resolve tree ───────────────────────────────────────────────────────────
  const tree        = treeAddress || process.env.SOLANA_TREE_ADDRESS;
  const merkleTree  = publicKey(tree);
  const recipient   = publicKey(recipientAddress);

  // ── Mint ───────────────────────────────────────────────────────────────────
  const { name, symbol, uri, sellerFeeBasisPoints = 0 } = metadata;

  const { signature } = await mintV1(umi, {
    merkleTree,
    leafOwner: recipient,
    metadata: {
      name,
      symbol,
      uri,
      sellerFeeBasisPoints,
      collection:  { key: publicKey("11111111111111111111111111111111"), verified: false },
      creators:    [{ address: umiKP.publicKey, verified: true, share: 100 }],
    },
  }).sendAndConfirm(umi);

  // ── Parse leaf index from tx ───────────────────────────────────────────────
  const leaf       = await parseLeafFromMintV1Transaction(umi, signature);
  const sigBase58  = Buffer.from(signature).toString("base64url"); // UMI returns Uint8Array
  const explorerUrl = `https://explorer.solana.com/tx/${sigBase58}?cluster=devnet`;

  return {
    signature:  sigBase58,
    explorerUrl,
    leafIndex:  leaf.index,
  };
}

module.exports = { mintBadge };
