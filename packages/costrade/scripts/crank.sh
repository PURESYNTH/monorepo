#!/bin/bash
# Crank the random price index on Sui testnet every 4 seconds.
# Equivalent of the Aptos `crank_random_index` loop.

PACKAGE="0x27b1ad64630c68ae1e0fbbcb8ed36a67d08cc31168c139e0cbb208089d16cc22"
ORDERBOOK="0xcbd7d5ac8f59258baa8970bb7d18eb79921351024dbb34ca423ff379abc3dce5"
RANDOM_INDEX="0x114422ac9d7b095e13f1aad1ac6338efbbbc427aa666cf6f77b883b59cc11954"
MESSAGE="0x776a55b1ea01d31608337d6d66ab509c6387742d0d4a435b00d2909e1d4f8478"
SUI_RANDOM="0x8"   # Sui system randomness object
GAS_BUDGET=3000000
SLEEP=1   # seconds between cranks

while true; do
  echo "[$(date '+%H:%M:%S')] sleeping ${SLEEP}s..."
  sleep "$SLEEP"

  echo "[$(date '+%H:%M:%S')] cranking price..."
  RESULT=$(sui client call \
    --package   "$PACKAGE"      \
    --module    grndx           \
    --function  crank_random_index \
    --args      "$ORDERBOOK"    \
                "$RANDOM_INDEX" \
                "$MESSAGE"      \
                "$SUI_RANDOM"   \
    --gas-budget "$GAS_BUDGET"  \
    --json 2>&1)

  DIGEST=$(echo "$RESULT" | jq -r '.digest // empty' 2>/dev/null)
  PRICE_RAW=$(echo "$RESULT" | jq -r \
    '[.events[]? | select(.type | test("RandomIndexEvent")) | .parsedJson.price] | first // empty' \
    2>/dev/null)

  GAS_COMPUTATION=$(echo "$RESULT" | jq -r '.effects.gasUsed.computationCost // 0' 2>/dev/null)
  GAS_STORAGE=$(echo "$RESULT" | jq -r '.effects.gasUsed.storageCost // 0' 2>/dev/null)
  GAS_REBATE=$(echo "$RESULT" | jq -r '.effects.gasUsed.storageRebate // 0' 2>/dev/null)
  GAS_COST=$(awk "BEGIN { printf \"%.4f\", ($GAS_COMPUTATION + $GAS_STORAGE - $GAS_REBATE) / 1000000000 }")
  COST_PER_DAY=$(awk "BEGIN { printf \"%.4f\", $GAS_COST * 86400 / $SLEEP }")

  if [ -n "$PRICE_RAW" ] && [ -n "$DIGEST" ]; then
    PRICE=$(awk "BEGIN { printf \"%.6f\", $PRICE_RAW / 1000000 }")
    echo "[$(date '+%H:%M:%S')] index: $PRICE  |  cost: ${GAS_COST} SUI  (~${COST_PER_DAY}/day)  |  digest: $DIGEST"
  else
    ERR=$(echo "$RESULT" | jq -r '.error // empty' 2>/dev/null)
    [ -z "$ERR" ] && ERR=$(echo "$RESULT" | head -2)
    echo "[$(date '+%H:%M:%S')] error: $ERR"
  fi
done
