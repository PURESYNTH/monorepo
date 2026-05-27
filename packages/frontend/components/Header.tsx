"use client";

import { ConnectButton, useCurrentAccount } from "@mysten/dapp-kit";

export function Header() {
  const account = useCurrentAccount();
  return (
    <header className="border-b border-gray-800 px-6 py-4 flex items-center justify-between">
      <div>
        <h1 className="text-xl font-bold tracking-tight">COSTRADEFI</h1>
        <p className="text-xs text-gray-400">Perpetuals · Sui Testnet</p>
      </div>
      <div className="flex items-center gap-3">
        {account && (
          <span className="text-xs text-gray-400 font-mono">
            {account.address.slice(0, 8)}…{account.address.slice(-6)}
          </span>
        )}
        <ConnectButton />
      </div>
    </header>
  );
}
