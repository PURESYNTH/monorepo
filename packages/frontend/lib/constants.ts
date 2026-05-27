// ── Deployed addresses (Sui Testnet) ──────────────────────────────────────────
export const PACKAGE_ID =
  "0x27b1ad64630c68ae1e0fbbcb8ed36a67d08cc31168c139e0cbb208089d16cc22";

export const ORDERBOOK_ID =
  "0xcbd7d5ac8f59258baa8970bb7d18eb79921351024dbb34ca423ff379abc3dce5";

export const RANDOM_INDEX_ID =
  "0x114422ac9d7b095e13f1aad1ac6338efbbbc427aa666cf6f77b883b59cc11954";

export const MESSAGE_ID =
  "0x776a55b1ea01d31608337d6d66ab509c6387742d0d4a435b00d2909e1d4f8478";

// Sui system Random object (always 0x8)
export const SUI_RANDOM_ID = "0x8";

// SCALE: 1 SUI = 1_000_000 MIST (as used by the contract)
export const SCALE = 1_000_000;

// Pretty-print a raw price (scaled by SCALE)
export function formatPrice(raw: number): string {
  return (raw / SCALE).toFixed(2);
}

// Pretty-print MIST as SUI
export function formatMist(mist: number | bigint): string {
  return (Number(mist) / 1e9).toFixed(6) + " SUI";
}
