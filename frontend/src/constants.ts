import { Player } from "../controller/contract";
export interface Room {
    id: string;
    name: string;
    ante: number;
}

export interface GameRoom {
    id: string;
    name: string;
    gameId: string;
    hasMe: boolean;
    disabled: boolean;
    ante: number;
    players: Player[];
    maxPot: number;
}
export const MAX_PLAYER_COUNT = 4;
export const LOW_STAKES = 5000000; // More or less 0.05 APT
export const MEDIUM_STAKES = 30000000; // More or less 0.3 APT
export const HIGH_STAKES = 100000000; // More or less 1 APT
export const AVAILABLE_ROOMS: Room[] = [
    { id: "1", name: "Pocket Pair Plaza", ante: LOW_STAKES },
    { id: "2", name: "Bluff Boulevard", ante: LOW_STAKES },
    { id: "3", name: "Flop Flats", ante: LOW_STAKES },
    { id: "4", name: "Jackpot Junction", ante: LOW_STAKES },
    { id: "5", name: "Blind Bluff Bay", ante: MEDIUM_STAKES },
    { id: "6", name: "Pot-Luck Point", ante: MEDIUM_STAKES },
    { id: "7", name: "Draw Duel Desert", ante: MEDIUM_STAKES },
    { id: "8", name: "High Roller Haven", ante: MEDIUM_STAKES },
    { id: "9", name: "Bet Bounty Beach", ante: HIGH_STAKES },
    { id: "10", name: "Ante Up Alley", ante: HIGH_STAKES },
    { id: "11", name: "Limitless Lagoon", ante: HIGH_STAKES },
    { id: "12", name: "All-In Avenue", ante: HIGH_STAKES },
];