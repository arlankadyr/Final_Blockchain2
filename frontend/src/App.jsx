import { useState, useEffect } from "react"
import { ethers } from "ethers"
import { ADDRESSES, ARBITRUM_SEPOLIA } from "./contracts/addresses"
import { CRAFT_TOKEN_ABI, SKIN_TOKEN_ABI, AMM_ABI, GOVERNOR_ABI, CASE_OPENING_ABI } from "./contracts/abis"
import Wallet from "./components/Wallet"
import Dashboard from "./components/Dashboard"
import AMMPanel from "./components/AMMPanel"
import GovernancePanel from "./components/GovernancePanel"
import CasePanel from "./components/CasePanel"
import "./App.css"

export default function App() {
  const [provider, setProvider]   = useState(null)
  const [signer, setSigner]       = useState(null)
  const [account, setAccount]     = useState(null)
  const [chainOk, setChainOk]     = useState(false)
  const [tab, setTab]             = useState("dashboard")

  async function connectWallet() {
    if (!window.ethereum) {
      alert("MetaMask не найден! Установи MetaMask.")
      return
    }
    try {
      const prov = new ethers.BrowserProvider(window.ethereum)
      const accounts = await prov.send("eth_requestAccounts", [])
      const network = await prov.getNetwork()
      const sign = await prov.getSigner()

      setProvider(prov)
      setSigner(sign)
      setAccount(accounts[0])
      setChainOk(network.chainId === 421614n)

      if (network.chainId !== 421614n) {
        await switchNetwork()
      }
    } catch (e) {
      console.error(e)
      alert("Ошибка подключения: " + e.message)
    }
  }

  async function switchNetwork() {
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: "0x66eee" }],
      })
    } catch {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [ARBITRUM_SEPOLIA],
      })
    }
    window.location.reload()
  }

  useEffect(() => {
    if (window.ethereum) {
      window.ethereum.on("accountsChanged", () => window.location.reload())
      window.ethereum.on("chainChanged", () => window.location.reload())
    }
  }, [])

  const tabs = [
    { id: "dashboard",   label: "📊 Dashboard" },
    { id: "amm",         label: "💱 Swap" },
    { id: "cases",       label: "🎁 Cases" },
    { id: "governance",  label: "🗳️ Governance" },
  ]

  return (
    <div className="app">
      <header className="header">
        <div className="header-left">
          <h1>🎮 CS:GO Skin Economy</h1>
          <p className="subtitle">Arbitrum Sepolia</p>
        </div>
        <Wallet account={account} onConnect={connectWallet} chainOk={chainOk} onSwitch={switchNetwork} />
      </header>

      {!chainOk && account && (
        <div className="warning">
          ⚠️ Неправильная сеть! <button onClick={switchNetwork}>Переключить на Arbitrum Sepolia</button>
        </div>
      )}

      <nav className="tabs">
        {tabs.map(t => (
          <button
            key={t.id}
            className={tab === t.id ? "tab active" : "tab"}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </nav>

      <main className="main">
        {!account ? (
          <div className="connect-prompt">
            <h2>Подключи MetaMask для начала</h2>
            <button className="btn-primary" onClick={connectWallet}>Подключить кошелёк</button>
          </div>
        ) : (
          <>
            {tab === "dashboard"  && <Dashboard provider={provider} signer={signer} account={account} />}
            {tab === "amm"        && <AMMPanel provider={provider} signer={signer} account={account} />}
            {tab === "cases"      && <CasePanel provider={provider} signer={signer} account={account} />}
            {tab === "governance" && <GovernancePanel provider={provider} signer={signer} account={account} />}
          </>
        )}
      </main>
    </div>
  )
}
