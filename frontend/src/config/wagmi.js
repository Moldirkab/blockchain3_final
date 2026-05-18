import { createConfig, http } from 'wagmi'
import { arbitrumSepolia } from 'wagmi/chains'
import { injected, walletConnect } from 'wagmi/connectors'

export const config = createConfig({
  chains: [arbitrumSepolia],

  connectors: [
    injected(),

    walletConnect({
      projectId: 'demo'
    })
  ],

  transports: {
    [arbitrumSepolia.id]: http()
  }
})