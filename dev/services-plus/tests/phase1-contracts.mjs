import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => readFile(resolve(root, path), "utf8");

const [manifest, callbacks, clientApp, serverEvents, schema] = await Promise.all([
  read("fxmanifest.lua"), read("client/callbacks.lua"), read("client/app.lua"),
  read("server/events.lua"), read("sql/install.sql")
]);

assert.match(manifest, /dependencies\s*\{[\s\S]*"lb-phone"/);
assert.match(manifest, /dependencies\s*\{[\s\S]*"oxmysql"/);
assert.match(clientApp, /AddCustomApp/);
assert.match(clientApp, /RemoveCustomApp/);
assert.match(clientApp, /SendCustomAppMessage/);
assert.doesNotMatch(clientApp, /SendNUIMessage/);
assert.match(callbacks, /getInitialState/);
assert.match(callbacks, /createRequest/);
assert.match(callbacks, /getMyActivity/);
assert.match(callbacks, /adminSaveCompany/);
assert.match(callbacks, /getEmployeeContact/);
assert.match(callbacks, /SetContactModal/);
assert.match(callbacks, /callback\(response\)/);
assert.match(callbacks, /callback\(ServicesPlus\.Ok/);

for (const event of serverEvents.matchAll(/(?:RegisterNetEvent|TriggerClientEvent)\("([^"]+)"/g)) {
  assert.ok(event[1].startsWith("services-plus:"), `Unnamespaced network event: ${event[1]}`);
}

for (const table of [
  "settings", "companies", "categories", "company_numbers", "employee_settings",
  "request_templates", "request_template_fields", "company_request_settings", "request_phases",
  "requests", "request_events", "call_history", "request_history", "message_assignments"
]) {
  assert.ok(schema.includes(`services_plus_${table}`), `Missing schema table: services_plus_${table}`);
}

const api = await read("server/api.lua");
assert.match(api, /IsServerAdmin/);
assert.match(api, /function Api\.adminSaveCompany/);
assert.match(api, /function Api\.getMyActivity/);
assert.match(api, /function Api\.getEmployeeContact/);
assert.match(schema, /background_image/);
assert.match(schema, /dispatch_mode/);
assert.doesNotMatch(serverEvents, /updateCompany\s*=\s*true/);

console.log("Phase 1 resource contracts passed.");
