# Portable Operator Runtime Spec v0.1

Status: Draft for confirmation  
Date: 2026-05-31  
Project: Operator  
Source basis: Speedy Operator AI Architecture preservation report plus 2026-05-31 runtime refinement direction

## 1. Purpose

This document reframes the Operator project as a portable runtime that can host AI capabilities, endpoint adapters, deterministic policies, simulation tools, audit/replay, and future hardware integrations.

The controlling direction is:

> The system should become more capable when better hardware exists, but never become incoherent when hardware is weak, missing, offline, degraded, or simulated.

The Operator System is not "an LLM attached to phones." It is a runtime environment with pluggable AI, pluggable endpoints, deterministic fallbacks, capability discovery, strict degradation rules, and auditability.

## 2. Scope

This spec covers:

- Portable runtime architecture.
- Capability tiers and degradation behavior.
- Core runtime modules.
- Endpoint adapter contracts.
- Endpoint policy matrix.
- Intent and action schemas.
- Watchdog chain.
- Truth oracle catalog.
- Authentication, authorization, and trust state.
- Deterministic emergency flows.
- Memory governance.
- Model routing.
- Simulator harness.
- Testing and evaluation.
- Security threat model.
- Audit and replay.
- Configuration profiles.
- Operator console.
- Chimes, dynamic utterances, and Foley/diegetic audio.
- Legal and regulatory verification queue.
- Build order and acceptance criteria.

This spec does not design:

- Physical PBX wiring.
- Radio hardware selection.
- Electrical systems.
- Rail, water, signalling, or power distribution.
- Final legal, radio, privacy, workplace, or emergency compliance rules.
- A final model stack.

Physical systems are treated as black-box endpoints behind adapters until a separate hardware or engineering spec exists.

## 3. Requirement Status Labels

Requirements and decisions must carry one of these labels:

| Label | Meaning |
| --- | --- |
| USER-STATED | Directly stated or strongly directed by the user. |
| USER-ACCEPTED | Previously proposed and explicitly accepted by the user. |
| ASSISTANT-PROPOSED | Proposed by the assistant and not yet confirmed. |
| NEEDS-CONFIRMATION | Plausible but should not be frozen without user approval. |
| UNVERIFIED | Requires external verification before implementation. |
| DEFERRED | Accepted as relevant but not planned for the near build. |
| REJECTED | Explicitly not part of the system. |
| SUPERSEDED | Replaced by a newer direction. |

Future specs should not treat ASSISTANT-PROPOSED or UNVERIFIED items as final requirements without a confirmation pass.

## 4. Top-Level Architecture

```text
Portable Operator Runtime
  Runtime Core
  Runtime Supervisor
  Capability Registry
  Resource Manager
  Event Bus
  Endpoint Registry
  Policy Engine
  Intent / Action Validator
  Session Manager
  Watchdog Chain
  Truth Oracle Catalog
  Auth and Trust Services
  Memory Manager
  Model Router
  Adapter Layer
  Simulator Layer
  Audit / Replay System
  Configuration System
  Operator Console
  Packaging / Deployment Layer
  Optional AI / TTS / STT / Hardware Modules
```

The AI layer is optional. The runtime must boot, log, simulate, enforce policy, and run deterministic fallback flows even if no AI service is available.

## 5. Core Principles

| ID | Principle | Status |
| --- | --- | --- |
| PRINCIPLE-01 | Runtime coherence must not depend on an LLM. | USER-STATED |
| PRINCIPLE-02 | The AI proposes; deterministic runtime services authorize, verify, route, and execute. | USER-STATED |
| PRINCIPLE-03 | All world-facing outputs and actions must pass validation and watchdog gates. | USER-STATED |
| PRINCIPLE-04 | Hardware-specific behavior must remain inside adapters. | USER-STATED |
| PRINCIPLE-05 | The runtime must degrade explicitly and predictably. | USER-STATED |
| PRINCIPLE-06 | Emergency flows must be state-machine-first. | USER-STATED |
| PRINCIPLE-07 | Memory is evidence with source, time, confidence, and sensitivity, not unqualified truth. | USER-STATED |
| PRINCIPLE-08 | Audit and replay are core features, not optional diagnostics. | USER-STATED |
| PRINCIPLE-09 | Assistant proposals must go through confirmation before becoming frozen requirements. | USER-STATED |

## 6. Capability Tiers

The runtime classifies itself at boot and updates its active tier during operation.

| Tier | Name | Example Hardware | Available Capability | AI Capability | Expected Behavior |
| --- | --- | --- | --- | --- | --- |
| T0 | Salvage Core | Very old PC, old laptop, no GPU | Config, logs, simulator, deterministic messages | None | Boots, logs, simulates, runs scripted fallback. |
| T1 | Text Runtime | CPU-only mini PC | Text console, endpoint simulation, rule engine | Optional tiny local or rules-only | Tests flows without speech. |
| T2 | Basic Voice Runtime | CPU-only or weak GPU | Limited ASR/TTS, canned prompts | Small local or remote optional | Basic operator behavior, slower responses. |
| T3 | Local Operator Runtime | Modern mini PC or single GPU | Local STT/TTS/small LLM | Fast local model | 9900/9901 usable, simulator plus some live adapters. |
| T4 | Full Local Runtime | Strong GPU box | Local STT/TTS/LLMs, multiple sessions | Fast plus heavier local models | Production-capable local operator. |
| T5 | Distributed Runtime | Multiple machines or server cluster | Pooled models, adapter nodes, storage, console | Multiple specialist models | Multi-call, multi-agent, resilient deployment. |
| T6 | Hybrid Cloud Runtime | Local plus cloud providers | Cloud fallback or augmentation | Local plus closed-source APIs | High capability with policy-gated offsite use. |

### 6.1 Degradation Declarations

Every feature and module must declare requirements and fallbacks.

```yaml
requires:
  cpu: true
  gpu: optional
  network: optional
  local_llm: optional
  tts: optional
  asr: optional
  hardware_adapter: optional
fallback:
  no_gpu: use_small_cpu_model_or_rules
  no_llm: use_deterministic_templates
  no_tts: use_text_console_or_prerecorded_audio
  no_asr: use_dtmf_or_text_console_or_manual_operator
  no_network: local_only
  no_hardware: simulator_only
```

If a feature has no safe fallback, it must fail closed and report degraded state to the Capability Registry and Operator Console.

## 7. Runtime Boot Sequence

```text
BOOT
  Load base config
  Load machine profile
  Initialize audit log
  Start capability registry
  Discover modules
  Discover adapters
  Register endpoints
  Load policy bundles
  Load watchdog gates
  Load memory manager
  Load simulator endpoints
  Probe AI/STT/TTS/model services
  Compute active capability tier
  Start runtime supervisor
  Start health monitor
  Start operator console
  Enter runtime loop
```

Hard rule: the runtime must be able to boot before AI services are available.

## 8. Runtime Core

The Runtime Core is the smallest useful system. It should boot on weak hardware and support simulator-only operation.

```text
Runtime Core
  Config Loader
  Capability Registry
  Module Loader
  Endpoint Registry
  Session Manager
  Policy Engine
  Intent Validator
  Action Validator
  Minimal Watchdog
  Event Bus
  Audit Logger
  Health Monitor
  Simulator Endpoints
  Local Operator Console
```

### 8.1 Runtime Supervisor

The Runtime Supervisor manages module lifecycle.

Responsibilities:

- Start and stop runtime modules.
- Track heartbeats.
- Restart failed modules with backoff.
- Mark dependencies degraded.
- Prevent crash loops from starving the runtime.
- Emit audit records for lifecycle events.
- Keep emergency and audit paths alive where possible.

### 8.2 Resource Manager

The Resource Manager tracks CPU, RAM, disk, GPU, network, and queue pressure.

When resources are constrained, it may:

- Pause or defer 9902 deep research.
- Disable Foley.
- Use canonical utterances instead of generated variation.
- Route to deterministic replies.
- Lower model size.
- Reject non-critical specialist work.
- Preserve emergency and audit processing first.

### 8.3 Event Bus

The Event Bus moves normalized events, intents, decisions, commands, and audit stamps.

Rules to specify before implementation:

- Event IDs must be unique.
- Commands should be idempotent where possible.
- Emergency events have priority over normal traffic.
- Expired commands must not execute.
- Duplicate events must be detected.
- Failed commands must produce result events.
- Dead-letter events must be auditable.
- Replay should be able to reconstruct the event chain.

### 8.4 Endpoint Registry

The Endpoint Registry records every known live, simulated, disabled, and future endpoint.

It should track:

- Endpoint ID.
- Endpoint family.
- Adapter owner.
- Simulated/live/unavailable status.
- Current mode.
- Policy bundle.
- Allowed command types.
- Priority class.
- Health state.
- Last event time.
- Failover or simulator replacement.

The Operator AI must not invent endpoints. It can only target endpoints known to the registry.

### 8.5 Session Manager

The Session Manager owns live interaction state.

It should support:

- Session creation and closure.
- Dropped calls.
- Holds.
- Resumption.
- Callback scheduling.
- Interruption and priority preemption.
- Multi-call isolation.
- Endpoint handoff.
- Auth continuity tokens.
- Emergency session promotion.
- Session timeout.
- Session audit summaries.

Session state should include endpoint, caller identity signals, auth state, authorization scope, active policy, priority, current task, held/resumable status, and last verified facts.

### 8.6 Policy Engine

The Policy Engine enforces deterministic rules before and during watchdog processing.

It should answer:

- Is this endpoint allowed to perform this action?
- Is this session authorized for this detail level?
- Does this priority override other work?
- Does this output violate endpoint length or style constraints?
- Is this command allowed while the endpoint is busy?
- Is this chime, Foley, or announcement suppressed by current state?
- Is this route available?

The Policy Engine should be able to reject impossible or forbidden requests before model or style work is attempted.

## 9. Configuration System

Profiles should layer in this order:

```text
base.yaml
  + machine_profile.yaml
  + environment_profile.yaml
  + local_override.yaml
```

Named profiles:

| Profile | Meaning |
| --- | --- |
| salvage | Old or weak hardware, no model assumption, deterministic fallback. |
| desktop | Developer workstation, local simulation, optional AI. |
| server | Multi-service production node. |
| offline | No internet or external model calls. |
| simulator | Fake endpoints only. |
| production | Real endpoint adapters enabled. |
| strict | Highest watchdog thresholds, minimal improvisation. |
| development | Verbose logs, replay tools, fake events enabled. |

Configuration must be auditable. Production and strict profiles should support signed or checksum-verified policy bundles.

## 10. Capability Registry

The Capability Registry is the runtime's self-knowledge. The Operator AI must ask the runtime what exists instead of guessing.

Queryable by:

- Model Router.
- Session Manager.
- Watchdog Chain.
- Operator Console.
- Test harness.
- Adapter modules.
- AI layer.

Example:

```yaml
capabilities:
  asr:
    status: available
    provider: local_whisper
    streaming: true
    latency_class: medium
  tts:
    status: unavailable
    provider: none
  local_llm_fast:
    status: available
    model: small_local
    context_window: 8192
  local_llm_heavy:
    status: unavailable
  internet:
    status: unavailable
  endpoints:
    phone_9900:
      status: simulated
    uhf_09:
      status: simulated
    pa:
      status: unavailable
  audit_log:
    status: available
  memory_manager:
    status: available
```

## 11. Adapter Contract

Adapters are plug-ins. The runtime should not care whether an endpoint is real, simulated, SIP, serial, MQTT, GPIO, web, radio, file-backed, or console-based.

### 11.1 Adapter Types

Expected adapter families:

- Phone/PBX.
- SIP.
- UHF.
- VHF.
- PA.
- Intercom.
- Web UI.
- SMS.
- Serial.
- GPIO.
- MQTT.
- File/event simulator.
- Console test adapter.

### 11.2 Adapter Interface

```yaml
Adapter:
  id:
  type:
  version:
  schema_version:
  capabilities:
  endpoints:
  permissions:
  status:
  input_events:
  output_commands:
  health:
  diagnostics:
```

### 11.3 Endpoint Event

```yaml
EndpointEvent:
  event_id:
  schema_version:
  timestamp_wall:
  timestamp_monotonic:
  adapter_id:
  endpoint_id:
  session_id:
  event_type:
    - CALL_STARTED
    - CALL_ENDED
    - AUDIO_FRAME_IN
    - TEXT_IN
    - PTT_DOWN
    - PTT_UP
    - CHANNEL_BUSY
    - CHANNEL_IDLE
    - DATA_SIGNAL
    - EMERGENCY_SIGNAL
    - DTMF
    - HARDWARE_FAULT
    - HEARTBEAT
  payload:
  confidence:
  source_status:
  sensitivity:
```

### 11.4 Endpoint Command

```yaml
EndpointCommand:
  command_id:
  schema_version:
  timestamp_wall:
  timestamp_monotonic:
  adapter_id:
  endpoint_id:
  session_id:
  command_type:
    - PLAY_AUDIO
    - SPEAK_TEXT
    - SEND_TEXT
    - ROUTE_CALL
    - END_CALL
    - HOLD_CALL
    - RESUME_CALL
    - BROADCAST
    - REQUEST_PTT
    - RELEASE_PTT
    - SEND_DATA_SIGNAL
    - SUPPRESS_CHIME
    - SET_ENDPOINT_MODE
  payload:
  priority:
  expiry:
  safety_label:
  sensitivity:
```

Hardware-specific details remain inside adapters. The runtime only sees normalized events and commands.

## 12. Plugin Permission Model

Modules and adapters should declare permissions. Permissions are denied by default in production profiles.

Example permissions:

- `read_audio`
- `read_transcript`
- `emit_endpoint_command`
- `request_model`
- `read_memory`
- `write_memory`
- `read_sensitive_logs`
- `write_audit`
- `access_network`
- `access_hardware`
- `create_callback`
- `broadcast_pa`
- `broadcast_radio`
- `modify_policy`
- `manual_override`

No specialist agent should have direct endpoint output permission. Specialist agents return proposals to the Operator/runtime pipeline.

## 13. Endpoint Policy Matrix

This starter matrix must become machine-readable policy.

| Endpoint | Mode | Tone | Latency Target | Auth Default | Verbosity | Allowed Output | Special Rules |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 9900 | Fast Operator | Brief, direct | Very low | Unauth or partial depending origin | Low | Routing, short info, auth challenge | Avoid long research. |
| 9901 | Concierge | Friendly, conversational | Low-medium | Unauth default | Medium | Help, discussion, info | Slower and more interactive than 9900. |
| 9902 | Deep Research | Structured, thoughtful | Acknowledge fast, work slow | Auth preferred | High | Research, delegation, callbacks | Holds and callbacks normal. |
| UHF 09 | Radio concierge | Concise radio-friendly | Low | Endpoint-limited | Low-medium | Simple help, coordination | Half-duplex constraints. |
| UHF 30 | Broadcast | Announcement | Scheduled or priority | System/auth only | Low | Announcements | No dialogue by default. |
| UHF 05/35 | Emergency override | Scripted emergency | Immediate ack | Emergency handling first | Very low | Emergency ack/instructions | Deterministic state machine. |
| UHF 11 | Calling monitor | Monitoring/calling | Low | Limited | Very low | Calling/ack/routing | Avoid chatter. |
| UHF 22/23 | Data monitor | Data-only/mostly silent | Event-based | System | None | Data signal intake | No casual voice. |
| PA | Broadcast | Clear, calm | Medium | System/auth only | Low | Announcements, chimes, emergency | Zone and suppression rules. |
| Callback | Follow-up | Context-aware | Scheduled | Reauth or continuity token | Medium-high | Results, follow-up | Verify recipient. |
| External SIP | Fast external operator | Formal, minimal | Low | Unauth default | Low | Routing, public info, messages | Strong privacy restrictions. |

## 14. Intent and Action Schemas

The runtime needs more than speech intents.

```text
Intent
  SpeechIntent
  ActionIntent
  ResearchIntent
  MemoryIntent
  BroadcastIntent
  EmergencyIntent
  CallbackIntent
  VerificationIntent
  AuthIntent
  RoutingIntent
  FoleyIntent
  ChimeIntent
  DiagnosticIntent
  SimulatorIntent
```

### 14.1 Base Intent

```yaml
BaseIntent:
  intent_id:
  schema_version:
  timestamp_wall:
  timestamp_monotonic:
  session_id:
  source_agent:
  source_module:
  intent_family:
  semantic_type:
  endpoint_target:
  priority:
  urgency:
  risk_level:
  auth_context:
  required_authz:
  claims:
  dependencies:
  expiry:
  proposed_effect:
  proposed_text:
  style_profile:
  voice_profile:
  audit_context:
  sensitivity:
```

### 14.2 Speech Intent

```yaml
SpeechIntent:
  family: speech
  proposed_text:
  style_profile:
  voice_profile:
  language:
  modality:
    - phone
    - uhf
    - pa
    - console
  length_limit:
  variation_allowed:
  fixed_phrase_required:
  foley_allowed:
```

### 14.3 Action Intent

```yaml
ActionIntent:
  family: action
  action_type:
    - route_call
    - hold_call
    - end_call
    - schedule_callback
    - send_data_signal
    - suppress_chime
    - set_endpoint_mode
  target_endpoint:
  parameters:
  reversible:
  timeout:
  confirmation_required:
```

### 14.4 Verification Intent

```yaml
VerificationIntent:
  family: verification
  verification_type:
    - truth_check
    - auth_check
    - policy_check
    - endpoint_state_check
    - memory_check
  claims:
  required_oracles:
  max_age_allowed:
  required_confidence:
```

### 14.5 Memory Intent

```yaml
MemoryIntent:
  family: memory
  operation:
    - create
    - update
    - strengthen
    - decay
    - summarize
    - archive
    - delete
  memory_type:
  content:
  source:
  confidence:
  sensitivity:
  retention_class:
  permission_effect_allowed: false
```

Default rule: memory should not affect permissions unless a separate authorization policy explicitly allows it.

## 15. Watchdog Chain

The watchdog is a chain of modular gates.

```text
Watchdog Chain
  Schema Validator
  Policy Gate
  Auth Gate
  Authorization Gate
  Truth Checker
  Safety Checker
  Privacy / Leakage Checker
  Protocol Checker
  Style-Preserving Rewriter
  Final Render Approval
  Audit Stamp
```

Each gate has one job. Gates must be replaceable and auditable.

Watchdog decisions:

- approve
- modify
- reject
- delay
- request_verification
- downgrade
- replace_with_fallback
- block
- log_only

Strict modes may skip style-preserving rewrite and use deterministic canonical output.

### 15.1 Watchdog Metrics

The runtime should track watchdog modification and rejection rates instead of guessing them.

Metrics:

- Intents approved unchanged.
- Intents modified.
- Intents rejected.
- Intents delayed for verification.
- Intents downgraded.
- Intents replaced with fallback.
- Gate responsible for each change.
- Endpoint and intent family involved.
- Model route involved.
- Latency added by each gate.

Expected rates should be learned from simulator and replay runs before production thresholds are frozen.

## 16. Truth Oracle Catalog

Truth sources need freshness and confidence rules.

| Oracle | Truth Type | Freshness Requirement | Confidence Rule |
| --- | --- | --- | --- |
| Endpoint State Oracle | Channel busy/idle, call active | Live/seconds | Adapter-reported. |
| System State Oracle | Alarms, hardware state | Live/seconds | Direct system/adapters. |
| Route Table Oracle | Endpoint routing rules | Config version | Signed or verified config. |
| Policy Oracle | SOPs, endpoint policy | Versioned | Active policy bundle. |
| Auth Oracle | Identity/auth state | Live/session | Auth service. |
| Authorization Oracle | Permissions | Live/session/config | RBAC/ABAC. |
| Incident Log Oracle | Active/past incidents | Live/recent | Audit store. |
| Roster Oracle | On-duty people | Minutes/hours | Roster source. |
| Memory Oracle | Semantic memory | Variable | Source-labelled. |
| External Data Oracle | Weather, roads, etc. | Source-dependent | Freshness tagged. |
| Manual Notes Oracle | Human operator notes | Timestamped | Author-labelled. |

### 16.1 Truth Result

```yaml
TruthResult:
  claim_id:
  status:
    - verified
    - contradicted
    - unknown
    - stale
    - not_authorized_to_check
  source:
  source_timestamp:
  freshness:
  confidence:
  caveat:
  allowed_to_say:
  allowed_detail_level:
```

The watchdog should ask:

- Is it true?
- How fresh is it?
- Can we say it?
- How much detail can we reveal?
- Is it safe to act on?

## 17. Auth and Trust Model

Authentication and authorization are separate.

Authentication asks: who or what is this caller likely to be?

Authorization asks: even if this identity is correct, what is this caller allowed to do or know?

### 17.1 Authentication Sources

- Static passcode.
- TOTP.
- Voiceprint.
- Caller ID.
- Internal extension.
- Privileged number.
- UHF callsign.
- Endpoint type.
- Physical/location clues.
- Manual operator approval.

### 17.2 Trust State

```text
UNKNOWN
  UNAUTHENTICATED
  PARTIALLY_AUTHENTICATED
  FULLY_AUTHENTICATED
```

Authorization is separate and must support:

```text
AUTHENTICATED_BUT_NOT_AUTHORIZED
```

Example: a caller can be verified as Contractor A but still be unauthorized to receive internal incident history.

### 17.3 Emergency Override

Emergency calls should not require normal auth to be acknowledged.

Emergency override permits:

- Acknowledge distress.
- Gather minimum facts.
- Trigger deterministic emergency state machine.
- Verify where possible.
- Escalate according to rules.
- Log all steps.

Emergency override does not permit:

- Revealing sensitive information.
- Granting system control.
- Trusting all claims.
- Bypassing logging.
- Treating unverified reports as verified facts.

## 18. Deterministic Emergency Flows

Emergency handling must be state-machine-first.

```text
IDLE
  EMERGENCY_SIGNAL_DETECTED
  ACKNOWLEDGE
  CAPTURE_MINIMUM_FACTS
  CLASSIFY_EMERGENCY
  VERIFY_OR_MARK_UNVERIFIED
  ESCALATE
  BROADCAST_OR_SUPPRESS
  MAINTAIN_CHANNEL
  UPDATE_INCIDENT_LOG
  HANDOFF_OR_CLOSE
  POST_INCIDENT_SUMMARY
```

### 18.1 Minimum Facts To Capture

- Location.
- Emergency type.
- Number of people affected.
- Immediate hazard.
- Caller identity/callsign if available.
- Whether emergency services or internal responders are needed.
- Whether the channel must be kept clear.

### 18.2 Hard Rules

- Always acknowledge emergency channels quickly.
- Never claim an emergency is verified unless verified.
- Never suppress an emergency signal without logging.
- Never play chimes or Foley over emergency traffic.
- Never let 9902 research jobs starve emergency processing.
- Never require normal authentication before acknowledging distress.
- Do not improvise escalation rules.

## 19. Data Classification

Every event, transcript, memory item, oracle result, model prompt, and output command should carry a sensitivity label.

Starter labels:

| Label | Meaning | Default Handling |
| --- | --- | --- |
| PUBLIC | Safe to reveal publicly. | May be spoken or logged normally. |
| INTERNAL | Site-internal operational detail. | Restrict to authorized users. |
| PRIVATE | Personal or sensitive caller/user data. | Minimize, protect, and verify access. |
| SAFETY_CRITICAL | Emergency, hazard, or operational safety data. | Preserve, prioritize, and tightly audit. |
| SECRET | Credentials, keys, privileged procedures. | Never speak unless explicitly authorized by policy. |
| LEGAL_HOLD | Data retained for investigation or compliance. | Do not delete without policy approval. |

Data classification drives:

- What can be spoken.
- What can be stored.
- What can be exported.
- What can be sent to remote models.
- What appears in the console.
- What can be used in memory retrieval.

## 20. Memory Governance

```text
Memory System
  Raw Event Log
  Transcript Store
  Blob Store
  Semantic Memory Store
  Memory Link Graph
  Memory Manager
  Memory Policy Engine
  Consolidation Jobs
  Decay/Strengthening Engine
  Deletion/Retention Engine
  Memory Audit Trail
```

Flow:

```text
AI proposes memory write
  Watchdog checks safety/privacy/policy
  Memory Manager stores, updates, links, decays, or rejects
  Audit log records the result
```

Rules:

- AIs do not directly access memory databases.
- Memory entries require source, timestamp, confidence, sensitivity, and retention class.
- Semantic memory is bounded and curated.
- Raw logs may be broader but remain subject to legal/privacy retention policy.
- Frequently used links may strengthen.
- Weak or stale items may decay, consolidate, archive, or delete.
- Memory cannot change permissions unless a separate authorization policy explicitly permits it.

## 21. Model Router

The Model Router chooses how much intelligence to spend.

### 21.1 Routing Request

```yaml
ModelRoutingRequest:
  endpoint:
  session_state:
  risk_level:
  latency_budget:
  privacy_level:
  auth_level:
  capability_tier:
  internet_available:
  local_models_available:
  task_type:
  user_waiting_live:
```

### 21.2 Routing Decision

```yaml
ModelRoutingDecision:
  route:
    - deterministic
    - local_tiny
    - local_fast
    - local_heavy
    - specialist_agent
    - remote_model
    - no_model_fallback
  reason:
  max_latency:
  allowed_data_scope:
  fallback_route:
```

### 21.3 Default Routing Philosophy

| Situation | Preferred Route |
| --- | --- |
| Emergency first acknowledgement | Deterministic. |
| UHF emergency instructions | Deterministic plus strict watchdog. |
| 9900 routing | Deterministic, local tiny, or local fast. |
| 9901 conversation | Local fast. |
| 9902 deep research | Local heavy, specialist, or remote if allowed. |
| Sensitive private data | Local only unless explicitly permitted. |
| No local model | Deterministic fallback or remote if policy allows. |
| No internet | Local only. |
| Weak hardware | Deterministic plus small CPU model. |

## 22. AI Layer

The AI layer provides capability, not coherence.

```text
AI Layer
  Operator AI
  Researcher AI
  Engineer AI
  Archivist AI
  Safety Analyst AI
  Communications AI
  Utterance Realiser
  Model Router
  Specialist Agent Bus
```

If this layer fails, the runtime should still:

- Answer with deterministic fallback messages.
- Log events.
- Route where configured.
- Run scripted emergency flows.
- Accept console control.
- Simulate endpoints.
- Preserve auditability.

## 23. Dynamic Utterances

The user preference for varied greetings and announcements is a real requirement, not cosmetic polish.

```text
Utterance Realiser
  Semantic template input
  Style profile
  Endpoint policy
  Latency budget
  Variation budget
  Watchdog approval
  Fallback canonical phrase
```

Rules:

- Generate fresh phrasing when compute allows.
- Reuse canonical or last-approved text when compute is tight.
- Do not vary protocol-critical emergency phrases unless explicitly allowed.
- Preserve the intended agent tone.
- Preserve the intended TTS voice.

## 24. Foley and Diegetic Audio

```text
Foley Engine
  Approved sound library
  Context selector
  Silence detector
  Mixer
  Limiter
  Ducking
  Endpoint policy
  Emergency suppression
  Audit markers
```

Rules:

- Never clip.
- Never mask speech.
- Never play during emergency instructions.
- Never mimic alarms or real signals.
- Must be contextually plausible.
- Must be suppressible by watchdog/session policy.

## 25. Chimes and Time Signals

```text
Scheduled Event Subsystem
  Chime Scheduler
  PA Overlay Policy
  Data Tick Publisher
  Suppression Rules
  Emergency Mute Rules
  Quiet Hours
  Zone Rules
  Audit Log
```

Preserved rules:

- PA is the likely primary audible channel.
- Data tick is safer for machine-readable timing.
- Do not use power cycles as a signal.
- Avoid shared UHF/VHF voice chimes by default.
- Use wait windows when PA/radio is busy.
- Suppress during emergencies.
- Keep alarm sounds distinct from chimes.

## 26. Time System

The runtime needs explicit time handling for audit, callbacks, freshness, chimes, and replay.

Requirements:

- Store wall-clock timestamps with timezone.
- Store monotonic timestamps for ordering and latency.
- Record clock-source quality where possible.
- Treat stale oracle results as stale, not false.
- Support offline operation with degraded clock confidence.
- Use signed or integrity-protected timestamps for production audit where feasible.

## 27. Simulation Harness

The simulator is a first-class build target before hardware exists.

```text
Simulation Harness
  Fake Phone Adapter
  Fake SIP Adapter
  Fake UHF Adapter
  Fake PA Adapter
  Fake Data Signal Adapter
  Fake Auth Service
  Fake Truth Oracles
  Fake Hardware State
  Fake Emergency Events
  Fake Caller Profiles
  Fault Injector
  Latency Injector
  Load Generator
  Replay Runner
```

Minimum simulated scenarios:

- Normal 9900 routing call.
- Normal 9901 conversation.
- 9902 research request with callback.
- External SIP caller asking for internal person.
- UHF 09 general call.
- UHF 30 announcement.
- UHF 05/35 emergency.
- UHF 11 calling event.
- UHF 22/23 data signal event.
- Dropped call.
- Interrupted call.
- Watchdog rejection.
- Failed auth.
- Spoofed caller ID.
- Fake emergency.
- Adapter failure.
- No TTS.
- No AI.
- No internet.
- High load.
- Chime while PA busy.
- Chime during emergency suppression.

## 28. Testing and Evaluation

Required test suites:

- Schema validation tests.
- Endpoint policy tests.
- Auth escalation tests.
- Authorization denial tests.
- Emergency flow tests.
- Watchdog rewrite tests.
- Truth oracle contradiction tests.
- Privacy leak tests.
- Memory write tests.
- Memory retrieval tests.
- Prompt injection tests.
- Rogue agent tests.
- Adapter fault tests.
- Latency/load tests.
- Chime suppression tests.
- Foley suppression tests.
- Replay determinism tests.
- Config profile tests.

### 28.1 Required Negative Tests

- AI claims a system state that is false.
- AI tries to escalate caller privilege.
- AI says an emergency is verified when it is not.
- AI reveals private/internal information to an unauthenticated caller.
- AI ignores endpoint style rules.
- AI speaks too long on UHF.
- AI plays Foley during emergency.
- AI chimes over active PA emergency.
- Memory write tries to store sensitive personal inference.
- Rogue specialist attempts direct output.
- Remote model receives data it should not receive.

## 29. Security Threat Model

| Threat | Example | Mitigation |
| --- | --- | --- |
| Prompt injection by voice | Caller says "ignore your rules." | Intent-only output and watchdog chain. |
| Social engineering | Fake authority claim. | Authentication plus authorization. |
| Replayed voiceprint | Recorded authorized voice. | Liveness and multifactor. |
| Stolen passcode | Leaked phrase. | TOTP and step-up auth. |
| Fake emergency | Caller creates panic. | Acknowledge but mark unverified. |
| Caller ID spoofing | External appears internal. | Treat caller ID as weak signal. |
| Compromised adapter | Fake endpoint events. | Signed adapters, permissions, health checks. |
| Poisoned memory | Malicious info promoted. | Watchdog-gated memory writes. |
| Rogue specialist agent | Bypasses Operator. | No direct endpoint access. |
| Log tampering | Erase bad event. | Append-only signed audit. |
| Remote model leakage | Sensitive prompt sent offsite. | Model router privacy policy. |
| Chime/Foley confusion | Sound mistaken for alert. | Distinct audio policy. |
| Config tampering | Relaxed watchdog rules. | Signed configs and audit. |

## 30. Audit and Replay

Every meaningful event should be reconstructable.

```text
Input event
  ASR/transcript
  User act
  Session state
  Model routing decision
  AI proposal
  Intent
  Watchdog gate decisions
  Oracle results
  Rewrite
  Final approved command/output
  Adapter action result
  Audit stamp
```

Replay modes:

```text
Replay Mode
  Exact replay
  Policy replay
  New-model replay
  Watchdog-only replay
  Oracle-simulated replay
  Regression-test replay
```

Replay questions:

- Would a new watchdog have blocked this?
- Would a new model hallucinate less?
- Did an endpoint policy change break old flows?
- Did a memory change affect authorization incorrectly?

## 31. Operator Console

The console is a core operational surface, not an afterthought.

Minimum functions:

- Active sessions.
- Endpoint status.
- Auth state.
- Current capability tier.
- Loaded modules.
- Adapter health.
- Current model routes.
- Watchdog decisions.
- Blocked intents.
- Memory writes pending approval.
- Emergency state.
- Chime schedule.
- Foley status.
- Logs and replay.
- Simulator controls.
- Config profile.
- Manual override/acknowledgement.

Console modes:

```text
Console Modes
  Read-only monitor
  Developer simulator
  Local operator
  Administrator
  Incident review
  Audit/replay
```

Console functions must be permissioned.

## 32. Manual Authority Model

Manual authority must be explicit.

Roles to define:

- Monitor: can observe status and logs allowed by policy.
- Developer: can run simulator and inspect non-production state.
- Local operator: can acknowledge events, manage sessions, and assist callers.
- Administrator: can configure profiles, modules, and permissions.
- Incident reviewer: can review incident logs and replay.
- Auditor: can review immutable records but not modify operational state.

Manual override must be logged. Emergency manual actions must preserve the incident trail.

## 33. Schema Versioning

All durable contracts need version fields:

- Endpoint events.
- Endpoint commands.
- Intents.
- Watchdog decisions.
- Truth results.
- Memory records.
- Audit records.
- Config files.
- Policy bundles.
- Replay files.

Migration rules:

- New runtime versions should read older audit/replay files where practical.
- Breaking schema changes require explicit migration tooling.
- Production policy bundles should declare compatible runtime versions.
- Adapters must declare supported schema versions at registration.

## 34. Packaging and Deployment

Deployment must stay portable.

Supported deployment shapes:

- Single local executable/service.
- Portable folder install.
- Native Windows service.
- Native Linux service.
- Optional sidecar processes for AI/STT/TTS.
- Optional Docker deployment.
- Optional distributed deployment.

Docker may be supported, but should not be required for the core runtime.

## 35. Portable Language Strategy

The better framing is not "everything must be C++ immediately." It is:

The portable runtime core should be implementable in conservative, dependency-light technologies; AI/model services can be modular sidecars.

| Area | Candidate Language | Reason |
| --- | --- | --- |
| Runtime Core | C++11 / C11-compatible subset | Portability, low dependency, old hardware. |
| Adapter SDK | C ABI plus C++ wrapper | Broad compatibility. |
| Config/parser core | C++11 or C | Portable. |
| Watchdog gates | C++11 core, Rust optional | Safety and validation. |
| Simulator | C++ core plus Python tooling optional | Fast core, flexible scenarios. |
| Offline analysis | Python | Easier analysis/training. |
| Operator Console | Web UI or native lightweight UI | Deployment-dependent. |
| Model services | Whatever serving stack needs | Isolated sidecars. |

## 36. Legal and Regulatory Verification Queue

These items are UNVERIFIED until reviewed against current sources and applicable jurisdiction:

- Call recording laws.
- Workplace monitoring/privacy.
- Voiceprint/biometric handling.
- Radio channel use.
- Emergency announcement language.
- PA announcements and quiet hours.
- Data retention obligations.
- Consent notices.
- Third-party model data transfer.
- Logging of sensitive incidents.
- Chimes/time signals in workplace environments.

## 37. Recommended Build Order

### Phase 0 - Spec Foundation

Deliver:

- Portable Runtime Core spec.
- Capability tier table.
- Adapter contract.
- Endpoint policy matrix.
- Intent/action schema v0.1.
- Watchdog chain v0.1.
- Simulation harness plan.

Goal: no real AI required yet.

### Phase 1 - Simulator-Only Runtime

Build:

- Config loader.
- Capability registry.
- Module loader.
- Endpoint registry.
- Audit log.
- Simulator endpoints.
- Deterministic policy engine.
- Intent validator.
- Basic console.

Goal: the system can simulate calls, UHF events, PA events, emergencies, failures, and logs without hardware or AI.

Acceptance criteria:

- Boots with no AI, no network, no TTS, no ASR, and no hardware.
- Loads `base + simulator + strict` profile.
- Registers fake 9900, 9901, 9902, UHF, PA, and external SIP endpoints.
- Emits and records endpoint events.
- Validates at least one speech intent and one action intent.
- Blocks at least one invalid intent.
- Records audit chain for a simulated session.
- Can replay the session.
- Survives simulated adapter failure.

### Phase 2 - Deterministic Operator

Build:

- Scripted 9900/9901/9902/UHF/PA responses.
- Emergency state machine.
- Auth simulation.
- Callback simulation.
- Chime scheduler.
- Replay system.

Goal: coherent operator behavior with no LLM.

Acceptance criteria:

- Handles the minimum simulated scenarios from Section 27.
- Emergency acknowledgement is deterministic and immediate within configured latency target.
- 9902 work cannot starve emergency processing.
- Chimes suppress during emergency.
- Foley is unavailable or suppressed by default in emergency states.

### Phase 3 - AI as Optional Enhancement

Add:

- Model router.
- Local small model.
- Utterance realiser.
- Watchdog chain.
- Memory manager.
- TTS/STT modules.

Goal: AI improves behavior but does not own system coherence.

Acceptance criteria:

- Runtime still passes Phase 1 and 2 tests with AI disabled.
- AI proposals pass through intent validation and watchdog gates.
- Remote model routing respects data classification.
- Same-tone rewrites are auditable.

### Phase 4 - Hardware Adapters

Add real adapters gradually:

- Web console first.
- SIP/phone simulator-to-real bridge.
- PA adapter.
- UHF adapter.
- Data signal adapter.

Goal: replace simulator endpoints with real ones one at a time.

Acceptance criteria:

- Each real adapter can be disabled and replaced by simulator mode.
- Adapter failures degrade cleanly.
- Hardware-specific details do not leak into core runtime logic.

### Phase 5 - Production Hardening

Add:

- Security review.
- Legal verification.
- Audit replay hardening.
- Load tests.
- Failover.
- Operator console roles.
- Model/provider policy gates.

Goal: production-capable runtime with verified policies and operational controls.

## 38. Confirmation Register

Items to confirm before freezing v0.1:

| ID | Item | Current Status |
| --- | --- | --- |
| CONFIRM-01 | Is Windows 7/older Linux support mandatory or aspirational? | NEEDS-CONFIRMATION |
| CONFIRM-02 | What minimum hardware should Phase 1 target? | NEEDS-CONFIRMATION |
| CONFIRM-03 | Should the first implementation use C++11 core immediately or prototype in a faster language first? | NEEDS-CONFIRMATION |
| CONFIRM-04 | What are the initial retention defaults for logs, audio, transcripts, and semantic memory? | NEEDS-CONFIRMATION |
| CONFIRM-05 | Are remote/cloud model calls allowed in any profile? | NEEDS-CONFIRMATION |
| CONFIRM-06 | Which endpoint policies are final for 9900, 9901, 9902, and UHF channels? | NEEDS-CONFIRMATION |
| CONFIRM-07 | What is the first acceptable operator console: CLI, web, native, or both CLI and web? | NEEDS-CONFIRMATION |
| CONFIRM-08 | Should chimes be included in Phase 2 or deferred? | NEEDS-CONFIRMATION |
| CONFIRM-09 | Should Foley be included in Phase 3 or deferred until after live hardware? | NEEDS-CONFIRMATION |
| CONFIRM-10 | What target concurrency should tests simulate first? | NEEDS-CONFIRMATION |

## 39. Requirements Register

| ID | Requirement | Status |
| --- | --- | --- |
| RUNTIME-REQ-01 | Specify the Operator as a portable runtime, not only an AI architecture. | USER-STATED |
| RUNTIME-REQ-02 | Support capability tiers from old laptop to future server. | USER-STATED |
| RUNTIME-REQ-03 | Include CPU-only, no-internet, no-local-LLM, no-TTS, simulator-only, and full operator modes. | USER-STATED |
| RUNTIME-REQ-04 | Define a minimal always-available Runtime Core. | USER-STATED |
| RUNTIME-REQ-05 | Define clean adapter contracts before hardware exists. | USER-STATED |
| RUNTIME-REQ-06 | Build the endpoint policy matrix. | USER-STATED |
| RUNTIME-REQ-07 | Expand intents beyond speech to action/research/memory/broadcast/emergency/callback/verification. | USER-STATED |
| RUNTIME-REQ-08 | Formalize auth and trust model. | USER-STATED |
| RUNTIME-REQ-09 | Make emergency flows mostly deterministic. | USER-STATED |
| RUNTIME-REQ-10 | Split watchdog into a chain of gates. | USER-STATED |
| RUNTIME-REQ-11 | Define truth oracle catalog with freshness/confidence. | USER-STATED |
| RUNTIME-REQ-12 | Formalize memory governance. | USER-STATED |
| RUNTIME-REQ-13 | Define model router. | USER-STATED |
| RUNTIME-REQ-14 | Build simulation harness before hardware. | USER-STATED |
| RUNTIME-REQ-15 | Add testing/evaluation suites. | USER-STATED |
| RUNTIME-REQ-16 | Add security threat model. | USER-STATED |
| RUNTIME-REQ-17 | Add audit/replay. | USER-STATED |
| RUNTIME-REQ-18 | Add portable configuration system. | USER-STATED |
| RUNTIME-REQ-19 | Add operator console. | USER-STATED |
| RUNTIME-REQ-20 | Maintain legal/regulatory verification queue. | USER-STATED |
| RUNTIME-REQ-21 | Pull forward UHF 22/23, UHF 11, UHF 30, UHF 05/35, UHF 09 details. | USER-STATED |
| RUNTIME-REQ-22 | Pull forward external SIP, dropped calls, holds, callbacks, interruptions, and resumption. | USER-STATED |
| RUNTIME-REQ-23 | Pull forward watchdog modification-rate expectations. | USER-STATED |
| RUNTIME-REQ-24 | Pull forward dynamic greetings/announcements. | USER-STATED |
| RUNTIME-REQ-25 | Pull forward Foley/diegetic audio constraints. | USER-STATED |
| RUNTIME-REQ-26 | Pull forward chimes/time signals. | USER-STATED |
| RUNTIME-REQ-27 | Reframe portability as portable core first. | USER-STATED |
| RUNTIME-REQ-28 | Run confirmation pass before freezing requirements. | USER-STATED |
| RUNTIME-REQ-29 | Add Runtime Supervisor for module lifecycle, health, and restarts. | ASSISTANT-PROPOSED |
| RUNTIME-REQ-30 | Add Event Bus rules for ordering, priority, retries, deduplication, and dead-letter handling. | ASSISTANT-PROPOSED |
| RUNTIME-REQ-31 | Add Resource Manager for constrained hardware behavior. | ASSISTANT-PROPOSED |
| RUNTIME-REQ-32 | Add Data Classification across events, memory, prompts, outputs, and logs. | ASSISTANT-PROPOSED |
| RUNTIME-REQ-33 | Add Plugin Permission Model for adapters and modules. | ASSISTANT-PROPOSED |
| RUNTIME-REQ-34 | Add Schema Versioning and migration rules. | ASSISTANT-PROPOSED |
| RUNTIME-REQ-35 | Add Manual Authority Model for console roles and overrides. | ASSISTANT-PROPOSED |
| RUNTIME-REQ-36 | Add explicit Time System for callbacks, chimes, audit, freshness, and replay. | ASSISTANT-PROPOSED |
| RUNTIME-REQ-37 | Add Packaging and Deployment strategy that keeps Docker optional. | ASSISTANT-PROPOSED |

## 40. Open Design Questions

- What exact endpoint policy matrix should be frozen?
- What target concurrency must the first runtime handle?
- Which truth oracles exist now, and which are simulated first?
- Which legal/privacy/radio/workplace obligations apply?
- Is Windows 7/older Linux support mandatory or aspirational?
- Which model/software stack is current, licensed, and performant?
- What memory retention policy applies to audio, transcripts, logs, and semantic memory?
- How much offsite or closed-source model usage is allowed?
- What chime schedule and zones should be used?
- What diegetic sounds are acceptable?
- How will watchdog tone/style preservation be evaluated?
- What is the minimum viable Operator build?

## 41. Immediate Next Deliverables

Recommended next artifacts:

1. `endpoint_policy_matrix.v0.1.yaml`
2. `schemas/base_intent.v0.1.yaml`
3. `schemas/endpoint_event.v0.1.yaml`
4. `schemas/endpoint_command.v0.1.yaml`
5. `watchdog_chain.v0.1.md`
6. `simulation_scenarios.v0.1.md`
7. `phase_1_acceptance_tests.v0.1.md`

The strongest next build target is Phase 1: simulator-only runtime with no hardware and no AI dependency.
