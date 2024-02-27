import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";

export function getAptosClient() {
  const config = new AptosConfig({
    network: Network.LOCAL,
  });
  return new Aptos(config);
}
