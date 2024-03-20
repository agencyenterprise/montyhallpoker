import {
    Account,
    AccountAddress,
    Ed25519PrivateKey,
    Secp256k1PrivateKey,
    Network,
    AptosConfig,
    Aptos
} from "@aptos-labs/ts-sdk";
import { getGameMapping } from "./index"
import { getGameById, GameStatus } from "./contract";
type Hand = { suit: string; value: string };

const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS!
const CONTRACT_PRIVATE_KEY = process.env.CONTRACT_PRIVATE_KEY


export const revealGameCards = async (gameId: number | string) => {
    const game = await getGameById(+gameId);
    if (!game) {
        throw new Error("No game found!");
    }
    if (game.state == GameStatus.CLOSE) {
        throw new Error("Game is already closed!");
    }
    const config = new AptosConfig({ network: Network.RANDOMNET }); // default network is devnet
    const aptos = new Aptos(config);
    // Create a private key instance for Ed25519 scheme
    const privateKey = new Ed25519PrivateKey(CONTRACT_PRIVATE_KEY!);
    // Or for Secp256k1 scheme
    //const privateKey = new Secp256k1PrivateKey("mySecp256k1privatekeystring");
    const address = AccountAddress.from(CONTRACT_ADDRESS);
    // Derieve an account from private key and address
    const gameMapping = await getGameMapping(+gameId);
    if (!gameMapping) {
        throw new Error("No game found!");
    }
    const mapping = gameMapping.mapping as Record<number, Hand>;
    const orderedMapping = Array(52).fill(0).map((_, i) => mapping[i])
    const orderedSuits = orderedMapping.map(card => card.suit);
    const orderedValues = orderedMapping.map(card => card.value);
    const account = await Account.fromPrivateKeyAndAddress({ privateKey, address });
    console.log(orderedSuits.length, orderedValues.length)
    const transaction = await aptos.transaction.build.simple({
        sender: account.accountAddress,
        data: {
            function: `${CONTRACT_ADDRESS}::poker_manager::populate_card_values`,
            functionArguments: [`1`, orderedSuits, orderedValues],
        },
    });
    const txHash = await aptos.signAndSubmitTransaction({ signer: account, transaction: transaction });
    await aptos.waitForTransaction({ transactionHash: txHash.hash });
}