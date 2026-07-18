---
name: db-cleanup
description: Shrink opencode disk usage by deleting old sessions, removing orphaned file blobs and stale project snapshots, vacuuming the SQLite DB, and clearing old logs. Use when the user says "cleanup", "shrink db", "free space", "opencode db is big", or wants to reduce opencode storage size.
---

# Opencode DB Cleanup

Shrink opencode's disk footprint by removing old sessions and reclaiming orphaned storage.

## Overview

opencode stores data in `~/.local/share/opencode/`:
- `opencode.db` — SQLite database (sessions, messages, parts, events)
- `storage/message/<session_id>/` — message JSON files per session
- `storage/part/<session_id>/` — message part JSON files per session
- `storage/session_diff/<session_id>.json` — session diff snapshots
- `snapshot/<project_hash>/` — git snapshot repos per project
- `log/` — rotating log files

`opencode session delete` removes DB rows but does NOT always clean up file blobs in `storage/`. This skill performs a thorough cleanup.

## Workflow

### Step 1 — Assess current size

```bash
echo "=== TOTAL ==="
du -sh ~/.local/share/opencode/
echo "=== BREAKDOWN ==="
du -sh ~/.local/share/opencode/*/ 2>/dev/null | sort -rh
du -sh ~/.local/share/opencode/storage/*/ 2>/dev/null | sort -rh
ls -lh ~/.local/share/opencode/opencode.db
echo "=== SESSION COUNT ==="
opencode db "SELECT COUNT(*) FROM session"
```

Report the findings to the user with a table.

### Step 2 — Ask the user for a retention policy

Present options:
1. Delete everything older than N days (common: 30, 60, 90)
2. Delete specific sessions
3. Keep only recent sessions

Wait for the user's choice. **Never delete without explicit confirmation.**

### Step 3 — Delete old sessions

Calculate the cutoff timestamp in milliseconds:
```bash
python3 -c "import time; print(int((time.time() - DAYS * 86400) * 1000))"
```
Replace `DAYS` with the agreed number.

Get sessions to delete:
```bash
opencode db "SELECT id FROM session WHERE time_updated < CUTOFF_MS" 
```

Delete each one:
```bash
opencode session delete <session_id>
```

For large batches, loop through the list. Show progress every 50 deletions.

### Step 4 — Remove orphaned file blobs

After session deletion, orphaned files remain in `storage/`. Run this Python script to find and remove them:

```python
import os, shutil, subprocess

# Get valid session IDs from DB
result = subprocess.run(['opencode', 'db', 'SELECT id FROM session'], capture_output=True, text=True)
valid_sessions = set(line.strip() for line in result.stdout.strip().split('\n')[1:] if line.strip())

# Get valid project IDs from DB
result = subprocess.run(['opencode', 'db', 'SELECT DISTINCT project_id FROM session'], capture_output=True, text=True)
valid_projects = set(line.strip() for line in result.stdout.strip().split('\n')[1:] if line.strip())

data_dir = os.path.expanduser('~/.local/share/opencode')

# --- Report orphaned sizes first ---
def dir_size(path):
    total = 0
    for root, dirs, files in os.walk(path):
        for fn in files:
            try: total += os.path.getsize(os.path.join(root, fn))
            except: pass
    return total

print("=== Orphaned storage ===")
for subdir in ['message', 'part']:
    base = os.path.join(data_dir, 'storage', subdir)
    if not os.path.isdir(base): continue
    total, count = 0, 0
    for d in os.listdir(base):
        if d not in valid_sessions:
            path = os.path.join(base, d)
            if os.path.isdir(path):
                total += dir_size(path)
                count += 1
    print(f'  {subdir}: {count} orphaned dirs, {total/1024/1024:.1f} MB')

# session_diff files (keyed by session_id.json)
sd = os.path.join(data_dir, 'storage', 'session_diff')
if os.path.isdir(sd):
    total, count = 0, 0
    for f in os.listdir(sd):
        if f.endswith('.json'):
            sid = f[:-5]
            if sid not in valid_sessions:
                fp = os.path.join(sd, f)
                try: total += os.path.getsize(fp); count += 1
                except: pass
    print(f'  session_diff: {count} orphaned files, {total/1024/1024:.1f} MB')

# Stale snapshots (project hash dirs with no active sessions)
snap = os.path.join(data_dir, 'snapshot')
if os.path.isdir(snap):
    total, count = 0, 0
    for d in os.listdir(snap):
        if d not in valid_projects:
            path = os.path.join(snap, d)
            if os.path.isdir(path):
                total += dir_size(path)
                count += 1
    print(f'  snapshot: {count} stale dirs, {total/1024/1024:.1f} MB')
```

**Show the report to the user and get confirmation before removing.**

Then remove (same script but with deletion):

```python
import os, shutil, subprocess

result = subprocess.run(['opencode', 'db', 'SELECT id FROM session'], capture_output=True, text=True)
valid_sessions = set(line.strip() for line in result.stdout.strip().split('\n')[1:] if line.strip())

result = subprocess.run(['opencode', 'db', 'SELECT DISTINCT project_id FROM session'], capture_output=True, text=True)
valid_projects = set(line.strip() for line in result.stdout.strip().split('\n')[1:] if line.strip())

data_dir = os.path.expanduser('~/.local/share/opencode')

# Remove orphaned message and part dirs
for subdir in ['message', 'part']:
    base = os.path.join(data_dir, 'storage', subdir)
    if not os.path.isdir(base): continue
    count = 0
    for d in os.listdir(base):
        if d not in valid_sessions:
            path = os.path.join(base, d)
            if os.path.isdir(path):
                shutil.rmtree(path)
                count += 1
    print(f'{subdir}: removed {count} orphaned dirs')

# Remove orphaned session_diff files
sd = os.path.join(data_dir, 'storage', 'session_diff')
if os.path.isdir(sd):
    count = 0
    for f in os.listdir(sd):
        if f.endswith('.json'):
            sid = f[:-5]
            if sid not in valid_sessions:
                os.remove(os.path.join(sd, f))
                count += 1
    print(f'session_diff: removed {count} orphaned files')

# Remove stale snapshot dirs
snap = os.path.join(data_dir, 'snapshot')
if os.path.isdir(snap):
    count = 0
    for d in os.listdir(snap):
        if d not in valid_projects:
            path = os.path.join(snap, d)
            if os.path.isdir(path):
                shutil.rmtree(path)
                count += 1
    print(f'snapshot: removed {count} stale dirs')
```

### Step 5 — Vacuum the SQLite DB

After all deletions, reclaim free pages in the database:

```bash
opencode db "VACUUM"
```

### Step 6 — Clear old logs (optional)

```bash
# Remove log files older than 30 days
find ~/.local/share/opencode/log/ -name "*.log" -mtime +30 -delete
```

### Step 7 — Report results

Show a before/after comparison table:

```
| Area       | Before  | After   | Saved   |
|------------|---------|---------|---------|
| Total      | X.X GB  | X.X GB  | X.X GB  |
| opencode.db| X MB    | X MB    | X MB    |
| storage/   | X MB    | X MB    | X MB    |
| snapshot/  | X MB    | X MB    | X MB    |
```

## Notes

- Always get user confirmation before deleting anything.
- The `opencode session delete` command is safe — it only removes the specified session's DB rows.
- Orphaned blob cleanup is safe — it only removes files for sessions that no longer exist in the DB.
- Stale snapshot cleanup is safe — it only removes project snapshot dirs for projects with no active sessions.
- `VACUUM` requires temporary disk space equal to the DB size; ensure enough free space.
- The user's current (active) session is never deleted because it won't match the age filter.

