import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";

export function getAptosClient() {
  const config = new AptosConfig({
    network: Network.RANDOMNET,
  });
  return new Aptos(config);
}

export const getAptosWallet = (): any => {
  if ("aptos" in window) {
    return window.aptos;
  } else {
    window.open("https://petra.app/", `_blank`);
  }
};
