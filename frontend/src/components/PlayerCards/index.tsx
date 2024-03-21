import classnames from "classnames";
import { SingleCard } from "../SingleCard";
import { BackCards } from "../BackCards";

export interface Card {
  suit: string;
  value: string;
}

interface CardsProps {
  cards?: Card[];
}

export function PlayerCards({ cards }: CardsProps) {
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
            <SingleCard
              valueString={`${cards[0].suit}_${cards[0].value}`}
              size="large"
            />
            <SingleCard
              valueString={`${cards[1].suit}_${cards[1].value}`}
              size="large"
            />
          </div>
        )}
      </div>
    </div>
  );
}
