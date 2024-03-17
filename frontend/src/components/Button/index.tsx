"use client";

import { cn } from "@/utils/styling";

interface ButtonProps extends React.HTMLAttributes<HTMLButtonElement> {
  disabled?: boolean;
  loading?: boolean;
  children: React.ReactNode;
}

export const buttonStyles =
  "nes-btn is-primary py-[10px] px-[24px] bg-cyan-400 font-bold rounded-[4px]";

export default function Button({
  disabled,
  loading,
  children,
  ...props
}: ButtonProps) {
  if (loading) {
    return (
      <div className={cn(buttonStyles, "opacity-50 cursor-not-allowed")}>
        Loading...
      </div>
    );
  }

  return (
    <button
      className={cn(
        buttonStyles,
        "hover:scale-110 cursor-pointer btn-small",
        disabled ? "opacity-50 cursor-not-allowed" : ""
      )}
      {...props}
    >
      {children}
    </button>
  );
}
