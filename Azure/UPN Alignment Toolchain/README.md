# UPN Alignment Toolchain

> **Azure Hybrid Automation Suite for Identity Alignment in AD/Entra Hybrid Environments**

![Azure](https://img.shields.io/badge/Azure-Logic_Apps-0078D4?logo=microsoftazure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-7.x-5391FE?logo=powershell&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-18-339933?logo=nodedotjs&logoColor=white)
![Azure Functions](https://img.shields.io/badge/Azure_Functions-Managed-FFCD00?logo=azurefunctions&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Problem Statement

Organizations with hybrid Active Directory / Entra ID (Azure AD) environments commonly develop a mismatch between User Principal Names (UPNs) and primary SMTP (email) addresses over time. This causes:

- **SSO authentication failures** in SAML applications using `user.userprincipalname` as NameID
- **Recurring helpdesk tickets** for sign-in problems
- **Vendor escalations** for broken identity federation
- **Compliance risk** from inconsistent identity assertions

This toolchain provides a **fully automated, auditable, batch-capable pipeline** to align UPNs to primary SMTP addresses in hybrid AD/Entra environments, with a web-based control center for execution and monitoring.

This is not my preferred architecture, I would instead pick full standardization if I were making the executive level decisions. I would standardize UPN / SMTP/ and sAMA values to match `firstname.lastname` in my ideal environment.

Given the constraints of the project at the company I built this tool for, this was the direction we were instructed to follow. I built this tool to make this task as simple as possible, since I didn't want to spend much effort manually on a task that does not align with industry preferred identity standardization best practices.

This repo exists to showcase something neat I built at work, additionally the idea behind the tool is useful broadly across many projects, e.g. building a full toolchain in Azure and surfacing a static web app to control it all from. I do not expect anybody to just copy this entire repo and recreate it 1:1 in their environment. I would also generally recommend if you do intend to do that, run it through an AI tool for help patching it into your environment e.g., Claude Code, Gemini CLI, OpenAI Codex, Grok Build, et al.

A lot of personally identifying information has been stripped out of every one of these files making it impossible to simply download these files and plug-and-play without much configuration on your end. This repo is not production ready as-is, buyer beware, etc. etc.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 4 — Static Web App (Control Center)                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Dashboard │ User Browser │ Batch Builder │ Audit │ SSO Apps  │  │
│  │                                                               │  │
│  │  Azure Functions API (Node 18)                                │  │
│  │  ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌───────────────────┐   │  │
│  │  │get-*    │ │update-sso│ │get-roles│ │trigger-batch      │   │  │
│  │  │(read)   │ │(write)   │ │(RBAC)   │ │(proxy→Logic App)  │   │  │
│  │  └────┬────┘ └────┬─────┘ └─────────┘ └────────┬──────────┘   │  │
│  └───────┼───────────┼────────────────────────────┼──────────────┘  │
│          │           │                            │                 │
├──────────┼───────────┼────────────────────────────┼─────────────────┤
│  Layer 3 │— Table Storage                         │                 │
│  ┌───────▼───────────▼──────┐                     │                 │
│  │  MigrationTargets        │                     │                 │
│  │  BatchHistory            │                     │                 │
│  │  AuditLog                │                     │                 │
│  │  SSOAppStatus            │                     │                 │
│  └───────▲──────────────────┘                     │                 │
│          │                                        │                 │
├──────────┼────────────────────────────────────────┼─────────────────┤
│  Layer 2 │— Logic App (Orchestrator)              │                 │
│  ┌───────┴────────────────────────────────────────▼──────────────┐  │
│  │  HTTP Trigger → Gate Checks → Start Runbook → Poll → Parse    │  │
│  │  → Write Tables → Return Results                              │  │
│  │                                                               │  │
│  │  System-assigned Managed Identity                             │  │
│  │  → Automation Operator / Job Operator (on Automation Account) │  │
│  │  → Storage Table Data Contributor (on Storage Account)        │  │
│  └───────────────────────────────────────────┬───────────────────┘  │
│                                              │                      │
├──────────────────────────────────────────────┼──────────────────────┤
│  Layer 1 — Hybrid Runbook (Engine)           │                      │
│  ┌───────────────────────────────────────────▼───────────────────┐  │
│  │  Invoke-UPNAlignment.ps1                                      │  │
│  │  Runs on: Hybrid Runbook Worker (Entra Connect server)        │  |  
│  │                                                               │  │
│  │  Pipeline: Parse → Fetch AD → Snapshot → Scope Validate →     │  │
│  │  Resolve Target → Conflict Check → Apply (or DryRun) →        │  │
│  │  Delta Sync → JSON Output                                     │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Component | Technology | Purpose |
|---|---|---|
| **Runbook** | PowerShell 7.x, Azure Automation | AD attribute changes, delta sync trigger |
| **Orchestrator** | Azure Logic Apps (Consumption) | Gate checks, job management, table writes, response composition |
| **Data Store** | Azure Table Storage | Migration targets, batch history, audit log, SSO app status |
| **Frontend** | Vanilla HTML/CSS/JS | Dark-theme dashboard, no build step, no framework dependencies |
| **API** | Azure Functions (Node 18, managed) | Table Storage queries, Logic App proxy, role resolution |
| **Auth** | Entra ID (Azure AD) | SSO, app roles, security group-based RBAC |
| **Infrastructure** | Azure Static Web Apps (Standard) | Hosting, CDN, built-in auth, managed Functions |

---

## Layer Breakdown

### Layer 1 — Hybrid Runbook (`Invoke-UPNAlignment.ps1`)

A PowerShell runbook that executes on an on-premises Hybrid Runbook Worker (co-located with the Entra Connect server). For each user in the batch, it:

1. **Fetches** the AD user object
2. **Snapshots** current state (UPN, proxy addresses, extension attributes)
3. **Validates scope** against a 6-stage filter pipeline (OU, enabled, identity tag, primary SMTP, etc.)
4. **Resolves target** UPN from primary SMTP address
5. **Checks conflicts** — ensures no other user owns the target UPN
6. **Applies changes** (or reports what would change in DryRun mode):
   - Sets UPN to match primary SMTP
   - Adds old UPN as `smtp:` proxy alias (preserves mail flow)
   - Stamps `extensionAttribute14` with migration breadcrumb
7. **Triggers delta sync** to propagate changes to Entra ID
8. **Outputs structured JSON** between delimited markers for upstream parsing

### Layer 2 — Logic App Orchestrator

A Consumption-tier Logic App with system-assigned managed identity that:

- Receives HTTP POST trigger from the Static Web App
- **Gate checks**: batch size ≤ 25, no concurrent runbook jobs
- Writes `BatchHistory` record (status: running)
- Starts the runbook via Automation REST API
- Polls every 15s until job completes (max 30 min)
- Extracts JSON from job output using `###BATCH_RESULT_JSON###` delimiters
- Parses result, upserts `MigrationTargets`, inserts `AuditLog` entries
- Updates `BatchHistory` with final status
- Returns full result JSON to caller

### Layer 3 — Table Storage

Four tables in a single Storage Account:

| Table | Partition Key | Purpose |
|---|---|---|
| `MigrationTargets` | `user` | Current state of every migration target (SAM, old/new UPN, status) |
| `BatchHistory` | `batch` | Every batch submission with status, counts, timing |
| `AuditLog` | `yyyy-MM-dd` | Per-user action log, partitioned by date for efficient queries |
| `SSOAppStatus` | `app` | HIGH-risk SSO app vendor readiness tracking |

> `Seed-MigrationTargets.ps1` is used to gather AD users into the `MigrationTargets` table

### Layer 4 — Static Web App (Control Center)

5 pages, vanilla HTML/CSS/JS, dark theme inspired by Azure Portal:

| Page | Purpose |
|---|---|
| **Dashboard** | Progress bar, stat cards, recent batch history |
| **User Browser** | Searchable/filterable table of all migration targets |
| **Batch Builder** | Select users, toggle dry run, submit, view per-user results |
| **Audit Log** | Date-filtered, searchable action history |
| **SSO App Tracker** | Toggle-based vendor readiness tracking for HIGH-risk apps |

7 Azure Functions (Node 18):
- `get-targets`, `get-batches`, `get-audit`, `get-sso` — Table Storage reads
- `update-sso` — Table Storage write (admin only)
- `trigger-batch` — Logic App proxy (admin only, keeps trigger URL server-side)
- `get-roles` — Maps Entra app role claims to SWA roles

---

## Security Model

- **Zero secrets in browser** — Logic App trigger URL stored as SWA app setting, proxied through Functions API
- **Managed Identity** — Logic App authenticates to Automation API and Table Storage via system-assigned MI (no API keys)
- **Entra ID SSO** — All users authenticate via organizational account
- **App Roles + Security Groups** — `admin` and `viewer` roles defined in app registration, mapped to Entra security groups, resolved via `rolesSource` function
- **Route-level RBAC** — Write endpoints (`trigger-batch`, `update-sso`) restricted to `admin` role in `staticwebapp.config.json`

---

## Deployment (High-Level)

### Prerequisites

- Azure subscription with:
  - Existing Automation Account + Hybrid Runbook Worker (on Entra Connect server)
  - Permissions to create resource groups, storage accounts, Logic Apps, Static Web Apps
- Entra ID permissions to create app registrations and security groups
- Node.js 18+ (for local development)
- Azure CLI

### Steps

1. **Layer 1**: Publish `Invoke-UPNAlignment.ps1` to your Automation Account
2. **Layer 2+3**: Run `Deploy-UPNToolchain.sh` — creates resource group, storage account, tables, Logic App, RBAC assignments
3. **Layer 4**: Run `Deploy-SWA.sh` — creates Static Web App, sets app settings, seeds SSO data, deploys frontend + API
4. **Auth**: Create Entra app registration, define app roles, assign security groups
5. **Pre-seed**: Run `Seed-MigrationTargets.ps1`, surfaces target OU users from AD into Azure storage account
6. **Test**: Submit a dry-run batch through the UI

---

## Lessons Learned / Gotchas

These were discovered during live deployment and testing:

| Issue | Root Cause | Fix |
|---|---|---|
| **OData filter 400 on job status query** | Automation REST API wraps properties under `properties` object | Filter path: `properties/status` not `status` |
| **Logic App HTTP action doesn't support MERGE** | Platform limitation | Use `PATCH` instead — semantically identical for Table Storage |
| **Table Storage returning Atom XML** | Missing `Accept` header | Add `Accept: application/json;odata=nometadata` to all Table Storage requests |
| **PUT to Table Storage 404 on new entities** | `If-Match: *` forces strict Update mode | Remove `If-Match` for InsertOrReplace (upsert) behavior |
| **`@azure/data-tables` crashes with "crypto is not defined"** | SWA managed functions Node 18 runtime missing Web Crypto API | Polyfill: `if (!globalThis.crypto) globalThis.crypto = require("crypto").webcrypto;` |
| **SWA Free tier doesn't support group-based role mapping** | SKU limitation | Upgrade to Standard ($9/mo) or use per-user invitation links |
| **Entra app roles not appearing in SWA `userRoles`** | SWA doesn't auto-map Entra role claims | Implement `rolesSource` function to extract roles from token claims |
| **Azure Automation test pane strips JSON array brackets** | Test pane input field quirk | Add fallback parser: split on comma if input doesn't start with `[` |
| **`string()` strips inner quotes from JSON arrays** | Logic App expression behavior | Use `join(array, ',')` to produce bare CSV for runbook's fallback parser |

---

## Cost

| Resource | SKU | Monthly Cost |
|---|---|---|
| Static Web App | Standard | ~$9 |
| Table Storage | Pay-per-use | ~$0.10 (minimal rows) |
| Logic App | Consumption | ~$0.50 (per-run pricing) |
| Automation Account | Existing | $0 (already provisioned) |
| **Total** | | **~$10/month** |

---

## Screenshots

<img width="1355" height="298" alt="image" src="https://github.com/user-attachments/assets/56390e3a-e254-4daf-94bf-b49b7fc946ca" />

<img width="1342" height="244" alt="image" src="https://github.com/user-attachments/assets/99a22572-18cb-4685-b3e2-408d94f5ba84" />

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

Built as an internal tooling project. The architecture pattern (Hybrid Runbook → Logic App → Table Storage → Static Web App) is generalizable to any hybrid AD/Entra automation workflow that needs a web-based control plane.
