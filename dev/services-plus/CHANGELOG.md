# Changelog

## 0.3.0-rc1

- Add Phase 3 installation, configuration, compatibility, database, troubleshooting and release-validation documentation.
- Guarantee frontend loading and busy states recover from rejected or timed-out NUI requests, including a localized conversation retry state.
- Bound call queue broadcasts and batch restart call-history cleanup to avoid unbounded reads and per-row updates.
- Correct the initial-state rate-limit key and add configurable debug, info, warning and error log thresholds.
- Remove diagnostic prototypes from the production manifest and make startup logging phase-neutral.
- Add Phase 3 contracts for callback responses, allow-lists, rate limits, API handlers, documentation coverage, query indexes, queue limits and production packaging.
- Preserve API version 7 while freezing the release-candidate surface for the Phase 4 documentation review.

## 0.2.18-phase2

- Show the assigned employee name and role on active and completed company requests.
- Persist assignee snapshots through migration 009 while keeping stable identifiers limited to trusted integrations.
- Add trusted employee reads and validated accept, decline and return request exports.
- Add a stable sanitized `requestLifecycle` event for MDT, dispatch and business integrations.
- Keep patrol units, multiple officers and live tracking owned by external systems linked through request IDs.

## 0.2.17-phase2

- Keep the request composer open when loading or submission fails.
- Replace technical request-creation errors with localized guidance to call the company instead.
- Add UI coverage for German submission failures and English request-option failures.

## 0.2.16-phase2

- Remove company-level workflow-step selection and always use the complete predefined category workflow.
- Ignore obsolete stored `phaseIds` and remove phase controls from leader request settings.
- Remove the taxi pickup location field and always capture server-side GTA coordinates for taxi requests.

## 0.2.15-phase2

- Allow leaders to configure phone fields as required while preserving automatic equipped-number prefilling and server validation.
- Rename active request phases in the UI to the clearer workflow-steps terminology.
- Refresh employee inbox unread state after message loading and mirror read behavior in the browser preview.

## 0.2.14-phase2

- Reserve red portal-tab counters for unanswered requests, unread messages and calls not yet viewed in the current app session.
- Mark loaded calls as seen when the calls tab is opened and highlight only subsequently unseen calls.
- Render zero counts, seen calls, team totals and empty number-inbox counters with neutral styling.

## 0.2.13-phase2

- Include the server-resolved numeric framework job grade in public on-duty employee state.
- Sort the active team by leader status and descending grade before status and name.
- Revalidate and broadcast role, grade and leader changes while an employee remains on duty.

## 0.2.12-phase2

- Move the active employee roster into a dedicated company-portal workspace tab beside requests, inboxes and calls.
- Add compact pagination to every portal list and team search by employee name or role.
- Preserve the selected portal tab for the current app session and prioritize operational statuses in the team list.

## 0.2.11-phase2

- Remove administrative line-staffing modes and per-number employee allow-lists.
- Let active dispatchers select individual enabled numbers for the current duty session, with all lines selected when dispatch starts.
- Keep enabled shared inboxes available to on-duty company employees independently of dispatch line selection.
- Add migration 008 to remove obsolete staffing, eligibility and persistent subscription storage.

## 0.2.10-phase2

- Remove general request templates; general contact now belongs exclusively to company messages.
- Expose requests only for categories with specialized structured templates.
- Hide citizen request actions and disable admin/leader request toggles when a category has no specialized request definition.
- Reject request-option loading for categories without specialized templates instead of returning an empty or generic workflow.

## 0.2.9-phase2

- Show category-specific request templates before the general request option.
- Consolidate appointments, complaints, information and callback requests into one universal free-text general request.
- Safely discard the removed duplicate general template identifiers from stored company settings.

## 0.2.8-phase2

- Separate universal free-text requests from category-specific structured requests in definitions, citizen selection and leader configuration.
- Add pickup, roadside/towing assistance, delivery, table reservation, medical transport, property viewing, legal assistance and police request templates with the requested minimal fields.
- Add server-validated select fields for legal area and urgency.
- Prefill request phone fields from the currently equipped LB Phone number while keeping the field editable and removable.
- Filter obsolete stored template identifiers and fall back to valid category defaults after definition updates.

## 0.2.7-phase2

- Rename ambiguous number settings and add localized explanations for every staffing mode and number capability.
- Move restricted employee eligibility out of request configuration into dedicated line access sections in both the admin editor and company portal.
- Expose the citizen-directory toggle to company leaders and clarify that it controls citizen access without hiding internal inboxes.

## 0.2.6-phase2

- Make dispatch activation staff every authorized active line by default while allowing per-session line deselection.
- Keep enabled authorized number inboxes visible and usable independently of active call-line staffing.
- Add visible localized labels for every phone-number field and capability group in the company admin editor.

## 0.2.5-phase2

- Added granular per-number call, inbox, request, visibility and operational enablement controls.
- Added persistent employee line subscriptions with separate access authorization and runtime LB Phone custom-number registration.
- Added explicit number inbox tabs, including empty staffed inboxes and per-number unread counters.
- Added live citizen request updates and persistent LB Phone status notifications.
- Added configurable disabled, prompted or automatic GTA waypoint routing when a request is accepted.
- Added an allow-listed server export API and local lifecycle events for MDT, dispatch and other trusted resources.
- Added migration 007 for number staffing, request navigation and idempotent external request references.

## 0.2.4-phase2

- Added an administrator-controlled request competition toggle for every category.
- Allow available employees from different companies in a competitive category to race for requests through the existing atomic assignment contract.
- Keep duty active while the app is closed and across Services+ restarts for the same connected player and equipped phone.
- Invalidate duty on explicit logout, disconnect, employment change, phone removal or equipped-number change.
- Allow active dispatch employees to soft-delete their own company's requests, shared-inbox conversations and individual messages; call history remains immutable.
- Added migration 006 for audited request, conversation and message soft deletion.

## 0.2.3-phase2

- Added interactive LB Phone request notifications with direct decline (`-`) and accept (`+`) actions.
- Routed notification actions through the existing validated and rate-limited request API.
- Clear stale in-app request offers after notification actions or assignment changes.
- Bring the Services+ request offer on screen and mirror LB Phone's default `ENTER`/`BACKSPACE` call controls with dedicated configurable key mappings.
- Reworked incoming requests into a full-screen offer view using the company background, logo, category and the three most relevant request fields.

## 0.2.2-phase2

- Added the red manual `occupied` employee status without conflating it with active-work Busy state.
- Excluded occupied employees from call and request offers while keeping messages available.
- Added LB Phone notifications for eligible incoming company calls; requests already use the same notification path.
- Changed incoming call and request actions to circular minus/plus controls.

## 0.2.1-phase2

- Replaced manual attachment URLs with the official LB Phone gallery picker.
- Added a fixed set of five general and five GTA-themed emojis for message composition.
- Added persistent, toggleable per-user message reactions with live inbox updates.
- Added server-side conversation authorization and emoji allowlist validation for reactions.

## 0.2.0-phase2

- Added native multi-number company call routing with ring-all, random and dispatch-only distribution.
- Added atomic call/request acceptance, per-number queues, queue updates, Busy-state restoration and restart cleanup.
- Added per-number employee eligibility enforced for calls and shared inboxes.
- Added shared conversations, read state, company-number replies, attachments and locations.
- Added extensible category request definitions, company-specific labels/templates/fields/phases and generic forms.
- Added request offers, assignment, transitions, completion, return, cancellation and recovery.
- Added personal and company communication histories with cursor-based server pagination.
- Added citizen and employee communication views and leader configuration controls.

## 0.1.0-phase1

- Added restart-safe LB Phone custom app registration.
- Added ESX, QBCore, Qbox and standalone framework bridges.
- Added versioned database schema and company cache.
- Added company directory, local search, availability and direct calling.
- Added server-authoritative duty, status, dispatch and single-employee behavior.
- Added company portal, active employee list and leader company settings.
- Added optional integration boundaries, API contracts and Phase 1 diagnostics.
- Added icon-first categorized directory cards in a two-column layout.
- Added English/German player preference with flag controls.
- Added personal call/request activity and basic citizen request creation.
- Added server-authorized company call recording.
- Added ACE/framework-protected company administration and global settings.
- Restricted company leaders to operational toggles; identity and phone settings are admin-only.
