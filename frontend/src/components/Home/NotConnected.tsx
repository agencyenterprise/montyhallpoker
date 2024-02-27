"use client";

import { useTypingEffect } from "@/utils/useTypingEffect";

export function NotConnected() {
  const text = useTypingEffect(
    `Welcome to Monty Hall Poker! Please connect your wallet to play.`
  );

  return (
    <div className="flex flex-col gap-6 p-6">
      <div className="nes-container is-dark with-title">
        <p className="title">Welcome!</p>
        <p>{text}</p>
      </div>
    </div>
  );
}
