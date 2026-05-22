import {
  RiskTypeUpdated,
  PolicyPurchased,
  ClaimPaid
} from "../generated/InsurancePool/InsurancePool"

import {
  RiskType,
  PolicyPurchase,
  Claim
} from "../generated/schema"

export function handleRiskTypeUpdated(event: RiskTypeUpdated): void {
  let id = event.params.riskType.toHex()
  let entity = RiskType.load(id)
  if (entity == null) {
    entity = new RiskType(id)
  }

  // 3. Update the fields (works for both new and existing)
  entity.riskType = event.params.riskType
  entity.accepted = event.params.accepted
  entity.premiumBps = event.params.premiumBps
  entity.triggerPrice = event.params.triggerPrice
  entity.duration = event.params.duration
  entity.updatedAt = event.block.timestamp

  entity.save()
}

export function handlePolicyPurchased(event: PolicyPurchased): void {
  // Good: Using Transaction Hash + Log Index ensures a truly unique ID
  let entity = new PolicyPurchase(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )

  entity.buyer = event.params.buyer
  entity.policyId = event.params.policyId
  entity.riskType = event.params.riskType
  entity.coverage = event.params.coverage
  entity.premium = event.params.premium
  entity.timestamp = event.block.timestamp

  entity.save()
}

export function handleClaimPaid(event: ClaimPaid): void {
  let entity = new Claim(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )

  entity.user = event.params.user
  entity.policyId = event.params.policyId
  entity.amount = event.params.amount
  entity.timestamp = event.block.timestamp
  entity.txHash = event.transaction.hash

  entity.save()
}