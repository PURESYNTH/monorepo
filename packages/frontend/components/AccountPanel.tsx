"use client";

import { useCurrentAccount, useSignAndExecuteTransaction, useSuiClientQuery } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { useState, useCallback } from "react";
import { PACKAGE_ID, ORDERBOOK_ID, formatMist } from "@/lib/constants";

// ── helpers ───────────────────────────────────────────────────────────────────

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-gray-900 rounded-xl p-5 border border-gray-800">
      <h2 className="text-sm font-semibold text-gray-300 uppercase tracking-widest mb-4">
        {title}
      </h2>
      {children}
    </div>
  );
}

function Btn({
  onClick,
  disabled,
  children,
  variant = "primary",
}: {
  onClick: () => void;
  disabled?: boolean;
  children: React.ReactNode;
  variant?: "primary" | "danger" | "secondary";
}) {
  const cls = {
    primary:
      "bg-brand-500 hover:bg-brand-600 text-white",
    danger: "bg-red-600 hover:bg-red-700 text-white",
    secondary: "bg-gray-700 hover:bg-gray-600 text-gray-100",
  }[variant];
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`${cls} w-full py-2 px-4 rounded-lg text-sm font-medium disabled:opacity-40 transition`}
    >
      {children}
    </button>
  );
}

// ── AccountPanel ──────────────────────────────────────────────────────────────

export function AccountPanel() {
  const account = useCurrentAccount();
  const { mutate: signAndExecute, isPending } = useSignAndExecuteTransaction();

  const [depositAmt, setDepositAmt] = useState("");
  const [withdrawAmt, setWithdrawAmt] = useState("");
  const [txStatus, setTxStatus] = useState<string | null>(null);

  const exec = useCallback(
    (tx: Transaction, label: string) => {
      setTxStatus(`${label}…`);
      signAndExecute(
        { transaction: tx },
        {
          onSuccess: (r) => setTxStatus(`✓ ${label} – ${r.digest.slice(0, 10)}…`),
          onError: (e) => setTxStatus(`✗ ${(e as Error).message}`),
        }
      );
    },
    [signAndExecute]
  );

  const openAccount = () => {
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE_ID}::grndx::hope_it`,
      arguments: [tx.object(ORDERBOOK_ID)],
    });
    exec(tx, "Open account");
  };

  const deposit = () => {
    const mist = Math.round(parseFloat(depositAmt) * 1e9);
    if (!mist || mist <= 0) return;
    const tx = new Transaction();
    const [coin] = tx.splitCoins(tx.gas, [mist]);
    tx.moveCall({
      target: `${PACKAGE_ID}::grndx::depeche_it`,
      arguments: [tx.object(ORDERBOOK_ID), coin],
    });
    exec(tx, `Deposit ${depositAmt} SUI`);
  };

  const withdraw = () => {
    const mist = Math.round(parseFloat(withdrawAmt) * 1e9);
    if (!mist || mist <= 0) return;
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE_ID}::grndx::without_it`,
      arguments: [tx.object(ORDERBOOK_ID), tx.pure.u64(mist)],
    });
    exec(tx, `Withdraw ${withdrawAmt} SUI`);
  };

  if (!account) {
    return (
      <Card title="Account">
        <p className="text-sm text-gray-500">Connect your wallet to manage an account.</p>
      </Card>
    );
  }

  return (
    <Card title="Account">
      <div className="space-y-4">
        <Btn onClick={openAccount} disabled={isPending}>
          Open Market Account
        </Btn>

        {/* Deposit */}
        <div className="space-y-2">
          <label className="text-xs text-gray-400">Deposit (SUI)</label>
          <div className="flex gap-2">
            <input
              type="number"
              min="0"
              step="0.001"
              value={depositAmt}
              onChange={(e) => setDepositAmt(e.target.value)}
              placeholder="0.01"
              className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
            <button
              onClick={deposit}
              disabled={isPending || !depositAmt}
              className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-40 rounded-lg text-sm font-medium transition"
            >
              Deposit
            </button>
          </div>
        </div>

        {/* Withdraw */}
        <div className="space-y-2">
          <label className="text-xs text-gray-400">Withdraw (SUI)</label>
          <div className="flex gap-2">
            <input
              type="number"
              min="0"
              step="0.001"
              value={withdrawAmt}
              onChange={(e) => setWithdrawAmt(e.target.value)}
              placeholder="0.01"
              className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-brand-500"
            />
            <button
              onClick={withdraw}
              disabled={isPending || !withdrawAmt}
              className="px-4 py-2 bg-orange-600 hover:bg-orange-700 disabled:opacity-40 rounded-lg text-sm font-medium transition"
            >
              Withdraw
            </button>
          </div>
        </div>

        {txStatus && (
          <p
            className={`text-xs rounded p-2 ${
              txStatus.startsWith("✓")
                ? "bg-emerald-900/40 text-emerald-300"
                : txStatus.startsWith("✗")
                ? "bg-red-900/40 text-red-300"
                : "bg-gray-800 text-gray-400 animate-pulse"
            }`}
          >
            {txStatus}
          </p>
        )}
      </div>
    </Card>
  );
}
