import classnames from "classnames";
import Image from "next/image";

interface TableProps {
  players: string[];
}
export default function Table({ players }: TableProps) {
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
          <Image
            src="/cards/clubs/king.svg"
            alt="Card Club"
            width={61}
            height={91}
          />
          <Image
            src="/cards/diamonds/ace.svg"
            alt="Card Club"
            width={61}
            height={91}
          />
          <Image
            src="/cards/hearts/4.svg"
            alt="Card Club"
            width={61}
            height={91}
          />
          <Image
            src="/cards/diamonds/6.svg"
            alt="Card Club"
            width={61}
            height={91}
          />
          <Image
            src="/cards/clubs/3.svg"
            alt="Card Club"
            width={61}
            height={91}
          />
        </div>
        <PokerTable />
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
        {!show && (
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
        )}
        {show && (
          <div className="absolute flex gap-x-4 -top-10">
            <Image
              src="/cards/clubs/king.svg"
              alt="Card Club"
              width={95}
              height={144}
            />
            <Image
              src="/cards/diamonds/ace.svg"
              alt="Card Club"
              width={95}
              height={144}
            />
          </div>
        )}
      </div>
    </div>
  );
}