---
name: macos-system-audit
description: Exhaustive, read-only macOS system audit covering APFS snapshot gap analysis, sparse VM disks, package/model caches, unpushed git repositories, launchd crash loops, toolchain/PATH shadowing, firewall/network priorities, and performance bottlenecks. Produces dual outputs (detailed machine Markdown for AI agents and visual HTML dashboard for humans).
---

# macOS System Audit & Optimization Playbook

This playbook guides an AI agent (or operator) through executing a **comprehensive, deep, and non-destructive system audit** on macOS.

The audit rigorously analyzes disk utilization, development toolchain health, background daemon stability, network configuration, security posture, and performance settings, producing **two dedicated outputs tailored to distinct audiences**.

---

## 🎯 The Goals of the Two Outputs

| Output | Audience | Purpose & Characteristics |
|---|---|---|
| **`~/Desktop/system-audit-YYYY-MM-DD.md`** | **AI Agent / Automation** | **100% Complete Technical Detail:** absolute filepaths, exact byte and block allocations, raw crash stack traces, git commit hashes and working-tree status, PATH precedence matrices, and ready-to-execute bash remediation scripts. Must allow an agent to execute follow-up fixes autonomously without having to re-scan or ask for missing context. |
| **`~/Desktop/system-audit-YYYY-MM-DD.html`** | **Human / User** | **Intuitive & Readable Visual Dashboard:** single standalone file (zero external CDN or font dependencies), automatic Light/Dark mode switching (`prefers-color-scheme`), KPI stat cards (Used Space, Pinned Snapshots, Reclaimable Caches), accessible charts (WCAG compliant contrast), collapsible cards, and clear visual severity badges (🔴 Blocker/Risk, 🟠 Warning/Stability, 🟡 Optimization/Hygiene, 🟢 Housekeeping). |

---

## 🛡️ Core Operational Invariants

1. **STRICTLY READ-ONLY (Golden Rule):** 
   - Never delete, move, mutate files, or modify system settings during the audit phase.
   - Any cleanup scripts or removal actions must only be **proposed and documented** in the reports, never executed automatically.
2. **Accurate Sparse File Accounting:**
   - Virtual machine disks (QCOW2/RAW such as Colima, Docker, Lima) have apparent sizes that differ drastically from actual allocated blocks.
   - Always run `du -k` / `du -shx` (actual physical disk allocation) and compare against `ls -lh` (apparent size).
3. **APFS Snapshot & Purgeable Gap Analysis:**
   - Do not rely solely on directory `du` sums in `$HOME`.
   - Always compute the delta: $\text{Gap} = \text{Data Volume Used Space (df)} - \sum (\text{Live Files across /Users, /Applications, /Library, /opt, /private})$.
   - This gap uncovers disk space pinned by local APFS snapshots (Time Machine reference snapshots) or `Purgeable` blocks.
4. **Low Resource Footprint:**
   - Restrict sampling commands (`top`, `log show`) to brief intervals (e.g., last 7 days or 5-second sampling).

---

## 🔍 The 8 Diagnostic Investigation Phases

Execute the following sequential diagnostic sweeps, collecting findings to populate both reports:

### Phase 1: Disk Storage & APFS Snapshot Gap Analysis
Inspect physical volume allocation and identify Time Machine snapshot pinning:
```bash
# 1. Volume usage and APFS container state
df -h / /System/Volumes/Data
diskutil apfs list

# 2. Measure top-level directories (live files)
du -shx /Applications /Library /usr /opt /private/var 2>/dev/null
du -shx /Users/* 2>/dev/null | sort -hr
du -shx ~/* ~/.[!.]* 2>/dev/null | sort -hr | head -20

# 3. Time Machine Status & Local Snapshots
tmutil listlocalsnapshots /
tmutil destinationinfo
tmutil latestbackup
defaults read /Library/Preferences/com.apple.TimeMachine.plist 2>/dev/null | head -50
```

### Phase 2: Virtualization & Container Disks (Colima / Docker / Lima)
Check sparse disk images and split-brain configurations:
```bash
# 1. Colima & Lima storage (actual vs apparent size)
du -shx ~/.config/colima ~/dotfiles/.config/colima ~/.colima ~/Library/Caches/colima 2>/dev/null
find ~/.config/colima ~/dotfiles/.config/colima ~/.colima -name "*disk*" -exec ls -lh {} + 2>/dev/null
find ~/.config/colima ~/dotfiles/.config/colima ~/.colima -name "*disk*" -exec du -shx {} + 2>/dev/null

# 2. Active Docker context and socket connectivity
docker context ls 2>&1
docker ps 2>&1
```

### Phase 3: Package Manager & ML Model Caches
Identify regenerable caches and directories untouched for >180 days:
```bash
# 1. Cache and package store sizes
du -shx ~/.cache/* ~/Library/Caches/* 2>/dev/null | sort -hr | head -15
du -shx ~/.npm ~/Library/pnpm ~/.rustup ~/go/pkg ~/.m2/repository ~/.cargo/registry ~/.bun ~/.platformio ~/.ollama ~/.lmstudio 2>/dev/null | sort -hr

# 2. Hugging Face & Ollama model weights
du -shx ~/.cache/huggingface/* ~/.ollama/models/* 2>/dev/null | sort -hr

# 3. Cache staleness check (last modified timestamp > 180 days)
for d in ~/.cache/uv ~/.cache/huggingface ~/.npm ~/Library/Caches/Yarn ~/Library/Caches/Homebrew ~/.m2 ~/.platformio; do
  if [ -d "$d" ]; then
    printf "%-35s Last modified: %s\n" "$d" "$(stat -f "%Sm" -t "%Y-%m-%d" "$d")"
  fi
done
```

### Phase 4: Git Repository Safety & Hygiene (`~/code`)
Identify unpushed commits, missing remotes, and forgotten stashes across all codebases:
```bash
# 1. Repositories with no remote configured (exist ONLY on local disk)
echo "=== REPOSITORIES WITH NO REMOTE ==="
for g in $(find ~/code -maxdepth 3 -name .git -type d 2>/dev/null); do
  d=$(dirname "$g")
  if [ -z "$(git -C "$d" remote 2>/dev/null)" ]; then
    echo "NO REMOTE: $d"
  fi
done

# 2. Repositories with unpushed commits on current branch
echo "=== REPOSITORIES WITH UNPUSHED COMMITS ==="
for g in $(find ~/code -maxdepth 3 -name .git -type d 2>/dev/null); do
  d=$(dirname "$g")
  if git -C "$d" remote 2>/dev/null | grep -q .; then
    unpushed=$(git -C "$d" log @{u}.. 2>/dev/null | grep '^commit ' | wc -l | tr -d ' ')
    if [ "$unpushed" -gt 0 ] 2>/dev/null; then
      echo "UNPUSHED ($unpushed commits): $d"
    fi
  fi
done

# 3. Repositories with active stashes
echo "=== REPOSITORIES WITH ACTIVE STASHES ==="
for g in $(find ~/code -maxdepth 3 -name .git -type d 2>/dev/null); do
  d=$(dirname "$g")
  stashes=$(git -C "$d" stash list 2>/dev/null | wc -l | tr -d ' ')
  if [ "$stashes" -gt 0 ]; then
    echo "STASH ($stashes): $d"
  fi
done

# 4. Reproducible build artifacts
find ~/code -maxdepth 4 -name "node_modules" -type d -prune -exec du -shx {} + 2>/dev/null
find ~/code -maxdepth 4 -name ".venv" -type d -prune -exec du -shx {} + 2>/dev/null
```

### Phase 5: Crash Reports & Daemon Stability
Inspect recent crash reports in `~/Library/Logs/DiagnosticReports`:
```bash
# 1. Recent crash report listing
ls -lt ~/Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head -15

# 2. Stack trace and termination reason extraction (e.g. git, Karabiner)
python3 -c "
import glob, json, os
files = sorted(glob.glob(os.path.expanduser('~/Library/Logs/DiagnosticReports/*.ips')), key=os.path.getmtime, reverse=True)[:10]
for f in files:
    try:
        header = json.loads(open(f).readline())
        print(f\"{header.get('timestamp')[:19]} | {header.get('procName')} (PID {header.get('pid')}) | {header.get('termination', {}).get('code', 'CRASH')}\")
    except Exception:
        pass
"
```

### Phase 6: Development Toolchains, PATH Shadowing & Version Managers
Verify duplicate versions, dead PATH entries, and `mise`/Homebrew shadowing:
```bash
# 1. Binary toolchain version map
for c in node npm pnpm yarn bun deno python3 uv ruby go rustc cargo java docker kubectl terraform git; do
  printf "%-12s %s\n" "$c" "$(command -v $c 2>/dev/null || echo 'NOT INSTALLED')"
done

# 2. Dead / non-existent PATH entries
echo "$PATH" | tr ':' '\n' | while IFS= read -r p; do
  [ -d "$p" ] || echo "DEAD PATH: $p"
done

# 3. Version manager shadowing (e.g., mise vs system binaries)
if command -v mise &>/dev/null; then
  mise current 2>/dev/null
  which -a ruby node python 2>/dev/null
fi

# 4. Homebrew hygiene & deprecated formulae
brew doctor 2>&1 | head -20
brew cleanup -n 2>&1
brew untrusted 2>/dev/null || brew tap
```

### Phase 7: Security, Firewall & Network Interface Priority
Inspect security controls and network service precedence:
```bash
# 1. Application firewall and stealth mode status
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode

# 2. Network service order (check if serial debug / USB docks rank above Wi-Fi/Ethernet)
networksetup -listnetworkserviceorder

# 3. Registered background and login items
sbtm list 2>/dev/null || osascript -e 'tell application "System Events" to get name of every login item'
```

### Phase 8: Spotlight Churn, Power Assertions & Performance
Check background indexing overhead and power profiles:
```bash
# 1. Spotlight indexing hit count on dev trees
mdfind -onlyin ~/code -name "package.json" | wc -l
sudo -n mdutil -s / /System/Volumes/Data 2>/dev/null

# 2. Power management and High Power Mode check (M4 Max / Pro on AC)
pmset -g
pmset -g assertions | head -25

# 3. Top CPU / Energy consumer sampling (5s sample)
top -l 1 -s 0 -n 10 -o cpu
```

---

## 📝 Output 1 Specification: Machine Markdown for Agents (`system-audit-YYYY-MM-DD.md`)

The markdown file written to `~/Desktop/system-audit-YYYY-MM-DD.md` must strictly follow this exhaustive structure:

```markdown
# macOS System Audit — [Long Form Date]

**Machine:** [Model Identifier, Chip, Cores, RAM]
**OS:** macOS [Version and Build Number]
**Disk:** [APFS Container, Total Used, Total Free, % Usage]
**Audit scope:** read-only. **No changes were made to the system.**

---

## 1. Executive Summary & Impact Matrix
| # | Finding | Category | Severity (🔴/🟠/🟡/🟢) | Reclaim / Benefit |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

## 2. Disk Space Breakdown & APFS Snapshot Gap (~XXX GiB)
- Live files table vs Data volume usage reported by `df`.
- APFS snapshot ledger (`com.apple.TimeMachine.*`), creation timestamps, `Purgeable` flags, and pinning root cause.
- Time Machine destination accessibility and status.

## 3. Virtual Disks & VM Storage (Colima / Docker / Lima)
- Table: Filepath | Apparent Size | Actual Allocated Disk Space | Last Modified | State.
- Split-brain config diagnostics (e.g. orphaned `~/.colima` vs active `COLIMA_HOME`).

## 4. Regenerable Caches & Age Breakdown (>180d)
- Comprehensive table for every package manager store with absolute filepaths and reclaimable bytes.

## 5. Build Artifacts (`node_modules` and `.venv`)
- Full ledger of paths for each project under `~/code` with size and last commit date.

## 6. Git Repository Safety Inventory
- List A: Repositories with no remote (`file:///...`).
- List B: Repositories with unpushed commits (branch name, commit count).
- List C: Repositories with active stashes.

## 7. Crash Logs & Daemon Stability
- Stack trace, exception codes, and termination reasons for recurring crash loops (`~/Library/Logs/DiagnosticReports/*.ips`).

## 8. Toolchain, PATH Precedence & Homebrew Hygiene
- Version map of active vs installed binaries.
- Stale/invalid directories in `PATH`.
- Resolution of `mise` activation order and shadowed deprecated binaries.

## 9. Security & Network Posture
- SocketFilter Firewall state.
- Network service resolution order and obsolete dock/serial adapters.

## 10. Performance, Spotlight & Power Management
- Spotlight hit count on dev repositories.
- Power assertions blocking idle sleep, and High Power Mode status on AC power.

## 11. Prioritized Action Plan & Ready-to-Execute Remediation Scripts
- Formatted bash code blocks **ready for immediate execution** for every remediation action (e.g. `tmutil addexclusion -p`, `brew reinstall`, `uv cache prune`, fish config edits).
```

---

## 🎨 Output 2 Specification: Visual HTML Dashboard for Humans (`system-audit-YYYY-MM-DD.html`)

The visual HTML dashboard written to `~/Desktop/system-audit-YYYY-MM-DD.html` must follow these design and utility standards:

1. **Self-Contained:** Zero external network calls, zero CDN scripts or fonts, modern inline CSS in `<style>`, inline SVG icons.
2. **Theme Adaptive:** Native Light/Dark mode via `@media (prefers-color-scheme: dark)` and clean CSS custom properties.
3. **Accessible Color Palette (WCAG Compliant):**
   - 🔴 Critical / Blocker: `#e05252` (Dark) / `#c53030` (Light)
   - 🟠 Warning / Stability: `#dd6b20` (Dark) / `#c05621` (Light)
   - 🟡 Optimization / Hygiene: `#d69e2e` (Dark) / `#b7791f` (Light)
   - 🟢 Housekeeping / OK: `#38a169` (Dark) / `#2f855a` (Light)
   - Accent / Primary: `#3182ce`
4. **Responsive Layout Architecture:**
   - **Header:** Machine details, OS build, CPU/RAM, Timestamp, and prominent "Read-Only Audit" badge.
   - **KPI Stat Cards (Row 1):** Storage Used (with progress bar), Pinned Snapshots (GB), Reclaimable Caches (GB), Repos Needing Push (count), Crashing Daemons (count).
   - **Storage Breakdown Chart (Row 2):** CSS horizontal percentage bar chart with clear legend showing: *User Files*, *APFS Snapshots*, *Package Caches*, *VM Storage*, *Build Artifacts*, *Free Space*.
   - **Interactive Findings Accordion / Cards (Row 3):** Grouped by severity badge with concise human explanations and expandable tabs for recommended solutions.
   - **Interactive Action Checklist:** Checklist boxes allowing the human user to visually track decisions.

---

## 🚀 Execution Instructions for the Agent

When this prompt/skill is triggered:
1. Immediately run the read-only diagnostic checks across all **8 Phases**.
2. Perform the live vs volume delta calculation to quantify the APFS gap.
3. Simultaneously write both output artifacts:
   - `~/Desktop/system-audit-YYYY-MM-DD.md` (machine-oriented technical ledger).
   - `~/Desktop/system-audit-YYYY-MM-DD.html` (user-friendly visual dashboard).
4. Provide the user with direct markdown links to both generated files upon completion.
