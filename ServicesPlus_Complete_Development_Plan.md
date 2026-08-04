# Services+ – Complete App and Development Plan

**Project:** FiveM LB Phone Custom App  
**App Name:** Services+  
**Resource Identifier:** `services-plus`  
**Development Priority:** Stability, compatibility, performance, low network traffic  
**Code Language:** English  
**Player-Facing Locales:** German and English

---

## 1. Product Goal

Services+ replaces the default LB Phone services app with a standalone custom app for companies, public services, hotlines, shared company inboxes, calls and service requests.

The app must feel like a native LB Phone application and must remain simple enough for players and server administrators to understand without extensive training.

Services+ must coexist cleanly with the server's existing resources. It must not assume ownership of unrelated jobs, phone features, inventories, dispatch systems, maps, billing systems or notification systems unless an integration is explicitly enabled.

The core priorities are:

1. Stability
2. Compatibility with LB Phone and common FiveM frameworks
3. Performance
4. Minimal network and database traffic
5. Simple server-side administration
6. Clear role boundaries
7. Restart safety
8. Continuous code review and testing

Services+ is not considered finished when the user interface merely works. It is finished when calls, requests, queues, status handling and permissions also remain correct during disconnects, high latency, resource restarts and concurrent user actions.

Compatibility with LB Phone, FiveM, common frameworks and common server resources is a release requirement, not an optional polish task.

---

## 2. Core User Experience

### 2.1 Company Overview

The main screen displays all configured companies and public services.

Every company requires:

- Company logo
- Company name
- Category
- Availability state
- Direct call button
- Create request button when requests are enabled

Optional information:

- Short description
- Opening hours
- Number of employees on duty
- Main location
- Current workload

Companies with no employee on duty are displayed in a disabled, greyed-out state.

For unavailable companies:

- Direct calls are disabled
- The availability label shows that no employee is currently on duty
- Messages may remain available if enabled
- Requests may remain available if enabled

### 2.2 Combined Search

The company overview contains one shared search field.

The search matches:

- Company names
- Categories
- Alternative keywords
- Configured services

Example placeholder:

```text
Search companies or categories...
```

Search filtering is performed locally on already loaded company data. The app must not send a server request for every typed character.

---

## 3. Companies and Categories

### 3.1 Categories

Every company belongs to at least one category.

Categories must be extensible without changing core call, duty, queue or permission logic.

Default categories are shipped with the resource, but server administrators can add new categories later through configuration or database-backed administration.

Example categories:

- Police and Justice
- Emergency Medical Services
- Taxi and Transport
- Vehicle Services
- Restaurants and Food
- Retail
- Government Services
- Real Estate
- Media
- Entertainment
- Other Services

The category controls:

- Available request templates
- Fixed request workflow steps
- Default icons and labels
- Category search matching

Each category contains:

- Stable category identifier
- Localized display name
- Localized search keywords
- Default icon
- Default request label
- Default request creation label
- Available request templates
- Available request field definitions
- Fixed request workflow steps

Adding a new category must not require writing new UI components for the normal request flow. New categories reuse the generic request creation, incoming-offer and active-request views.

Category configuration may define different player-facing labels. For example, a taxi company may show `Ride Request`, while a restaurant may show `Order` or `Reservation`.

The technical model still uses `request` internally.

### 3.2 Company Data

Each company contains:

- Unique company identifier
- Linked framework job
- Display name
- Logo
- Category
- Description
- Location
- Native LB Phone numbers
- Request settings
- Opening hours
- Active employees
- Services+ leaders
- Company-specific request label overrides
- Company-specific enabled templates
- Company-specific enabled request fields

Company configuration is cached server-side and only reloaded or redistributed when it changes.

Company-specific configuration may override supported template and field defaults. Request workflow steps remain fixed by category and cannot be customized by a company.

---

## 4. Native Phone Numbers

A company may own multiple native LB Phone numbers.

Examples:

- Main line
- Emergency line
- Booking line
- Reservation line
- Dispatch line

Each number only has three individual settings:

1. Distribution mode
2. Enabled citizen and company channels
3. Dedicated shared inbox

### 4.1 Distribution Modes

There are exactly three call distribution modes.

#### Ring All

All eligible and available employees receive the incoming call.

When one employee accepts:

- Ringing stops for all other employees
- The call is assigned to the accepting employee
- Duplicate acceptance is rejected server-side

#### Random Employee

One random eligible and available employee is selected.

If the employee declines or does not respond:

- Another eligible employee may be selected
- The caller may be moved into the queue when no employee can accept

#### Dispatch Only

The call is only offered to eligible employees who currently enabled the dispatch function.

If only one employee is on duty, the single-employee rule overrides the normal distribution behavior.

### 4.2 Dispatch Line Selection

There is no administrative staffing mode and no per-number employee allow-list.

When an employee activates dispatch:

- Every enabled company number is selected for that dispatch session by default
- The dispatcher can deselect or reselect individual numbers
- The selection is session-scoped and resets when dispatch or duty ends
- Numbers using `Dispatch Only` are offered only to dispatchers who selected that number

Normal on-duty employees remain available for enabled numbers using `Ring All` or `Random Employee`. Number selection does not control shared inbox visibility.

### 4.3 Dedicated Shared Inbox

Each phone number has its own shared company inbox.

Examples:

```text
Taxi – Main Line
Taxi – Bookings
Taxi – Emergency Line
```

Eligible employees can access:

- Shared conversations
- Shared message history
- Shared read state
- Incoming messages
- Supported attachments
- Shared locations
- Employee reply attribution

Replies are sent from the company number and never from the private employee number.

---

## 5. Employee and Duty System

### 5.1 Automatic Employee Linking

Employees are detected through their framework job.

Supported framework bridges:

- ESX
- QBCore
- Qbox
- Optional standalone adapter

The bridge exposes neutral functions such as:

```text
GetPlayerIdentifier
GetCharacterName
GetJob
GetJobGrade
IsEmployee
IsCompanyLeader
IsPlayerOnline
```

### 5.2 Pseudo Login

Opening the company portal starts a short visual login sequence.

Example:

```text
Identifying employee...
Checking company access...
Connecting to company services...
```

No real credentials are entered.

The server validates the player identity and company membership automatically.

After successful validation:

- The employee enters duty
- The company portal opens
- The employee becomes visible in the active employee list

### 5.3 Logout

When the employee logs out:

- Duty state is disabled
- The employee disappears from the active employee list
- Calls are no longer delivered
- New requests are no longer offered
- Company live updates are stopped

An employee cannot log out while a call or active request is still assigned unless the action is safely completed, cancelled or returned.

### 5.4 Employee Statuses

Services+ uses only four duty statuses:

- Available
- Busy
- On Break
- Off Duty

#### Available

The employee can receive calls and requests.

#### Busy

The employee is handling an active call or active request.

The employee does not receive automatic new assignments.

#### On Break

The employee remains visible in the company portal but receives no calls or requests.

#### Off Duty

The employee is not visible in the active employee list.

---

## 6. Simple Role System

Services+ intentionally avoids a complex permission hierarchy.

### 6.1 Leader

The leader is assigned by:

- Server configuration
- Framework job grade
- Explicit Services+ assignment

The leader can:

- Edit company data
- Manage phone numbers
- Select distribution modes
- Configure per-number channels
- Enable or disable requests
- Select request templates
- Configure active request phases
- View call and request history

The leader role cannot be selected freely by employees.

### 6.2 Dispatch

Any employee on duty may enable or disable the dispatch function for themselves.

Dispatch employees:

- Receive numbers configured as Dispatch Only
- Can accept calls
- Can accept requests
- Can view queues
- Can access enabled shared inboxes

### 6.3 Employee

Every normal employee can:

- Go on duty
- Change personal status
- Enable or disable dispatch
- Accept offered calls
- Accept offered requests
- Reply to enabled shared inboxes
- Process active requests

---

## 7. Single-Employee Rule

When exactly one employee is on duty:

- Dispatch is automatically enabled
- Dispatch cannot be disabled
- Call acceptance cannot be disabled
- Eligible calls are delivered to that employee
- Available requests are offered to that employee

This rule cannot be overridden by the leader.

When a second employee joins duty:

- Dispatch becomes optional again
- Normal distribution modes become active again

This prevents a company from appearing available while no one can actually answer.

---

## 8. Call System

### 8.1 Starting a Call

The user presses the direct call button in the company overview.

If the company has multiple numbers, a simple number selection is shown.

Example:

```text
Main Line
Emergency Line
Booking Line
```

The call is then started through the native LB Phone calling system.

### 8.2 Call Assignment

Depending on the configured distribution mode, the call is offered to:

- All eligible available employees
- One random eligible available employee
- Dispatch employees only

The authoritative call state is handled server-side.

Recommended states:

```text
queued
offered
accepted
declined
ended
```

The first valid acceptance wins.

Later acceptance attempts receive a result indicating that the call was already accepted.

### 8.3 Call Queue

If all eligible employees are busy, the caller enters the queue for that number.

Example:

```text
All employees are currently busy.

Your position: 3
```

Queues are separated by company phone number.

Stored queue data:

- Queue entry identifier
- Caller number
- Company number
- Entry time
- Current position
- Current state

Queue updates are sent only when the queue changes. There is no constant client polling.

### 8.4 Status During Calls

When an employee accepts a call:

- Status automatically changes to Busy
- No new calls or requests are assigned
- Previous status is restored when the call ends

The normal restored status is Available.

---

## 9. Requests

The internal technical model always uses `request`.

The default player-facing term is:

```text
Request
```

The visible label may be overridden by category or company configuration.

Examples:

- Taxi: Ride Request
- Restaurant: Order
- Restaurant: Reservation
- Mechanic: Service Request
- Government: Appointment

Common labels:

- Create Request
- New Request
- Accept Request
- Decline Request
- Active Request
- My Requests
- Request History

These labels are defaults only. The UI must render labels from the active category or company configuration when overrides exist.

The term `ticket` should not be used as a hardcoded global label. A company may only display `Ticket` if it is explicitly configured as that company's label.

### 9.1 Request Creation

The user selects the configured creation action.

Default:

```text
Create Request
```

A predefined template is selected from the company's enabled templates.

Company templates are resolved in this order:

1. Company-specific enabled templates
2. Category default templates
3. Global fallback templates

The server validates that the selected template is enabled for the target company.

If request options cannot be loaded or the request cannot be created for any reason, the composer remains open and shows a localized player-facing message that the request was not sent and the player should call the company instead. Internal error codes and diagnostics are not displayed to the player.

Taxi examples:

- Immediate Pickup

Vehicle service examples:

- Repair
- Towing
- Roadside Assistance

Restaurant examples:

- Order
- Reservation
- Catering

Different companies in the same category may expose different templates. For example, one restaurant may only accept reservations, while another may accept orders and catering requests.

### 9.2 Request Templates

Templates are centrally defined and can be assigned to categories and companies.

The leader can only:

- Enable or disable requests
- Enable or disable existing templates
- Assign a responsible number or inbox
- Override configured player-facing labels when allowed
- Enable or disable supported fields for an enabled template
- Mark supported fields as required or optional when allowed

There is no complex form builder.

Administrators can add new predefined categories, templates, field definitions and phases through controlled configuration or database administration.

Leaders do not create arbitrary field types, validation rules or workflows in the first release.

Supported field types:

- Description
- Location
- Phone number
- Requested time
- Number of people
- Vehicle plate
- Image
- Additional notes

Template fields define:

- Field key
- Localized label
- Field type
- Required or optional state
- Maximum length or size
- Allowed attachments when relevant
- Server-side validation rule

Phone fields are prefilled from the currently equipped LB Phone number when available, but remain editable. Their required or optional state is configurable like other supported fields and is enforced server-side.

The UI renders fields generically based on the template definition.

Examples:

- Taxi pickup requests require location and phone number.
- Scheduled taxi rides additionally require requested time.
- Restaurant orders may require notes, phone number and optional image.
- Restaurant reservations may require requested time and number of people.
- Vehicle service requests may require vehicle plate and location.

### 9.3 Request Acceptance Interface

Incoming requests are displayed and controlled like incoming phone calls.

Example:

```text
New Request

Taxi – Immediate Pickup
Legion Square

[Decline]    [Accept]
```

The title uses the configured category or company label when available.

Examples:

```text
New Ride Request
New Order
New Reservation
New Service Request
```

The interaction includes:

- Prominent incoming overlay
- Notification sound
- Accept button
- Decline button
- Server-side assignment lock
- Automatic removal from other employees after acceptance
- Duplicate acceptance protection

Calls and requests use the same generic incoming-offer component with different payload data.

### 9.4 Request Workflow Steps

After acceptance, the employee status automatically changes to Busy.

Each company has enabled workflow steps derived from its category defaults. These are the ordered processing statuses an accepted request moves through before completion.

Taxi example:

```text
Accepted
On the Way
Passenger Picked Up
Ride Active
Completed
```

Vehicle service example:

```text
Accepted
On the Way
Vehicle in Service
Completed
```

Restaurant example:

```text
Accepted
In Preparation
Ready
Delivered
Completed
```

Server administrators may add new predefined phases for new or existing categories.

Company leaders cannot remove, reorder or otherwise customize workflow steps. Every request uses the complete predefined category workflow.

Every phase belongs to a configured category or company template and is validated server-side.

### 9.5 Completing a Request

The last active phase must be completed manually.

Only then:

- The request becomes completed
- The employee returns to Available
- New calls and requests can be received
- The request is moved into history

If the request is:

- Cancelled
- Returned
- Force-closed by the leader

The assigned employee is also released from Busy.

The server must recover or safely close orphaned active requests after disconnects or resource restarts.

---

## 10. Company Portal

The company portal only lists employees who are currently on duty.

### 10.1 Active Employee List

The active team is presented as a dedicated company-portal workspace tab beside requests, inboxes and calls. It must not push the operational queues below an unbounded roster.

Displayed information:

- Employee name
- Company role or position
- Current status
- Dispatch enabled or disabled
- Active call indicator
- Active request indicator
- Direct LB Phone call and contact actions for other employees

Employees who are off duty are not shown.

Long portal lists are paginated with a compact mobile page size. The team tab supports searching by employee name or company role. Leaders are listed first, followed by the framework job grade in descending order. Status priority and employee name are used only to order employees with the same leadership and grade level.

Portal tab counters use red only for actionable or unseen items: unanswered requests, unread messages and calls not yet viewed in the calls tab. Zero counts, previously viewed calls and the active-team count use a neutral gray or light background.

### 10.2 Employee View

Employees can:

- Change status
- Enable or disable dispatch
- View incoming requests
- Process active requests
- Open enabled shared inboxes
- View call queues
- View call history
- View request history
- Log out

### 10.3 Leader View

Only leaders can access:

- Company data
- Phone number settings
- Distribution modes
- Request settings
- Template selection
- Complete call history
- Complete request history

---

## 11. Personal User Activity

Every user must be able to see their own Services+ activity.

### 11.1 My Calls

Displayed information:

- Company
- Called number
- Date and time
- Answered
- Missed
- Cancelled
- Queue duration
- Call duration

### 11.2 My Messages

Displayed information:

- Company
- Contacted company inbox
- Conversation history
- Attachments
- Locations
- Read state
- Last activity

### 11.3 My Requests

Displayed information:

- Company
- Request type
- Creation time
- Current status
- Current active phase
- Assigned employee when visible
- Completion or cancellation state

Depending on the current phase, users may:

- Add information
- Cancel the request
- Contact the company

---

## 12. History

### 12.1 Call History

Stored data:

- Caller
- Company
- Company number
- Assigned employee
- Distribution mode
- Queue duration
- Call duration
- Result
- Timestamp

### 12.2 Request History

Stored data:

- Request creator
- Company
- Template
- Assigned employee
- Status changes
- Workflow phase history
- Acceptance time
- Completion time

History lists are always paginated.

The app never loads the entire history of a company in one request.

---

## 13. Server Administration

### 13.1 Technical Configuration

Technical defaults are stored in:

```text
config.lua
```

This includes:

- Framework selection
- Database adapter
- Locale
- Debug mode
- History limits
- Cache settings
- Default categories
- Default request templates
- Fixed category request workflows
- Default request field definitions

### 13.2 In-App Administration

Content configuration is managed inside Services+.

Leaders or authorized server administrators can:

- Create companies
- Assign logos
- Select categories
- Link framework jobs
- Add native phone numbers
- Select distribution modes
- Configure per-number channels
- Enable requests
- Select templates
- Override request labels
- Select supported request fields
- Mark supported request fields as required or optional

Changes are saved server-side and distributed only to affected clients.

A full server restart should not be required for normal configuration changes.

New categories, new template definitions, new field definitions and new phase definitions are administrator-level configuration tasks.

Company leaders can configure their own company inside the available definitions, but they cannot create unrestricted custom forms or arbitrary workflow logic in version 1.

---

## 14. Technical Architecture

### 14.1 Recommended Resource Structure

```text
services-plus/
├── fxmanifest.lua
├── config.lua
├── README.md
├── CHANGELOG.md
├── shared/
│   ├── constants.lua
│   ├── categories.lua
│   ├── request_templates.lua
│   ├── request_phases.lua
│   └── locales/
├── bridge/
│   ├── esx.lua
│   ├── qbcore.lua
│   ├── qbox.lua
│   └── standalone.lua
├── client/
│   ├── main.lua
│   ├── app.lua
│   ├── calls.lua
│   ├── requests.lua
│   ├── messages.lua
│   └── notifications.lua
├── server/
│   ├── main.lua
│   ├── companies.lua
│   ├── employees.lua
│   ├── numbers.lua
│   ├── calls.lua
│   ├── queues.lua
│   ├── requests.lua
│   ├── messages.lua
│   ├── history.lua
│   └── permissions.lua
├── ui/
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── tsconfig.json
│   └── vite.config.ts
├── web/
│   └── build-output/
└── sql/
    ├── install.sql
    └── migrations/
```

Configuration layout rules:

- `config.lua` is the single Lua entry point for technical runtime configuration.
- Shared constants, categories, request templates and request phases live in `shared/`.
- Player-facing locale strings are stored separately for German and English.
- Frontend-visible locale data must be JSON-compatible.
- The resource must not modify files inside the `lb-phone` resource.

### 14.2 Frontend Stack

Recommended frontend stack:

```text
React
TypeScript
Vite
```

Reasons:

- Clear component architecture
- Strong type safety
- Reusable incoming call and request components
- Easier state management
- Local browser testing
- Better long-term maintainability

### 14.3 Communication Flow

```text
React NUI
↓
NUI Callback
↓
FiveM Client
↓
Validated Server Event
↓
Services+ Server
↓
Cache / Database / LB Phone Integration
```

Every NUI callback must always return a response.

All transmitted data must be JSON-compatible.

Initial application data must not be pushed from the LB Phone `onOpen` handler.

The frontend must request initial state after it is mounted and ready:

```text
React app mounted
↓
fetchNui("getInitialState")
↓
Client callback always responds
↓
Server validates and returns authorized state
```

Later updates are delivered through LB Phone custom app messages.

All API responses use one consistent shape:

```text
success: true, data: ...
success: false, error: { code, message }
```

Internal SQL errors, stack traces and sensitive diagnostics must never be returned to the player.

### 14.3.1 Event and API Contracts

All events and callbacks are documented before implementation.

Each contract includes:

- Event or callback name
- Direction
- Input payload
- Success response
- Error response
- Required permission
- Rate limit
- Side effects

Event names are namespaced:

```text
services-plus:server:createRequest
services-plus:server:updateRequestPhase
services-plus:client:requestUpdated
services-plus:client:employeeStatusChanged
```

Live updates should include a version or sequence number when ordering matters.

### 14.4 Database

Recommended database adapter:

```text
oxmysql
```

Recommended tables:

```text
services_plus_companies
services_plus_categories
services_plus_company_numbers
services_plus_number_employees
services_plus_employee_settings
services_plus_request_templates
services_plus_request_template_fields
services_plus_company_request_settings
services_plus_request_phases
services_plus_requests
services_plus_request_events
services_plus_call_history
services_plus_request_history
services_plus_message_assignments
```

Short-lived runtime data should remain in memory.

Runtime data includes:

- Employees on duty
- Current employee statuses
- Dispatch state
- Active calls
- Call queues
- Active requests
- Company cache

Persistent storage is only used for relevant long-term data and history.

Category, template, field and phase definitions are persistent configuration data when database-backed administration is enabled. If configuration-only mode is used, these definitions are loaded from Lua configuration and cached server-side.

Database rules:

- All queries are server-side only.
- All queries use parameters.
- SQL strings must not be built from untrusted values.
- Large lists require stable pagination.
- History lists require a maximum limit.
- Indexes must be defined for common filters and joins.
- Queries inside loops are not allowed when a batched query can be used.
- Related writes use transactions where consistency matters.
- Migrations are versioned.
- Rollback or backup instructions are documented before production migrations.

### 14.5 Cache Strategy

Server cache:

- Companies
- Categories
- Phone numbers
- Session-scoped dispatch line selections
- Request templates
- Request field definitions
- Request phases
- Company request settings

Client cache:

- Company overview
- Categories
- Template metadata for visible companies
- Current user basics
- Last loaded history pages

Updates must send only the changed entity.

Avoid:

```text
Send all companies again
```

Prefer:

```text
Company 14 updated
Employee 37 changed status
Request 921 changed phase
```

### 14.6 Network Strategy

The app must not use permanent polling loops for status synchronization.

Updates are event-driven:

- Employee enters duty
- Employee leaves duty
- Employee changes status
- Dispatch state changes
- Call starts
- Call ends
- Queue changes
- Request is created
- Request is accepted
- Request phase changes
- Company configuration changes

Only affected clients receive updates.

Large payloads must be avoided by design. Latent events may only be used when a larger transfer is unavoidable and must not replace pagination or delta updates.

### 14.7 Server Authority

Every action is validated server-side.

Examples:

- Is the player part of the company?
- Is the player on duty?
- Is the number enabled and selected when dispatch selection applies?
- Is the player allowed to change this setting?
- Is the request still available?
- Was the call already accepted?
- Is the employee already busy?
- Is the status transition valid?

The client must never be authoritative for:

- Roles
- Company membership
- Call acceptance winner
- Request assignment
- Request state
- History records
- Phone number ownership

The server must also derive or validate:

- Sender identity
- Phone number ownership
- Company relationship
- Job and grade
- Leader status
- Request creation time
- Request status transitions
- Message sender number
- Queue position
- Call and request assignment target

### 14.8 Rate Limits

Server-side rate limits are required for:

- Request creation
- Message sending
- Status changes
- Dispatch toggling
- Company search endpoints when used
- History loading
- Configuration changes
- Call queue actions

### 14.9 Restart Safety

On resource start:

- Validate dependencies
- Wait until `lb-phone` exports are available
- Register the LB Phone custom app through the official `AddCustomApp` export
- Validate the `AddCustomApp` return value
- Log registration failures with an actionable error
- Load configuration
- Check database version
- Build required caches
- Restore or resolve active persistent states

On resource stop:

- Remove the custom app through the official `RemoveCustomApp` export
- Stop timers
- Remove temporary listeners
- Clean runtime state
- Safely resolve open server-side operations

Duplicate listeners and duplicate app registration must be prevented.

The custom app must be registered again when `lb-phone` restarts after Services+.

### 14.10 Frontend Lifecycle

When the app opens:

- Initialize local UI state
- Register NUI message listeners
- Request initial state through `getInitialState`
- Load visible data only

When the app closes or unmounts:

- Remove NUI message listeners
- Stop timers
- Cancel pending UI-only work when possible
- Pause media
- Revoke temporary object URLs
- Clear temporary state that must not survive the session

The frontend must not keep background polling, animations, listeners or media alive after the app closes.

### 14.11 Compatibility and Integration Boundaries

Services+ is developed as a separate FiveM resource.

It must not edit or monkey-patch:

- `lb-phone`
- Framework resources
- Inventory resources
- Dispatch resources
- Billing resources
- Map or GPS resources
- Other phone apps

All integrations use public exports, documented events or explicit adapter files.

Required compatibility targets:

- Current supported LB Phone version
- ESX
- QBCore
- Qbox
- Optional standalone mode
- OneSync
- FiveM NUI / CEF
- `oxmysql`

Common resource compatibility targets:

- Existing job systems
- Existing dispatch systems
- Existing notification systems
- Existing billing or invoice systems
- Existing inventory systems
- Existing map, waypoint or location systems

Integrations with common resources are optional adapters. The core Services+ workflow must still work when an optional third-party resource is missing.

Dependency rules:

- `lb-phone` is required.
- `oxmysql` is the recommended database dependency.
- Framework dependencies are selected through the bridge configuration.
- Optional integrations are detected at runtime before use.
- Missing optional integrations must degrade gracefully.
- Missing required dependencies must produce clear startup errors.

Conflict prevention:

- All events are namespaced with `services-plus`.
- All exports are namespaced or documented.
- All database tables use the `services_plus_` prefix.
- Global variables are avoided.
- Shared state remains inside the Services+ resource.
- The default LB Phone services app is only replaced or hidden through supported LB Phone configuration or exports.

The app must not assume that it is the only resource using company jobs, phone numbers, notifications, locations or billing.

Any integration that can trigger money transfer, inventory changes, dispatch alerts, waypoints or external side effects must be isolated behind a server-side adapter and must include permission checks, rate limits and failure handling.

### 14.12 External Dispatch and MDT Contract

Services+ owns the request lifecycle and one primary responsible employee. It does not model patrol units, multiple unit members, live officer or vehicle locations, dispatch maps, radio channels or MDT-specific state.

Trusted external resources can correlate their own domain state through stable Services+ request IDs and server-resolved employee identifiers. The documented server API provides bounded request and on-duty employee reads plus validated request acceptance, decline, transition and return actions. Every write still requires a real player source and passes the normal Services+ employment, availability, assignment, workflow and rate-limit checks.

A single stable local lifecycle event exposes sanitized integration request entities containing the status, workflow step, primary assignee snapshot, optional active player source, request coordinates and external reference. Existing specific lifecycle events remain available for compatibility. External resources must consume local events or documented exports and must never invoke Services+ network events directly.

An external police dispatch can therefore display a Services+ request on its own live map and associate any number of patrol units or officers in its own storage. Services+ only retains the primary employee responsible for the phone request and does not duplicate the external unit model.

---

## 15. Development Plan – Four Phases

# Phase 1 – Foundation and Core Company System

## Goal

Build a stable Services+ base with company overview, duty handling, company portal and reliable LB Phone integration.

## Technical Research and Prototypes

Before full implementation, create isolated prototypes for:

1. LB Phone custom app registration
2. Custom app restart behavior
3. Native company phone number handling
4. Native call start and end detection
5. Company message events
6. Multiple company numbers
7. Shared inbox behavior
8. NUI focus and input behavior
9. LB Phone restart behavior
10. Framework job detection
11. Optional integration detection
12. Missing optional resource fallback behavior

## Implementation

- Resource structure
- `fxmanifest.lua`
- Framework bridge
- Optional integration adapter structure
- Dependency validation with clear startup errors
- Database schema
- Versioned database migrations
- App registration through `AddCustomApp`
- App removal through `RemoveCustomApp`
- Duplicate registration protection
- `lb-phone` restart re-registration
- `getInitialState` NUI callback
- Shared API response schema
- Documented event and callback contracts
- Company overview
- Company logos
- Category display
- Combined company and category search
- Greyed-out unavailable companies
- Automatic employee detection
- Pseudo login
- Duty login and logout
- Employee statuses
- Leader role
- Employee-controlled dispatch toggle
- Single-employee rule
- Company portal
- Active employee list
- Basic leader configuration
- Frontend open and close lifecycle cleanup
- Integration boundary documentation

## Testing

- Resource starts before and after LB Phone
- Resource restart without server restart
- LB Phone restart
- Missing required dependency startup failure
- Missing optional dependency graceful fallback
- App registration failure handling
- Duplicate app registration prevention
- Initial state request after frontend mount
- Player join and leave
- Job change
- Employee removal while on duty
- Multiple characters
- Duplicate event registration
- Invalid NUI payloads
- Unauthorized server events
- Malformed callback payloads still receive responses
- 50 to 100 configured companies
- Local search without repeated server requests
- Light and dark mode
- NUI input focus
- NUI listeners and timers are cleaned up after close
- No conflict with existing job resources
- No conflict with existing notification resources
- No conflict with existing dispatch resources when integration is disabled

## Code Review Focus

- Event namespace consistency
- Documented event and callback contracts
- Guaranteed callback responses
- Server-side permission checks
- Consistent API response shape
- Cache invalidation
- Duplicate listeners
- Duplicate app registration
- Unnecessary loops
- Unnecessary full-state updates
- Frontend lifecycle cleanup
- Optional integration isolation
- No direct edits to third-party resources
- No global state conflicts
- English code and documentation

## Completion Criteria

Phase 1 is complete when:

- Services+ opens and closes reliably
- Companies display correctly
- Unavailable companies are correctly disabled
- Duty states remain synchronized
- Leader and dispatch permissions are correct
- Single-employee behavior works
- Restarts do not leave invalid employee states
- `getInitialState` is the only initial data loading path
- App registration and removal are restart-safe
- NUI listeners and timers are removed when the app closes

---

# Phase 2 – Calls, Shared Inboxes and Requests

## Goal

Deliver the complete communication and request workflow.

## Call Implementation

- Multiple native numbers per company
- Session-scoped dispatch line selection
- Three distribution modes
- Call acceptance locking
- Automatic Busy status
- Call queues per number
- Queue position updates
- Personal call history
- Company call history

## Message Implementation

- Dedicated shared inbox per number
- Shared conversations
- Shared read state
- Replies through company number
- Personal company message overview
- Supported attachment tests
- Supported location tests

## Request Implementation

- Extensible predefined templates per category
- Company-specific enabled templates
- Company-specific request label overrides
- Generic request form rendering from supported field definitions
- Request creation
- Incoming request UI matching incoming calls
- Accept and decline
- Server-side assignment lock
- Automatic Busy status
- Active request phases
- Manual completion
- Request return and cancellation
- Personal request overview
- Company request history

## Functional Testing

- Two employees accept the same call simultaneously
- Two employees accept the same request simultaneously
- Employee disconnects during acceptance
- Caller leaves the queue
- Employee changes to On Break while ringing
- Dispatch is disabled while a call is offered
- Single-employee state begins during an active session
- Single-employee state ends when another employee joins
- Request is cancelled during an active phase
- Employee disconnects during an active request
- Resource restarts during an active request
- LB Phone restarts during an active call
- Company number permissions change during an active session
- Company A and Company B in the same category expose different templates
- Taxi request fields differ from restaurant order fields
- Company-specific request labels render correctly
- Disabled templates cannot be submitted through manipulated client payloads
- Required template fields are enforced server-side
- Unknown category, template, field and phase identifiers are rejected server-side

## Compatibility Testing

Test at least:

- ESX
- QBCore
- Qbox
- Standalone bridge mode
- OneSync
- FiveM NUI / CEF
- Different screen resolutions
- Light mode
- Dark mode
- Native LB Phone audio configuration
- NUI-based LB Phone audio configuration
- LB Phone app list behavior when the default services app is disabled or replaced
- LB Phone app list behavior when the default services app remains enabled
- Server with existing dispatch resource
- Server with existing billing or invoice resource
- Server with existing notification resource
- Server with existing inventory resource
- Server with existing map or waypoint resource
- Server without optional dispatch integration
- Server without optional billing integration
- Server without optional inventory integration
- Resource start order variations for optional integrations
- Restart of optional integration resources while Services+ is running

## Load Testing

Simulate:

- Multiple parallel calls
- Multiple queues
- 20 to 50 employees in one company
- 100 active users
- Frequent status changes
- Large histories
- Rapid repeated accept and decline attempts
- High-latency clients

## Code Review Focus

- Race conditions
- Duplicate acceptance protection
- Queue consistency
- Request state transitions
- Category and company request configuration resolution
- Generic request field validation
- Label override fallback behavior
- Busy status restoration
- Message permission checks
- Optional integration permission checks
- Optional integration failure handling
- Payload size
- History pagination
- Database query count
- Missing disconnect cleanup

## Completion Criteria

Phase 2 is complete when:

- Duplicate acceptance is impossible
- Queue order remains correct
- Employee status is always restored correctly
- Messages always reach the correct inbox
- Requests recover or close safely after restart
- Only actual changes generate network updates

---

# Phase 3 – Stabilization, Bug Search and Release Candidate

## Goal

Prepare Services+ for real server operation and produce a technically validated release candidate.

## Systematic Bug Search

Search the complete codebase for:

- Infinite loops
- Unnecessary threads
- Unremoved event handlers
- Missing callback responses
- Unprotected network events
- Duplicate database queries
- Queries inside loops
- Race conditions
- Uncleaned timers
- Orphaned calls
- Orphaned requests
- Invalid permission paths
- Oversized network payloads
- Full-list updates where deltas are sufficient
- NUI memory leaks
- Missing error handling
- Invalid state transitions
- Duplicate app registration
- Stale caches

## Automated Checks

Frontend:

- TypeScript type checking
- ESLint
- Production build
- Component tests
- Search logic tests
- Status state tests
- Request phase tests

Lua and Server:

- Lua static checks
- Event validation tests
- Permission tests
- Database migration tests
- Database rollback or backup procedure check
- Database index checks for common queries
- Query batching checks
- Framework adapter tests
- Duplicate request tests
- Restart recovery tests

## Manual End-to-End Tests

Test the complete workflow as:

- Normal user
- Employee
- Dispatch employee
- Leader
- Unauthorized player

Additional scenarios:

- High latency
- Rapid open and close actions
- Switching between phone apps
- Closing the phone during calls
- Character switch
- Resource restart
- Server restart
- Database reconnect
- Multiple simultaneous calls
- Full queues
- Missing company logo
- Long company names
- Empty company list
- Empty inbox
- Empty history

## Performance Measurement

Measure:

- Client `resmon` while idle
- Client `resmon` while app is open
- Server CPU usage
- Database queries per action
- Network payload sizes
- Number of network events
- UI memory use
- Company overview load time
- Large history load time
- UI re-render count

## Logging and Diagnostics

Provide configurable log levels:

- Debug
- Info
- Warning
- Error

Log important failures such as:

- Failed custom app registration
- Invalid framework data
- Rejected permission attempts
- Duplicate acceptance attempts
- Unresolved call states
- Orphaned active requests
- Database failures
- NUI callback failures

Debug logging must be disabled by default in production.

## Release Documentation

Required files:

- `README.md`
- `CHANGELOG.md`
- Installation guide
- Configuration guide
- Framework compatibility guide
- Optional integration guide
- Compatibility matrix
- Database migration guide
- Database rollback guide
- Backup instructions
- Troubleshooting guide
- Event and API documentation

## Release Checklist

Before release, verify:

- TypeScript compiles without errors
- ESLint reports no relevant issues
- Production frontend build succeeds
- All NUI callbacks always respond
- All events and callbacks are documented
- All client inputs are validated server-side
- Permissions are tested for user, employee, dispatch and leader paths
- Rate limits are active for write and expensive actions
- Large lists are paginated
- No unnecessary global broadcasts exist
- No avoidable database queries run inside loops
- Database indexes are checked
- Resource restart is tested
- LB Phone restart is tested
- Server restart is tested
- Required dependency failures are documented and tested
- Optional integration fallback behavior is tested
- Existing dispatch, billing, inventory, notification and map resources are not modified
- Event, export and database namespaces do not conflict with common resources
- Dark mode is tested
- Light mode is tested
- Empty and missing data states are tested
- High latency is simulated
- Duplicate requests are tested
- Resmon is checked while idle and while the app is open
- Client and server profiler data is reviewed for critical workflows
- Production build excludes development-only files
- Database migration and rollback steps are documented
- Backup instructions are complete
- README and changelog are current

## Completion Criteria

The Phase 3 release candidate is technically complete when:

- No known critical or high-severity bugs remain
- Core workflows survive resource and server restarts
- ESX, QBCore and Qbox are tested
- Standalone bridge mode is tested when enabled
- Optional integrations degrade gracefully when missing
- Compatibility with common dispatch, billing, inventory, notification and map resources is tested or documented as unsupported
- Idle resource usage is minimal
- No unnecessary permanent network traffic exists
- All server events are validated
- All NUI callbacks are guaranteed to answer
- The complete API surface is frozen and inventoried for Phase 4
- Database migrations, rollback and backups are documented
- Installation and configuration documentation is complete
- All code and technical documentation are written in English

---

# Phase 4 – Complete API and Integration Documentation

## Goal

Provide one authoritative, comprehensive Markdown reference that explains every Services+ interface offered to other resources, the phone frontend and integration developers. The documentation is a release requirement and must remain synchronized with the implemented contracts.

## Required Deliverable

The resource must ship a complete English-language `API.md` in the Services+ resource root.

`README.md` and `INTEGRATIONS.md` must link to `API.md` instead of duplicating or contradicting its contracts. `CHANGELOG.md` must identify API additions, breaking changes, deprecations and API version changes.

## Required API Inventory

`API.md` must document every implemented interface category:

- Trusted server exports offered to allow-listed resources
- Local server lifecycle and integration events emitted by Services+
- Client-to-server and NUI callback contracts used by the Services+ app
- Custom app push-message types sent through LB Phone
- Optional adapter hooks and supported integration boundaries
- Shared response envelopes, public entities and integration-only entities
- API version, compatibility expectations and deprecation policy

Internal implementation functions that are not supported integration surfaces must be clearly marked as internal and must not be presented as callable APIs.

## Required Contract Details

Every documented export, event, callback and push message must include:

- Stable name and direction
- Purpose and intended consumer
- Required resource or runtime context
- Input payload with field names, types, optional fields and limits
- Success response payload
- Error response codes and retryability
- Permission and role requirements
- Rate limit
- Server-side validation performed
- Database or gameplay side effects
- Events or push updates emitted as a result
- Restart, idempotency and concurrency behavior where relevant
- API version in which the contract was introduced or changed

## Integration Examples

The documentation must provide tested Lua examples for:

- Reading companies, phone numbers and on-duty employees
- Reading and paginating company requests
- Creating an idempotent external request
- Accepting, declining, transitioning and returning a request
- Listening to `services-plus:server:requestLifecycle`
- Correlating a Services+ request ID with an external MDT or dispatch record
- Handling success and error envelopes without trusting client data
- Configuring `Config.ApiAllowedResources`

The MDT example must explain that Services+ stores one primary request assignee while patrol units, multiple officers, vehicles, radio state and live locations remain owned by the external system.

## Diagrams and Reference Tables

`API.md` must contain:

- A request lifecycle/state-transition diagram
- A call lifecycle summary
- A message and shared-inbox flow summary
- A permissions matrix for citizen, employee, dispatch, leader, administrator and trusted resource access
- An event audience matrix
- A versioned entity reference for company, employee, request, assignee, conversation, message and error payloads

Diagrams must be represented in Markdown-compatible text or Mermaid so the documentation remains usable without proprietary tooling.

## Documentation Verification

Before Phase 4 is complete:

- Compare the export list in `server/exports.lua` with `API.md`
- Compare server event emissions with the documented event table
- Compare NUI callback allow-lists and rate-limit configuration with the callback table
- Verify all example names, payloads and response fields against the current source
- Execute or contract-test the supplied integration examples where practical
- Search for undocumented public exports, events and push-message types
- Confirm that no example bypasses server authorization or invokes internal network events
- Confirm that sensitive integration-only fields are not documented as citizen-facing data
- Verify all links from `README.md` and `INTEGRATIONS.md`

## Completion Criteria

Phase 4 is complete when:

- `API.md` documents every supported API and integration surface in full
- Every contract includes permissions, validation, rate limits, side effects and errors
- Copy-ready Lua examples cover the supported integration workflows
- API entities and lifecycle behavior are documented unambiguously
- External MDT and dispatch ownership boundaries are explicit
- Automated contract checks detect missing documented exports and events
- `README.md`, `INTEGRATIONS.md`, `CHANGELOG.md` and `API.md` agree
- No supported public interface remains undocumented
- All technical documentation is written in English

Services+ is release-ready only after the Phase 4 documentation review and contract verification have passed.

---

## 16. Scope Limits for Version 1

The first stable version does not include:

- Custom role builders
- Complex form builders
- AI-based assignment
- Public ratings
- Advanced employee analytics
- Live map tracking
- Multiple simultaneous active requests per employee
- Automatic pricing
- External web administration
- Complex workflow editors
- Excessive dashboards

Version 1 does include controlled extensibility for categories, request labels, predefined templates, supported field definitions and predefined phases.

This is not a complex form builder. Administrators can add or configure predefined building blocks, while company leaders can enable, disable or label those building blocks within allowed limits.

Version 1 focuses on:

```text
Find a company
Call a company
Message a company
Create a request
Go on duty
Accept a call or request
Process the request
Complete the request
```

---

## 17. Definition of Done

A Services+ feature is complete only when:

1. The feature is functionally complete.
2. The UI is responsive and understandable.
3. All important decisions are validated server-side.
4. All inputs are validated.
5. Network payloads are minimized.
6. Database access is optimized.
7. Error states are handled.
8. Restart and disconnect scenarios work.
9. Code and technical documentation are written in English.
10. A dedicated code review was completed.
11. Relevant tests passed.
12. Performance was measured.
13. No known critical or high-severity bugs remain.
14. Official LB Phone and FiveM documentation was rechecked for relevant changes.

---

## 18. Development Principles

> The server is authoritative.

> Never trust client-provided data.

> Send the smallest possible payload to the smallest possible audience.

> Prefer events over polling.

> Load initial data only when the UI is ready.

> Use official LB Phone exports instead of bypassing the integration layer.

> Every callback must return a response.

> Every write operation must be validated and rate-limited.

> Review code continuously, not only before release.

> Stable and maintainable code is more valuable than a quickly assembled feature.

> A smooth interface must never come at the cost of server security or data integrity.
