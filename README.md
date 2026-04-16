# 🪓 scythefuzzer

> Recon + target prioritization tool for bug bounty hunters focused on **IDOR, SSRF, Open Redirects, and Business Logic flaws**

---

## ⚡ Why scythefuzzer?

Most recon tools focus on **volume**.

ScytheFuzzer focuses on **relevance**.

Instead of dumping thousands of URLs and leaving you guessing, it:

- Extracts **high-value targets**
- Prioritizes endpoints likely vulnerable to:
  - IDOR
  - SSRF
  - Open Redirect
  - Business Logic flaws
- Reduces noise so you can **focus on real bugs**

---

## Features

- 📦 Collects URLs from Wayback (stable, no CommonCrawl issues)
- 🧹 Cleans and deduplicates messy input
- 🎯 Filters **parameterized endpoints**
- 🌐 Identifies **live targets**
- 🧠 Automatically extracts:
  - IDOR candidates
  - SSRF / Redirect parameters
  - API endpoints
  - Sensitive actions (reset, delete, export, etc.)
- 📂 Organized output directory per run

---

## 🛠️ Requirements
Ensure the following tools are installed before running the script:
- `gau`
- `httpx`
- `uro`

Install dependencies:

```bash
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
pip install uro

```
Make the script executable
```bash
chmod +x scythefuzzer.sh
```
---
🚀 Usage

Single target
`./scythefuzzer.sh example.com`

Multiple targets
`./scythefuzzer.sh domains.txt`

---
📂 Output

Each run generates a directory:
`scythe_output_<timestamp>/`

---
📄 Core Files

`all_urls.txt`: Full dataset collected from Wayback + input

`filtered_urls.txt`: URLs containing parameters

`live_urls.txt`: Reachable endpoints

🔥 High-Value Targets
idor_candidates.txt	Test authorization flaws (IDOR)
ssrf_redirect_candidates.txt	Test SSRF & open redirect vectors
api_candidates.txt	API endpoints for deeper testing
sensitive_actions.txt	Business logic abuse targets










