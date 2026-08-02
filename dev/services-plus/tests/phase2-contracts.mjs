import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => readFile(resolve(root, path), "utf8");
const [manifest, callbacks, events, config, repository, calls, inboxes, requests, definitions, constants, schema, migration, mediaMigration, operationsMigration, staffingMigration, phoneComponents, messageComposer, clientApp, companies, employees, clientMain, workspace, publicApi, serverApi, adminPanel, requestComposer] = await Promise.all([
  read("fxmanifest.lua"), read("client/callbacks.lua"), read("server/events.lua"), read("config.lua"),
  read("server/repository.lua"), read("server/calls.lua"), read("server/inboxes.lua"), read("server/requests.lua"),
  read("shared/request_definitions.lua"), read("shared/constants.lua"), read("sql/install.sql"), read("sql/migrations/004_phase2_communications.sql"),
  read("sql/migrations/005_phase2_media_reactions.sql"), read("sql/migrations/006_phase2_competition_duty_dispatch_deletion.sql"), read("sql/migrations/007_phase2_number_staffing_notifications_navigation_api.sql"), read("ui/src/lib/phoneComponents.ts"), read("ui/src/components/MessageComposer.tsx"), read("client/app.lua"),
  read("server/companies.lua"), read("server/employees.lua"), read("client/main.lua"), read("ui/src/components/CompanyWorkspace.tsx"), read("server/exports.lua"), read("server/api.lua"), read("ui/src/components/AdminPanel.tsx"), read("ui/src/components/RequestComposer.tsx")
]);

for (const module of ["server/calls.lua", "server/inboxes.lua", "server/requests.lua", "shared/request_definitions.lua"]) {
  assert.ok(manifest.includes(`"${module}"`), `Manifest does not load ${module}`);
}

const actions = [
  "registerIncomingCall", "acceptCall", "declineCall", "endCustomCall", "getRequestOptions", "getCompanyWorkspace",
  "acceptRequest", "declineRequest", "transitionRequest", "returnRequest", "cancelRequest", "updateRequestSettings",
  "updateNumberEligibility", "sendCitizenMessage", "sendEmployeeMessage", "getCitizenInbox", "getConversationMessages", "reactToMessage",
  "adminUpdateCategory", "deleteRequest", "deleteConversation", "deleteMessage"
  , "updateNumberOperations", "toggleNumberSubscription"
];
for (const action of actions) {
  assert.ok(events.includes(`${action} = true`), `Server action is not allow-listed: ${action}`);
  assert.ok(config.includes(`${action} = { limit =`), `Server action has no rate limit: ${action}`);
  assert.ok(callbacks.includes(`"${action}"`), `Client callback is missing: ${action}`);
}

for (const table of ["call_queue", "inbox_conversations", "inbox_messages", "inbox_reads"]) {
  assert.ok(schema.includes(`services_plus_${table}`), `Install schema is missing services_plus_${table}`);
  assert.ok(migration.includes(`services_plus_${table}`), `Migration is missing services_plus_${table}`);
}
assert.match(schema, /\(4, 'phase2_communications'\)/);
assert.match(schema, /\(5, 'phase2_media_reactions'\)/);
assert.match(schema, /\(6, 'phase2_competition_duty_dispatch_deletion'\)/);
assert.match(schema, /\(7, 'phase2_number_staffing_notifications_navigation_api'\)/);
assert.match(staffingMigration, /services_plus_number_subscriptions/);
assert.match(staffingMigration, /staffing_mode/);
assert.match(staffingMigration, /target_number_id/);
assert.match(staffingMigration, /external_source[\s\S]*external_id/);
assert.ok(schema.includes("services_plus_inbox_message_reactions"));
assert.ok(mediaMigration.includes("services_plus_inbox_message_reactions"));
assert.match(operationsMigration, /services_plus_requests[\s\S]*deleted_at/);
assert.match(operationsMigration, /services_plus_inbox_conversations[\s\S]*deleted_at/);
assert.match(operationsMigration, /services_plus_inbox_messages[\s\S]*deleted_at/);
assert.match(repository, /AcceptCallQueue[\s\S]*assigned_identifier` IS NULL/);
assert.match(repository, /AcceptRequest[\s\S]*assigned_identifier` IS NULL/);
assert.match(calls, /isEligible\(employee, company, number\)[\s\S]*AcceptCallQueue/);
assert.match(calls, /lb-phone:newCall/);
assert.match(calls, /lb-phone:callEnded/);
assert.match(calls, /SendNotification/);
assert.match(calls, /resource == "lb-phone"/);
assert.match(inboxes, /canUseNumber\(employee, conversation\.number_id\)/);
assert.match(inboxes, /number\.inboxEnabled/);
assert.match(inboxes, /SendMessage/);
assert.match(inboxes, /SendCoords/);
assert.match(inboxes, /MessageReactions\[emoji\]/);
assert.match(inboxes, /canUseNumber\(employee, context\.number_id\)/);
assert.match(repository, /ToggleMessageReaction/);
assert.match(repository, /GetVisibleRequests[\s\S]*category_id/);
assert.match(repository, /DeleteRequest[\s\S]*deleted_at/);
assert.match(repository, /DeleteConversation[\s\S]*deleted_at/);
assert.match(repository, /DeleteInboxMessage[\s\S]*deleted_at/);
assert.match(constants, /\["👍"\]/);
assert.match(constants, /\["🍔"\]/);
assert.match(constants, /occupied = true/);
assert.match(phoneComponents, /components\.setGallery/);
assert.doesNotMatch(messageComposer, /attachmentUrl|type="url"/);
assert.match(requests, /template_disabled/);
assert.match(requests, /invalid_transition/);
assert.match(requests, /field\.enabled ~= false/);
assert.match(requests, /SendNotification/);
assert.match(requests, /request\.citizen\.updated/);
assert.match(requests, /requestNavigation/);
assert.match(requests, /navigationOnAccept/);
assert.match(requests, /resolvedTemplateIds/);
assert.match(requests, /field\.type == "select"[\s\S]*option\.value == value/);
assert.match(definitions, /generalTemplates = \{ "general", "appointment", "complaint", "information", "callback" \}/);
assert.match(definitions, /immediate_pickup[\s\S]*location[\s\S]*people[\s\S]*phone/);
assert.doesNotMatch(definitions, /scheduled_pickup/);
for (const template of ["roadside_assistance", "delivery", "reservation", "medical_transport", "property_viewing", "legal_assistance", "police_report"]) {
  assert.ok(definitions.includes(template), `Missing specialized request template: ${template}`);
}
assert.match(definitions, /legal_area[\s\S]*criminal_law[\s\S]*civil_law/);
assert.match(serverApi, /phoneNumber = ServicesPlus\.Bridge\.GetEquippedPhoneNumber\(source\)[\s\S]*settings\.defaultPhone = phoneNumber and tostring\(phoneNumber\) or ""/);
assert.match(requestComposer, /optgroup label=\{t\(locale, "generalRequests"\)\}/);
assert.match(requestComposer, /optgroup label=\{t\(locale, "specialRequests"\)\}/);
assert.match(requestComposer, /initialValues[\s\S]*defaultPhone/);
assert.match(requests, /customData[\s\S]*requestNotificationAction[\s\S]*action = "accept"/);
assert.match(clientApp, /handleRequestOfferAction[\s\S]*RequestServer\(action/);
assert.match(clientApp, /requestNotificationAction[\s\S]*handleRequestOfferAction\(data\.id, data\.action\)/);
assert.match(clientApp, /ToggleOpen\(true, true\)[\s\S]*OpenApp\(APP_IDENTIFIER\)/);
assert.match(clientApp, /RegisterKeyMapping\("servicesPlusAcceptRequest"[\s\S]*"RETURN"\)/);
assert.match(clientApp, /RegisterKeyMapping\("servicesPlusDeclineRequest"[\s\S]*"BACK"\)/);
assert.match(companies, /requestCompetition/);
assert.match(requests, /Requests\.CanHandle[\s\S]*GetCategoryRequestCompetition/);
assert.match(employees, /servicesPlusDuty/);
assert.match(employees, /ToggleNumberSubscription/);
assert.match(employees, /SyncPhoneNumbers/);
assert.match(employees, /dispatchNumberSelections = enabled and \{\} or nil/);
assert.match(employees, /employee\.dispatchNumberSelections\[number\.id\] ~= false/);
assert.match(employees, /phoneNumber == saved\.phoneNumber/);
assert.match(inboxes, /Employees\.IsNumberAuthorized\(employee, number\)/);
assert.doesNotMatch(inboxes, /Employees\.CanUseNumber\(employee, number\)/);
assert.match(serverApi, /authorized = authorized/);
assert.match(serverApi, /employee\.dispatchEnabled or number\.staffingMode/);
assert.match(serverApi, /numberEligibility\[company\.id\] = entries/);
assert.match(serverApi, /local isAdmin = ServicesPlus\.Bridge\.IsServerAdmin\(source\)/);
assert.match(clientMain, /lb-phone:numberChanged[\s\S]*phoneChanged/);
assert.match(workspace, /deleteRequest/);
assert.match(workspace, /deleteConversation/);
assert.match(workspace, /inbox-number-tabs/);
assert.match(workspace, /number\.inboxEnabled && number\.authorized/);
assert.match(workspace, /navigationOnAccept/);
for (const label of ["numberLabel", "phoneNumber", "callDistribution", "staffingMode", "numberCapabilities"]) {
  assert.ok(adminPanel.includes(`t(locale, "${label}")`), `Admin number field is missing label: ${label}`);
}
assert.match(adminPanel, /numberCapabilitiesHint/);
for (const exported of ["GetCompany", "GetCompanyNumbers", "GetRequest", "GetCompanyRequests", "CreateRequest", "TransitionRequest", "SendCompanyMessage"]) {
  assert.ok(publicApi.includes(`exports(\"${exported}\"`), `Missing public server export: ${exported}`);
}
assert.match(publicApi, /ApiAllowedResources/);
assert.match(publicApi, /externalId/);
assert.doesNotMatch(events, /deleteCall/);
assert.match(definitions, /immediate_pickup/);
assert.match(definitions, /order/);
assert.match(definitions, /restaurants_food/);
assert.doesNotMatch(events, /TriggerClientEvent\([^\n]*-1/);

console.log("Phase 2 resource contracts passed.");
