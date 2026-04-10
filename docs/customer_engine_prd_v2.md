# Customer Engine PRD v2

## Vision

Customer Engine is an AI-powered customer intelligence and autonomous resolution platform that helps businesses resolve customer problems before they impact ratings, retention, and revenue.

The product combines:
- Review intelligence across Google, Yelp, Trustpilot, Amazon, and Shopify reviews
- Support resolution across Zendesk, Intercom, Shopify, email, and chat
- AI-guided and policy-safe autonomous actions for high-volume support teams

## Core Value Optimization

This version sharpens the business value around two connected engines:

1. **Review Intelligence Engine (reputation protection)**
   - Collect and normalize review signals from major review platforms
   - Detect sentiment and recurring issue categories by location, product, and channel
   - Trigger early alerts when rating or issue trends degrade
   - Generate on-brand review responses and escalation tasks

2. **AI Customer Support Resolution Engine (cost + speed)**
   - Ingest support requests from helpdesk/chat/email systems
   - Resolve common intents automatically (for example: order tracking, basic policy questions)
   - Route medium-confidence cases to agent assist
   - Escalate high-risk or low-confidence cases safely

Together, these engines create a shared intelligence loop: review issues improve support playbooks, and support outcomes improve review prevention.

## Problem Statement

Businesses face three gaps:
- **Fragmented feedback:** reviews and support signals are siloed
- **Reactive operations:** action starts after damage is visible
- **Low visibility:** teams cannot identify root causes, failing locations, or revenue impact quickly

## Product Goals

- Automate 60-80% of repetitive support resolutions
- Improve rating trend and response timeliness for public reviews
- Reduce cost per resolved issue
- Identify churn/revenue risk early and trigger intervention

## Target Segments

- **SMB:** local businesses, eCommerce stores, small SaaS teams
- **Mid-market:** multi-location operators, growing online brands
- **Enterprise:** large CX teams with strict compliance and governance requirements

## Product Modules

1. **Unified Signal Engine**
   - Aggregates review, support, and account context into a tenant-scoped feed
2. **AI Sentiment and Issue Detection**
   - Classifies sentiment, issue type, urgency, and trend deltas
3. **Review Intelligence**
   - Auto-tagging, location trend tracking, and suggested/automated review responses
4. **Resolution Orchestrator**
   - Chooses `auto_resolve`, `agent_assist`, or `escalate` path based on confidence and policy
5. **Tool Execution Layer**
   - Executes verified actions via connectors with policy gates and audit trail
6. **AI Response Engine**
   - Generates multilingual, brand-consistent responses with citations/context
7. **Alerts and Notifications**
   - Pushes issue spikes, rating drop alerts, and unresolved-risk alerts
8. **CX Intelligence Dashboard**
   - Shows issue trends, automation rate, reopen rate, and estimated revenue impact

## Automation Safety Levels

- **L0:** Analytics only
- **L1:** Draft only (human approval required)
- **L2:** Auto-response for low-risk intents
- **L3:** Low-risk tool actions
- **L4:** Financial/sensitive actions with stricter policy gates
- **L5:** Controlled autonomy for approved playbooks with post-action QA

## Platform Architecture (Aligned to Current Repo)

The existing Rails + Sidekiq + Redis + Vue architecture remains the execution backbone.

- Rails models and services hold core decision and audit entities
- Sidekiq handles asynchronous ingestion, enrichment, and orchestration jobs
- Existing conversation/account/inbox data model remains the anchor for support events
- New review and AI decision entities stay account-scoped for tenancy and reporting
- Enterprise overlay under `enterprise/` extends policies and controls without forking OSS logic

## Initial Data Model (Phase 1)

- `ai_review_signals`
  - Review source payloads + sentiment/issue extraction output
- `ai_triage_decisions`
  - Confidence-scored triage decisions for review/support events
- `ai_resolution_attempts`
  - Resolution execution attempts, outcomes, and policy state

These entities are linked to `account` and optional `conversation` to keep compatibility with existing workflows.

## KPI Tree

- **Automation:** auto-resolution rate, auto-response rate
- **Quality:** reopen rate, false-action rate, agent override rate
- **Experience:** response SLA, CSAT trend, review rating trend
- **Business:** retained revenue estimate, churn risk mitigated, cost per resolution

## Phased Rollout

### Phase 1: Foundation (0-90 days)
- Unified signal ingestion baseline
- AI sentiment/issue extraction
- Triage + routing for low-risk support intents
- Review alerting and suggested responses

### Phase 2: Controlled Automation (3-6 months)
- Resolution orchestrator with policy gates
- Expanded connectors and tool actions
- Confidence-aware fallback to agent assist

### Phase 3: Enterprise Control Plane (6-12 months)
- Governance controls (approval chains, audit views)
- Advanced roles and policy packs
- Multi-region and compliance enhancements

**Current repo:** OSS includes single-step approve/reject for `requires_approval` attempts (with reviewer id, timestamps, and notes on `ai_resolution_attempts`), inbox audit timeline + suggested draft insert, and Enterprise `prepend_mod_with` stubs for extending approval policy. Multi-step chains and granular roles remain future work.

### Phase 4: Autonomous Optimization (12+ months)
- Multi-step autonomous resolution playbooks
- Predictive prevention and proactive customer recovery
- Verticalized templates for priority industries

## Implemented API (current baseline)

Account-scoped JSON endpoints (auth: same as other `api/v1/accounts` routes). Ingest and account-level Customer Engine settings typically require administrator privileges; conversation context uses normal conversation `show?` authorization.

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/accounts/:account_id/ai_resolution/ingest_review` | Body: `source_platform`, `source_payload` (include `text` for analysis), optional `source_message_id`, `occurred_at`. Enqueues analysis + triage. |
| POST | `/api/v1/accounts/:account_id/ai_resolution/ingest_support` | Params: `conversation_id` (required). Builds signal from last inbound message text; optional `source_platform` (otherwise inferred from inbox: email → `email`, API → `api`, else Chatwoot). Enqueues pipeline. |
| GET | `/api/v1/accounts/:account_id/ai_resolution/metrics` | Counts of signals, triage decisions, and resolution attempts by status. |
| GET | `/api/v1/accounts/:account_id/ai_resolution/review_signals` | Recent signals (optional `limit`, max 200). |
| GET / PATCH | `/api/v1/accounts/:account_id/customer_engine/settings` | Tenant policy, Slack/email alerts, OpenAI overrides (see `CustomerEngine::SettingsController`). |
| GET / POST / DELETE | `/api/v1/accounts/:account_id/customer_engine/connectors` | List, create, update, or remove connectors; `POST …/connectors/:id/sync` runs ingestion for that connector. |
| GET | `/api/v1/accounts/:account_id/customer_engine/resolution_attempts` | Paginated recent resolution attempts (admin-facing diagnostics). |
| GET | `/api/v1/accounts/:account_id/customer_engine/conversations/:conversation_id/context` | JSON: `timeline`, `latest_draft` (from `actions_executed.draft_reply`), `pending_approval` if an attempt is `requires_approval`. Powers inbox sidebar. |
| POST | `/api/v1/accounts/:account_id/customer_engine/resolution_attempts/:id/approve` | Optional JSON `note`. Sets attempt to succeeded; records `approval_reviewed_by`, `approval_reviewed_at`, `approval_note`. Requires account admin (`Account` `update?`). |
| POST | `/api/v1/accounts/:account_id/customer_engine/resolution_attempts/:id/reject` | JSON `reason` (required). Marks attempt failed; records reviewer and timestamps. Requires account admin. |
| POST | `/api/v1/accounts/:account_id/customer_engine/alerts/test` | Sends test Slack/email alert. |

**Connectors (`customer_engine_connectors`):** `zendesk`, `yelp_fusion`, `google_business`, `trustpilot`, `intercom`, `shopify`, `amazon_selling_partner`. Shopify sync ingests **product catalog text** as review-style signals (`kind: product_catalog` in payload), not third-party star reviews. Amazon is **stub-only** until Selling Partner review ingestion is implemented (`stub_mode` must be `true` in settings).

**Settings:** Policy fields (automation level, confidence thresholds, live reply flags, auto-ingest) are persisted via Customer Engine settings API; see controller strong params for the exact shape.

**Background job:** `AiResolution::ProcessSignalJob` runs heuristic analysis, triage, and attempt completion. Connector and channel actions are reflected in `actions_executed` and attempt status (including `requires_approval`).

**Enterprise:** API controllers and `AiResolution::ApprovalDecisionService` use `prepend_mod_with` so Enterprise can add governance (e.g. multi-step approval) without forking OSS behavior.

**Database:** Run `bundle exec rails db:migrate` (includes `ai_resolution_attempts` approval columns and `customer_engine` tables).

