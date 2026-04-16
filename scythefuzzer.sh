#!/bin/bash

# =========================
# ScytheFuzzer
# Recon + Target Prioritization Tool
# =========================

# Colors
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
RESET='\033[0m'

# Handle Ctrl+C
trap 'echo -e "\n${RED}[!] Interrupted. Exiting...${RESET}"; exit 1' SIGINT

clear

# Banner
echo -e "${RED}"
cat << "EOF"

   _____           __  __         ______
  / ___/_____   __/ /_/ /_  ___  / ____/_  __________ ___  _____
  \__ \/ ___/  / / __/ __ \/ _ \/ /_  / / / /_  /_   / _ \/ ___/
 ___/ / /__\ \/ / /_/ / / /  __/ __/ / /_/ / / / /_ /  __/_/ /
/____/\___/ \  /\__/_/ /_/\___/_/    \____/ /___/___\___/_/
            / /
           /_/
                  scythefuzzer - by scythesec 🪲

EOF
echo -e "${RESET}"

# =========================
# Argument check
# =========================
if [[ -z "$1" ]]; then
    echo -e "${RED}Usage: ./scythefuzzer.sh <domain | file>${RESET}"
    exit 1
fi

INPUT="$1"
echo -e "${GREEN}[INFO] Target: $INPUT${RESET}"

# =========================
# Check dependencies
# =========================
echo -e "${GREEN}[INFO] Checking dependencies...${RESET}"

REQUIRED_TOOLS=("gau" "uro" "httpx")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}[ERROR] $tool is not installed.${RESET}"
        exit 1
    fi
done

# =========================
# Output directory
# =========================
OUTPUT_DIR="scythe_output_$(date +%s)"
mkdir -p "$OUTPUT_DIR"

RAW="$OUTPUT_DIR/raw_input.txt"
URLS="$OUTPUT_DIR/urls.txt"
DOMAINS="$OUTPUT_DIR/domains.txt"
GAU_FILE="$OUTPUT_DIR/all_urls.txt"
FILTERED="$OUTPUT_DIR/filtered_urls.txt"
LIVE="$OUTPUT_DIR/live_urls.txt"

IDOR="$OUTPUT_DIR/idor_candidates.txt"
SSRF="$OUTPUT_DIR/ssrf_redirect_candidates.txt"
API="$OUTPUT_DIR/api_candidates.txt"
SENSITIVE="$OUTPUT_DIR/sensitive_actions.txt"

# =========================
# Preprocessing
# =========================
echo -e "${GREEN}[INFO] Preprocessing input...${RESET}"

if [ -f "$INPUT" ]; then
    cat "$INPUT" | tr ' ' '\n' | sed '/^$/d' > "$RAW"
else
    echo "$INPUT" | tr ' ' '\n' > "$RAW"
fi

grep -Eo 'https?://[^ ]+' "$RAW" | sort -u > "$URLS"

grep -Eo '([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})' "$RAW" | \
sed 's|^//||' | sed 's|\.$||' | sort -u > "$DOMAINS"

echo -e "${GREEN}[INFO] URLs found: $(wc -l < "$URLS")${RESET}"
echo -e "${GREEN}[INFO] Domains found: $(wc -l < "$DOMAINS")${RESET}"

# =========================
# STEP 1 - URL Collection
# =========================
echo -e "${GREEN}[INFO] Collecting URLs (wayback)...${RESET}"

> "$GAU_FILE"

if [ -s "$DOMAINS" ]; then
    while read -r domain; do
        echo "[INFO] gau -> $domain"

        RESULT=$(timeout 20 gau --providers wayback "$domain" 2>/dev/null)

        if [ -n "$RESULT" ]; then
            echo "$RESULT" >> "$GAU_FILE"
        else
            echo "[WARNING] No data for $domain"
        fi

    done < "$DOMAINS"
fi

# Add provided URLs
if [ -s "$URLS" ]; then
    cat "$URLS" >> "$GAU_FILE"
fi

# Deduplicate
sort -u "$GAU_FILE" -o "$GAU_FILE"

# Fallback
if [ ! -s "$GAU_FILE" ]; then
    echo -e "${YELLOW}[WARNING] No URLs found, using fallback...${RESET}"
    echo "https://$INPUT" > "$GAU_FILE"
fi

echo -e "${GREEN}[INFO] Total URLs collected: $(wc -l < "$GAU_FILE")${RESET}"

# =========================
# Optional Scope Filtering
# =========================
read -p "Filter only target domain? (y/n): " SCOPE

if [[ "$SCOPE" == "y" ]]; then
    grep "$INPUT" "$GAU_FILE" > "$GAU_FILE.tmp"
    mv "$GAU_FILE.tmp" "$GAU_FILE"
    echo -e "${GREEN}[INFO] Scoped URLs: $(wc -l < "$GAU_FILE")${RESET}"
fi

# =========================
# STEP 2 - Parameter Filtering
# =========================
echo -e "${GREEN}[INFO] Filtering parameterized URLs...${RESET}"

grep -E '\?[^=]+=.*' "$GAU_FILE" | uro | sort -u > "$FILTERED"

echo -e "${GREEN}[INFO] Parameterized URLs: $(wc -l < "$FILTERED")${RESET}"

# =========================
# STEP 3 - Live Check
# =========================
echo -e "${GREEN}[INFO] Checking live URLs...${RESET}"

httpx -silent -threads 100 -rate-limit 200 < "$FILTERED" > "$LIVE"

echo -e "${GREEN}[INFO] Live URLs: $(wc -l < "$LIVE")${RESET}"

# =========================
# STEP 4 - Intelligence Extraction
# =========================
echo -e "${GREEN}[INFO] Extracting high-value targets...${RESET}"

grep -Ei 'id=|user=|account=|profile=|uid=|customer=' "$LIVE" | sort -u > "$IDOR"

grep -Ei 'url=|redirect=|next=|return=|dest=|callback=' "$LIVE" | sort -u > "$SSRF"

grep -Ei '/api|/v[0-9]/|graphql' "$LIVE" | sort -u > "$API"

grep -Ei 'delete|update|reset|export|confirm|token|password' "$LIVE" | sort -u > "$SENSITIVE"

# =========================
# Results
# =========================
echo ""
echo -e "${GREEN}[DONE] Results saved in: $OUTPUT_DIR${RESET}"
echo ""
echo "📂 Files:"
echo " - All URLs: $GAU_FILE"
echo " - Filtered URLs: $FILTERED"
echo " - Live URLs: $LIVE"
echo ""
echo "🔥 High-value targets:"
echo " - IDOR: $IDOR ($(wc -l < "$IDOR"))"
echo " - SSRF/Redirect: $SSRF ($(wc -l < "$SSRF"))"
echo " - API: $API ($(wc -l < "$API"))"
echo " - Sensitive: $SENSITIVE ($(wc -l < "$SENSITIVE"))"
