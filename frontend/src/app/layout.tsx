import Image from "next/image";
import { WalletProvider } from "@/context/WalletProvider";
import type { Metadata } from "next";
import localFont from "next/font/local";
import { PropsWithChildren } from "react";
import { GeoTargetly } from "@/utils/GeoTargetly";
import "./globals.css";
import dynamic from "next/dynamic";
import { WalletButtons } from "@/components/WalletButtons";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Monty Hall Poker",
  description: "Your auditable, decentralized, and fair poker platform.",
};

export default function RootLayout({ children }: PropsWithChildren) {
  return (
    <html lang="en">
      <head>
        <meta
          name="google-site-verification"
          content="Rnm3DL87HNmPncIFwBLXPhy-WGFDXIyplSL4fRtnFsA"
        />
      </head>
      <body className="bg-slate-950 h-screen">
        <WalletProvider>
          <Header />
          <div className="pt-[76px] max-w-[1280px] mx-auto h-full">
            {children}
          </div>
        </WalletProvider>
      </body>
    </html>
  );
}

function Header() {
  return (
    <header className="absolute top-0 shadow-md w-full bg-slate-900">
      <div className="flex justify-between items-center py-4 max-w-[1280px] gap-2 mx-auto">
        <Link href="/">
          <MontyHallLogo />
        </Link>

        <DynamicWalletButtons />
      </div>
    </header>
  );
}
const DynamicWalletButtons = dynamic(
  async () => {
    return { default: WalletButtons };
  },
  {
    loading: () => (
      <div className="nes-btn is-primary opacity-50 cursor-not-allowed">
        Loading...
      </div>
    ),
    ssr: false,
  }
);

function MontyHallLogo() {
  return (
    <Image
      alt="Monty Hall Poker"
      src="/monty-hall-logo.svg"
      width={91}
      height={34}
    />
  );
}
