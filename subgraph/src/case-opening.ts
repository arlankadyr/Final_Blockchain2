import { BigInt } from "@graphprotocol/graph-ts"
import { CaseOpened } from "../generated/CaseOpening/CaseOpening"
import { CaseOpenedEvent, ProtocolStats } from "../generated/schema"

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

export function handleCaseOpened(event: CaseOpened): void {
  let caseEvent = new CaseOpenedEvent(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )
  caseEvent.player = event.params.player
  caseEvent.caseId = event.params.requestId
  caseEvent.skinId = event.params.skinId
  caseEvent.timestamp = event.block.timestamp
  caseEvent.save()

  let stats = getOrCreateStats()
  stats.totalCasesOpened = stats.totalCasesOpened.plus(BigInt.fromI32(1))
  stats.save()
}
