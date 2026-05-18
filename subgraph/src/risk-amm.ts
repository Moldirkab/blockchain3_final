import { LiquidityAdded, LiquidityRemoved, Swapped } from "../generated/RiskAMM/RiskAMM"
import { LiquidityPosition, Swap } from "../generated/schema"

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let id = event.params.provider.toHex()
  let entity = LiquidityPosition.load(id)

  if (entity == null) {
    entity = new LiquidityPosition(id)
    entity.provider = event.params.provider 
  }

  // UPDATED: Using amount0, amount1, and shares from your contract params
  entity.amount0 = event.params.amount0
  entity.amount1 = event.params.amount1
  entity.shares = event.params.shares
  entity.timestamp = event.block.timestamp
  
  entity.save()
}

export function handleLiquidityRemoved(event: LiquidityRemoved): void {
  let id = event.params.provider.toHex()

  let entity = LiquidityPosition.load(id)
  if (entity == null) {
    return 
  }

  // UPDATED: Using amount0, amount1, and shares from your contract params
  entity.amount0 = entity.amount0.minus(event.params.amount0)
  entity.amount1 = entity.amount1.minus(event.params.amount1)
  entity.shares = entity.shares.minus(event.params.shares)
  entity.timestamp = event.block.timestamp

  entity.save()
}

export function handleSwapped(event: Swapped): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString()

  let entity = new Swap(id)
  entity.user = event.params.user
  entity.tokenIn = event.params.tokenIn
  entity.amountIn = event.params.amountIn
  entity.amountOut = event.params.amountOut
  entity.timestamp = event.block.timestamp

  entity.save()
}