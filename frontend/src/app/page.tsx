"use client";

import { getAptosClient, getAptosWallet, toAptos } from "@/utils/aptosClient";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import classnames from "classnames";
import Image from "next/image";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useRouter } from "next/navigation";
import { Player, getGameByRoomId } from "../../controller/contract";
import Button from "@/components/Button";

interface Room {
  id: string;
  name: string;
  ante: number;
}

interface GameRoom {
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

const CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS!;

const aptosClient = getAptosClient();

export default function Home() {
  const { connected } = useWallet();
  if (!connected) {
    return (
      <div className="text-white">
        <Banner />

        <div className="mt-6 w-full p-6 bg-slate-900 flex flex-col gap-6 rounded-[20px]">
          <div className="w-full h-full flex items-center justify-center  flex-col">
            <h1 className="text-2xl">Connect your wallet</h1>
            <p>Connect your wallet to play poker</p>
          </div>
        </div>
      </div>
    );
  }
  return (
    <div className="text-white">
      <Banner />
      <div className="mt-6 w-full p-6 bg-slate-900 flex flex-col gap-6 rounded-[20px]">
        <div className="w-full h-full flex items-center justify-center  flex-col">
          <h1 className="text-white text-2xl">Poker - Sit & Go</h1>
          <GameRoomLobby />
        </div>
      </div>
    </div>
  );
}

function GameRoomLobby() {
  const router = useRouter();
  const [allRoomsData, setAllRoomsData] = useState<GameRoom[]>([]);

  useEffect(() => {
    fetchLobbyData().catch(console.error);
  }, []);

  const fetchLobbyData = async () => {
    const lobbyData = await Promise.all(
      AVAILABLE_ROOMS.map((room) => pullRoomData(room))
    );
    const isMeInAnyGame = !!lobbyData.find((room) => room.hasMe);
    const processedLobbyData = lobbyData.map((room) => {
      return {
        ...room,
        disabled:
          room.players.length >= MAX_PLAYER_COUNT ||
          (!room.hasMe && isMeInAnyGame),
      };
    });
    setAllRoomsData(processedLobbyData);
  };

  const pullRoomData = async (room: Room): Promise<GameRoom> => {
    const wallet = getAptosWallet();
    const account = await wallet?.account();
    const game = await getGameByRoomId(room.id);

    const newGameRoom: GameRoom = {
      id: room.id,
      name: room.name,
      gameId: game?.id || "",
      hasMe: !!game?.players.find((player) => player.id === account.address),
      disabled: false,
      ante: Number(game?.stake || 0),
      players: game?.players || [],
      maxPot: Number(game?.pot) || 0,
    };
    return newGameRoom;
  };

  return (
    <div className="grid grid-cols-4 gap-6 mt-8">
      {allRoomsData.map((room) => {
        return <GameRoomBadge key={room.id} room={room} />;
      })}
    </div>
  );
}

function Banner() {
  return (
    <Image src="/banner.png" width={1280} height={308} alt="Cassino banner" />
  );
}

interface GameRoomBadgeProps extends React.HTMLAttributes<HTMLButtonElement> {
  room: GameRoom;
}

function GameRoomBadge({ room }: GameRoomBadgeProps) {
  const { signAndSubmitTransaction } = useWallet();
  const router = useRouter();
  let style = "";
  let bgColor = "";
  switch (room.ante) {
    case HIGH_STAKES:
      bgColor = "bg-gradient-to-r from-rose-400/25 to-rose-400/0";
      style =
        "bg-game bg-[left_8rem_center] bg-scale border-rose-400 border bg-no-repeat bg-scale";
      break;
    case MEDIUM_STAKES:
      bgColor = "bg-gradient-to-r from-amber-400/25 to-amber-400/0";
      style =
        "bg-game bg-[left_8rem_center] bg-scale border-amber-400 border bg-no-repeat bg-scale";
      break;
    case LOW_STAKES:
      bgColor = "bg-gradient-to-r from-lime-400/25 to-lime-400/0";
      style =
        "bg-game border-lime-400 border bg-no-repeat bg-[left_8rem_center] bg-scale";
      break;
  }

  const joinGame = async () => {
    const wallet = getAptosWallet();
    const account = await wallet?.account();
    const meInRoom = room.players.find(
      (player) => player.id === account.address
    );

    if (meInRoom) {
      router.push(`/table/${room.id}`);
      return;
    }
    if (room.players.length >= MAX_PLAYER_COUNT && !meInRoom) {
      return;
    }

    try {
      const wallet = getAptosWallet();
      const account = await wallet?.account();

      const response = await signAndSubmitTransaction({
        sender: account.address,

        data: {
          function: `${CONTRACT_ADDRESS}::poker_manager::join_game`,
          typeArguments: [],
          functionArguments: [`${room.gameId}`, `${room.ante}`],
        },
      });
      await aptosClient.waitForTransaction({
        transactionHash: response.hash,
      });
      router.push(`/table/${room.id}`);
    } catch (error: any) {
      console.error(error);
    }
  };
  return (
    <div className={classnames("rounded-[10px] w-[290px] ", bgColor)}>
      <div
        className={classnames(
          `font-bold text-white h-[142px] rounded-[10px] leading-[19px] p-4 flex justify-between ${style}`
        )}
      >
        <div className="flex flex-col gap-y-[10px] text-justify">
          <h1>{room.name}</h1>
          <div className="flex gap-x-[10px]">
            <PlayersIcon />
            <p>{room.players.length}/4</p>
          </div>
          <div className="flex gap-x-[10px]">
            <BuyinIcon />
            <p>{toAptos(room.ante).toFixed(2)} APT</p>
          </div>
          <div className="flex gap-x-[10px]">
            <MoneyIcon />
            <p>{toAptos(room.maxPot).toFixed(2)} APT</p>
          </div>
        </div>
        {!room.disabled && (
          <div className="flex h-full text-black items-end justify-end">
            <Button onClick={joinGame}>Join</Button>
          </div>
        )}
      </div>
    </div>
  );
}
function MoneyIcon() {
  return (
    <Image src="/money-icon.svg" width={14} height={14} alt="Money icon" />
  );
}
function PlayersIcon() {
  return (
    <Image src="/players-icon.svg" width={14} height={14} alt="Players icon" />
  );
}
function BuyinIcon() {
  return (
    <Image src="/buyin-icon.svg" width={14} height={14} alt="Buyin icon" />
  );
}
