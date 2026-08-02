# Services+ Phase 1 API Contracts

All payloads are JSON-compatible. Every response uses `{ success, data? , error? }`.
Server events are request/response based and return through `services-plus:client:response`.

| Name | Direction | Input | Permission | Rate limit | Side effect |
| --- | --- | --- | --- | --- | --- |
| `getInitialState` | NUI to client to server | `{}` | Phone user | 12/min | None |
| `enterDuty` | NUI to client to server | `{}` | Framework employee | 5/30 sec | Creates runtime duty state |
| `leaveDuty` | NUI to client to server | `{}` | On-duty employee | 5/30 sec | Removes runtime duty state |
| `updateStatus` | NUI to client to server | `{ status }` | On-duty employee | 15/30 sec | Updates employee status |
| `toggleDispatch` | NUI to client to server | `{ enabled }` | On-duty employee | 10/30 sec | Updates dispatch preference |
| `updateCompanyOperations` | NUI to client to server | `{ companyId, patch }` | Company leader | 8/min | Persists request/message toggles and dispatch mode |
| `startCompanyCall` | NUI to client to server | `{ companyId, numberId? }` | Phone user | 8/30 sec | Records an owned call attempt and returns an authorized number |
| `getEmployeeContact` | NUI to client to server | `{ targetSource }` | Active colleague | 10/30 sec | Resolves an equipped number after same-company validation |
| `createRequest` | NUI to client to server | `{ companyId, details, location? }` | Phone user | 4/min | Creates an owned pending request |
| `getMyActivity` | NUI to client to server | `{ limit }` | Phone user | 12/min | Loads only the caller's calls and requests |
| `getAdminState` | NUI to client to server | `{}` | Server administrator | 8/min | Loads administrative configuration |
| `adminSaveCompany` | NUI to client to server | `{ company }` | Server administrator | 10/min | Creates or replaces a company and its numbers |
| `adminDeleteCompany` | NUI to client to server | `{ companyId }` | Server administrator | 5/min | Deletes a company and invalidates duty sessions |
| `adminUpdateSettings` | NUI to client to server | `{ settings }` | Server administrator | 8/min | Persists global Services+ switches |

Push events sent through `SendCustomAppMessage` use `{ type, version, timestamp, payload }`.

| Type | Audience | Payload |
| --- | --- | --- |
| `company.updated` | All app clients | Public company entity |
| `company.deleted` | All app clients | `{ id }` |
| `settings.updated` | All app clients | Public global settings |
| `employee.updated` | On-duty members of company | Public employee entity |
| `employee.removed` | On-duty members of company | `{ companyId, source }` |
| `session.invalidated` | Affected player | `{ reason }` |

Malformed requests and denied actions always receive an error envelope. Internal errors are logged server-side and never exposed to clients.

Company leaders cannot edit company identity, framework job, category, logo, card background, public profile, keywords, or phone numbers. Those fields require server-administrator authorization. They can configure the operational dispatch mode.
