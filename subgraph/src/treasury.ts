import {
  TokenWithdrawn,
  ProtocolFeeUpdated
} from "../generated/ProtocolTreasury/ProtocolTreasury"

import {
  TreasuryWithdrawal,
  TreasuryFeeUpdate
} from "../generated/schema"

export function handleTokenWithdrawn(event: TokenWithdrawn): void {
  let entity = new TreasuryWithdrawal(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )

  entity.token = event.params.token
  entity.to = event.params.to
  entity.amount = event.params.amount
  entity.timestamp = event.block.timestamp

  entity.save()
}

export function handleProtocolFeeUpdated(event: ProtocolFeeUpdated): void {
  let entity = new TreasuryFeeUpdate(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )

  entity.oldFeeBps = event.params.oldFeeBps
  entity.newFeeBps = event.params.newFeeBps
  entity.timestamp = event.block.timestamp

  entity.save()
}