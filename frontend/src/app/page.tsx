"use client";

import classnames from "classnames";
import Image from "next/image";
import { PropsWithChildren } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useRouter } from "next/navigation";

const FixedSizeWrapper = ({ children }: PropsWithChildren) => {
  const fixedStyle = {
    width: "1200px",
    height: "800px",
    margin: "auto",
  };

  return (
    <div
      style={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        height: "100vh",
      }}
    >
      <div style={fixedStyle}>{children}</div>
    </div>
  );
};

export default function Home() {
  const { connected } = useWallet();
  const router = useRouter();
  const goToTable = () => {
    router.push("/table");
  };
  return (
    <div>
      <Banner />
      <div className="mt-6 w-full p-6 bg-slate-900 flex flex-col gap-6 rounded-[20px]">
        <h1 className="text-white text-2xl">Poker - Sit & Go</h1>
        <div className="grid grid-cols-4 gap-6">
          <Table onClick={() => goToTable()} title="Table 1" playerCount={2} buyin={20} maxPot={200} color="red" />
          <Table onClick={() => goToTable()} title="Table 1" playerCount={2} buyin={20} maxPot={200} color="red" />
          <Table onClick={() => goToTable()} title="Table 1" playerCount={2} buyin={20} maxPot={200} color="red" />
          <Table onClick={() => goToTable()} title="Table 1" playerCount={2} buyin={20} maxPot={200} color="red" />
          <Table onClick={() => goToTable()} title="Table 2" playerCount={3} buyin={200} maxPot={300} color="yellow" />
          <Table onClick={() => goToTable()} title="Table 2" playerCount={3} buyin={200} maxPot={300} color="yellow" />
          <Table onClick={() => goToTable()} title="Table 2" playerCount={3} buyin={200} maxPot={300} color="yellow" />
          <Table onClick={() => goToTable()} title="Table 2" playerCount={3} buyin={200} maxPot={300} color="yellow" />
          <Table onClick={() => goToTable()} title="Table 3" playerCount={4} buyin={800} maxPot={400} color="green" />
          <Table onClick={() => goToTable()} title="Table 3" playerCount={4} buyin={800} maxPot={400} color="green" />
          <Table onClick={() => goToTable()} title="Table 3" playerCount={4} buyin={800} maxPot={400} color="green" />
          <Table onClick={() => goToTable()} title="Table 3" playerCount={4} buyin={800} maxPot={400} color="green" />
        </div>
      </div>
    </div>
  );
}

function Banner() {
  return <Image src="/banner.png" width={1280} height={308} alt="Cassino banner" />;
}

interface TableProps extends React.HTMLAttributes<HTMLButtonElement> {
  title: string;
  playerCount: number;
  buyin: number;
  maxPot: number;
  color: "red" | "yellow" | "green";
}
function Table({ title, playerCount, buyin, maxPot, color, onClick }: TableProps) {
  let style = "";
  let bgColor = "";
  switch (color) {
    case "red":
      bgColor = "bg-gradient-to-r from-rose-400/25 to-rose-400/0";
      style = "bg-game bg-[left_8rem_center] bg-scale border-rose-400 border bg-no-repeat bg-scale";
      break;
    case "yellow":
      bgColor = "bg-gradient-to-r from-amber-400/25 to-amber-400/0";
      style = "bg-game bg-[left_8rem_center] bg-scale border-amber-400 border bg-no-repeat bg-scale";
      break;
    case "green":
      bgColor = "bg-gradient-to-r from-lime-400/25 to-lime-400/0";
      style = "bg-game border-lime-400 border bg-no-repeat bg-[left_8rem_center] bg-scale";
      break;
  }

  return (
    <button className={classnames("rounded-[10px] w-[290px] ", bgColor)} onClick={onClick}>
      <div className={`cursor-pointer font-bold text-white h-[142px] rounded-[10px] leading-[19px] p-4 flex ${style}`}>
        <div className="flex flex-col gap-y-[10px]">
          <h1>{title}</h1>
          <div className="flex gap-x-[10px]">
            <PlayersIcon />
            <p>{playerCount}/4</p>
          </div>
          <div className="flex gap-x-[10px]">
            <BuyinIcon />
            <p>{buyin}</p>
          </div>
          <div className="flex gap-x-[10px]">
            <MoneyIcon />
            <p>{maxPot}</p>
          </div>
        </div>
      </div>
    </button>
  );
}
function MoneyIcon() {
  return <Image src="/money-icon.svg" width={14} height={14} alt="Money icon" />;
}
function PlayersIcon() {
  return <Image src="/players-icon.svg" width={14} height={14} alt="Players icon" />;
}
function BuyinIcon() {
  return <Image src="/buyin-icon.svg" width={14} height={14} alt="Buyin icon" />;
}
