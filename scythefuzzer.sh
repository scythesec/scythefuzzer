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
# Input handling
# =========================
if [[ -z "$1" ]]; then
    read -p "Enter target domain or file: " INPUT
else
    INPUT="$1"
fi

if [[ -z "$INPUT" ]]; then
    echo -e "${RED}[ERROR] No input provided.${RESET}"
    exit 1
fi

echo -e "${GREEN}[INFO] Target: $INPUT${RESET}"

# =========================
# Dependencies
# =========================
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
# STEP 1 - GAU (FIXED)
# =========================
echo -e "${GREEN}[INFO] Collecting URLs (wayback)...${RESET}"

> "$GAU_FILE"

while read -r domain; do
    echo "[INFO] gau -> $domain"
    timeout 20 gau --providers wayback "$domain" 2>/dev/null >> "$GAU_FILE"
done < "$DOMAINS"

# Add provided URLs
if [ -s "$URLS" ]; then
    cat "$URLS" >> "$GAU_FILE"
fi

sort -u "$GAU_FILE" -o "$GAU_FILE"

# Fallback
if [ ! -s "$GAU_FILE" ]; then
    echo -e "${YELLOW}[WARNING] No URLs from gau, using fallback...${RESET}"
    echo "https://$INPUT" > "$GAU_FILE"
fi

echo -e "${GREEN}[INFO] Total URLs collected: $(wc -l < "$GAU_FILE")${RESET}"

# =========================
# Scope Filter (UPDATED)
# =========================
read -p "Filter only target domain? (y/n): " SCOPE

if [[ "$SCOPE" == "y" ]]; then
    echo -e "${GREEN}[INFO] Splitting in-scope and out-of-scope URLs...${RESET}"

    INSCOPE="$OUTPUT_DIR/in_scope_urls.txt"
    OUTSCOPE="$OUTPUT_DIR/out_scope_urls.txt"

    > "$INSCOPE"
    > "$OUTSCOPE"

    while read -r url; do
        host=$(echo "$url" | awk -F/ '{print $3}')

        if [[ "$host" == "$INPUT" || "$host" == *".$INPUT" ]]; then
            echo "$url" >> "$INSCOPE"
        else
            echo "$url" >> "$OUTSCOPE"
        fi
    done < "$GAU_FILE"

    echo -e "${GREEN}[INFO] In-scope URLs: $(wc -l < "$INSCOPE")${RESET}"
    echo -e "${YELLOW}[INFO] Out-of-scope URLs: $(wc -l < "$OUTSCOPE")${RESET}"

    # 🔥 CRITICAL: Continue ONLY with in-scope
    cp "$INSCOPE" "$GAU_FILE"
fi

# =========================
# STEP 2 - FILTER PARAMS
# =========================
echo -e "${GREEN}[INFO] Filtering parameterized URLs...${RESET}"

grep -E '\?[^=]+=.*' "$GAU_FILE" | uro | sort -u > "$FILTERED"

echo -e "${GREEN}[INFO] Parameterized URLs: $(wc -l < "$FILTERED")${RESET}"

# Debug
echo "[DEBUG] Sample URLs:"
head -n 5 "$GAU_FILE"

# =========================
# STEP 3 - LIVE CHECK
# =========================
echo -e "${GREEN}[INFO] Checking live URLs...${RESET}"

httpx -silent -threads 100 -rate-limit 200 < "$FILTERED" > "$LIVE"

echo -e "${GREEN}[INFO] Live URLs: $(wc -l < "$LIVE")${RESET}"

# =========================
# STEP 4 - TARGET EXTRACTION
# =========================
echo -e "${GREEN}[INFO] Extracting high-value targets...${RESET}"

grep -Ei '(^|[?&])(id|user|account|profile|uid|customer|userid|accountid|orderid|owner|uuid)=' "$LIVE" | sort -u > "$IDOR"

grep -Ei 'url=|redirect=|next=|return=|dest=|callback=' "$LIVE" | sort -u > "$SSRF"

grep -Ei '/api|/v[0-9]/|graphql' "$LIVE" | sort -u > "$API"

grep -Ei 'delete|update|reset|export|confirm|token|password' "$LIVE" | sort -u > "$SENSITIVE"

# =========================
# RESULTS
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
