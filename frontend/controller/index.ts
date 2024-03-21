import { connectToDatabase } from "./mongodb";
import { getGameById, GameState, DeckCard, PlayerStatus } from "./contract";
import { verifySignature, getAddressFromPublicKey } from "./security";
import crypto from "crypto";
type CardValueMapping = Record<number, string>;
type SuitValueMapping = Record<number, string>;
export type RevealedHand = Record<number, Hand>;
export type Hand = { suit: string; value: string };
export type PrivateHand = { suit: number; value: number };
export type UserSignedMessage = { signedMessage: string; message: string };
export type GameMappingDB = { gameId: number; mapping: Record<number, Hand> };

export const getGameMapping = async (gameId: number) => {
  const { db } = await connectToDatabase();
  const mappings = db.collection("mappings");
  return await mappings.findOne({ gameId });
};

const insertCardMapping = async (
  gameId: number,
  mapping: Record<number, Hand>
): Promise<any> => {
  const gameMapping = await getGameMapping(gameId);
  if (!gameMapping) {
    const { db } = await connectToDatabase();
    const mappings = db.collection("mappings");
    return await mappings.insertOne({ gameId, mapping });
  }
  return gameMapping;
};

const transformValueSuitMappingToSequencialMapping = (
  valueMapping: CardValueMapping,
  suitMapping: SuitValueMapping
): RevealedHand => {
  const entries = Object.entries(suitMapping)
    .map(([suitIndex, suit]) => {
      const j = parseInt(suitIndex);
      return Object.entries(valueMapping).map(([valueIndex, value]) => {
        const i = parseInt(valueIndex);
        return {
          suit: j * 13 + i,
          value: j * 13 + i,
          suit_string: suit,
          value_string: value,
        };
      });
    })
    .flat();
  return entries.reduce(
    (acc, card) => ({
      ...acc,
      [card.suit]: { suit: card.suit_string, value: card.value_string },
    }),
    {}
  );
};

const revealMappingFromDB = async (
  gameId: number,
  value: number,
  suit: number
): Promise<Hand> => {
  const gameMapping = await getGameMapping(gameId);
  if (!gameMapping) {
    throw new Error("No game found!");
  }
  const { mapping } = gameMapping;
  const privateCard =
    suit == value ? mapping[suit] : mapping[suit * 13 + value];
  return { value: privateCard.value, suit: privateCard.suit };
};
function secureRandom(min: number, max: number) {
  return crypto.randomInt(min, max + 1);
}

const generateCardMappings = async (): Promise<Record<number, Hand>> => {
  function shuffleArray(array: any) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = secureRandom(0, i);
      [array[i], array[j]] = [array[j], array[i]]; // Swap elements
    }
  }
  const cardValues = [
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "jack",
    "queen",
    "king",
    "ace",
  ];
  shuffleArray(cardValues); // Shuffle to ensure randomness

  // Mapping numbers 0-12 to shuffled card values
  const valueMapping: Record<number, string> = {};
  for (let i = 0; i < cardValues.length; i++) {
    valueMapping[i] = cardValues[i];
  }

  // Suits are fixed, so a simple mapping is sufficient
  const suits = ["clubs", "diamonds", "hearts", "spades"];
  shuffleArray(suits);
  const suitMapping: Record<number, string> = {};
  for (let i = 0; i < suits.length; i++) {
    suitMapping[i] = suits[i];
  }
  const cardMapping = transformValueSuitMappingToSequencialMapping(
    valueMapping,
    suitMapping
  );
  const mapping = Object.values(cardMapping).map((v) => ({
    suit: v.suit,
    value: v.value,
  }));
  shuffleArray(mapping);

  return mapping.reduce((acc, v, i) => ({ ...acc, [i]: v }), {});
};

export const createCardMapping = async (gameId: number) => {
  const mapping = await generateCardMappings();
  return await insertCardMapping(gameId, mapping);
};

const extractGamePlayers = (game: GameState) => {
  return game.players.map((v) => v.id);
};
const parseAddress = (userAddress: string) => {
  if (userAddress.startsWith("0x0")) {
    userAddress = userAddress.replace("0x0", "");
  } else if (userAddress.startsWith("0x")) {
    userAddress = userAddress.replace("0x", "");
  }
  return userAddress;
};
const isPlayerPresentOnGame = async (
  pubKey: string,
  userSignedMessage: UserSignedMessage,
  players: string[]
): Promise<boolean> => {
  let userAddress = parseAddress(getAddressFromPublicKey(pubKey));

  const isSignatureValid = await verifySignature(
    pubKey,
    userSignedMessage.message,
    userSignedMessage.signedMessage
  );
  if (!isSignatureValid) {
    throw new Error("Invalid signature!");
  }
  return !!players.find((v) => parseAddress(v) == userAddress);
};

export const revealPlayerCard = async (
  gameId: number,
  userPubKey: string,
  userSignedMessage: UserSignedMessage
): Promise<Hand[]> => {
  const game = await getGameById(gameId);
  if (!game) {
    throw new Error("Game not found");
  }
  const players = extractGamePlayers(game);
  const isPresentOnGame = await isPlayerPresentOnGame(
    userPubKey,
    userSignedMessage,
    players
  );
  if (!isPresentOnGame) {
    throw new Error("User does not have permission to reveal cards");
  }
  const currentPlayerAddress = getAddressFromPublicKey(userPubKey);
  const currentPlayer = game.players.find(
    (v) => parseAddress(v.id) == parseAddress(currentPlayerAddress)
  );
  const playerCards = currentPlayer!.hand.map((v) => ({
    value: v.cardId,
    suit: v.cardId,
  }));
  if (currentPlayer!.status != PlayerStatus.Active) {
    throw new Error("Player is not active in this game");
  }
  const playerPrivateCards: Hand[] = await Promise.all(
    playerCards.map(
      async (v): Promise<Hand> => revealMappingFromDB(gameId, v.value!, v.suit!)
    )
  );
  return playerPrivateCards;
};

const getTableCards = (game: GameState) => {
  return game.community;
};

export const revealCommunityCards = async (gameId: number): Promise<Hand[]> => {
  const game = await getGameById(gameId);
  if (!game) {
    throw new Error("Game not found");
  }
  const tableCards = getTableCards(game);
  const revealedCommunityCards = await Promise.all(
    tableCards.map(async (v) => revealMappingFromDB(gameId, v.cardId, v.cardId))
  );
  return revealedCommunityCards;
};
