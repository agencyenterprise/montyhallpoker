"use client";

import Image from "next/image";
import classnames from "classnames";
import { GameState, PlayerStatus } from "../../../controller/contract";
import { Card, PlayerCards } from "../PlayerCards";
import { StackIcon } from "../Icons";
import { Stack } from "../Stack";
import { getAptosClient, toAptos } from "@/utils/aptosClient";
import { useEffect, useState } from "react";

const aptosClient = getAptosClient();
interface PlayerBannerProps {
  relative?: boolean;
  isMe: boolean;
  currentIndex: number;
  playerIndex: number;
  gameState: GameState;
  stack: number;
  cards?: Card[];
  position: number;
}
export function PlayerBanner({
  relative,
  isMe,
  currentIndex,
  playerIndex: index,
  gameState,
  cards,
  position,
}: PlayerBannerProps) {
  const [walletAmount, setWalletAmount] = useState<number | null>(null);
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

  useEffect(() => {
    if (!walletAmount) {
      aptosClient
        .getAccountResource({
          accountAddress: gameState?.players[playerIndex].id,
          resourceType: "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
        })
        .then((accountResource) => {
          setWalletAmount(toAptos(Number(accountResource.coin.value)));
        });
    }
  }, []);

  const playerBet = Number(gameState.players[playerIndex].current_bet);
  const playerCards = gameState.players[playerIndex].hand;
  const playerStatus = gameState.players[playerIndex].status;

  if (relative) {
    return (
      <div className={classnames(width, "mx-7 relative bottom-0")}>
        {playerIndex == currentIndex && <TurnToken position={position} />}

        <div className={classnames()}>
          {playerBet > 0 && <Stack stack={playerBet} />}
        </div>
        {playerCards.length == 2 && playerStatus !== PlayerStatus.Folded && (
          <PlayerCards cards={cards} />
        )}
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
            <h1 className="font-bold text-sm">Player {playerIndex + 1}</h1>
            <div>
              <div className="flex gap-x-1 text-xs">
                <StackIcon />
                <span>{walletAmount?.toFixed(2)}</span>
              </div>

              <div className="flex gap-x-1 text-xs">
                <Image
                  src="/trophy-icon.svg"
                  height="13"
                  width="13"
                  alt="icon"
                />
                <span>2/20</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={classnames("relative", width, !isMe ? "mx-7" : "")}>
      {playerIndex == currentIndex && <TurnToken position={position} />}

      <div
        className={classnames(
          relative ? "" : "absolute ",
          (position == 0 || position == 3) && !relative ? "-top-[120px] " : "",
          (position == 1 || position == 2) && !relative ? "-bottom-[120px]" : ""
        )}
      >
        {playerBet > 0 && <Stack stack={playerBet} />}
      </div>
      {playerCards.length == 2 && playerStatus !== PlayerStatus.Folded && (
        <PlayerCards cards={cards} />
      )}
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
        <div className="text-white flex flex-col justify-center py-2">
          <h1 className="font-bold text-sm">Player {playerIndex + 1}</h1>
          <div>
            <div className="flex gap-x-1 text-xs mt-2">
              <StackIcon />
              <span>{walletAmount?.toFixed(2)}</span>
            </div>
          </div>
        </div>
      </div>
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
