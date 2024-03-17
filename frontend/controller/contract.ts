import { getAptosClient } from "../src/utils/aptosClient";

type Maybe<T> = T | null;

const client = getAptosClient();
const CONTRACT_ADDRESS =
  process.env.CONTRACT_ADDRESS ||
  "0x7436bbe16422c873f3d81bf1668b96ef50f2c6624a851c1a991c92de1b253b29";
type LastRaiser = {
  vec: string[];
};
export type DeckCard = {
  suit: number;
  suit_string?: string;
  value: number;
  value_string?: string;
};

export enum PlayerStatus {
  Active = 0,
  Folded = 1,
  AllIn = 2,
}

export enum GameStage {
  PreFlop = 0,
  Flop = 1,
  Turn = 2,
  River = 3,
  Showdown = 4,
}
export enum GameStatus {
  OPEN = 0,
  INPROGRESS = 1,
  CLOSE = 2,
}
type Player = {
  current_bet: string;
  hand: DeckCard[];
  id: string;
  status: PlayerStatus;
};
export type GameState = {
  community: DeckCard[];
  continueBetting: boolean;
  currentPlayerIndex: number;
  currentRound: number;
  current_bet: string;
  deck: DeckCard[];
  id: string;
  lastRaiser: LastRaiser;
  last_action_timestamp: string;
  order: any[];
  players: Player[];
  pot: string;
  room_id: string;
  seed: number;
  stage: GameStage;
  stake: string;
  starter: number;
  state: GameStatus;
  turn: string;
  winner: string;
};

export type ChainResponse = {
  vec: any[];
};

export const getGameById = async (
  gameId: number
): Promise<Maybe<GameState>> => {
  try {
    const game = await client.view({
      payload: {
        function: `${CONTRACT_ADDRESS}::poker_manager::get_game_by_id`,
        functionArguments: [`${gameId}`],
      },
    });
    return !game.length ? null : (game[0] as GameState);
  } catch (err) {
    return null;
  }
};

export const getGameByRoomId = async (
  roomId: string
): Promise<Maybe<GameState>> => {
  try {
    const game = (await client.view({
      payload: {
        function: `${CONTRACT_ADDRESS}::poker_manager::get_last_game_by_room_id`,
        functionArguments: [`${roomId}`],
      },
    })) as ChainResponse[];
    return !game.length ? null : (game[0]?.vec?.[0] as GameState);
  } catch (err) {
    return null;
  }
};
