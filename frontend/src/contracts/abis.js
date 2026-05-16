export const CRAFT_TOKEN_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function delegate(address delegatee)",
  "function getVotes(address account) view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function mint(address to, uint256 amount)",
  "function burn(uint256 amount)",
]

export const SKIN_TOKEN_ABI = [
  "function balanceOf(address account, uint256 id) view returns (uint256)",
  "function skins(uint256) view returns (string name, uint8 rarity, uint256 maxSupply, bool exists)",
  "function nextSkinId() view returns (uint256)",
  "function setApprovalForAll(address operator, bool approved)",
]

export const AMM_ABI = [
  "function reserveA() view returns (uint256)",
  "function reserveB() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function getAmountOutAforB(uint256 amountIn) view returns (uint256)",
  "function getAmountOutBforA(uint256 amountIn) view returns (uint256)",
  "function swapAforB(uint256 amountIn, uint256 minAmountOut) returns (uint256)",
  "function addLiquidity(uint256 amountA, uint256 amountB, uint256 minLpTokens) returns (uint256)",
  "function removeLiquidity(uint256 lpTokens, uint256 minAmountA, uint256 minAmountB) returns (uint256, uint256)",
]

export const GOVERNOR_ABI = [
  "function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
  "function state(uint256 proposalId) view returns (uint8)",
  "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)",
  "function votingDelay() view returns (uint256)",
  "function votingPeriod() view returns (uint256)",
  "function quorumNumerator() view returns (uint256)",
  "event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)",
]

export const CASE_OPENING_ABI = [
  "function openCase(uint256 caseId) returns (uint256)",
  "function cases(uint256) view returns (string name, uint256 price, bool exists)",
  "function nextCaseId() view returns (uint256)",
  "event CaseOpened(uint256 indexed requestId, address indexed player, uint256 skinId)",
]

export const VAULT_ABI = [
  "function deposit(uint256 assets, address receiver) returns (uint256)",
  "function withdraw(uint256 assets, address receiver, address owner) returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function totalAssets() view returns (uint256)",
  "function convertToAssets(uint256 shares) view returns (uint256)",
]
