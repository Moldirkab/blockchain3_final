import { useState } from "react";
import { ethers } from "ethers";

const GOVERNOR_ADDRESS =
  "0x6b1d70679aF861FEbDA1f6607530A05990f446a4";

const TOKEN_ADDRESS =
  "0xda6442729B8CD5B9E84C99397E717b9408A94C6f";

const PROPOSAL_ID =
  "12831444624111998230646544667875121348246616082657703003430943894696582972868";

const GOVERNOR_ABI = [
  "function votingDelay() view returns (uint256)",
  "function votingPeriod() view returns (uint256)",
  "function proposalThreshold() view returns (uint256)",
  "function quorum(uint256 blockNumber) view returns (uint256)",
  "function state(uint256 proposalId) view returns (uint8)",
  "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)",
  "function hasVoted(uint256 proposalId, address account) view returns (bool)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
];

const TOKEN_ABI = [
  "function balanceOf(address account) view returns (uint256)",
  "function getVotes(address account) view returns (uint256)",
  "function delegates(address account) view returns (address)",
  "function delegate(address delegatee)",
  "function decimals() view returns (uint8)",
];

export default function App() {
  const [wallet, setWallet] = useState("");
  const [signer, setSigner] = useState(null);

  const [tokenBalance, setTokenBalance] = useState("0");
  const [votingPower, setVotingPower] = useState("0");

  const [status, setStatus] = useState("");

  async function connectWallet() {
    try {
      if (!window.ethereum) {
        alert("Install MetaMask");
        return;
      }

      const provider = new ethers.BrowserProvider(window.ethereum);

      await provider.send("eth_requestAccounts", []);

      const signer = await provider.getSigner();

      const address = await signer.getAddress();

      setSigner(signer);
      setWallet(address);

      const tokenContract = new ethers.Contract(
        TOKEN_ADDRESS,
        TOKEN_ABI,
        provider
      );

      const balance = await tokenContract.balanceOf(address);

      const votes = await tokenContract.getVotes(address);

      const decimals = await tokenContract.decimals();

      setTokenBalance(
        ethers.formatUnits(balance, decimals)
      );

      setVotingPower(
        ethers.formatUnits(votes, decimals)
      );

      setStatus("Wallet connected successfully");
    } catch (err) {
      console.log(err);
      setStatus("Connection failed");
    }
  }

  async function delegateVotes() {
    try {
      if (!signer) {
        setStatus("Connect wallet first");
        return;
      }

      setStatus("Delegating votes...");

      const tokenContract = new ethers.Contract(
        TOKEN_ADDRESS,
        TOKEN_ABI,
        signer
      );

      const tx = await tokenContract.delegate(wallet);

      await tx.wait();

      setStatus("Votes delegated successfully");
    } catch (err) {
      console.log(err);
      setStatus("Delegation failed");
    }
  }

  async function castVote(support) {
    try {
      if (!signer) {
        setStatus("Connect wallet first");
        return;
      }

      setStatus("Submitting vote...");

      const governorContract = new ethers.Contract(
        GOVERNOR_ADDRESS,
        GOVERNOR_ABI,
        signer
      );

      const tx = await governorContract.castVote(
        PROPOSAL_ID,
        support
      );

      await tx.wait();

      setStatus("Vote submitted successfully");
    } catch (err) {
      console.log(err);
      setStatus("Vote failed");
    }
  }

  return (
    <div
      style={{
        minHeight: "100vh",
        background:
          "linear-gradient(to bottom right, #0f172a, #020617)",
        color: "white",
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        padding: "30px",
        fontFamily: "Arial",
      }}
    >
      <div
        style={{
          width: "500px",
          background: "#1e293b",
          padding: "30px",
          borderRadius: "20px",
          boxShadow: "0 0 30px rgba(0,0,0,0.5)",
        }}
      >
        <h1
          style={{
            textAlign: "center",
            fontSize: "40px",
            marginBottom: "25px",
            lineHeight: "1.2",
          }}
        >
          DAO Governance DApp
        </h1>

        <button
          onClick={connectWallet}
          style={{
            width: "100%",
            padding: "14px",
            borderRadius: "12px",
            border: "none",
            background: "#3b82f6",
            color: "white",
            fontWeight: "bold",
            fontSize: "16px",
            cursor: "pointer",
            marginBottom: "20px",
          }}
        >
          {wallet
            ? `Connected: ${wallet.slice(0, 6)}...${wallet.slice(-4)}`
            : "Connect MetaMask"}
        </button>

        <div
          style={{
            background: "#334155",
            padding: "20px",
            borderRadius: "15px",
            marginBottom: "20px",
          }}
        >
          <h2
            style={{
              marginBottom: "15px",
              textAlign: "center",
            }}
          >
            Wallet Information
          </h2>

          <p>
            <strong>Token Balance:</strong>{" "}
            {Number(tokenBalance).toFixed(2)}
          </p>

          <p>
            <strong>Voting Power:</strong>{" "}
            {Number(votingPower).toFixed(2)}
          </p>
        </div>

        <div
          style={{
            background: "#334155",
            padding: "20px",
            borderRadius: "15px",
            marginBottom: "20px",
          }}
        >
          <h2
            style={{
              marginBottom: "15px",
              textAlign: "center",
            }}
          >
            Delegate Voting Power
          </h2>

          <button
            onClick={delegateVotes}
            style={{
              width: "100%",
              padding: "12px",
              borderRadius: "10px",
              border: "none",
              background: "#10b981",
              color: "white",
              fontWeight: "bold",
              cursor: "pointer",
            }}
          >
            Delegate Votes
          </button>
        </div>

        <div
          style={{
            background: "#334155",
            padding: "20px",
            borderRadius: "15px",
            marginBottom: "20px",
          }}
        >
          <h2
            style={{
              marginBottom: "15px",
              textAlign: "center",
            }}
          >
            Governance Voting
          </h2>

          <button
            onClick={() => castVote(1)}
            style={{
              width: "100%",
              padding: "12px",
              borderRadius: "10px",
              border: "none",
              background: "#22c55e",
              color: "white",
              fontWeight: "bold",
              cursor: "pointer",
              marginBottom: "10px",
            }}
          >
            Vote FOR
          </button>

          <button
            onClick={() => castVote(0)}
            style={{
              width: "100%",
              padding: "12px",
              borderRadius: "10px",
              border: "none",
              background: "#ef4444",
              color: "white",
              fontWeight: "bold",
              cursor: "pointer",
            }}
          >
            Vote AGAINST
          </button>
        </div>

        <div
          style={{
            background: "#0f172a",
            padding: "15px",
            borderRadius: "12px",
            textAlign: "center",
          }}
        >
          <strong>Status:</strong>
          <p>{status}</p>
        </div>
      </div>
    </div>
  );
}