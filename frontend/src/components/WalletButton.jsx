import {
  useAccount,
  useConnect,
  useDisconnect,
  useChainId
} from 'wagmi'

export default function WalletButton() {
  const { address, isConnected } = useAccount()

  const { connect, connectors } = useConnect()

  const { disconnect } = useDisconnect()

  const chainId = useChainId()

  if (!isConnected) {
    return (
      <div
        style={{
          display: 'flex',
          gap: '16px',
          flexWrap: 'wrap',
          marginTop: '30px'
        }}
      >
        {connectors.map((connector) => (
          <button
            key={connector.uid}
            onClick={() => connect({ connector })}
            style={{
              padding: '14px 24px',
              borderRadius: '14px',
              border: 'none',
              background: '#111827',
              color: 'white',
              cursor: 'pointer',
              fontSize: '16px',
              fontWeight: '600',
              transition: '0.2s',
              boxShadow: '0 4px 12px rgba(0,0,0,0.15)'
            }}
          >
            Connect {connector.name}
          </button>
        ))}
      </div>
    )
  }

  return (
    <div
      style={{
        marginTop: '30px',
        padding: '24px',
        borderRadius: '18px',
        background: '#111827',
        color: 'white',
        maxWidth: '520px',
        boxShadow: '0 6px 20px rgba(0,0,0,0.2)'
      }}
    >
      <h3 style={{ marginBottom: '16px' }}>
        Wallet Connected
      </h3>

      <p
        style={{
          wordBreak: 'break-all',
          marginBottom: '12px'
        }}
      >
        {address}
      </p>

      {chainId !== 421614 ? (
        <div
          style={{
            background: '#7f1d1d',
            padding: '12px',
            borderRadius: '10px',
            marginBottom: '16px'
          }}
        >
          Wrong Network — Switch to Arbitrum Sepolia
        </div>
      ) : (
        <div
          style={{
            background: '#14532d',
            padding: '12px',
            borderRadius: '10px',
            marginBottom: '16px'
          }}
        >
          Connected to Arbitrum Sepolia
        </div>
      )}

      <button
        onClick={() => disconnect()}
        style={{
          padding: '12px 20px',
          borderRadius: '12px',
          border: 'none',
          background: '#dc2626',
          color: 'white',
          cursor: 'pointer',
          fontWeight: '600'
        }}
      >
        Disconnect
      </button>
    </div>
  )
}