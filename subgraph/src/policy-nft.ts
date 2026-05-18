import {
  PolicyMinted, PolicyDeactivated
} from "../generated/PolicyNFT/PolicyNFT"

import {
  Policy
} from "../generated/schema"

export function handlePolicyMinted(event: PolicyMinted): void {
  let id = event.params.tokenId.toString()
  
  // Try to load first to prevent "duplicate ID" crashes
  let entity = Policy.load(id)
  if (entity == null) {
    entity = new Policy(id)
  }

  entity.tokenId = event.params.tokenId
  entity.policyholder = event.params.policyholder
  entity.coverageAmount = event.params.coverageAmount
  entity.premium = event.params.premium
  entity.expiry = event.params.expiry
  entity.riskType = event.params.riskType
  entity.active = true
  entity.claimed = false
  entity.timestamp = event.block.timestamp
  entity.txHash = event.transaction.hash

  entity.save()
}

export function handlePolicyDeactivated(event: PolicyDeactivated): void {
  let id = event.params.tokenId.toString()

  let policy = Policy.load(id)
  if (policy !== null) {
    policy.active = false
    policy.save()
  }
}