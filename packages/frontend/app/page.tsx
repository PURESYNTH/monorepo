"use client";

import { Header } from "@/components/Header";
import { PriceCard } from "@/components/PriceCard";
import { AccountPanel } from "@/components/AccountPanel";
import { TradePanel } from "@/components/TradePanel";
import { PACKAGE_ID } from "@/lib/constants";

export default function HomePage() {
  return (
    <div className="flex flex-col min-h-screen">
      <Header />

      <main className="flex-1 max-w-5xl mx-auto w-full px-4 py-8 space-y-6">
        {/* Price */}
        <PriceCard />

        {/* Two-column layout */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <AccountPanel />
          <TradePanel />
        </div>

        {/* Footer info */}
        <div className="text-xs text-gray-600 space-y-1">
          <p>
            <span className="text-gray-500">Package</span>{" "}
            <a
              href={`https://testnet.suivision.xyz/package/${PACKAGE_ID}`}
              target="_blank"
              rel="noopener noreferrer"
              className="font-mono hover:text-gray-400 underline break-all"
            >
              {PACKAGE_ID}
            </a>
          </p>
          <p className="text-gray-700">Network: Sui Testnet</p>
        </div>
      </main>
    </div>
  );
}
