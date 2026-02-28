require('dotenv').config();
const { createUmi } = require('@metaplex-foundation/umi-bundle-defaults');
const { keypairIdentity, generateSigner } = require('@metaplex-foundation/umi');
const { mplBubblegum, createTree } = require('@metaplex-foundation/mpl-bubblegum');
const { Keypair } = require('@solana/web3.js');

(async () => {
    console.log('🌳 Creating Merkle tree on Devnet...');

    const rawKey = JSON.parse(process.env.SOLANA_PRIVATE_KEY);
    const web3KP = Keypair.fromSecretKey(Uint8Array.from(rawKey));

    const umi = createUmi('https://api.devnet.solana.com').use(mplBubblegum());
    const umiKP = umi.eddsa.createKeypairFromSecretKey(web3KP.secretKey);
    umi.use(keypairIdentity(umiKP));

    const merkleTree = generateSigner(umi);
    console.log('Tree address will be:', merkleTree.publicKey);

    const builder = await createTree(umi, {
        merkleTree,
        maxDepth: 14,
        maxBufferSize: 64,
    });

    const { signature } = await builder.sendAndConfirm(umi);
    const sig = Buffer.from(signature).toString('base64');

    console.log('✅ Tree created!');
    console.log('Signature:', sig);
    console.log('');
    console.log('👉 Add this to your .env:');
    console.log('SOLANA_TREE_ADDRESS=' + merkleTree.publicKey);
})();