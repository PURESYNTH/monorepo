"use client";

import { useSuiClientQuery } from "@mysten/dapp-kit";
import { useCurrentAccount, useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { useCallback } from "react";
import {
  ORDERBOOK_ID,
  RANDOM_INDEX_ID,
  PACKAGE_ID,
  MESSAGE_ID,
  SUI_RANDOM_ID,
  formatPrice,
} from "@/lib/constants";

export function PriceCard() {
  const { data, isLoading } = useSuiClientQuery(
    "getObject",
    { id: RANDOM_INDEX_ID, options: { showContent: true } },
    { refetchInterval: 500 },
  );

  const price: number = (data?.data?.content as any)?.fields?.price ?? 0;

  const { mutate: signAndExecute, isPending } = useSignAndExecuteTransaction();
  const account = useCurrentAccount();

  const crankPrice = useCallback(() => {
    if (!account) return;
    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE_ID}::grndx::crank_random_index`,
      arguments: [
        tx.object(ORDERBOOK_ID),
        tx.object(RANDOM_INDEX_ID),
        tx.object(MESSAGE_ID),
        tx.object(SUI_RANDOM_ID),
      ],
    });
    signAndExecute({ transaction: tx });
  }, [account, signAndExecute]);

  return (
    <div className="bg-gray-900 rounded-xl p-5 border border-gray-800">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs text-gray-400 uppercase tracking-widest mb-1">
            Index Price
          </p>
          {isLoading ? (
            <p className="text-3xl font-bold text-gray-500 animate-pulse">—</p>
          ) : (
            <p className="text-3xl font-bold text-emerald-400">
              ${formatPrice(price)}
            </p>
          )}
          <p className="text-xs text-gray-500 mt-1 font-mono">raw: {price}</p>
        </div>
        <div className="flex flex-col gap-2">
          {account && (
            <button
              onClick={crankPrice}
              disabled={isPending}
              className="text-xs px-3 py-1 rounded bg-brand-500 hover:bg-brand-600 disabled:opacity-50 transition"
            >
              {isPending ? "Cranking…" : "Crank Price"}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
