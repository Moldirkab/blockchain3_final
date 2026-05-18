import { useState, useEffect, useCallback } from "react";
import { ethers } from "ethers";

// ── Contract Addresses (Arbitrum Sepolia) ────────────────────────────────────
const ADDRESSES = {
  governanceToken: "0xE702422e215AEc71Db454590cBAe7b9570A775C6",
  stableToken:     "0xAb71a7c9d52056925652d5C65607A91Fe5D7D750",
  oracle:          "0x9Bd58302FC22B1801Ae2602C90B82320b8D16cbE",
  vault:           "0xD2B179a3a8206845de14f627009D02F17ae04cE8",
  policyNFT:       "0x778aa3d56d284BdBA96350306D0B8a02BF9B9250",
  insurancePool:   "0x1e485606B0806Ea72508119Af2B132dc8F26E2B0",
  amm:             "0x9cF2362C438F8eE98746f68f03Ff54d514307c92",
  timelock:        "0x43683ad2312868720022d74b9C6E2FCfc57e463A",
  governor:        "0xA5c868efEe2d45961B0eA069EC8a3fa5f15b8Abb",
  factory:         "0x366a89cC4f309677A38D3CF4024390046Cc3e911",
};

// ── ABIs ─────────────────────────────────────────────────────────────────────
const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
];

const GOV_TOKEN_ABI = [
  ...ERC20_ABI,
  "function getVotes(address) view returns (uint256)",
  "function delegates(address) view returns (address)",
  "function delegate(address delegatee)",
];

const INSURANCE_ABI = [
  "function buyPolicy(bytes32 riskType, uint256 coverageAmount) returns (uint256)",
  "function claim(uint256 policyId)",
];

const VAULT_ABI = [
  "function deposit(uint256 assets, address receiver) returns (uint256)",
  "function withdraw(uint256 assets, address receiver, address owner) returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function totalAssets() view returns (uint256)",
  "function availableLiquidity() view returns (uint256)",
];

const AMM_ABI = [
  "function addLiquidity(uint256 amountA, uint256 amountB) returns (uint256)",
  "function removeLiquidity(uint256 shares) returns (uint256, uint256)",
  "function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) returns (uint256)",
  "function getAmountOut(address tokenIn, uint256 amountIn) view returns (uint256)",
];

const GOVERNOR_ABI = [
  "function state(uint256 proposalId) view returns (uint8)",
  "function proposalVotes(uint256 proposalId) view returns (uint256, uint256, uint256)",
  "function hasVoted(uint256 proposalId, address account) view returns (bool)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
];

const PROPOSAL_ID = "98880771107137624284678011468404233143556596969012362779027641758325374327148";

const PROPOSAL_STATES = ["Pending","Active","Canceled","Defeated","Succeeded","Queued","Expired","Executed"];

// ── Styles ────────────────────────────────────────────────────────────────────
const styles = `
  @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@400;600;700;800&display=swap');

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg: #080c12;
    --surface: #0d1420;
    --surface2: #121c2e;
    --border: #1e2d45;
    --accent: #00d4ff;
    --accent2: #7b2fff;
    --green: #00ff9d;
    --red: #ff4b6e;
    --yellow: #ffd166;
    --text: #e2eaf6;
    --muted: #5a7a9a;
    --font-display: 'Syne', sans-serif;
    --font-mono: 'Space Mono', monospace;
  }

  body { background: var(--bg); color: var(--text); font-family: var(--font-display); min-height: 100vh; }

  .app { min-height: 100vh; display: flex; flex-direction: column; }

  /* Header */
  .header {
    display: flex; align-items: center; justify-content: space-between;
    padding: 1rem 2rem; border-bottom: 1px solid var(--border);
    background: rgba(13,20,32,0.9); backdrop-filter: blur(12px);
    position: sticky; top: 0; z-index: 100;
  }
  .logo { font-size: 1.2rem; font-weight: 800; letter-spacing: -0.02em; }
  .logo span { color: var(--accent); }
  .connect-btn {
    background: linear-gradient(135deg, var(--accent2), var(--accent));
    border: none; color: white; padding: 0.5rem 1.2rem;
    border-radius: 8px; cursor: pointer; font-family: var(--font-mono);
    font-size: 0.8rem; font-weight: 700; letter-spacing: 0.05em;
    transition: opacity 0.2s;
  }
  .connect-btn:hover { opacity: 0.85; }
  .wallet-badge {
    font-family: var(--font-mono); font-size: 0.75rem; color: var(--accent);
    background: rgba(0,212,255,0.08); border: 1px solid rgba(0,212,255,0.2);
    padding: 0.4rem 0.9rem; border-radius: 20px;
  }

  /* Nav */
  .nav {
    display: flex; gap: 0; padding: 0 2rem;
    border-bottom: 1px solid var(--border); background: var(--surface);
    overflow-x: auto;
  }
  .nav-btn {
    background: none; border: none; color: var(--muted);
    padding: 1rem 1.2rem; cursor: pointer; font-family: var(--font-display);
    font-size: 0.85rem; font-weight: 600; white-space: nowrap;
    border-bottom: 2px solid transparent; transition: all 0.2s;
  }
  .nav-btn:hover { color: var(--text); }
  .nav-btn.active { color: var(--accent); border-bottom-color: var(--accent); }

  /* Main */
  .main { flex: 1; padding: 2rem; max-width: 1100px; margin: 0 auto; width: 100%; }

  /* Cards */
  .card {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 16px; padding: 1.5rem; margin-bottom: 1.5rem;
  }
  .card-title {
    font-size: 0.7rem; font-weight: 700; letter-spacing: 0.15em;
    text-transform: uppercase; color: var(--muted); margin-bottom: 1rem;
  }
  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }
  .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem; }

  /* Stat */
  .stat { padding: 1rem; background: var(--surface2); border-radius: 12px; }
  .stat-label { font-size: 0.7rem; color: var(--muted); margin-bottom: 0.3rem; font-family: var(--font-mono); }
  .stat-value { font-size: 1.4rem; font-weight: 800; letter-spacing: -0.02em; }
  .stat-value.green { color: var(--green); }
  .stat-value.blue { color: var(--accent); }
  .stat-value.purple { color: var(--accent2); }
  .stat-value.yellow { color: var(--yellow); }

  /* Form */
  .form-group { margin-bottom: 1rem; }
  .form-label { font-size: 0.75rem; color: var(--muted); margin-bottom: 0.4rem; display: block; font-family: var(--font-mono); }
  .form-input {
    width: 100%; padding: 0.7rem 1rem; background: var(--surface2);
    border: 1px solid var(--border); border-radius: 8px; color: var(--text);
    font-family: var(--font-mono); font-size: 0.9rem; outline: none;
    transition: border-color 0.2s;
  }
  .form-input:focus { border-color: var(--accent); }

  /* Buttons */
  .btn {
    padding: 0.7rem 1.4rem; border-radius: 8px; border: none;
    cursor: pointer; font-family: var(--font-display); font-weight: 700;
    font-size: 0.85rem; transition: all 0.2s; width: 100%;
  }
  .btn-primary { background: var(--accent); color: var(--bg); }
  .btn-primary:hover { opacity: 0.85; }
  .btn-danger { background: var(--red); color: white; }
  .btn-danger:hover { opacity: 0.85; }
  .btn-success { background: var(--green); color: var(--bg); }
  .btn-success:hover { opacity: 0.85; }
  .btn-outline {
    background: transparent; color: var(--accent);
    border: 1px solid var(--accent);
  }
  .btn-outline:hover { background: rgba(0,212,255,0.08); }
  .btn:disabled { opacity: 0.4; cursor: not-allowed; }

  /* Status */
  .status {
    margin-top: 1rem; padding: 0.7rem 1rem; border-radius: 8px;
    font-family: var(--font-mono); font-size: 0.8rem;
  }
  .status.success { background: rgba(0,255,157,0.08); color: var(--green); border: 1px solid rgba(0,255,157,0.2); }
  .status.error { background: rgba(255,75,110,0.08); color: var(--red); border: 1px solid rgba(255,75,110,0.2); }
  .status.info { background: rgba(0,212,255,0.08); color: var(--accent); border: 1px solid rgba(0,212,255,0.2); }

  /* Vote buttons */
  .vote-row { display: flex; gap: 1rem; }
  .badge {
    display: inline-block; padding: 0.25rem 0.6rem; border-radius: 20px;
    font-size: 0.7rem; font-weight: 700; font-family: var(--font-mono);
  }
  .badge-green { background: rgba(0,255,157,0.15); color: var(--green); }
  .badge-red { background: rgba(255,75,110,0.15); color: var(--red); }
  .badge-blue { background: rgba(0,212,255,0.15); color: var(--accent); }

  /* Page title */
  .page-title { font-size: 1.8rem; font-weight: 800; margin-bottom: 0.3rem; letter-spacing: -0.03em; }
  .page-sub { color: var(--muted); font-size: 0.85rem; margin-bottom: 1.5rem; font-family: var(--font-mono); }

  /* Connect prompt */
  .connect-prompt {
    text-align: center; padding: 4rem 2rem;
    color: var(--muted); font-family: var(--font-mono);
  }
  .connect-prompt h2 { font-size: 1.2rem; margin-bottom: 0.5rem; color: var(--text); }

  @media (max-width: 640px) {
    .grid-2, .grid-3 { grid-template-columns: 1fr; }
    .main { padding: 1rem; }
  }
`;

// ── Helper ────────────────────────────────────────────────────────────────────
const fmt = (val, dec = 18) => {
  try { return Number(ethers.formatUnits(val, dec)).toLocaleString(undefined, { maximumFractionDigits: 2 }); }
  catch { return "0"; }
};

// ── Pages ─────────────────────────────────────────────────────────────────────

function Dashboard({ signer, wallet }) {
  const [data, setData] = useState({});

  useEffect(() => {
    if (!signer || !wallet) return;
    (async () => {
      try {
        const govToken = new ethers.Contract(ADDRESSES.governanceToken, GOV_TOKEN_ABI, signer);
        const stable   = new ethers.Contract(ADDRESSES.stableToken, ERC20_ABI, signer);
        const vault    = new ethers.Contract(ADDRESSES.vault, VAULT_ABI, signer);
        const [govBal, stableBal, votes, totalAssets, liquidity] = await Promise.all([
          govToken.balanceOf(wallet),
          stable.balanceOf(wallet),
          govToken.getVotes(wallet),
          vault.totalAssets().catch(() => 0n),
          vault.availableLiquidity().catch(() => 0n),
        ]);
        setData({ govBal, stableBal, votes, totalAssets, liquidity });
      } catch(e) { console.error(e); }
    })();
  }, [signer, wallet]);

  return (
    <div>
      <div className="page-title">Dashboard</div>
      <div className="page-sub">Overview of your DeFi Insurance Protocol positions</div>

      <div className="grid-3">
        <div className="stat">
          <div className="stat-label">GOV Token Balance</div>
          <div className="stat-value purple">{fmt(data.govBal || 0n)}</div>
        </div>
        <div className="stat">
          <div className="stat-label">Stable Token Balance</div>
          <div className="stat-value blue">{fmt(data.stableBal || 0n)}</div>
        </div>
        <div className="stat">
          <div className="stat-label">Voting Power</div>
          <div className="stat-value green">{fmt(data.votes || 0n)}</div>
        </div>
        <div className="stat">
          <div className="stat-label">Vault Total Assets</div>
          <div className="stat-value yellow">{fmt(data.totalAssets || 0n)}</div>
        </div>
        <div className="stat">
          <div className="stat-label">Available Liquidity</div>
          <div className="stat-value blue">{fmt(data.liquidity || 0n)}</div>
        </div>
        <div className="stat">
          <div className="stat-label">Network</div>
          <div className="stat-value" style={{fontSize:'1rem'}}>Arbitrum Sepolia</div>
        </div>
      </div>

      <div className="card" style={{marginTop:'1.5rem'}}>
        <div className="card-title">Protocol Contracts</div>
        <div style={{display:'grid', gap:'0.5rem'}}>
          {Object.entries(ADDRESSES).map(([k, v]) => (
            <div key={k} style={{display:'flex', justifyContent:'space-between', padding:'0.5rem', background:'var(--surface2)', borderRadius:'8px'}}>
              <span style={{color:'var(--muted)', fontSize:'0.8rem', textTransform:'capitalize'}}>{k}</span>
              <span style={{fontFamily:'var(--font-mono)', fontSize:'0.75rem', color:'var(--accent)'}}>{v.slice(0,6)}...{v.slice(-4)}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function Insurance({ signer, wallet }) {
  const [coverage, setCoverage] = useState("");
  const [duration, setDuration] = useState("");
  const [policyId, setPolicyId] = useState("");
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(false);
  const [riskTypeInput, setRiskTypeInput] = useState("DEPEG");

const buyPolicy = async () => {
    if (!signer) return;
    setLoading(true); setStatus(null);
    try {
      const feeData = await signer.provider.getFeeData();
      const gasopts = { maxFeePerGas: feeData.maxFeePerGas, maxPriorityFeePerGas: feeData.maxPriorityFeePerGas };
      const stable = new ethers.Contract(ADDRESSES.stableToken, ERC20_ABI, signer);
      const approveTx = await stable.approve(ADDRESSES.insurancePool, ethers.parseEther(coverage), gasopts);
      await approveTx.wait();
      const pool = new ethers.Contract(ADDRESSES.insurancePool, INSURANCE_ABI, signer);
      const riskType = ethers.encodeBytes32String(riskTypeInput);
      const tx = await pool.buyPolicy(riskType, ethers.parseEther(coverage), gasopts);
      await tx.wait();
      setStatus({ type: "success", msg: `Policy purchased! TX: ${tx.hash.slice(0,10)}...` });
    } catch(e) {
      setStatus({ type: "error", msg: e.reason || e.message });
    }
    setLoading(false);
  };

  const claimPolicy = async () => {
    if (!signer) return;
    setLoading(true); setStatus(null);
    try {
      const pool = new ethers.Contract(ADDRESSES.insurancePool, INSURANCE_ABI, signer);
      const feeData = await signer.provider.getFeeData(); const tx = await pool.claim(Number(policyId), { maxFeePerGas: feeData.maxFeePerGas, maxPriorityFeePerGas: feeData.maxPriorityFeePerGas });
      await tx.wait();
      setStatus({ type: "success", msg: `Claim submitted! TX: ${tx.hash.slice(0,10)}...` });
    } catch(e) {
      setStatus({ type: "error", msg: e.reason || e.message });
    }
    setLoading(false);
  };

  return (
    <div>
      <div className="page-title">Insurance Pool</div>
      <div className="page-sub">Buy coverage policies and submit claims</div>

      <div className="grid-2">
        <div className="card">
          <div className="card-title">Buy Policy</div>
          <div className="form-group">
            <div className="form-group">
  <label className="form-label">Risk Type</label>
  <select className="form-input" value={riskTypeInput} onChange={e => setRiskTypeInput(e.target.value)}>
    <option value="DEPEG">DEPEG</option>
    <option value="WEATHER">WEATHER</option>
    <option value="LIQUIDATION">LIQUIDATION</option>
  </select>
</div>
            <label className="form-label">Coverage Amount (tokens)</label>
            <input className="form-input" value={coverage} onChange={e => setCoverage(e.target.value)} placeholder="1000" />
          </div>
          <div className="form-group">
            <label className="form-label">Duration (days)</label>
            <input className="form-input" value={duration} onChange={e => setDuration(e.target.value)} placeholder="30" />
          </div>
          <button className="btn btn-primary" onClick={buyPolicy} disabled={loading || !coverage || !duration}>
            {loading ? "Processing..." : "Buy Policy"}
          </button>
        </div>

        <div className="card">
          <div className="card-title">Submit Claim</div>
          <div className="form-group">
            <label className="form-label">Policy ID</label>
            <input className="form-input" value={policyId} onChange={e => setPolicyId(e.target.value)} placeholder="0" />
          </div>
          <p style={{color:'var(--muted)', fontSize:'0.8rem', marginBottom:'1rem', fontFamily:'var(--font-mono)'}}>
            Claim triggers automatically if oracle detects a depeg event for your policy.
          </p>
          <button className="btn btn-danger" onClick={claimPolicy} disabled={loading || !policyId}>
            {loading ? "Processing..." : "Submit Claim"}
          </button>
        </div>
      </div>

      {status && <div className={`status ${status.type}`}>{status.msg}</div>}
    </div>
  );
}

function Vault({ signer, wallet }) {
  const [depositAmt, setDepositAmt] = useState("");
  const [withdrawAmt, setWithdrawAmt] = useState("");
  const [shares, setShares] = useState("0");
  const [totalAssets, setTotalAssets] = useState("0");
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!signer || !wallet) return;
    (async () => {
      try {
        const vault = new ethers.Contract(ADDRESSES.vault, VAULT_ABI, signer);
        const [s, t] = await Promise.all([vault.balanceOf(wallet), vault.totalAssets()]);
        setShares(fmt(s)); setTotalAssets(fmt(t));
      } catch(e) {}
    })();
  }, [signer, wallet]);

  const deposit = async () => {
    setLoading(true); setStatus(null);
    try {
      const stable = new ethers.Contract(ADDRESSES.stableToken, ERC20_ABI, signer);
      const vault  = new ethers.Contract(ADDRESSES.vault, VAULT_ABI, signer);
      const amt = ethers.parseEther(depositAmt);
      const approveTx = await stable.approve(ADDRESSES.vault, amt);
      await approveTx.wait();
      const tx = await vault.deposit(amt, wallet, { gasPrice: ethers.parseUnits("0.1", "gwei") });
      await tx.wait();
      setStatus({ type: "success", msg: `Deposited ${depositAmt} tokens as underwriter!` });
    } catch(e) {
      setStatus({ type: "error", msg: e.reason || e.message });
    }
    setLoading(false);
  };

  const withdraw = async () => {
    setLoading(true); setStatus(null);
    try {
      const vault = new ethers.Contract(ADDRESSES.vault, VAULT_ABI, signer);
      const tx = await vault.withdraw(ethers.parseEther(withdrawAmt), wallet, wallet, { gasPrice: ethers.parseUnits("0.1", "gwei") });
      await tx.wait();
      setStatus({ type: "success", msg: `Withdrew ${withdrawAmt} tokens!` });
    } catch(e) {
      setStatus({ type: "error", msg: e.reason || e.message });
    }
    setLoading(false);
  };

  return (
    <div>
      <div className="page-title">Underwriter Vault</div>
      <div className="page-sub">ERC-4626 vault — stake collateral to earn yield as an underwriter</div>

      <div className="grid-2" style={{marginBottom:'1.5rem'}}>
        <div className="stat">
          <div className="stat-label">Your Vault Shares</div>
          <div className="stat-value green">{shares}</div>
        </div>
        <div className="stat">
          <div className="stat-label">Total Assets in Vault</div>
          <div className="stat-value blue">{totalAssets}</div>
        </div>
      </div>

      <div className="grid-2">
        <div className="card">
          <div className="card-title">Deposit (Underwrite)</div>
          <div className="form-group">
            <label className="form-label">Amount (Stable Token)</label>
            <input className="form-input" value={depositAmt} onChange={e => setDepositAmt(e.target.value)} placeholder="1000" />
          </div>
          <button className="btn btn-success" onClick={deposit} disabled={loading || !depositAmt}>
            {loading ? "Processing..." : "Deposit & Earn Yield"}
          </button>
        </div>

        <div className="card">
          <div className="card-title">Withdraw</div>
          <div className="form-group">
            <label className="form-label">Amount to Withdraw</label>
            <input className="form-input" value={withdrawAmt} onChange={e => setWithdrawAmt(e.target.value)} placeholder="500" />
          </div>
          <button className="btn btn-outline" onClick={withdraw} disabled={loading || !withdrawAmt}>
            {loading ? "Processing..." : "Withdraw"}
          </button>
        </div>
      </div>

      {status && <div className={`status ${status.type}`}>{status.msg}</div>}
    </div>
  );
}

function AMM({ signer, wallet }) {
  const [amtA, setAmtA] = useState("");
  const [amtB, setAmtB] = useState("");
  const [swapAmt, setSwapAmt] = useState("");
  const [amountOut, setAmountOut] = useState(null);
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(false);

  const getQuote = async () => {
    if (!signer || !swapAmt) return;
    try {
      const amm = new ethers.Contract(ADDRESSES.amm, AMM_ABI, signer);
      const out = await amm.getAmountOut(ADDRESSES.stableToken, ethers.parseEther(swapAmt));
      setAmountOut(fmt(out));
    } catch(e) { setAmountOut("Error"); }
  };

  const addLiquidity = async () => {
    setLoading(true); setStatus(null);
    try {
      const amm = new ethers.Contract(ADDRESSES.amm, AMM_ABI, signer);
      const tx = await amm.addLiquidity(ethers.parseEther(amtA), ethers.parseEther(amtB));
      await tx.wait();
      setStatus({ type: "success", msg: "Liquidity added successfully!" });
    } catch(e) {
      setStatus({ type: "error", msg: e.reason || e.message });
    }
    setLoading(false);
  };

  const swap = async () => {
    setLoading(true); setStatus(null);
    try {
      const amm = new ethers.Contract(ADDRESSES.amm, AMM_ABI, signer);
      const feeData = await signer.provider.getFeeData(); const gasopts = { maxFeePerGas: feeData.maxFeePerGas, maxPriorityFeePerGas: feeData.maxPriorityFeePerGas }; const stable = new ethers.Contract(ADDRESSES.stableToken, ERC20_ABI, signer); const approveTx = await stable.approve(ADDRESSES.amm, ethers.parseEther(swapAmt), gasopts); await approveTx.wait(); const tx = await amm.swap(ADDRESSES.stableToken, ethers.parseEther(swapAmt), 0n, gasopts);
      await tx.wait();
      setStatus({ type: "success", msg: "Swap executed!" });
    } catch(e) {
      setStatus({ type: "error", msg: e.reason || e.message });
    }
    setLoading(false);
  };

  return (
    <div>
      <div className="page-title">Risk AMM</div>
      <div className="page-sub">Automated market maker for risk token swaps</div>

      <div className="grid-2">
        <div className="card">
          <div className="card-title">Add Liquidity</div>
          <div className="form-group">
            <label className="form-label">Amount Token A (Stable)</label>
            <input className="form-input" value={amtA} onChange={e => setAmtA(e.target.value)} placeholder="100" />
          </div>
          <div className="form-group">
            <label className="form-label">Amount Token B (GOV)</label>
            <input className="form-input" value={amtB} onChange={e => setAmtB(e.target.value)} placeholder="100" />
          </div>
          <button className="btn btn-primary" onClick={addLiquidity} disabled={loading || !amtA || !amtB}>
            {loading ? "Processing..." : "Add Liquidity"}
          </button>
        </div>

        <div className="card">
          <div className="card-title">Swap Tokens</div>
          <div className="form-group">
            <label className="form-label">Amount In (Stable Token)</label>
            <input className="form-input" value={swapAmt} onChange={e => setSwapAmt(e.target.value)} placeholder="50" />
          </div>
          {amountOut && (
            <div style={{padding:'0.6rem', background:'var(--surface2)', borderRadius:'8px', marginBottom:'1rem'}}>
              <span style={{color:'var(--muted)', fontSize:'0.75rem', fontFamily:'var(--font-mono)'}}>Expected out: </span>
              <span style={{color:'var(--green)', fontFamily:'var(--font-mono)'}}>{amountOut}</span>
            </div>
          )}
          <div style={{display:'flex', gap:'0.5rem'}}>
            <button className="btn btn-outline" onClick={getQuote} disabled={!swapAmt} style={{flex:1}}>
              Get Quote
            </button>
            <button className="btn btn-primary" onClick={swap} disabled={loading || !swapAmt} style={{flex:1}}>
              {loading ? "..." : "Swap"}
            </button>
          </div>
        </div>
      </div>

      {status && <div className={`status ${status.type}`}>{status.msg}</div>}
    </div>
  );
}

function Governance({ signer, wallet }) {
  const [proposalState, setProposalState] = useState(null);
  const [votes, setVotes] = useState(null);
  const [hasVoted, setHasVoted] = useState(false);
  const [delegate, setDelegate] = useState("");
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!signer || !wallet) return;
    (async () => {
      try {
        const gov = new ethers.Contract(ADDRESSES.governor, GOVERNOR_ABI, signer);
        const [state, voteData, voted] = await Promise.all([
          gov.state(PROPOSAL_ID),
          gov.proposalVotes(PROPOSAL_ID),
          gov.hasVoted(PROPOSAL_ID, wallet),
        ]);
        setProposalState(Number(state));
        setVotes({ against: fmt(voteData[0]), for: fmt(voteData[1]), abstain: fmt(voteData[2]) });
        setHasVoted(voted);
      } catch(e) {}
    })();
  }, [signer, wallet]);

  const castVote = async (support) => {
    setLoading(true); setStatus(null);
    try {
      const gov = new ethers.Contract(ADDRESSES.governor, GOVERNOR_ABI, signer);
      const tx = await gov.castVote(PROPOSAL_ID, support);
      await tx.wait();
      setStatus({ type: "success", msg: `Vote cast: ${support === 1 ? "FOR" : "AGAINST"}` });
      setHasVoted(true);
    } catch(e) {
      setStatus({ type: "error", msg: e.reason || e.message });
    }
    setLoading(false);
  };

  const delegateVotes = async () => {
    setLoading(true); setStatus(null);
    try {
      const token = new ethers.Contract(ADDRESSES.governanceToken, GOV_TOKEN_ABI, signer);
      const tx = await token.delegate(delegate || wallet);
      await tx.wait();
      setStatus({ type: "success", msg: `Delegated to ${delegate || "self"}` });
    } catch(e) {
      setStatus({ type: "error", msg: e.reason || e.message });
    }
    setLoading(false);
  };

  return (
    <div>
      <div className="page-title">DAO Governance</div>
      <div className="page-sub">Vote on risk parameters and protocol upgrades</div>

      <div className="card">
        <div className="card-title">Active Proposal</div>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:'1rem'}}>
          <span style={{fontFamily:'var(--font-mono)', fontSize:'0.8rem', color:'var(--muted)'}}>
            ID: {PROPOSAL_ID.slice(0,12)}...
          </span>
          {proposalState !== null && (
            <span className={`badge ${proposalState === 1 ? 'badge-green' : 'badge-blue'}`}>
              {PROPOSAL_STATES[proposalState]}
            </span>
          )}
        </div>

        {votes && (
          <div className="grid-3" style={{marginBottom:'1.5rem'}}>
            <div className="stat">
              <div className="stat-label">FOR</div>
              <div className="stat-value green">{votes.for}</div>
            </div>
            <div className="stat">
              <div className="stat-label">AGAINST</div>
              <div className="stat-value" style={{color:'var(--red)'}}>{votes.against}</div>
            </div>
            <div className="stat">
              <div className="stat-label">ABSTAIN</div>
              <div className="stat-value yellow">{votes.abstain}</div>
            </div>
          </div>
        )}

        {hasVoted ? (
          <div className="status info">You have already voted on this proposal.</div>
        ) : (
          <div className="vote-row">
            <button className="btn btn-success" onClick={() => castVote(1)} disabled={loading}>
              {loading ? "..." : "Vote FOR"}
            </button>
            <button className="btn btn-danger" onClick={() => castVote(0)} disabled={loading}>
              {loading ? "..." : "Vote AGAINST"}
            </button>
          </div>
        )}
      </div>

      <div className="card">
        <div className="card-title">Delegate Voting Power</div>
        <div className="form-group">
          <label className="form-label">Delegate Address (leave empty to self-delegate)</label>
          <input className="form-input" value={delegate} onChange={e => setDelegate(e.target.value)} placeholder="0x... or leave empty for self" />
        </div>
        <button className="btn btn-outline" onClick={delegateVotes} disabled={loading}>
          {loading ? "Processing..." : "Delegate Votes"}
        </button>
      </div>

      {status && <div className={`status ${status.type}`}>{status.msg}</div>}
    </div>
  );
}

// ── App ───────────────────────────────────────────────────────────────────────
export default function App() {
  const [page, setPage] = useState("dashboard");
  const [wallet, setWallet] = useState(null);
  const [signer, setSigner] = useState(null);

  const connect = useCallback(async () => {
    if (!window.ethereum) return alert("Install MetaMask");
    const provider = new ethers.BrowserProvider(window.ethereum);
    await provider.send("eth_requestAccounts", []);
    const s = await provider.getSigner();
    setSigner(s);
    setWallet(await s.getAddress());
  }, []);

  useEffect(() => {
    if (window.ethereum?.selectedAddress) connect();
  }, []);

  const pages = [
    { id: "dashboard",   label: "Dashboard" },
    { id: "insurance",   label: "Insurance" },
    { id: "vault",       label: "Vault" },
    { id: "amm",         label: "AMM" },
    { id: "governance",  label: "Governance" },
  ];

  const renderPage = () => {
    if (!wallet) return (
      <div className="connect-prompt">
        <h2>Connect your wallet to continue</h2>
        <p style={{marginTop:'0.5rem'}}>Make sure MetaMask is on Arbitrum Sepolia</p>
      </div>
    );
    const props = { signer, wallet };
    switch(page) {
      case "dashboard":  return <Dashboard {...props} />;
      case "insurance":  return <Insurance {...props} />;
      case "vault":      return <Vault {...props} />;
      case "amm":        return <AMM {...props} />;
      case "governance": return <Governance {...props} />;
      default:           return <Dashboard {...props} />;
    }
  };

  return (
    <>
      <style>{styles}</style>
      <div className="app">
        <header className="header">
          <div className="logo">Risk<span>Shield</span> Protocol</div>
          {wallet
            ? <div className="wallet-badge">{wallet.slice(0,6)}...{wallet.slice(-4)}</div>
            : <button className="connect-btn" onClick={connect}>Connect Wallet</button>
          }
        </header>

        <nav className="nav">
          {pages.map(p => (
            <button key={p.id} className={`nav-btn ${page === p.id ? "active" : ""}`} onClick={() => setPage(p.id)}>
              {p.label}
            </button>
          ))}
        </nav>

        <main className="main">
          {renderPage()}
        </main>
      </div>
    </>
  );
}
