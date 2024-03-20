import { getAptosClient } from "../src/utils/aptosClient";

type Maybe<T> = T | null;

const client = getAptosClient();
export const CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS!;
type LastRaiser = {
  vec: string[];
};
export type DeckCard = {
  cardId: number;
  suit?: number;
  value?: number;
  suit_string?: string;
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
export enum GameStage {
  OPEN = "0",
  INPROGRESS = "1",
  CLOSE = "2",
}
export type Player = {
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
  state: GameStage;
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
