"use client";

import Image from "next/image";

export function BackCards() {
  return (
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
  );
}
