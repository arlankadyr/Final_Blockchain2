import { BigInt } from "@graphprotocol/graph-ts"
import {
  Swap,
  LiquidityAdded
} from "../generated/SkinMarketAMM/SkinMarketAMM"
import { SwapEvent, LiquidityEvent, ProtocolStats } from "../generated/schema"

function getOrCreateStats(): ProtocolStats {
  let stats = ProtocolStats.load("global")
  if (!stats) {
    stats = new ProtocolStats("global")
    stats.totalSwaps = BigInt.fromI32(0)
    stats.totalSkinsMinted = BigInt.fromI32(0)
    stats.totalCasesOpened = BigInt.fromI32(0)
    stats.totalLiquidityEvents = BigInt.fromI32(0)
  }
  return stats
}

export function handleSwap(event: Swap): void {
  let swap = new SwapEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  swap.user = event.params.user
  swap.tokenIn = event.params.tokenIn
  swap.amountIn = event.params.amountIn
  swap.amountOut = event.params.amountOut
  swap.timestamp = event.block.timestamp
  swap.blockNumber = event.block.number
  swap.save()

  let stats = getOrCreateStats()
  stats.totalSwaps = stats.totalSwaps.plus(BigInt.fromI32(1))
  stats.save()
}

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let liq = new LiquidityEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  liq.provider = event.params.provider
  liq.amountA = event.params.amountA
  liq.amountB = event.params.amountB
  liq.lpTokens = event.params.lpTokens
  liq.timestamp = event.block.timestamp
  liq.save()

  let stats = getOrCreateStats()
  stats.totalLiquidityEvents = stats.totalLiquidityEvents.plus(BigInt.fromI32(1))
  stats.save()
}
