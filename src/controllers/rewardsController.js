/**
 * rewardsController.js
 * Mints a compressed NFT (cNFT) badge on Solana Devnet using
 * Metaplex Bubblegum + UMI.
 */

"use strict";

const { createUmi }                                  = require("@metaplex-foundation/umi-bundle-defaults");
const { keypairIdentity, publicKey }                 = require("@metaplex-foundation/umi");
const { mplBubblegum, mintV1, parseLeafFromMintV1Transaction } = require("@metaplex-foundation/mpl-bubblegum");
const { Keypair }                                    = require("@solana/web3.js");

const DEVNET_RPC = "https://api.devnet.solana.com";

// ─── Core function ────────────────────────────────────────────────────────────

async function mintBadge(recipientAddress, metadata, treeAddress) {
  const rawKey = JSON.parse(process.env.SOLANA_PRIVATE_KEY);
  const web3KP = Keypair.fromSecretKey(Uint8Array.from(rawKey));

  const umi   = createUmi(DEVNET_RPC).use(mplBubblegum());
  const umiKP = umi.eddsa.createKeypairFromSecretKey(web3KP.secretKey);
  umi.use(keypairIdentity(umiKP));

  const tree       = treeAddress || process.env.SOLANA_TREE_ADDRESS;
  const merkleTree = publicKey(tree);
  const recipient  = publicKey(recipientAddress);

  const { name, symbol = "", uri, sellerFeeBasisPoints = 0 } = metadata;

  const { signature } = await mintV1(umi, {
    merkleTree,
    leafOwner: recipient,
    metadata: {
      name,
      symbol,
      uri,
      sellerFeeBasisPoints,
      collection: { key: publicKey("11111111111111111111111111111111"), verified: false },
      creators:   [{ address: umiKP.publicKey, verified: true, share: 100 }],
    },
  }).sendAndConfirm(umi);

  const leaf        = await parseLeafFromMintV1Transaction(umi, signature);
  const sigBase58   = Buffer.from(signature).toString("base64url");
  const explorerUrl = `https://explorer.solana.com/tx/${sigBase58}?cluster=devnet`;

  return { signature: sigBase58, explorerUrl, leafIndex: leaf.index };
}

// ─── Express handler ──────────────────────────────────────────────────────────

const mint = async (req, res) => {
  const { recipientAddress, metadata, treeAddress } = req.body;

  if (!recipientAddress || !metadata?.name || !metadata?.uri) {
    return res.status(400).json({
      error: "recipientAddress, metadata.name, and metadata.uri are required.",
    });
  }

  try {
    const result = await mintBadge(recipientAddress, metadata, treeAddress);
    res.json(result);
  } catch (error) {
    console.error("[rewards/mint]", error.message);
    res.status(500).json({ error: error.message });
  }
};

module.exports = { mint, mintBadge };
