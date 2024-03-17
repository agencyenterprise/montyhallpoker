"use client";

import { getAptosClient } from "@/utils/aptosClient";
import { useEffect, useState } from "react";
import classnames from "classnames";
import Image from "next/image";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useRouter } from "next/navigation";
import { CONTRACT_ADDRESS, getGameByRoomId } from "../../controller/contract";

export const AVAILABLE_ROOMS = [
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "10",
  "11",
  "12",
];

const aptosClient = getAptosClient();

export const MAX_PLAYER_COUNT = 4;
export const LOW_STAKES = 5000000; // More or less 0.05 APT
export const MEDIUM_STAKES = 30000000; // More or less 0.3 APT
export const HIGH_STAKES = 100000000; // More or less 1 APT

export default function Home() {
  const { connected } = useWallet();
  const router = useRouter();

  const goToTable = (roomId: string) => {
    router.push(`/table/${roomId}`);
  };

  return (
    <div className="text-white">
      <Banner />
      <div className="mt-6 w-full p-6 bg-slate-900 flex flex-col gap-6 rounded-[20px]">
        <h1 className="text-white text-2xl">Poker - Sit & Go</h1>
        <div className="grid grid-cols-4 gap-6">
          {AVAILABLE_ROOMS.map((room) => {
            return (
              <GameRoom key={room} onEnterRoom={goToTable} roomId={room} />
            );
          })}
        </div>
      </div>
    </div>
  );
}

const getAptosWallet = (): any => {
  if ("aptos" in window) {
    return window.aptos;
  } else {
    window.open("https://petra.app/", `_blank`);
  }
};
interface GameRoomProps extends React.HTMLAttributes<HTMLButtonElement> {
  roomId: string;
  onEnterRoom: (roomId: string) => void;
}

function GameRoom({ roomId, onEnterRoom }: GameRoomProps) {
  const { signAndSubmitTransaction } = useWallet();
  const [playerCount, setPlayerCount] = useState(0);
  const [buyinOctas, setBuyinOctas] = useState(0);
  const [buyin, setBuyin] = useState(0);
  const [maxPot, setMaxPot] = useState(0);
  const [color, setColor] = useState<"red" | "yellow" | "green">("green");
  const [currentGameId, setCurrentGameId] = useState("");

  useEffect(() => {
    pullRoomData().catch(console.error);
  });

  const joinGame = async () => {
    if (playerCount >= MAX_PLAYER_COUNT) {
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
          functionArguments: [`${currentGameId}`, `${buyinOctas}`],
        },
      });
      await aptosClient.waitForTransaction({
        transactionHash: response.hash,
      });
      await onEnterRoom(roomId);
    } catch (error: any) {
      console.error(error);
    }
  };

  const pullRoomData = async () => {
    const game = await getGameByRoomId(roomId);
    const stakeOctas = Number(game?.stake || 0);
    const stakeAptos = stakeOctas / 10 ** 8;
    const maxPotAptos = (Number(game?.pot) || 0) / 10 ** 8;
    setBuyinOctas(stakeOctas);
    setPlayerCount(game?.players.length || 0);
    setBuyin(stakeAptos);
    setMaxPot(maxPotAptos);
    setCurrentGameId(game?.id || "");
    if (stakeOctas <= LOW_STAKES) {
      setColor("green");
    }
    if (stakeOctas > LOW_STAKES && stakeOctas <= MEDIUM_STAKES) {
      setColor("yellow");
    }
    if (stakeOctas > MEDIUM_STAKES) {
      setColor("red");
    }

    console.log(game);
  };

  return (
    <GameRoomBadge
      onClick={joinGame}
      title={`Table ${roomId}`}
      playerCount={playerCount}
      buyin={buyin}
      maxPot={maxPot}
      color={color}
    />
  );
}

function Banner() {
  return (
    <Image src="/banner.png" width={1280} height={308} alt="Cassino banner" />
  );
}

interface GameRoomBadgeProps extends React.HTMLAttributes<HTMLButtonElement> {
  title: string;
  playerCount: number;
  buyin: number;
  maxPot: number;
  color: "red" | "yellow" | "green";
}

function GameRoomBadge({
  title,
  playerCount,
  buyin,
  maxPot,
  color,
  onClick,
}: GameRoomBadgeProps) {
  let style = "";
  let bgColor = "";
  switch (color) {
    case "red":
      bgColor = "bg-gradient-to-r from-rose-400/25 to-rose-400/0";
      style =
        "bg-game bg-[left_8rem_center] bg-scale border-rose-400 border bg-no-repeat bg-scale";
      break;
    case "yellow":
      bgColor = "bg-gradient-to-r from-amber-400/25 to-amber-400/0";
      style =
        "bg-game bg-[left_8rem_center] bg-scale border-amber-400 border bg-no-repeat bg-scale";
      break;
    case "green":
      bgColor = "bg-gradient-to-r from-lime-400/25 to-lime-400/0";
      style =
        "bg-game border-lime-400 border bg-no-repeat bg-[left_8rem_center] bg-scale";
      break;
  }

  return (
    <button
      className={classnames("rounded-[10px] w-[290px] ", bgColor)}
      onClick={onClick}
    >
      <div
        className={classnames(
          `font-bold text-white h-[142px] rounded-[10px] leading-[19px] p-4 flex ${style}`,
          playerCount >= 4 ? "cursor-not-allowed" : "cursor-pointer"
        )}
      >
        <div className="flex flex-col gap-y-[10px] text-justify">
          <h1>{title}</h1>
          <div className="flex gap-x-[10px]">
            <PlayersIcon />
            <p>{playerCount}/4</p>
          </div>
          <div className="flex gap-x-[10px]">
            <BuyinIcon />
            <p>{buyin.toFixed(2)} APT</p>
          </div>
          <div className="flex gap-x-[10px]">
            <MoneyIcon />
            <p>{maxPot.toFixed(2)} APT</p>
          </div>
        </div>
      </div>
    </button>
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
