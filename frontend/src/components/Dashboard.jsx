import { useState, useEffect } from "react"
import { ethers } from "ethers"
import { ADDRESSES } from "../contracts/addresses"
import { CRAFT_TOKEN_ABI, SKIN_TOKEN_ABI, AMM_ABI, VAULT_ABI } from "../contracts/abis"

const SKIN_NAMES = ["AK-47 | Redline", "AWP | Dragon Lore", "M4A4 | Howl", "Glock | Water Elemental", "USP | Neo-Noir"]
const RARITY_LABELS = ["Common", "Rare", "Legendary"]
const RARITY_COLORS = ["#888", "#4a9eff", "#ff9500"]

export default function Dashboard({ provider, account }) {
  const [craftBalance, setCraftBalance] = useState("0")
  const [votingPower, setVotingPower]   = useState("0")
  const [skins, setSkins]               = useState([])
  const [reserves, setReserves]         = useState({ a: "0", b: "0" })
  const [vaultAssets, setVaultAssets]   = useState("0")
  const [loading, setLoading]           = useState(true)

  useEffect(() => {
    if (provider && account) loadData()
  }, [provider, account])

  async function loadData() {
    setLoading(true)
    try {
      const craft = new ethers.Contract(ADDRESSES.CraftToken, CRAFT_TOKEN_ABI, provider)
      const skin  = new ethers.Contract(ADDRESSES.SkinToken, SKIN_TOKEN_ABI, provider)
      const amm   = new ethers.Contract(ADDRESSES.SkinMarketAMM, AMM_ABI, provider)
      const vault = new ethers.Contract(ADDRESSES.RentalVault, VAULT_ABI, provider)

      const [bal, votes, resA, resB, assets] = await Promise.all([
        craft.balanceOf(account),
        craft.getVotes(account),
        amm.reserveA(),
        amm.reserveB(),
        vault.totalAssets(),
      ])

      setCraftBalance(ethers.formatEther(bal))
      setVotingPower(ethers.formatEther(votes))
      setReserves({
        a: parseFloat(ethers.formatEther(resA)).toFixed(2),
        b: parseFloat(ethers.formatEther(resB)).toFixed(4),
      })
      setVaultAssets(ethers.formatEther(assets))

      const skinData = []
      for (let i = 0; i < 5; i++) {
        const bal = await skin.balanceOf(account, i)
        if (bal > 0n) {
          const info = await skin.skins(i)
          skinData.push({
            id: i,
            name: SKIN_NAMES[i],
            rarity: Number(info.rarity),
            amount: bal.toString(),
          })
        }
      }
      setSkins(skinData)
    } catch (e) {
      console.error(e)
    }
    setLoading(false)
  }

  if (loading) return <div className="loading">Загрузка данных...</div>

  return (
    <div className="dashboard">
      <h2>📊 Dashboard</h2>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label">CRAFT Balance</div>
          <div className="stat-value">{parseFloat(craftBalance).toFixed(2)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Voting Power</div>
          <div className="stat-value">{parseFloat(votingPower).toFixed(2)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">AMM Reserve CRAFT</div>
          <div className="stat-value">{reserves.a}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">AMM Reserve WETH</div>
          <div className="stat-value">{reserves.b}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Vault Total Assets</div>
          <div className="stat-value">{parseFloat(vaultAssets).toFixed(2)}</div>
        </div>
      </div>

      <h3>🎒 Мой инвентарь</h3>
      {skins.length === 0 ? (
        <p className="empty">Нет скинов. Открой кейс!</p>
      ) : (
        <div className="skins-grid">
          {skins.map(s => (
            <div key={s.id} className="skin-card">
              <div className="skin-name">{s.name}</div>
              <div className="skin-rarity" style={{ color: RARITY_COLORS[s.rarity] }}>
                {RARITY_LABELS[s.rarity]}
              </div>
              <div className="skin-amount">x{s.amount}</div>
            </div>
          ))}
        </div>
      )}

      <button className="btn-secondary" onClick={loadData}>🔄 Обновить</button>
    </div>
  )
}
