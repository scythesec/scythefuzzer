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

## 🔥 Features

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

- `gau`
- `httpx`
- `uro`

Install dependencies:

```bash
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
pip install uro
