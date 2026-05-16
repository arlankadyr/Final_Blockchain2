import { useState } from "react"
import { ethers } from "ethers"
import { ADDRESSES } from "../contracts/addresses"
import { CRAFT_TOKEN_ABI, CASE_OPENING_ABI } from "../contracts/abis"

const SKIN_NAMES = ["AK-47 | Redline", "AWP | Dragon Lore", "M4A4 | Howl", "Glock | Water Elemental", "USP | Neo-Noir"]

export default function CasePanel({ signer }) {
  const [loading, setLoading] = useState(false)
  const [txHash, setTxHash]   = useState("")
  const [error, setError]     = useState("")

  async function openCase() {
    setError("")
    setTxHash("")
    setLoading(true)
    try {
      const craft = new ethers.Contract(ADDRESSES.CraftToken, CRAFT_TOKEN_ABI, signer)
      const cases = new ethers.Contract(ADDRESSES.CaseOpening, CASE_OPENING_ABI, signer)

      const price = ethers.parseEther("100")
      const approveTx = await craft.approve(ADDRESSES.CaseOpening, price)
      await approveTx.wait()

      const tx = await cases.openCase(0)
      await tx.wait()
      setTxHash(tx.hash)
    } catch (e) {
      setError(e.reason || e.message || "Ошибка")
    }
    setLoading(false)
  }

  return (
    <div className="panel">
      <h2>🎁 Case Opening</h2>

      <div className="case-card">
        <h3>Fracture Case</h3>
        <p>Цена: 100 CRAFT токенов</p>
        <div className="drop-rates">
          <div>🟢 AK-47 | Redline — 70%</div>
          <div>🔵 Glock | Water Elemental — 25%</div>
          <div>🟠 AWP | Dragon Lore — 5%</div>
        </div>

        {error && <div className="error">❌ {error}</div>}
        {txHash && (
          <div className="success">
            ✅ Кейс открыт! Скин придёт после VRF callback.{" "}
            <a href={`https://sepolia.arbiscan.io/tx/${txHash}`} target="_blank" rel="noreferrer">
              Транзакция
            </a>
          </div>
        )}

        <button className="btn-primary" onClick={openCase} disabled={loading}>
          {loading ? "Открываем..." : "Открыть кейс (100 CRAFT)"}
        </button>
      </div>
    </div>
  )
}
