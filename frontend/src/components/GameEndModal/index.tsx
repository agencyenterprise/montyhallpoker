"use client";
import { parseAddress } from "@/utils/address";
import { getAptosClient, getAptosWallet } from "@/utils/aptosClient";
import { playSound } from "@/utils/audio";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import * as Dialog from "@radix-ui/react-dialog";
import { Maybe } from "aptos";
import { useRouter } from "next/navigation";
import { useRef, useState, useEffect } from "react";
import {
  GameState,
  GameStage,
  GameStatus,
  getGameByRoomId,
  CONTRACT_ADDRESS,
} from "../../../controller/contract";
import Button from "../Button";
import { PlayerBanner } from "../PlayerBanner";
import { Card } from "../PlayerCards";

const aptosClient = getAptosClient();

interface GameEndModalProps {
  show: boolean;
  gameState: GameState;
}
export function GameEndModal({ show, gameState }: GameEndModalProps) {
  const router = useRouter();
  const { signAndSubmitTransaction } = useWallet();
  const newStateRef = useRef<Maybe<GameState>>();
  const [winners, setWinners] = useState<any[]>();

  const finishedGame = gameState && gameState?.stage === GameStage.Showdown;
  useEffect(() => {
    newStateRef.current = gameState;
    if (gameState?.state == GameStatus.CLOSE) {
      const winnerAdd = gameState.winners.map((pa) => parseAddress(pa));
      const winnerPlayers = gameState.players.filter((player: any) =>
        winnerAdd.includes(parseAddress(player.id))
      );
      setWinners(winnerPlayers);
    }
  }, [gameState]);

  if (!finishedGame) {
    return <></>;
  }

  const joinGame = async () => {
    const gameStorage = JSON.parse(window.localStorage.getItem("game") ?? "{}");
    if (!gameStorage?.id) {
      return;
    }
    const game = await getGameByRoomId(gameStorage.room_id);

    try {
      const wallet = getAptosWallet();
      const account = await wallet?.account();

      const response = await signAndSubmitTransaction({
        sender: account.address,
        data: {
          function: `${CONTRACT_ADDRESS}::poker_manager::join_game`,
          typeArguments: [],
          functionArguments: [`${game?.id!}`, `${gameStorage?.stake}`],
        },
      });
      await aptosClient.waitForTransaction({
        transactionHash: response.hash,
      });
      playSound("door");
      window.location.reload();
      router.push(`/table/${newStateRef?.current?.room_id}`);
    } catch (error: any) {
      console.error(error);
    }
  };

  return (
    <Dialog.Root open={show}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-50 bg-dialogOverlay backdrop-blur-sm" />
        <Dialog.Content className="z-50 fixed top-1/2 left-1/2 transform bg-[#0F172A] -translate-x-1/2 border border-cyan-400 rounded-lg -translate-y-1/2 shadow-md w-[50vw] h-[600px] min-w-[600px] min-h-[200px] p-6">
          <div className="nes-container is-dark with-title w-[100%] h-[100%] text-white">
            <Dialog.Title className="text-2xl font-bold text-center">
              End Game
            </Dialog.Title>
            <br />
            <div className="w-full h-full flex flex-col items-center gap-y-40 ">
              <>
                <h1>Congratulations to the winner!</h1>
                {winners?.map((winner: any) => (
                  <div className="flex flex-col items-end ">
                    <PlayerBanner
                      relative={true}
                      isMe={true}
                      gameState={newStateRef.current!}
                      currentIndex={
                        newStateRef.current?.currentPlayerIndex || 0
                      }
                      playerIndex={
                        newStateRef?.current?.players
                          .map((p) => parseAddress(p.id))
                          .indexOf(parseAddress(winner.id))!
                      }
                      stack={1000}
                      position={0}
                      cards={winner.hand?.map((card: any) => ({
                        suit: `${parseHexTostring(card?.suit_string!)}`,
                        value: `${parseHexTostring(card?.value_string!)}`,
                      }))}
                    />
                  </div>
                ))}
                <Button className="text-[#0F172A]" onClick={joinGame}>
                  Join Next Game
                </Button>
              </>
            </div>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function parseHexTostring(hexString: string) {
  let str = "";
  for (let i = 0; i < hexString.length; i += 2) {
    str += String.fromCharCode(parseInt(hexString.substr(i, 2), 16));
  }
  return str.split("\x00")[1];
}
