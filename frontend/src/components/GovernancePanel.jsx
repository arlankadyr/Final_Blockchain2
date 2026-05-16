import { useState, useEffect } from "react"
import { ethers } from "ethers"
import { ADDRESSES } from "../contracts/addresses"
import { CRAFT_TOKEN_ABI, GOVERNOR_ABI } from "../contracts/abis"

const STATES = ["Pending", "Active", "Canceled", "Defeated", "Succeeded", "Queued", "Expired", "Executed"]
const STATE_COLORS = ["#888", "#4a9eff", "#ff4444", "#ff4444", "#00cc44", "#ff9500", "#888", "#00cc44"]

export default function GovernancePanel({ provider, signer, account }) {
  const [votes, setVotes]       = useState("0")
  const [delegate, setDelegate] = useState("")
  const [loading, setLoading]   = useState(false)
  const [txHash, setTxHash]     = useState("")
  const [error, setError]       = useState("")
  const [proposalId, setProposalId] = useState("")
  const [proposalState, setProposalState] = useState(null)

  useEffect(() => {
    if (provider && account) loadVotes()
  }, [provider, account])

  async function loadVotes() {
    try {
      const craft = new ethers.Contract(ADDRESSES.CraftToken, CRAFT_TOKEN_ABI, provider)
      const v = await craft.getVotes(account)
      setVotes(parseFloat(ethers.formatEther(v)).toFixed(2))
    } catch (e) { console.error(e) }
  }

  async function delegateSelf() {
    setError("")
    setLoading(true)
    try {
      const craft = new ethers.Contract(ADDRESSES.CraftToken, CRAFT_TOKEN_ABI, signer)
      const tx = await craft.delegate(account)
      await tx.wait()
      setTxHash(tx.hash)
      loadVotes()
    } catch (e) {
      setError(e.reason || e.message || "Ошибка")
    }
    setLoading(false)
  }

  async function checkProposal() {
    if (!proposalId) return
    try {
      const gov = new ethers.Contract(ADDRESSES.SkinGovernor, GOVERNOR_ABI, provider)
      const state = await gov.state(proposalId)
      setProposalState(Number(state))
    } catch (e) {
      setError("Предложение не найдено")
    }
  }

  async function castVote(support) {
    if (!proposalId) return
    setError("")
    setLoading(true)
    try {
      const gov = new ethers.Contract(ADDRESSES.SkinGovernor, GOVERNOR_ABI, signer)
      const tx = await gov.castVote(proposalId, support)
      await tx.wait()
      setTxHash(tx.hash)
      checkProposal()
    } catch (e) {
      setError(e.reason || e.message || "Ошибка голосования")
    }
    setLoading(false)
  }

  return (
    <div className="panel">
      <h2>🗳️ Governance</h2>

      <div className="gov-section">
        <h3>Твои голоса</h3>
        <div className="stat-value">{votes} CRAFT</div>
        <button className="btn-secondary" onClick={delegateSelf} disabled={loading}>
          Делегировать себе
        </button>
      </div>

      <div className="gov-section">
        <h3>Проверить предложение</h3>
        <input
          className="input"
          placeholder="Proposal ID"
          value={proposalId}
          onChange={e => setProposalId(e.target.value)}
        />
        <button className="btn-secondary" onClick={checkProposal}>Проверить</button>

        {proposalState !== null && (
          <div className="proposal-state">
            Статус: <span style={{ color: STATE_COLORS[proposalState] }}>
              {STATES[proposalState]}
            </span>

            {proposalState === 1 && (
              <div className="vote-buttons">
                <button className="btn-success" onClick={() => castVote(1)} disabled={loading}>
                  ✅ За
                </button>
                <button className="btn-danger" onClick={() => castVote(0)} disabled={loading}>
                  ❌ Против
                </button>
                <button className="btn-secondary" onClick={() => castVote(2)} disabled={loading}>
                  🤷 Воздержаться
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      {error && <div className="error">❌ {error}</div>}
      {txHash && (
        <div className="success">
          ✅ <a href={`https://sepolia.arbiscan.io/tx/${txHash}`} target="_blank" rel="noreferrer">
            Транзакция успешна
          </a>
        </div>
      )}
    </div>
  )
}
