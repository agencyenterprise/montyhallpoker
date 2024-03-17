"use client";

import classnames from "classnames";
import Image from "next/image";
import { cn } from "@/utils/styling";
import { useEffect, useState } from "react";
import { GameState, getGameByRoomId } from "../../../../controller/contract";
import { Maybe } from "aptos";
import { usePollingEffect } from "@/hooks/usePoolingEffect";

const getAptosWallet = (): any => {
  if ("aptos" in window) {
    return window.aptos;
  } else {
    window.open("https://petra.app/", `_blank`);
  }
};

export default function PokerGameTable({ params }: { params: any }) {
  const { roomId } = params;
  const [loaded, setLoaded] = useState(false);
  const [me, setMe] = useState(null);
  const [currentPlayer, setCurrentPlayer] = useState(null);
  const [playerOne, setPlayerOne] = useState(null);
  const [playerTwo, setPlayerTwo] = useState(null);
  const [playerThree, setPlayerThree] = useState(null);
  const [playerFour, setPlayerFour] = useState(null);
  const [communityCards, setCommunityCards] = useState([]);
  const [gameState, setGameState] = useState<Maybe<GameState>>();
  const [stop, setStop] = useState(false)
  const controller = new AbortController();
  const gameWorker = async () => {
    const game = await getGameByRoomId(roomId)
    setGameState(game)
  }
  usePollingEffect(
    async () => await gameWorker(),
    [],
    { interval: 2000, stop, controller }
  )
  useEffect(() => {
    console.log(gameState);
  }, [gameState])
  useEffect(() => {
    retrieveGameState()
  });

  const retrieveGameState = async (): Promise<void> => {
    const wallet = getAptosWallet();
    try {
      const account = await wallet?.account();
      setMe(account.address);
    } catch (error) {
      // { code: 4001, message: "User rejected the request."}
    }
    setLoaded(true);
  };
  const revealCurrentUserCard = async () => {
    const message = "Sign this to reveal your cards";
    const nonce = Date.now().toString();
    const aptosClient = getAptosWallet()
    const response = await aptosClient.signMessage({
      message,
      nonce,
    });
    const { publicKey } = await aptosClient.account();
    const revealPayload = {
      gameId: gameState!.id,
      userPubKey: publicKey,
      userSignedMessage: response,
    };
    const res = await fetch(`/api/reveal/private`, {
      method: "POST",
      body: JSON.stringify(revealPayload),
      headers: {
        "Content-Type": "application/json",
      },
    });
    const data = await res.json();
    console.log(data);
  }

  return (
    <div className="h-full w-full flex items-center justify-center relative">
      <div className="relative">
        <div className="absolute max-w-[582px] flex justify-between w-full top-0 left-[290px]">
          <PlayerBanner
            isMe={false}
            name="Player 1"
            stack={1000}
            position={1}
          />
          <PlayerBanner
            isMe={false}
            name="Player 2"
            stack={1000}
            position={1}
          />
        </div>
        <div className="absolute max-w-[582px] flex justify-between items-end h-full w-full top-0 left-[290px] bottom-0">
          <PlayerBanner isMe={true} name="Player 3" stack={1000} position={1} />
          <PlayerBanner
            isMe={false}
            name="Player 4"
            stack={1000}
            position={1}
          />
        </div>
        <div className="absolute h-full w-full flex gap-x-3 items-center justify-center">
          {communityCards.map((card, index) => (
            <Card valueString={card} size="large" key={index} />
          ))}
        </div>
        <div className="absolute -bottom-20 flex gap-x-4">
          <ActionButtons />
        </div>
        <PokerTable />
      </div>
    </div>
  );
}

function ActionButtons() {
  return (
    <>
      <button
        className={cn(
          "nes-btn is-primary py-[10px] px-[24px] bg-cyan-400 font-bold rounded-[4px]"
        )}
      >
        Raise
      </button>
      <button
        className={cn(
          "nes-btn is-primary py-[10px] px-[24px] bg-cyan-400 font-bold rounded-[4px]"
        )}
      >
        Fold
      </button>
      <button
        className={cn(
          "nes-btn is-primary py-[10px] px-[24px] bg-cyan-400 font-bold rounded-[4px]"
        )}
      >
        Call
      </button>
      <button
        className={cn(
          "nes-btn is-primary py-[10px] px-[24px] bg-cyan-400 font-bold rounded-[4px]"
        )}
      >
        Check
      </button>
    </>
  );
}

function PokerTable() {
  return (
    <Image src="/poker-table.png" alt="Poker Table" width={1200} height={800} />
  );
}

interface PlayerBannerProps {
  isMe: boolean;
  name: string;
  stack: number;
  position: number;
}
function PlayerBanner({ isMe, name, stack, position }: PlayerBannerProps) {
  const width = isMe ? "w-[230px]" : "w-[174px]";

  return (
    <div className={classnames("relative", width, !isMe ? "mx-7" : "")}>
      <Cards show={isMe} />
      <div
        className={classnames(
          "rounded-[50px] h-[87px] border bg-gradient-to-r z-[2] from-cyan-400 to-[#0F172A] border-cyan-400 relative w-full flex",
          width
        )}
      >
        <Image
          src="/player-avatar.svg"
          alt="Avatar"
          width={81}
          height={81}
          className=""
        />
        <div className="text-white flex flex-col justify-between py-2">
          <h1 className="font-bold text-sm">{name}</h1>
          <div>
            <div className="flex gap-x-1 text-xs">
              <Image src="/stack-icon.svg" height="13" width="13" alt="icon" />
              <span>{stack}</span>
            </div>

            <div className="flex gap-x-1 text-xs">
              <Image src="/trophy-icon.svg" height="13" width="13" alt="icon" />
              <span>2/20</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

interface CardsProps {
  show: boolean;
}
function Cards({ show }: CardsProps) {
  const cardPosition = show ? "left-4" : `left-10`;

  return (
    <div
      className={classnames(
        "w-[91px] h-[91px] z-[1] text-white absolute -top-10",
        cardPosition
      )}
    >
      <div className="flex relative mx-auto">
        {!show && <BackCards />}
        {show && (
          <div className="absolute flex gap-x-[10px] -top-10">
            <Card valueString="clubs_king" size="large" />
            <Card valueString="diamonds_ace" size="large" />
          </div>
        )}
      </div>
    </div>
  );
}

function BackCards() {
  return (
    <div>
      <Image
        src="/card-back.svg"
        alt="Card Back"
        width={61}
        height={91}
        className="absolute z-[2]"
      />
      <Image
        src="/card-back.svg"
        alt="Card Back"
        width={61}
        height={91}
        className="absolute z-[1] left-[30px]"
      />
    </div>
  );
}

function Card({
  valueString,
  size,
}: {
  valueString: string;
  size: "small" | "large";
}) {
  const width = size === "small" ? 61 : 95;
  const height = size === "small" ? 91 : 144;
  return (
    <div
      className=" bg-white rounded-[10px] border border-black flex items-center justify-center"
      style={{
        width: `${width}px`,
        height: `${height}px`,
      }}
    >
      <Image
        src={`/cards/${valueString}.png`}
        alt="Card Club"
        width={width}
        height={height}
      />
    </div>
  );
}
