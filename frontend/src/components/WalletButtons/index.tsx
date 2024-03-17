"use client";

import {
  useWallet,
  WalletReadyState,
  Wallet,
  isRedirectable,
  WalletName,
} from "@aptos-labs/wallet-adapter-react";
import { cn } from "@/utils/styling";
import { HexString, TxnBuilderTypes } from "aptos";
import Button from "../Button";

export const buttonStyles =
  "nes-btn is-primary py-[10px] px-[24px] bg-cyan-400 font-bold rounded-[4px]";

export const WalletButtons = () => {
  const { wallets, connected, disconnect, isLoading } = useWallet();

  if (connected || isLoading || !wallets[0]) {
    return (
      <div className="flex flex-row">
        <Button loading={isLoading || !wallets[0]} onClick={disconnect}>
          Disconnect
        </Button>
      </div>
    );
  }

  return <WalletView wallet={wallets[0]} />;
};

const WalletView = ({ wallet }: { wallet: Wallet }) => {
  const { connect } = useWallet();
  const isWalletReady =
    wallet.readyState === WalletReadyState.Installed ||
    wallet.readyState === WalletReadyState.Loadable;
  const mobileSupport = wallet.deeplinkProvider;

  const onWalletConnectRequest = async (walletName: WalletName) => {
    try {
      await connect(walletName);
      const account = await (window as any)["aptos"].account();
      console.log(account);
      let pubKey = account.publicKey;

      let key = HexString.ensure(pubKey).toUint8Array();

      pubKey = new TxnBuilderTypes.Ed25519PublicKey(key);

      const authKey =
        TxnBuilderTypes.AuthenticationKey.fromEd25519PublicKey(pubKey);

      console.log(authKey.derivedAddress().toString());
    } catch (error) {
      console.warn(error);
      window.alert("Failed to connect wallet");
    }
  };

  /**
   * If we are on a mobile browser, adapter checks whether a wallet has a `deeplinkProvider` property
   * a. If it does, on connect it should redirect the user to the app by using the wallet's deeplink url
   * b. If it does not, up to the dapp to choose on the UI, but can simply disable the button
   * c. If we are already in a in-app browser, we don't want to redirect anywhere, so connect should work as expected in the mobile app.
   *
   * !isWalletReady - ignore installed/sdk wallets that don't rely on window injection
   * isRedirectable() - are we on mobile AND not in an in-app browser
   * mobileSupport - does wallet have deeplinkProvider property? i.e does it support a mobile app
   */
  return (
    <Button
      className={cn(
        buttonStyles,
        isWalletReady ? "hover:scale-110" : "opacity-50 cursor-not-allowed"
      )}
      disabled={!isWalletReady}
      key={wallet.name}
      onClick={() => onWalletConnectRequest(wallet.name)}
      style={{ maxWidth: "300px" }}
    >
      Connect Wallet
    </Button>
  );
};
