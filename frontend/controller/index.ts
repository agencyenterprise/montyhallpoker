import { connectToDatabase } from "./mongodb";
import { getGameById, GameState, DeckCard, PlayerStatus } from "./contract";
import { verifySignature, getAddressFromPublicKey } from "./security";
import crypto from "crypto";
type CardValueMapping = Record<number, string>;
type SuitValueMapping = Record<number, string>;
export type Hand = { suit: string; value: string };
export type UserSignedMessage = { signedMessage: string; message: string };

const getGameMapping = async (gameId: number) => {
  const { db } = await connectToDatabase();
  const mappings = db.collection("mappings");
  return await mappings.findOne({ gameId });
};

const insertCardMapping = async (gameId: number, valueMapping: CardValueMapping, suitMapping: SuitValueMapping) => {
  const gameMapping = await getGameMapping(gameId);
  if (!gameMapping) {
    const { db } = await connectToDatabase();
    const mappings = db.collection("mappings");
    return await mappings.insertOne({ gameId, valueMapping, suitMapping });
  }
  return gameMapping;
};

const revealMappingFromDB = async (gameId: number, value: number, suit: number): Promise<Hand> => {
  const gameMapping = await getGameMapping(gameId);
  if (!gameMapping) {
    throw new Error("No game found!");
  }
  const { valueMapping, suitMapping } = gameMapping;
  const privateHandValue = valueMapping[value] as string;
  const privateHandSuit = suitMapping[suit] as string;
  if (!privateHandValue || !privateHandSuit) {
    throw new Error("Invalid suit or value index");
  }
  return { value: privateHandValue, suit: privateHandSuit };
};
function secureRandom(min: number, max: number) {
  return crypto.randomInt(min, max + 1);
}

const generateCardMappings = async () => {
  function shuffleArray(array: string[]) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = secureRandom(0, i);
      [array[i], array[j]] = [array[j], array[i]]; // Swap elements
    }
  }
  const cardValues = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace"];
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
  return { valueMapping, suitMapping };
};

export const createCardMapping = async (gameId: number) => {
  const { valueMapping, suitMapping } = await generateCardMappings();
  return await insertCardMapping(gameId, valueMapping, suitMapping);
};

const extractGamePlayers = (game: GameState) => {
  return game.players.map((v) => v.id);
};

const isPlayerPresentOnGame = async (
  pubKey: string,
  userSignedMessage: UserSignedMessage,
  players: string[]
): Promise<boolean> => {
  const userAddress = getAddressFromPublicKey(pubKey);
  const isSignatureValid = await verifySignature(pubKey, userSignedMessage.message, userSignedMessage.signedMessage);
  if (!isSignatureValid) {
    throw new Error("Invalid signature!");
  }
  return !!players.find((v) => v == userAddress);
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
  const isPresentOnGame = await isPlayerPresentOnGame(userPubKey, userSignedMessage, players);
  if (!isPresentOnGame) {
    throw new Error("User does not have permission to reveal cards");
  }
  const currentPlayerAddress = getAddressFromPublicKey(userPubKey);
  const currentPlayer = game.players.find((v) => v.id == currentPlayerAddress);
  const playerCards = currentPlayer!.hand.map((v) => ({
    value: v.value,
    suit: v.suit,
  }));
  if (currentPlayer!.status != PlayerStatus.Active) {
    throw new Error("Player is not active in this game");
  }
  const playerPrivateCards: Hand[] = await Promise.all(
    playerCards.map(async (v): Promise<Hand> => revealMappingFromDB(gameId, v.value, v.suit))
  );
  return playerPrivateCards;
};

const checkIfCardBelongToCommunityDeck = (tableCard: DeckCard, communityDeck: DeckCard[]): boolean => {
  return !!communityDeck.find((v) => v.suit == tableCard.suit && v.value == tableCard.value);
};

const checkIfTableCardsBelongToCommunityDeck = (tableCards: DeckCard[], communityDeck: DeckCard[]): boolean => {
  return tableCards.reduce((acc, value) => acc && checkIfCardBelongToCommunityDeck(value, communityDeck), true);
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
  const communityDeck = game!.deck;
  const areTableCardsCommunityCards = checkIfTableCardsBelongToCommunityDeck(tableCards, communityDeck);
  if (!areTableCardsCommunityCards) {
    throw new Error("Table cards are not community Cards");
  }
  const revealedCommunityCards = await Promise.all(
    tableCards.map(async (v) => revealMappingFromDB(gameId, v.value, v.suit))
  );
  return revealedCommunityCards;
};
