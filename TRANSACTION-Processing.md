## **Objective**

Replace the current “static success” UI with a real, stateful **transaction process**:

* Frontend sends **PACS XML** (with required header) to `payment-process-java-service`.  
* Service validates header \+ XML, checks balance, emits **IN\_PROGRESS** with a **txnRef**.  
* Frontend polls status every 1s using `txnRef` until **SUCCESS** or **FAILED**.  
* `payment-process-java-service` transforms XML → JSON and calls `CoreBanking-Java-Service`.  
* CoreBanking persists, assigns a **cbsId**, simulates 1.5s processing, returns **APPROVED** (or error).  
* Payment service records approval time \+ cbsId in Redis, flips state to **SUCCESS** and returns to UI.  
* If balance is low, immediately **FAILED** with reason.

## **Services**

1. **payment-process-java-service** (Java):  
* Purpose: external API for payments; validate header, parse PACS XML body, check balance, manage transaction state, call CoreBanking, expose status polling.  
* Storage: **Redis** (primary state store \+ balance cache).  
* Responsibilities:  
  * Validate request header (source, signature/token, content-type).  
  * Validate and parse PACS XML payload.  
  * Run business validations (mandatory fields, amount \> 0, IFSC length/pattern, account type SAVINGS/CURRENT, etc.).  
  * **Balance check** (from Redis-backed account snapshot; fail fast if insufficient).  
  * Create **txnRef** (UUID), write **TxnState=IN\_PROGRESS** to Redis with all captured data \+ timestamps.  
  * Convert PACS XML → canonical JSON.  
  * Call CoreBanking async/sync (HTTP) with JSON \+ correlation headers.  
  * On CoreBanking **APPROVED**, set **TxnState=SUCCESS**, store `approvedAt` \+ `cbsId`.  
  * On CoreBanking error/timeout, set **TxnState=FAILED** with reason.  
  * Expose **idempotent** create endpoint (Idempotency-Key support) and a **GET /status/{txnRef}** for polling.  
  * TTL policy for completed txns (e.g., 24–48h) in Redis.  
2. **CoreBanking-Java-Service** (Java):  
* Purpose: validate canonical JSON, assign **cbsId**, persist, and respond to payment service.  
* Storage: **Postgres** (authoritative record of core ops).  
* Responsibilities:  
  * Validate inbound JSON (schema \+ business rules).  
  * Generate **cbsId** (UUID), persist the request \+ correlation to `txnRef`.  
  * Simulate **1.5s** processing delay (async or timed) to emulate core posting.  
  * Return **APPROVED** (or **REJECTED**) with `cbsId` and mapped `txnRef`.  
  * Maintain account ledger table snapshot for reporting (optional now, but create schema hooks).

## **Inbound Message (from Frontend → payment-process-java-service)**

* Transport: HTTP `POST /payments/transfer`  
* **Headers (validate in a header module):**  
  * `X-Api-Client: web-portal`  
  * `X-Request-Id: <uuid>` (generate if missing, echo everywhere)  
  * `Content-Type: application/xml`  
  * `X-Signature` or `Authorization` (placeholder; just validate presence \+ simple rule)  
* **Body:** PACS XML envelope (ISO-20022-like). Include:  
  * Payee Name  
  * IFSC Code  
  * Payment Type (NEFT | IMPS | UPI)  
  * DateTime of initiation (UTC ISO8601)  
  * Customer Name  
  * From Account No  
  * To Account No  
  * Branch Name  
  * Amount (decimal)  
  * Comments

## **Canonical JSON (payment-process → CoreBanking)**

* Derived from the XML (1:1 fields). Include:  
  * `txnRef` (from payment service)  
  * `paymentType`, `amount`, `currency: "INR"`  
  * `payer` { name, accountNo, accountType }  
  * `payee` { name, accountNo or vpa, ifsc }  
  * `meta` { branchName, initiatedAt, comments }  
  * `headers` echo { xRequestId, xApiClient }  
* Transport: HTTP `POST /core/payments`  
* Response JSON:  
  * On success: `{ status: "APPROVED", cbsId, txnRef, approvedAt }`  
  * On reject: `{ status: "REJECTED", reason, txnRef }`

## **API Contract (external \+ internal)**

**payment-process-java-service**

* `POST /payments/transfer`  
  * Validates headers \+ XML.  
  * On OK \+ sufficient balance: creates `txnRef`, writes Redis state, returns:  
    * `202 Accepted` `{ txnRef, status: "IN_PROGRESS" }`  
  * On insufficient balance: `402 Payment Required` or `409 Conflict` `{ txnRef, status: "FAILED", reason: "INSUFFICIENT_BALANCE" }`  
  * On validation error: `400` with reason.  
* `GET /payments/status/{txnRef}`  
  * Returns `{ txnRef, status: "IN_PROGRESS"|"SUCCESS"|"FAILED", cbsId?, approvedAt?, reason? }`  
  * Frontend polls every 1s until terminal state.

**CoreBanking-Java-Service**

* `POST /core/payments`  
  * Validates JSON, persists request, assigns `cbsId`, waits \~1.5s, returns `APPROVED` (happy path) referencing original `txnRef`.  
* (Optional) `GET /core/payments/{cbsId}` for ops/debug.

## **State Machine (payment-process-java-service)**

* **RECEIVED** → (header \+ XML valid?) else **FAILED/VALIDATION\_ERROR**  
* **VALIDATED** → (balance sufficient?) else **FAILED/INSUFFICIENT\_BALANCE**  
* **IN\_PROGRESS** (after enqueue \+ call CoreBanking)  
* **SUCCESS** (on CoreBanking APPROVED; store `cbsId`, `approvedAt`)  
* **FAILED** (on CoreBanking reject/timeout or business error)  
* All transitions recorded with timestamps in Redis.

## **Redis Design (payment service)**

* Keys (prefix with env/app):  
  * `txn:{txnRef}` → Hash:  
    * `status` (RECEIVED|VALIDATED|IN\_PROGRESS|SUCCESS|FAILED)  
    * `payloadXml` (optional short-term), `payloadJson` (optional), `paymentType`, `amount`, `payerAccount`, `payeeAccount`, `ifsc`, `comments`  
    * `createdAt`, `validatedAt`, `inProgressAt`, `approvedAt`  
    * `cbsId`, `failureReason`  
  * `bal:{accountNo}` → String (decimal balance) for quick balance check (seeded/updated via ops or callback)  
* TTL:  
  * `txn:{txnRef}` expire after 48h (configurable).  
* Concurrency:  
  * Use Redis `SETNX` on `lock:txn:{idempotencyKey}` to enforce **idempotency** for create.  
* Pub/Sub (optional):  
  * `payments.events` to notify status changes (future use; not required for polling).

## **Postgres Design (CoreBanking)**

* Tables:  
  * `core_payments(id SERIAL, cbs_id UUID, txn_ref UUID, status TEXT, amount NUMERIC, payer_account TEXT, payee_account TEXT, ifsc TEXT, payment_type TEXT, initiated_at TIMESTAMPTZ, approved_at TIMESTAMPTZ, comments TEXT, raw_json JSONB, created_at TIMESTAMPTZ DEFAULT now())`  
  * `accounts(id SERIAL, account_no TEXT PK, account_type TEXT, balance NUMERIC, currency TEXT, updated_at TIMESTAMPTZ)` (for reporting; source of truth can be elsewhere; we just persist)  
* Index txn\_ref, cbs\_id.  
* Ensure mapping **txnRef ↔ cbsId** is unique, persisted.

## **Validations**

* **Header module** (payment service): enforce `X-Api-Client`, `Content-Type`, `X-Request-Id`, and minimal auth (token/sig placeholder).  
* **XML body**: schema validation (well-formed), required fields present, IFSC regex, amount \> 0, account numbers non-empty, paymentType in {NEFT,IMPS,UPI}.  
* **Balance**: use Redis `bal:{accountNo}`; if `< amount`, reject **FAILED/INSUFFICIENT\_BALANCE**immediately.  
* **Idempotency**: support `Idempotency-Key` header; same key \+ same payload returns same `txnRef` \+ last status.  
* **Size limits**: reject oversized XML; limit comments length.

## **Orchestration & Timing**

* On valid \+ sufficient balance:  
  * Write `txn:{txnRef}` with `IN_PROGRESS`, timestamps.  
  * Transform XML → canonical JSON.  
  * POST to CoreBanking with headers: `X-Request-Id`, `X-Origin-Service: payment-process`, `X-Txn-Ref`.  
  * Await response (timeout e.g. 5s). If timeout, set **FAILED/TIMEOUT**.  
* CoreBanking path:  
  * Validate JSON → persist → assign `cbsId` → sleep \~1500 ms → return `{ APPROVED, cbsId, txnRef, approvedAt }`.  
* On APPROVED:  
  * Payment service updates Redis state to **SUCCESS**, stores `cbsId`, `approvedAt`.  
  * `GET /payments/status/{txnRef}` will now show **SUCCESS**; frontend stops polling and shows success.  
* On REJECT or error:  
  * Set **FAILED** with `reason` → frontend shows failed.

## **Polling Behavior (Frontend hint)**

* After `202 Accepted` with `{ txnRef, status: IN_PROGRESS }`, call `GET /payments/status/{txnRef}` every 1s.  
* Stop on terminal states **SUCCESS** or **FAILED**.  
* Show transaction reference throughout.

## **Security & Reliability**

* All endpoints behind HTTPS (assume reverse proxy/ingress in deployment).  
* Propagate `X-Request-Id` end-to-end for traceability.  
* Basic JWT or shared secret for payment→CoreBanking call (Copilot: stub a simple shared token verification).  
* Timeouts & retries:  
  * Payment→CoreBanking: 5s timeout, 1 retry (idempotent on CoreBanking; use `txnRef` to avoid dup posting).  
* Input sanitization; log safe fields only (no PII leakage).  
* Rate limiting at payment service (basic sliding window; Copilot can stub).

## **Observability Hooks (placeholders)**

* Emit logs with `level`, `xRequestId`, `txnRef`, `status`, `latencyMs`.  
* Add counters: `payments_created_total`, `payments_success_total`, `payments_failed_total`.  
* Add histograms: `payment_end_to_end_latency_seconds`.  
* Include trace headers (`traceparent`) passthrough.

## **Why move away from “static success” to this design**

* **Realism & integrity**: Simulates true banking flows: header/body validation, balance checks, async core posting.  
* **User feedback**: IN\_PROGRESS → SUCCESS/FAILED mirrors actual experience, not instant/fictional success.  
* **Traceability**: Each transaction has a `txnRef`, lifecycle timestamps, and a `cbsId` for audit.  
* **Extensibility**: Can plug in real core later by swapping CoreBanking service without changing the frontend.  
* **Resilience**: Timeouts, retries, and explicit failure states prevent silent errors and improve debuggability.

## **Acceptance Criteria**

* Creating a payment with valid data \+ sufficient balance returns `202` with `{ txnRef, IN_PROGRESS }` within 300ms.  
* Polling returns **SUCCESS** with `cbsId` within \~2s (1.5s core delay \+ overhead).  
* Insufficient balance returns **FAILED** immediately with reason.  
* Redis contains complete transaction record with timestamps and final state for at least 24h.  
* CoreBanking persists JSON request, `cbsId`, `txnRef`, and status in Postgres.  
* Idempotent create: same `Idempotency-Key` \+ payload → same `txnRef`, no dup CoreBanking rows.  
* End-to-end logs carry `X-Request-Id` and `txnRef`.

