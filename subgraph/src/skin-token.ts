import { BigInt } from "@graphprotocol/graph-ts"
import {
  SkinMinted,
  SkinTypeCreated
} from "../generated/SkinToken/SkinToken"
import { SkinType, PlayerInventory, ProtocolStats } from "../generated/schema"

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

export function handleSkinTypeCreated(event: SkinTypeCreated): void {
  let skinType = new SkinType(event.params.skinId.toString())
  skinType.name = event.params.name
  skinType.rarity = event.params.rarity
  skinType.maxSupply = event.params.maxSupply
  skinType.totalMinted = BigInt.fromI32(0)
  skinType.save()
}

export function handleSkinMinted(event: SkinMinted): void {
  // Обновляем SkinType
  let skinType = SkinType.load(event.params.skinId.toString())
  if (skinType) {
    skinType.totalMinted = skinType.totalMinted.plus(event.params.amount)
    skinType.save()
  }

  // Обновляем инвентарь игрока
  let inventoryId = event.params.to.toHex() + "-" + event.params.skinId.toString()
  let inventory = PlayerInventory.load(inventoryId)
  if (!inventory) {
    inventory = new PlayerInventory(inventoryId)
    inventory.player = event.params.to
    inventory.skinId = event.params.skinId
    inventory.amount = BigInt.fromI32(0)
  }
  inventory.amount = inventory.amount.plus(event.params.amount)
  inventory.lastUpdated = event.block.timestamp
  inventory.save()

  // Обновляем статистику
  let stats = getOrCreateStats()
  stats.totalSkinsMinted = stats.totalSkinsMinted.plus(event.params.amount)
  stats.save()
}
