"use client";

import classnames from "classnames";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { CONTRACT_ADDRESS, GameState, GameStage, getGameByRoomId, GameStatus } from "../../../../controller/contract";
import { Maybe } from "aptos";
import { usePollingEffect } from "@/hooks/usePoolingEffect";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { getAptosClient, getAptosWallet, toAptos } from "../../../utils/aptosClient";
import Button from "@/components/Button";
import { parseAddress } from "@/utils/address";
import { useRouter } from "next/navigation";
import { skip } from "node:test";
import { playSound } from "../../../utils/audio";
import usePrevious from "../../../hooks/usePrevious";

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
  const { connected } = useWallet();
  const { signAndSubmitTransaction } = useWallet();
  const { roomId } = params;
  const [me, setMe] = useState(null);
  const [meIndex, setMeIndex] = useState(0);
  const [communityCards, setCommunityCards] = useState<PlayerCards[]>([]);
  const [currentPot, setCurrentPot] = useState(0);
  const [gameStarted, setGameStarted] = useState(false);
  const [handRevealed, setHandRevealed] = useState(false);
  const [gameState, setGameState] = useState<Maybe<GameState>>();
  const [userCards, setUserCards] = useState<PlayerCards[]>([]);
  const [stop, setStop] = useState(false);

  const currentGame = useRef<Maybe<GameState>>();

  const controller = new AbortController();
  const router = useRouter();

  const gameWorker = async () => {
    const game = await getGameByRoomId(roomId);
    // We have to manually set the currentGame ref to the game we want to track
    if (game && !currentGame.current) {
      currentGame.current = game;
    }
    if (currentGame.current?.id !== game?.id) {
      return;
    }
    const wallet = getAptosWallet();
    const { address } = await wallet?.account();
    const mePlayer = game?.players.find((player) => parseAddress(player.id) === parseAddress(address))!;
    const mePlayerIndex = game?.players.indexOf(mePlayer);
    setMeIndex(mePlayerIndex || 0);
    setGameState(game);
    if (game?.stage == GameStage.Showdown && game.state != GameStatus.CLOSE) {
      fetch(`/api/reveal/all`, {
        method: "POST",
        body: JSON.stringify({ gameId: Number(game.id) }),
        headers: {
          "Content-Type": "application/json",
        },
      });
    } else if (game?.state == GameStatus.CLOSE) {
      alert("Game Ended!");
    }
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
    if (gameState?.state == GameStatus.CLOSE) {
      setStop(true);
    }
  }, [gameState]);

  const previousGameState = usePrevious<Maybe<GameState> | undefined>(gameState);

  useEffect(() => {
    retrieveGameState();
  }, [gameState]);

  useEffect(() => {
    if (gameState && gameState?.state === GameStatus.INPROGRESS && !handRevealed) {
      revealCurrentUserCard();
      setHandRevealed(true);
    }
  }, [gameStarted, gameState]);

  useEffect(() => {
    if (gameState?.state == GameStatus.INPROGRESS) {
      console.log("turn ", gameState?.turn, " me", me, " previous turn", previousGameState?.turn);
      if (gameState?.turn == me && previousGameState?.turn != me) {
        if (document.hidden) {
          playSound("your-turn-blurred");
        } else {
          playSound("your-turn");
        }
      } else if (gameState?.turn != me && previousGameState?.turn != me && gameState?.turn != previousGameState?.turn) {
        // determine last action made
        if (+gameState?.current_bet > +previousGameState?.current_bet) {
          playSound("more-chips");
          console.log("raise");
        } else if (+gameState?.current_bet == +previousGameState?.current_bet && +gameState?.current_bet > 0) {
          playSound("chips");
          console.log("call");
          // if last player is folded do not play check sound:
        } else if (
          +gameState?.current_bet == 0 &&
          gameState?.players?.[previousGameState?.currentPlayerIndex]?.status != 1
        ) {
          playSound("wood-knock");
          console.log("check");
        } else if (gameState?.players?.[previousGameState.currentPlayerIndex]?.status == 1) {
          playSound("fold", 0.7);
          console.log("fold");
        }
      }
    }
    if (gameState?.stage == GameStage.Flop && previousGameState?.stage != GameStage.Flop) {
      revealComunityCards(gameState.id);
    } else if (gameState?.stage == GameStage.Turn && previousGameState?.stage != GameStage.Turn) {
      revealComunityCards(gameState.id);
    } else if (gameState?.stage == GameStage.River && previousGameState?.stage != GameStage.River) {
      revealComunityCards(gameState.id);
    }
  }, [gameState, me]);

  const revealComunityCards = async (gameId: string, retry = 0) => {
    if (!gameId) {
      return;
    }
    if (retry > 3) {
      alert("Failed to reveal community cards, try refreshing the page");
      return;
    }
    const response = await fetch(`/api/reveal/community`, {
      method: "POST",
      body: JSON.stringify({ gameId: Number(gameId) }),
      headers: {
        "Content-Type": "application/json",
      },
    });
    const data = await response.json();
    if (data.message == "OK") {
      setCommunityCards(data.communityCards);
      playSound("shuffle");
    } else {
      console.error(data);
      // Retry
      setTimeout(() => {
        revealComunityCards(gameId, retry + 1);
      }, 2000);
    }
  };

  const retrieveGameState = async (): Promise<void> => {
    const wallet = getAptosWallet();
    try {
      const account = await wallet?.account();
      if (account.address) {
        setMe(account.address);

        setGameStarted(true);
        setCurrentPot(toAptos(gameState?.pot!));
      }
    } catch (error) {
      // { code: 4001, message: "User rejected the request."}
      console.error(error);
    }
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
      setUserCards(data.userCards);
      playSound("harp");
    }
  };

  return (
    <div className="h-full w-full flex items-center justify-center relative">
      <div className="relative">
        <div className="absolute max-w-[582px] flex justify-between w-full top-0 left-[290px]">
          <PlayerBanner
            isMe={false}
            gameState={gameState!}
            currentIndex={gameState?.currentPlayerIndex || 0}
            playerIndex={(meIndex + 1) % 4}
            stack={1000}
            position={2}
          />
          <PlayerBanner
            isMe={false}
            gameState={gameState!}
            currentIndex={gameState?.currentPlayerIndex || 0}
            playerIndex={(meIndex + 2) % 4}
            stack={1000}
            position={1}
          />
        </div>
        <div className="absolute max-w-[582px] flex justify-between items-end h-full w-full top-0 left-[290px] bottom-0">
          <PlayerBanner
            isMe={true}
            gameState={gameState!}
            currentIndex={gameState?.currentPlayerIndex || 0}
            playerIndex={meIndex % 4}
            stack={1000}
            position={0}
            cards={userCards}
          />
          <PlayerBanner
            isMe={false}
            gameState={gameState!}
            currentIndex={gameState?.currentPlayerIndex || 0}
            playerIndex={(meIndex + 3) % 4}
            stack={1000}
            position={3}
          />
        </div>
        <div className="absolute h-full w-full flex gap-x-3 items-center justify-center">
          {communityCards.map((card, index) => (
            <Card valueString={`${card.suit}_${card.value}`} size="large" key={index} />
          ))}
        </div>
        <div className="flex gap-x-4">
          <ActionButtons meIndex={meIndex} gameState={gameState!} />
        </div>
        <div className="absolute right-40 h-full flex justify-center gap-x-2 items-center text-white">
          <Stack stack={currentPot} />
        </div>
        <PokerTable />
      </div>
    </div>
  );
}

function PokerStackIcon() {
  return <Image src="/poker-stacks.png" alt="Poker Stacks" width={20} height={15} />;
}
interface ActionButtonsProps {
  gameState: Maybe<GameState>;
  meIndex: number;
}

function ActionButtons({ meIndex, gameState }: ActionButtonsProps) {
  const { signAndSubmitTransaction } = useWallet();
  const [raiseValue, setRaiseValue] = useState<number>(Number(gameState?.stake) || 0);
  const maxValue = Number();
  const skipInactivePlayer = async () => {
    try {
      if (!gameState?.id) {
        return;
      }
      const currentUnixTimestamp = Math.floor(Date.now() / 1000);
      const lastActionUnixTimestamp = Number(gameState!.last_action_timestamp);
      if (currentUnixTimestamp - lastActionUnixTimestamp < 60) {
        return;
      }
      const wallet = getAptosWallet();
      const account = await wallet?.account();
      const response = await signAndSubmitTransaction({
        sender: account.address,

        data: {
          function: `${CONTRACT_ADDRESS}::poker_manager::skip_inactive_player`,
          typeArguments: [],
          functionArguments: [`${gameState!.id!}`],
        },
      });
      await aptosClient.waitForTransaction({
        transactionHash: response.hash,
      });
    } catch (error: any) {
      console.error(error);
    }
  };
  // 0 FOLD, 1 CHECK, 2 CALL, 3 RAISE, 4 ALL_IN
  const performAction = async (action: number, amount: number) => {
    if (!gameState?.id) {
      return;
    }

    console.log(Number(+gameState?.current_bet - +gameState!.players[meIndex].current_bet));

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

      switch (action) {
        case ACTIONS.CALL:
          playSound("chips");
          break;
        case ACTIONS.RAISE:
          playSound("more-chips");
          break;
        case ACTIONS.CHECK:
          playSound("wood-knock");
          alert("action from player");
          break;
        case ACTIONS.FOLD:
          playSound("fold", 0.7);
          break;
        default:
          break;
      }

      await aptosClient.waitForTransaction({
        transactionHash: response.hash,
      });
      // Do something
    } catch (error: any) {
      //console.error(error);
    }
  };

  if (!gameState) {
    return <div></div>;
  }

  if (gameState.state == GameStatus.OPEN) {
    return (
      <div className="absolute top-4 left-4">
        <div className="text-white whitespace-pre font-bold">
          Waiting for {4 - gameState.players.length} more players
        </div>
      </div>
    );
  }

  if (meIndex !== gameState?.currentPlayerIndex && +gameState.last_action_timestamp - Date.now() / 1000 > 30) {
    return (
      <div className="flex w-fit absolute bottom-4 -left-20" title="You can skip an inactive player after 60s">
        <Button className="w-full whitespace-pre" onClick={skipInactivePlayer}>
          Skip inactive player
        </Button>
      </div>
    );
  }

  if (meIndex !== gameState?.currentPlayerIndex) {
    return <div></div>;
  }

  return (
    <div className="flex flex-col gap-y-4 absolute bottom-4 left-4">
      <div className="flex gap-x-2 h-fit">
        <Button disabled={raiseValue <= 0} onClick={() => setRaiseValue((prev) => prev - Number(gameState?.stake))}>
          -
        </Button>
        <input
          className="text-center bg-[#0F172A] text-white w-[100px] h-auto min-h-full rounded-[10px] border border-cyan-400"
          value={toAptos(raiseValue).toFixed(2)}
        />
        <Button onClick={() => setRaiseValue((prev) => prev + Number(gameState?.stake))}>+</Button>
      </div>
      <Button onClick={() => performAction(ACTIONS.RAISE, raiseValue)}>Raise</Button>
      <div className="flex gap-x-4 w-full">
        <Button className="w-full" onClick={() => performAction(ACTIONS.FOLD, 0)}>
          Fold
        </Button>
        {Number(gameState?.current_bet) > 0 && (
          <Button
            className="w-full"
            onClick={() =>
              performAction(ACTIONS.CALL, Number(+gameState?.current_bet - +gameState!.players[meIndex].current_bet))
            }
          >
            Call
          </Button>
        )}
        {Number(gameState?.current_bet) === 0 && (
          <Button className="w-full" onClick={() => performAction(ACTIONS.CHECK, 0)}>
            Check
          </Button>
        )}
      </div>
    </div>
  );
}

function PokerTable() {
  return <Image src="/poker-table.png" alt="Poker Table" width={1200} height={800} />;
}

interface PlayerBannerProps {
  isMe: boolean;
  currentIndex: number;
  playerIndex: number;
  gameState: GameState;
  stack: number;
  cards?: PlayerCards[];
  position: number;
}
function PlayerBanner({ isMe, currentIndex, playerIndex: index, gameState, cards, position }: PlayerBannerProps) {
  const width = isMe ? "w-[230px]" : "w-[174px]";
  const playerIndex = index;
  if (typeof gameState?.players[playerIndex] === "undefined") {
    return (
      <div className={classnames("relative", width, !isMe ? "mx-7" : "")}>
        {playerIndex == currentIndex && <TurnToken position={position} />}
        <div
          className={classnames(
            "rounded-[50px] h-[87px] border bg-gradient-to-r z-[2] from-cyan-400 to-[#0F172A] border-cyan-400 relative w-full flex",
            width
          )}
        ></div>
      </div>
    );
  }
  const playerBet = Number(gameState.players[playerIndex].current_bet);
  const playerStack = gameState.players[playerIndex];
  const playerCards = gameState.players[playerIndex].hand;

  return (
    <div className={classnames("relative", width, !isMe ? "mx-7" : "")}>
      {playerIndex == currentIndex && <TurnToken position={position} />}

      <div className={classnames("absolute -top-[120px] ")}>
        <Stack stack={playerBet} />
      </div>
      {playerCards.length == 2 && <Cards cards={cards} />}
      <div
        className={classnames(
          "rounded-[50px] h-[87px] border bg-gradient-to-r z-[2] from-cyan-400 to-[#0F172A] border-cyan-400 relative w-full flex",
          width
        )}
      >
        <Image src="/player-avatar.svg" alt="Avatar" width={81} height={81} className="" />
        <div className="text-white flex flex-col justify-between py-2">
          <h1 className="font-bold text-sm">Player {playerIndex + 1}</h1>
          <div>
            <div className="flex gap-x-1 text-xs">
              <StackIcon />
              <span>{1000}</span>
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

function StackIcon() {
  return <Image src="/stack-icon.svg" height="13" width="13" alt="icon" />;
}
interface StackProps {
  stack: number;
}

function Stack({ stack }: StackProps) {
  return (
    <div className="flex gap-x-2">
      <PokerStackIcon />{" "}
      <span className="flex gap-x-2 text-white rounded-full bg-[#0F172A] px-2 py-[6px] text-xs">
        <StackIcon />
        {toAptos(stack).toFixed(2)}
      </span>
    </div>
  );
}

function TurnToken({ position }: { position: number }) {
  return (
    <div
      className={classnames(
        "absolute -bottom-20 rounded-full text-white font-bold border-cyan-400 border bg-slate-700 w-10 h-10 flex items-center justify-center",
        position == 0 ? "-top-20 -left-10" : "",
        position == 3 ? "-top-20" : ""
      )}
    >
      T
    </div>
  );
}

interface CardsProps {
  cards?: PlayerCards[];
}
function Cards({ cards }: CardsProps) {
  const cardPosition = cards?.length ? "left-4" : `left-10`;

  return (
    <div className={classnames("w-[91px] h-[91px] z-[1] text-white absolute -top-10", cardPosition)}>
      <div className="flex relative mx-auto">
        {!cards?.length && <BackCards />}
        {cards?.length && (
          <div className="absolute flex gap-x-[10px] -top-10">
            <Card valueString={`${cards[0].suit}_${cards[0].value}`} size="large" />
            <Card valueString={`${cards[1].suit}_${cards[1].value}`} size="large" />
          </div>
        )}
      </div>
    </div>
  );
}

function BackCards() {
  return (
    <div>
      <Image src="/card-back.svg" alt="Card Back" width={61} height={91} className="absolute z-[2]" />
      <Image src="/card-back.svg" alt="Card Back" width={61} height={91} className="absolute z-[1] left-[30px]" />
    </div>
  );
}

function Card({ valueString, size }: { valueString: string; size: "small" | "large" }) {
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
      <Image src={`/cards/${valueString}.png`} alt="Card Club" width={width} height={height} />
    </div>
  );
}
