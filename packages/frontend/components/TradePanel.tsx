"use client";

import { useCurrentAccount, useSignAndExecuteTransaction, useSuiClientQuery } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { useState, useCallback } from "react";
import { PACKAGE_ID, ORDERBOOK_ID, RANDOM_INDEX_ID, formatPrice } from "@/lib/constants";

export function TradePanel() {
  const account = useCurrentAccount();
  const { mutate: signAndExecute, isPending } = useSignAndExecuteTransaction();

  const [leverage, setLeverage] = useState(10);
  const [contracts, setContracts] = useState(1);
  const [sideLong, setSideLong] = useState(true);
  const [txStatus, setTxStatus] = useState<string | null>(null);

  const { data: riData } = useSuiClientQuery("getObject", {
    id: RANDOM_INDEX_ID,
    options: { showContent: true },
  });
  const price: number = (riData?.data?.content as any)?.fields?.price ?? 0;
  const requiredMarginMist =
    price > 0 ? Math.ceil((contracts * price) / leverage) : 0;

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

  const openPosition = () => {
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE_ID}::grndx::said_it`,
      arguments: [
        tx.object(ORDERBOOK_ID),
        tx.object(RANDOM_INDEX_ID),
        tx.pure.u64(leverage),
        tx.pure.u64(contracts),
        tx.pure.bool(sideLong),
      ],
    });
    exec(tx, `Open ${sideLong ? "LONG" : "SHORT"} × ${contracts} @ ${leverage}×`);
  };

  const closePosition = () => {
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE_ID}::grndx::liquidate_it`,
      arguments: [tx.object(ORDERBOOK_ID), tx.object(RANDOM_INDEX_ID)],
    });
    exec(tx, "Close position");
  };

  if (!account) return null;

  return (
    <div className="bg-gray-900 rounded-xl p-5 border border-gray-800">
      <h2 className="text-sm font-semibold text-gray-300 uppercase tracking-widest mb-4">
        Trade
      </h2>

      <div className="space-y-4">
        {/* Side toggle */}
        <div className="flex rounded-lg overflow-hidden border border-gray-700">
          <button
            onClick={() => setSideLong(true)}
            className={`flex-1 py-2 text-sm font-medium transition ${
              sideLong
                ? "bg-emerald-600 text-white"
                : "bg-gray-800 text-gray-400 hover:bg-gray-700"
            }`}
          >
            LONG
          </button>
          <button
            onClick={() => setSideLong(false)}
            className={`flex-1 py-2 text-sm font-medium transition ${
              !sideLong
                ? "bg-red-600 text-white"
                : "bg-gray-800 text-gray-400 hover:bg-gray-700"
            }`}
          >
            SHORT
          </button>
        </div>

        {/* Leverage */}
        <div className="space-y-1">
          <div className="flex justify-between text-xs text-gray-400">
            <label>Leverage</label>
            <span className="font-mono font-bold text-yellow-400">{leverage}×</span>
          </div>
          <input
            type="range"
            min={1}
            max={100}
            value={leverage}
            onChange={(e) => setLeverage(Number(e.target.value))}
            className="w-full accent-brand-500"
          />
          <div className="flex justify-between text-xs text-gray-600">
            <span>1×</span><span>100×</span>
          </div>
        </div>

        {/* Contracts */}
        <div className="space-y-1">
          <label className="text-xs text-gray-400">Contracts</label>
          <input
            type="number"
            min={1}
            step={1}
            value={contracts}
            onChange={(e) => setContracts(Math.max(1, parseInt(e.target.value) || 1))}
            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-brand-500"
          />
        </div>

        {/* Summary */}
        <div className="bg-gray-800/60 rounded-lg p-3 space-y-1 text-xs text-gray-400">
          <div className="flex justify-between">
            <span>Index price</span>
            <span className="text-gray-200">${formatPrice(price)}</span>
          </div>
          <div className="flex justify-between">
            <span>Required margin</span>
            <span className="text-gray-200">
              {(requiredMarginMist / 1e9).toFixed(6)} SUI
            </span>
          </div>
          <div className="flex justify-between">
            <span>Notional</span>
            <span className="text-gray-200">
              ${formatPrice(contracts * price)}
            </span>
          </div>
        </div>

        {/* Buttons */}
        <button
          onClick={openPosition}
          disabled={isPending || price === 0}
          className={`w-full py-2 rounded-lg text-sm font-semibold transition disabled:opacity-40 ${
            sideLong
              ? "bg-emerald-600 hover:bg-emerald-700"
              : "bg-red-600 hover:bg-red-700"
          }`}
        >
          {isPending
            ? "Sending…"
            : `Open ${sideLong ? "Long" : "Short"} ${contracts} × ${leverage}×`}
        </button>

        <button
          onClick={closePosition}
          disabled={isPending}
          className="w-full py-2 rounded-lg text-sm font-medium bg-gray-700 hover:bg-gray-600 disabled:opacity-40 transition"
        >
          Close Position
        </button>

        {txStatus && (
          <p
            className={`text-xs rounded p-2 break-all ${
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
    </div>
  );
}
