"use client";

import classnames from "classnames";
import Image from "next/image";
import { cn } from "@/utils/styling";
import { useEffect, useState } from "react";
import {
  CONTRACT_ADDRESS,
  GameState,
  GameStatus,
  getGameByRoomId,
} from "../../../../controller/contract";
import { Maybe } from "aptos";
import { usePollingEffect } from "@/hooks/usePoolingEffect";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { getAptosClient } from "../../../utils/aptosClient";
import Button from "@/components/Button";

const getAptosWallet = (): any => {
  if ("aptos" in window) {
    return window.aptos;
  } else {
    window.open("https://petra.app/", `_blank`);
  }
};

const ACTIONS = {
  FOLD: 0,
  CHECK: 1,
  CALL: 2,
  RAISE: 3,
  ALL_IN: 4,
};

const aptosClient = getAptosClient();

interface PlayerCards {
  suit: string;
  value: string;
}

export default function PokerGameTable({ params }: { params: any }) {
  const { roomId } = params;
  const [loaded, setLoaded] = useState(false);
  const [me, setMe] = useState(null);
  const [meIndex, setMeIndex] = useState(0);
  const [currentPlayer, setCurrentPlayer] = useState(null);
  const [playerOne, setPlayerOne] = useState(null);
  const [playerTwo, setPlayerTwo] = useState(null);
  const [playerThree, setPlayerThree] = useState(null);
  const [playerFour, setPlayerFour] = useState(null);
  const [communityCards, setCommunityCards] = useState([]);
  const [currentPot, setCurrentPot] = useState(0);
  const [gameStarted, setGameStarted] = useState(false);
  const [handRevealed, setHandRevealed] = useState(false);
  const [gameState, setGameState] = useState<Maybe<GameState>>();
  const [userCards, setUserCards] = useState<PlayerCards[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [stop, setStop] = useState(false);
  const controller = new AbortController();
  const gameWorker = async () => {
    const game = await getGameByRoomId(roomId);
    setGameState(game);
    const wallet = getAptosWallet();
    const { address } = await wallet?.account()
    const mePlayer = gameState?.players.find((player) => player.id === address)!;
    const mePlayerIndex = gameState?.players.indexOf(mePlayer);
    setMeIndex(mePlayerIndex || 0);
    //console.log("oie", mePlayerIndex);
    //console.log(me)
  };
  usePollingEffect(async () => await gameWorker(), [], {
    interval: 2000,
    stop,
    controller,
  });
  useEffect(() => {
    console.log(gameState);
  }, [gameState]);

  useEffect(() => {
    retrieveGameState();
  }, []);

  useEffect(() => {
    if (
      gameState &&
      gameState?.state === GameStatus.INPROGRESS &&
      !handRevealed
    ) {
      revealCurrentUserCard();
      setHandRevealed(true);
    }
  }, [gameStarted, gameState]);

  const retrieveGameState = async (): Promise<void> => {
    const wallet = getAptosWallet();
    try {
      const account = await wallet?.account();

      if (account.address) {
        setMe(account.address);
        console.log(account.address);
        setGameStarted(true);
        setCurrentPot(Number(gameState?.pot) / 10 ** 8);
      }
    } catch (error) {
      // { code: 4001, message: "User rejected the request."}
      console.error(error);
    }
    setLoaded(true);
  };

  const revealCurrentUserCard = async () => {
    const message = "Sign this to reveal your cards";
    const nonce = Date.now().toString();
    const aptosClient = getAptosWallet();
    const response = await aptosClient.signMessage({
      message,
      nonce,
    });
    const { publicKey } = await aptosClient.account();

    const revealPayload = {
      gameId: +gameState!.id,
      userPubKey: publicKey,
      userSignedMessage: {
        message: response.fullMessage,
        signedMessage: response.signature,
      },
    };

    const res = await fetch(`/api/reveal/private`, {
      method: "POST",
      body: JSON.stringify(revealPayload),
      headers: {
        "Content-Type": "application/json",
      },
    });

    const data = await res.json();
    if (data.message == "OK") {
      //console.log(data);
      setUserCards(data.userCards);
    }
  };

  return (
    <div className="h-full w-full flex items-center justify-center relative">
      <div className="relative">
        <div className="absolute max-w-[582px] flex justify-between w-full top-0 left-[290px]">
          <PlayerBanner
            isMe={false}
            name={`Player ${((meIndex + 1) % 4) + 1}`}
            stack={1000}
            position={1}
          />
          <PlayerBanner
            isMe={false}
            name={`Player ${((meIndex + 2) % 4) + 1}`}
            stack={1000}
            position={1}
          />
        </div>
        <div className="absolute max-w-[582px] flex justify-between items-end h-full w-full top-0 left-[290px] bottom-0">
          <PlayerBanner
            isMe={true}
            name={`Player ${meIndex + 1}`}
            stack={1000}
            position={1}
            cards={userCards}
          />
          <PlayerBanner
            isMe={false}
            name={`Player ${((meIndex + 3) % 4) + 1}`}
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
          <ActionButtons meIndex={meIndex} gameState={gameState!} />
        </div>
        <div className="absolute right-40 h-full flex justify-center items-center text-white">
          Pot: {currentPot.toFixed(2)}
        </div>
        <PokerTable />
      </div>
    </div>
  );
}

interface ActionButtonsProps {
  gameState: Maybe<GameState>;
  meIndex: number;
}

function ActionButtons({ meIndex, gameState }: ActionButtonsProps) {
  const { signAndSubmitTransaction } = useWallet();
  const [raiseValue, setRaiseValue] = useState<number>(
    Number(gameState?.stake) || 0
  );
  const maxValue = Number();

  // 0 FOLD, 1 CHECK, 2 CALL, 3 RAISE, 4 ALL_IN
  const performAction = async (action: number, amount: number) => {
    if (!gameState?.id) {
      //console.log("no game id");
      return;
    }

    try {
      const wallet = getAptosWallet();
      const account = await wallet?.account();
      const response = await signAndSubmitTransaction({
        sender: account.address,
        data: {
          function: `${CONTRACT_ADDRESS}::poker_manager::perform_action`,
          typeArguments: [],
          functionArguments: [`${gameState.id}`, `${action}`, `${amount}`],
        },
      });
      await aptosClient.waitForTransaction({
        transactionHash: response.hash,
      });
      // Do something
    } catch (error: any) {
      //console.error(error);
    }
  };

  if (meIndex !== gameState?.currentPlayerIndex) {
    return <div></div>;
  }

  return (
    <div className="flex flex-col gap-y-4">
      <div className="flex gap-x-2 h-fit">
        <Button
          disabled={raiseValue <= 0}
          onClick={() =>
            setRaiseValue((prev) => prev - Number(gameState?.stake))
          }
        >
          -
        </Button>
        <input
          className="text-center bg-[#0F172A] text-white w-[100px] h-full rounded-[10px] border border-cyan-400"
          value={Number(raiseValue / 10 ** 8).toFixed(2)}
        />
        <Button
          onClick={() =>
            setRaiseValue((prev) => prev + Number(gameState?.stake))
          }
        >
          +
        </Button>
      </div>
      <Button
        onClick={() => performAction(ACTIONS.RAISE, Number(gameState?.stake))}
      >
        Raise
      </Button>
      <div className="flex gap-x-4 w-full">
        <Button
          className="w-full"
          onClick={() => performAction(ACTIONS.FOLD, 0)}
        >
          Fold
        </Button>
        {Number(gameState?.current_bet) > 0 && (
          <Button
            className="w-full"
            onClick={() =>
              performAction(ACTIONS.CALL, Number(gameState?.stake))
            }
          >
            Call
          </Button>
        )}
        {Number(gameState?.current_bet) === 0 && (
          <Button
            className="w-full"
            onClick={() => performAction(ACTIONS.CHECK, 0)}
          >
            Check
          </Button>
        )}
      </div>
    </div>
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
  cards?: PlayerCards[];
  position: number;
}
function PlayerBanner({
  isMe,
  name,
  stack,
  cards,
  position,
}: PlayerBannerProps) {
  const width = isMe ? "w-[230px]" : "w-[174px]";

  return (
    <div className={classnames("relative", width, !isMe ? "mx-7" : "")}>
      <Cards cards={cards} />
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
  cards?: PlayerCards[];
}
function Cards({ cards }: CardsProps) {
  const cardPosition = cards?.length ? "left-4" : `left-10`;

  return (
    <div
      className={classnames(
        "w-[91px] h-[91px] z-[1] text-white absolute -top-10",
        cardPosition
      )}
    >
      <div className="flex relative mx-auto">
        {!cards?.length && <BackCards />}
        {cards?.length && (
          <div className="absolute flex gap-x-[10px] -top-10">
            <Card
              valueString={`${cards[0].suit}_${cards[0].value}`}
              size="large"
            />
            <Card
              valueString={`${cards[1].suit}_${cards[1].value}`}
              size="large"
            />
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
