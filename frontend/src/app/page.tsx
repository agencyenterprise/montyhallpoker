"use client";

import { getAptosClient, getAptosWallet, toAptos } from "@/utils/aptosClient";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import classnames from "classnames";
import Image from "next/image";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useRouter } from "next/navigation";
import { Player, getGameByRoomId } from "../../controller/contract";
import Button from "@/components/Button";
import { parseAddress } from "@/utils/address";
import { PlayersIcon, BuyinIcon, MoneyIcon } from "@/components/Icons";
import { Room, GameRoom, MAX_PLAYER_COUNT, LOW_STAKES, MEDIUM_STAKES, HIGH_STAKES, AVAILABLE_ROOMS } from "@/constants";
import { playSound } from "../utils/audio";

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
  const [myRoom, setMyRoom] = useState<GameRoom | null>(null);

  useEffect(() => {
    fetchLobbyData().catch(console.error);
  }, []);

  const fetchLobbyData = async () => {
    const lobbyData = await Promise.all(AVAILABLE_ROOMS.map((room) => pullRoomData(room)));
    const isMeInAnyGame = !!lobbyData.find((room) => room.hasMe);
    const processedLobbyData = lobbyData.map((room) => {
      console.log(!room.hasMe && isMeInAnyGame, room.hasMe, isMeInAnyGame, room.players.length, MAX_PLAYER_COUNT);
      return {
        ...room,
        disabled: room.players.length >= MAX_PLAYER_COUNT && !room.hasMe,
      };
    });
    setMyRoom(processedLobbyData.find((room) => room.hasMe) || null);
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
      hasMe: !!game?.players.find((player) => parseAddress(player.id) === parseAddress(account.address)),
      disabled: false,
      ante: Number(game?.stake || 0),
      players: game?.players || [],
      maxPot: Number(game?.pot) || 0,
    };
    return newGameRoom;
  };

  return (
    <div>
      {myRoom && (
        <h1 className="text-white w-full text-center text-xl">
          You are currently playing in room{" "}
          <span
            onClick={() => {
              router.push(`/table/${myRoom.id}`);
              playSound("door");
            }}
            className="font-bold cursor-pointer underline"
          >
            {myRoom.name}
          </span>
        </h1>
      )}
      <div className="grid grid-cols-4 gap-6 mt-8">
        {allRoomsData.map((room) => {
          return <GameRoomBadge key={room.id} room={room} />;
        })}
      </div>
    </div>
  );
}

function Banner() {
  return <Image src="/banner.png" width={1280} height={308} alt="Cassino banner" />;
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
      style = "bg-game bg-[left_8rem_center] border-rose-400 border bg-no-repeat bg-scale";
      break;
    case MEDIUM_STAKES:
      bgColor = "bg-gradient-to-r from-amber-400/25 to-amber-400/0";
      style = "bg-game bg-[left_8rem_center] border-amber-400 border bg-no-repeat bg-scale";
      break;
    case LOW_STAKES:
      bgColor = "bg-gradient-to-r from-lime-400/25 to-lime-400/0";
      style = "bg-game border-lime-400 border bg-no-repeat bg-[left_8rem_center] bg-scale";
      break;
  }

  const joinGame = async () => {
    const wallet = getAptosWallet();
    const account = await wallet?.account();
    const meInRoom = room.players.find((player) => parseAddress(player.id) === parseAddress(account.address));

    if (meInRoom) {
      router.push(`/table/${room.id}`);
      playSound("door");
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
      playSound("door");
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
        title={room.disabled ? "You must finish your game first" : ""}
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
