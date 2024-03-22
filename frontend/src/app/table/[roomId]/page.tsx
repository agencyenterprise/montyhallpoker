"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { GameState, GameStage, getGameByRoomId, GameStatus, getGameById } from "../../../../controller/contract";
import { Maybe } from "aptos";
import { usePollingEffect } from "@/hooks/usePoolingEffect";
import { getAptosWallet, toAptos } from "../../../utils/aptosClient";
import { parseAddress } from "@/utils/address";
import { playSound } from "../../../utils/audio";
import usePrevious from "../../../hooks/usePrevious";
import { AVAILABLE_ROOMS } from "@/constants";
import { Card } from "@/components/PlayerCards";
import { SingleCard } from "@/components/SingleCard";
import { ActionButtons } from "@/components/ActionButtons";
import { PlayerBanner } from "@/components/PlayerBanner";
import { Stack } from "@/components/Stack";
import { GameEndModal } from "@/components/GameEndModal";

export default function PokerGameTable({ params }: { params: any }) {
  const { roomId } = params;
  const [me, setMe] = useState<string>("");
  const [meIndex, setMeIndex] = useState(0);
  const [communityCards, setCommunityCards] = useState<Card[]>([]);
  const [currentPot, setCurrentPot] = useState(0);
  const [gameStarted, setGameStarted] = useState(false);
  const [handRevealed, setHandRevealed] = useState(false);
  const [gameState, setGameState] = useState<Maybe<GameState>>();
  const [userCards, setUserCards] = useState<Card[]>([]);
  const [stop, setStop] = useState(false);
  const [showGameEndModal, setShowGameEndModal] = useState(false);

  const gameId = useRef<string | undefined>();

  const controller = new AbortController();

  const gameWorker = async () => {
    let game;

    if (!gameId.current) {
      game = await getGameByRoomId(roomId);
      gameId.current = game?.id;
      setShowGameEndModal(false);
    } else {
      game = await getGameById(Number(gameId.current));
      gameId.current = game?.id;
    }

    if (!game) {
      return;
    }
    const wallet = getAptosWallet();

    const { address, ...rest } = await wallet?.account();
    const mePlayer = game?.players.find((player) => parseAddress(player.id) === parseAddress(address))!;

    const mePlayerIndex = game?.players.indexOf(mePlayer);
    setMeIndex(mePlayerIndex || 0);
    setGameState(game);
    window.localStorage.setItem("game", JSON.stringify(game ?? {}));

    if (game?.stage == GameStage.Showdown && game.state != GameStatus.CLOSE) {
      window.localStorage.setItem("game", JSON.stringify(game ?? {}));
      const response = await fetch(`/api/reveal/all`, {
        method: "POST",
        body: JSON.stringify({ gameId: Number(game.id) }),
        headers: {
          "Content-Type": "application/json",
        },
      });
      const data = await response.json();
      if (data.message == "OK") {
        playSound("winner");
      }
    } else if (game?.state == GameStatus.CLOSE && game.winners.length > 0) {
      window.localStorage.setItem("game", JSON.stringify(game ?? {}));
      setShowGameEndModal(true);
    }
  };

  usePollingEffect(async () => await gameWorker(), [], {
    interval: 2000,
    stop,
    controller,
  });

  useEffect(() => {
    if (gameState?.state != GameStatus.CLOSE) {
      setShowGameEndModal(false);
    } else {
      if (gameState?.winners.length > 0) setShowGameEndModal(true);
    }
  }, [gameState?.state]);

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
    if (gameState?.state == GameStatus.INPROGRESS && previousGameState?.state == GameStatus.INPROGRESS) {
      if (
        parseAddress(gameState?.turn) == parseAddress(me) &&
        parseAddress(previousGameState?.turn) != parseAddress(me)
      ) {
        if (document.hidden) {
          playSound("your-turn-blurred");
        } else {
          playSound("your-turn");
        }
      } else if (
        parseAddress(gameState?.turn) != parseAddress(me) &&
        parseAddress(previousGameState?.turn) != parseAddress(me) &&
        parseAddress(gameState?.turn) != parseAddress(previousGameState?.turn)
      ) {
        // determine last action made
        if (gameState?.players?.[previousGameState?.currentPlayerIndex]?.status == 1) {
          playSound("fold", 0.7);
        } else if (+gameState?.current_bet > +previousGameState?.current_bet) {
          playSound("more-chips");
        } else if (+gameState?.current_bet == +previousGameState?.current_bet && +gameState?.current_bet > 0) {
          playSound("chips");
          // if last player is folded do not play check sound:
        } else if (
          +gameState?.current_bet == 0 &&
          gameState?.players?.[previousGameState?.currentPlayerIndex]?.status != 1 &&
          gameState?.stage == previousGameState?.stage
        ) {
          playSound("wood-knock");
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
        setCurrentPot(+(gameState?.pot || 0));
      }
    } catch (error) {
      // { code: 4001, message: "User rejected the request."}
      console.error(error);
    }
  };

  const revealCurrentUserCard = async () => {
    const message = "By signing this transaction you'll be able to see your cards.";
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
    <>
      <GameEndModal show={showGameEndModal} gameState={gameState!} communityCards={communityCards} />
      <div className="h-full w-full flex items-center justify-center relative">
        {gameState?.state === GameStatus.INPROGRESS && (
          <div className="absolute top-4 left-4">
            <div className="text-white whitespace-pre font-bold text-2xl">
              {AVAILABLE_ROOMS.find((room) => room.id === gameState?.room_id)?.name}
            </div>
          </div>
        )}
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
              <SingleCard valueString={`${card.suit}_${card.value}`} size="large" key={index} />
            ))}
          </div>
          {gameState?.state !== GameStatus.CLOSE && (
            <div className="flex gap-x-4">
              <ActionButtons
                meIndex={meIndex}
                stake={Number(gameState?.stake || 0)}
                currentBet={Number(gameState?.current_bet ?? 0)}
                gameState={gameState!}
              />
            </div>
          )}
          <div className="absolute right-40 h-full flex justify-center gap-x-2 items-center text-white">
            <Stack stack={currentPot} />
          </div>
          <PokerTable />
        </div>
      </div>
    </>
  );
}

function PokerTable() {
  return <Image src="/poker-table.png" alt="Poker Table" width={1200} height={800} />;
}
