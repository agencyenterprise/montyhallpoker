import {
    Account,
    AccountAddress,
    Ed25519PrivateKey,
    Secp256k1PrivateKey,
    Network,
    AptosConfig,
    Aptos
} from "@aptos-labs/ts-sdk";

const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || "0xe4ab044df91caf41e1b13ea1a2d57a72f5d9a3b8edb52755046e3f5d3d3082d7";

const revealGameCards = async (gameId: string, cards: string[]) => {
    const config = new AptosConfig({ network: Network.RANDOMNET }); // default network is devnet
    const aptos = new Aptos(config);
    // Create a private key instance for Ed25519 scheme
    const privateKey = new Ed25519PrivateKey("myEd25519privatekeystring");
    // Or for Secp256k1 scheme
    //const privateKey = new Secp256k1PrivateKey("mySecp256k1privatekeystring");

    // Derive an account from private key and address

    // create an AccountAddress instance from the account address string
    const address = AccountAddress.from(CONTRACT_ADDRESS);
    // Derieve an account from private key and address
    const account = await Account.fromPrivateKeyAndAddress({ privateKey, address });
    await aptos.signAndSubmitTransaction({ signer, transaction: rawTxn });
}