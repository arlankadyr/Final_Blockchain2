import { useState, useEffect } from "react"
import { ethers } from "ethers"
import { ADDRESSES } from "../contracts/addresses"
import { CRAFT_TOKEN_ABI, AMM_ABI } from "../contracts/abis"

export default function AMMPanel({ provider, signer, account }) {
  const [amountIn, setAmountIn]   = useState("")
  const [amountOut, setAmountOut] = useState("0")
  const [reserves, setReserves]   = useState({ a: "0", b: "0" })
  const [loading, setLoading]     = useState(false)
  const [direction, setDirection] = useState("AtoB")
  const [txHash, setTxHash]       = useState("")
  const [error, setError]         = useState("")

  useEffect(() => {
    if (provider) loadReserves()
  }, [provider])

  useEffect(() => {
    if (amountIn && parseFloat(amountIn) > 0) getQuote()
    else setAmountOut("0")
  }, [amountIn, direction])

  async function loadReserves() {
    try {
      const amm = new ethers.Contract(ADDRESSES.SkinMarketAMM, AMM_ABI, provider)
      const [a, b] = await Promise.all([amm.reserveA(), amm.reserveB()])
      setReserves({
        a: parseFloat(ethers.formatEther(a)).toFixed(2),
        b: parseFloat(ethers.formatEther(b)).toFixed(6),
      })
    } catch (e) { console.error(e) }
  }

  async function getQuote() {
    try {
      const amm = new ethers.Contract(ADDRESSES.SkinMarketAMM, AMM_ABI, provider)
      const parsed = ethers.parseEther(amountIn)
      const out = direction === "AtoB"
        ? await amm.getAmountOutAforB(parsed)
        : await amm.getAmountOutBforA(parsed)
      setAmountOut(parseFloat(ethers.formatEther(out)).toFixed(6))
    } catch { setAmountOut("0") }
  }

  async function doSwap() {
    setError("")
    setTxHash("")
    if (!amountIn || parseFloat(amountIn) <= 0) {
      setError("Введи сумму")
      return
    }
    setLoading(true)
    try {
      const craft = new ethers.Contract(ADDRESSES.CraftToken, CRAFT_TOKEN_ABI, signer)
      const amm   = new ethers.Contract(ADDRESSES.SkinMarketAMM, AMM_ABI, signer)
      const parsed = ethers.parseEther(amountIn)

      const approveTx = await craft.approve(ADDRESSES.SkinMarketAMM, parsed)
      await approveTx.wait()

      const tx = direction === "AtoB"
        ? await amm.swapAforB(parsed, 0n)
        : await amm.swapBforA(parsed, 0n)
      await tx.wait()

      setTxHash(tx.hash)
      setAmountIn("")
      loadReserves()
    } catch (e) {
      setError(e.reason || e.message || "Ошибка транзакции")
    }
    setLoading(false)
  }

  return (
    <div className="panel">
      <h2>💱 Swap</h2>

      <div className="reserves">
        <span>Reserve CRAFT: {reserves.a}</span>
        <span>Reserve WETH: {reserves.b}</span>
      </div>

      <div className="swap-box">
        <div className="direction-toggle">
          <button
            className={direction === "AtoB" ? "btn-primary" : "btn-secondary"}
            onClick={() => setDirection("AtoB")}
          >CRAFT → WETH</button>
          <button
            className={direction === "BtoA" ? "btn-primary" : "btn-secondary"}
            onClick={() => setDirection("BtoA")}
          >WETH → CRAFT</button>
        </div>

        <input
          className="input"
          type="number"
          placeholder="Сумма"
          value={amountIn}
          onChange={e => setAmountIn(e.target.value)}
        />

        <div className="quote">
          Получишь: <strong>{amountOut}</strong>
        </div>

        {error && <div className="error">❌ {error}</div>}
        {txHash && (
          <div className="success">
            ✅ <a href={`https://sepolia.arbiscan.io/tx/${txHash}`} target="_blank" rel="noreferrer">
              Транзакция успешна
            </a>
          </div>
        )}

        <button className="btn-primary" onClick={doSwap} disabled={loading}>
          {loading ? "Обработка..." : "Swap"}
        </button>
      </div>
    </div>
  )
}
