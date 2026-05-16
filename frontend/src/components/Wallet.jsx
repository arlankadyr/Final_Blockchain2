export default function Wallet({ account, onConnect, chainOk, onSwitch }) {
  return (
    <div className="wallet">
      {account ? (
        <div className="wallet-info">
          <span className={`chain-badge ${chainOk ? "ok" : "bad"}`}>
            {chainOk ? "✅ Arbitrum Sepolia" : "❌ Wrong Network"}
          </span>
          <span className="account">
            {account.slice(0, 6)}...{account.slice(-4)}
          </span>
        </div>
      ) : (
        <button className="btn-primary" onClick={onConnect}>
          Connect MetaMask
        </button>
      )}
    </div>
  )
}
