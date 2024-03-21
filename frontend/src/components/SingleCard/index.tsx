"use client";

import Image from "next/image";

export function SingleCard({
  valueString,
  size,
}: {
  valueString: string;
  size: "small" | "large";
}) {
  const width = size === "small" ? 61 : 95;
  const height = size === "small" ? 91 : 144;
  return (
    <div
      className=" bg-white rounded-[10px] border border-black flex items-center justify-center"
      style={{
        width: `${width}px`,
        height: `${height}px`,
      }}
    >
      <Image
        src={`/cards/${valueString}.png`}
        alt="Card Club"
        width={width}
        height={height}
        onError={(i) => ((i.target as HTMLImageElement).style.display = "none")}
      />
    </div>
  );
}
