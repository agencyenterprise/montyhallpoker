import { AVAILABLE_ROOMS } from "@/constants";
import { getAptosClient, getAptosWallet, toAptos } from "@/utils/aptosClient";
import { playSound } from "@/utils/audio";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Maybe } from "aptos";
import { useEffect, useState } from "react";
import { GameState, CONTRACT_ADDRESS, GameStatus } from "../../../controller/contract";
import Button from "../Button";

const aptosClient = getAptosClient();

interface ActionButtonsProps {
  gameState: Maybe<GameState>;
  currentBet: number;
  stake: number;
  meIndex: number;
}

const ACTIONS = {
  FOLD: 0,
  CHECK: 1,
  CALL: 2,
  RAISE: 3,
  ALL_IN: 4,
};

export function ActionButtons({ meIndex, currentBet, stake, gameState }: ActionButtonsProps) {
  const { signAndSubmitTransaction } = useWallet();
  const [raiseValue, setRaiseValue] = useState<number>(currentBet);
  const [playerBet, setPlayerBet] = useState<number>(0);

  useEffect(() => {
    setRaiseValue(currentBet);
  }, [currentBet]);

  useEffect(() => {
    const bet = gameState?.players[meIndex]?.current_bet;
    if (bet) {
      console.log(bet);
      setPlayerBet(Number(bet));
    }
  }, [meIndex]);

  const skipInactivePlayer = async () => {
    try {
      if (!gameState?.id) {
        return;
      }
      const currentUnixTimestamp = Math.floor(Date.now() / 1000);
      const lastActionUnixTimestamp = Number(gameState!.last_action_timestamp);
      if (currentUnixTimestamp - lastActionUnixTimestamp < 30) {
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
        <div className="text-white whitespace-pre font-bold">
          {AVAILABLE_ROOMS.find((room) => room.id === gameState?.room_id)?.name}
        </div>
      </div>
    );
  }

  const idleTime = Date.now() / 1000 - Number(gameState.last_action_timestamp);
  if (meIndex !== gameState?.currentPlayerIndex && idleTime > 30) {
    return (
      <div className="flex w-fit absolute bottom-4 -left-20">
        <Button className="w-full whitespace-pre" onClick={() => skipInactivePlayer()}>
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
        <Button
          disabled={raiseValue <= 0 || raiseValue <= currentBet}
          onClick={() => setRaiseValue((prev) => prev - stake)}
        >
          -
        </Button>
        <input
          className="text-center bg-[#0F172A] text-white w-[100px] h-auto min-h-full rounded-[10px] border border-cyan-400"
          value={toAptos(raiseValue).toFixed(2)}
          readOnly
        />
        <Button onClick={() => setRaiseValue((prev) => prev + stake)}>+</Button>
      </div>

      <div className="flex gap-x-4 w-full">
        <Button className="w-full" onClick={() => performAction(ACTIONS.FOLD, 0)}>
          Fold
        </Button>
        {currentBet > 0 && raiseValue == currentBet && (
          <Button className="w-full" onClick={() => performAction(ACTIONS.CALL, 0)}>
            Call
          </Button>
        )}
        {raiseValue > 0 && raiseValue !== currentBet && (
          <Button className="w-full" onClick={() => performAction(ACTIONS.RAISE, raiseValue - playerBet)}>
            Raise
          </Button>
        )}

        {Number(currentBet) === 0 && raiseValue === 0 && (
          <Button className="w-full" onClick={() => performAction(ACTIONS.CHECK, 0)}>
            Check
          </Button>
        )}
      </div>
    </div>
  );
}
