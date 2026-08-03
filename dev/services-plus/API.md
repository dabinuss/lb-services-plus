# Services+ Phase 2 API Contracts

All payloads are JSON-compatible. Every response uses `{ success, data? , error? }`.
Server events are request/response based and return through `services-plus:client:response`.

| Name | Direction | Input | Permission | Rate limit | Side effect |
| --- | --- | --- | --- | --- | --- |
| `getInitialState` | NUI to client to server | `{}` | Phone user | 12/min | None |
| `enterDuty` | NUI to client to server | `{}` | Framework employee | 5/30 sec | Creates runtime duty state |
| `leaveDuty` | NUI to client to server | `{}` | On-duty employee | 5/30 sec | Removes runtime duty state |
| `updateStatus` | NUI to client to server | `{ status: "available" | "on_break" | "occupied" }` | On-duty employee | 15/30 sec | Updates employee status; `occupied` suppresses call and request offers |
| `toggleDispatch` | NUI to client to server | `{ enabled }` | On-duty employee | 10/30 sec | Updates dispatch preference |
| `updateCompanyOperations` | NUI to client to server | `{ companyId, patch }` | Company leader | 8/min | Persists request/message toggles and dispatch mode |
| `updateNumberOperations` | NUI to client to server | `{ numbers }` | Company leader | 8/min | Persists operational flags and distribution without changing number identity |
| `toggleDispatchLine` | NUI to client to server | `{ numberId, enabled }` | Active dispatcher | 20/min | Selects or releases a number for the current dispatch session |
| `startCompanyCall` | NUI to client to server | `{ companyId, numberId? }` | Phone user | 8/30 sec | Records an owned call attempt and returns an authorized number |
| `getEmployeeContact` | NUI to client to server | `{ targetSource }` | Active colleague | 10/30 sec | Resolves an equipped number after same-company validation |
| `createRequest` | NUI to client to server | `{ companyId, templateId, values, locale }` | Phone user | 4/min | Creates an owned pending request and captures server-side navigation coordinates when configured |
| `getMyActivity` | NUI to client to server | `{ limit }` | Phone user | 12/min | Loads only the caller's calls and requests |
| `getAdminState` | NUI to client to server | `{}` | Server administrator | 8/min | Loads administrative configuration |
| `adminSaveCompany` | NUI to client to server | `{ company }` | Server administrator | 10/min | Creates or replaces a company and its numbers |
| `adminDeleteCompany` | NUI to client to server | `{ companyId }` | Server administrator | 5/min | Deletes a company and invalidates duty sessions |
| `adminUpdateSettings` | NUI to client to server | `{ settings }` | Server administrator | 8/min | Persists global Services+ switches |
| `adminUpdateCategory` | NUI to client to server | `{ categoryId, requestCompetition }` | Server administrator | 12/min | Persists category-wide cross-company request competition |
| `getRequestOptions` | NUI to client to server | `{ companyId, locale }` | Phone user | 15/min | Resolves category and company request configuration |
| `registerIncomingCall` | Client to server | `{ callToken, number }` | Offered on-duty employee | 20/30 sec | Registers a custom-number offer in the queue |
| `acceptCall` | NUI to client to server | `{ id, callToken }` | Currently offered employee | 8/30 sec | Atomically assigns call and sets Busy |
| `declineCall` | NUI to client to server | `{ id }` | Offered employee | 12/30 sec | Removes employee from the current offer |
| `endCustomCall` | Client to server | `{ callToken }` | Registered call recipient | 12/30 sec | Ends queue ownership and restores status |
| `getCompanyWorkspace` | NUI to client to server | `{ cursor?, limit? }` | On-duty employee | 15/min | Loads enabled inboxes, requests and call history |
| `acceptRequest` | NUI to client to server | `{ id }` | Available on-duty employee | 8/30 sec | Atomically assigns request and sets Busy |
| `declineRequest` | NUI to client to server | `{ id }` | On-duty employee | 12/30 sec | Records personal decline |
| `transitionRequest` | NUI to client to server | `{ id, phaseId }` | Assigned employee | 15/30 sec | Performs next allowed request transition |
| `returnRequest` | NUI to client to server | `{ id }` | Assigned employee | 8/30 sec | Returns request and restores status |
| `cancelRequest` | NUI to client to server | `{ id }` | Request owner | 6/min | Cancels owned active request |
| `deleteRequest` | NUI to client to server | `{ id }` | Active dispatch of owning company | 10/min | Soft-deletes and audits a company request |
| `updateRequestSettings` | NUI to client to server | `{ settings }` | Company leader | 6/min | Persists controlled labels/templates/fields/phases, target number and navigation mode |
| `sendCitizenMessage` | NUI to client to server | Message payload | Phone user | 12/min | Sends via LB Phone and stores in target number inbox |
| `sendEmployeeMessage` | NUI to client to server | Conversation message payload | On-duty company employee with enabled inbox | 20/min | Replies through the company number |
| `getCitizenInbox` | NUI to client to server | `{ cursor?, limit? }` | Phone user | 15/min | Loads caller-owned company conversations |
| `getConversationMessages` | NUI to client to server | `{ conversationId, citizen, cursor?, limit? }` | Conversation participant | 20/min | Loads a validated conversation page and updates read state |
| `reactToMessage` | NUI to client to server | `{ messageId, emoji, citizen }` | Conversation participant | 30/min | Toggles one allow-listed reaction for the current participant |
| `deleteConversation` | NUI to client to server | `{ id }` | Active authorized company dispatch | 10/min | Soft-deletes a Services+ shared-inbox conversation |
| `deleteMessage` | NUI to client to server | `{ id }` | Active authorized company dispatch | 20/min | Soft-deletes one Services+ shared-inbox message |

Push events sent through `SendCustomAppMessage` use `{ type, version, timestamp, payload }`.

Incoming request notifications use LB Phone `customData.buttons`. Their `-` and `+` actions invoke the existing rate-limited `declineRequest` and `acceptRequest` contracts and remain fully server-authoritative.

| Type | Audience | Payload |
| --- | --- | --- |
| `company.updated` | All app clients | Public company entity |
| `company.deleted` | All app clients | `{ id }` |
| `settings.updated` | All app clients | Public global settings |
| `category.updated` | All app clients | Public category entity including competition mode |
| `employee.updated` | On-duty members of company | Public employee entity |
| `employee.removed` | On-duty members of company | `{ companyId, source }` |
| `session.invalidated` | Affected player | `{ reason }` |
| `inbox.reaction` | Authorized conversation participants | `{ messageId, conversationId, reactions }` |
| `inbox.deleted` | Authorized company inbox users | `{ id, companyId }` |
| `inbox.message.deleted` | Authorized company inbox users | `{ messageId, conversationId }` |
| `request.citizen.updated` | Connected request creator | Updated request entity |

## Trusted Resource API

Add trusted resource names to `Config.ApiAllowedResources`. All exports return the standard Services+ response envelope. Write exports still validate the supplied player source through the normal Services+ permission and workflow rules.

| Server export | Input | Purpose |
| --- | --- | --- |
| `GetCompany` | `companyId` | Returns one public company entity |
| `GetCompanyNumbers` | `companyId` | Returns operational number state |
| `GetRequest` | `requestId` | Returns one request |
| `GetCompanyRequests` | `companyId, { cursor?, limit?, activeOnly? }` | Returns a bounded request page |
| `CreateRequest` | `source, { companyId, templateId, values, externalId, locale? }` | Creates an idempotent external request |
| `TransitionRequest` | `source, requestId, phaseId` | Uses the assigned employee transition contract |
| `SendCompanyMessage` | `source, messagePayload` | Uses the authorized company inbox sender contract |

Local server events are emitted as `services-plus:server:requestCreated`, `requestUpdated`, `requestAccepted`, `requestPhaseChanged`, `requestReturned`, `requestCompleted`, `requestCancelled`, `requestDeleted`, and `messageReceived`. They are integration events, not client-triggerable network APIs.

Malformed requests and denied actions always receive an error envelope. Internal errors are logged server-side and never exposed to clients.

Company leaders cannot edit company identity, framework job, category, logo, card background, public profile, keywords, or phone numbers. Those fields require server-administrator authorization. They can configure the operational dispatch mode.
