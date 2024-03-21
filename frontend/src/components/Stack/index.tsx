import { toAptos } from "@/utils/aptosClient";
import { PokerStackIcon, StackIcon } from "../Icons";

interface StackProps {
  stack: number;
}

export function Stack({ stack }: StackProps) {
  return (
    <div className="flex gap-x-2">
      <PokerStackIcon />{" "}
      <span className="flex gap-x-2 text-white rounded-full bg-[#0F172A] px-2 py-[6px] text-xs">
        <StackIcon />
        {toAptos(stack).toFixed(2)}
      </span>
    </div>
  );
}
