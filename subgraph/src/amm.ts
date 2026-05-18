import {
  LiquidityAdded,
  Swapped
} from "../generated/RiskAMM/RiskAMM"

import {
  LiquidityPosition,
  Swap
} from "../generated/schema"

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let entity = new LiquidityPosition(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )

  entity.provider = event.params.provider
  entity.amount0 = event.params.amount0
  entity.amount1 = event.params.amount1
  entity.shares = event.params.shares
  entity.timestamp = event.block.timestamp

  entity.save()
}

export function handleSwapped(event: Swapped): void {
  let entity = new Swap(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )

  entity.user = event.params.user
  entity.tokenIn = event.params.tokenIn
  entity.amountIn = event.params.amountIn
  entity.amountOut = event.params.amountOut
  entity.timestamp = event.block.timestamp

  entity.save()
}