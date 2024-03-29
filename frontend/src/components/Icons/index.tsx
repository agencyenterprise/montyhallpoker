"use client";

import Image from "next/image";

export function MoneyIcon() {
  return (
    <Image src="/money-icon.svg" width={14} height={14} alt="Money icon" />
  );
}

export function PlayersIcon() {
  return (
    <Image src="/players-icon.svg" width={14} height={14} alt="Players icon" />
  );
}

export function BuyinIcon() {
  return (
    <Image src="/buyin-icon.svg" width={14} height={14} alt="Buyin icon" />
  );
}

export function StackIcon() {
  return <Image src="/stack-icon.svg" height="13" width="13" alt="icon" />;
}

export function PokerStackIcon() {
  return (
    <Image src="/poker-stacks.png" alt="Poker Stacks" width={20} height={15} />
  );
}
