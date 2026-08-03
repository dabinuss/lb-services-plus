import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { dirname, extname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => readFile(resolve(root, path), "utf8");
const [manifest, callbacks, events, config, api, exportsFile, apiDocs, repository, calls, schema, constants, packageJson, app, bridge, integrations, main, logger] = await Promise.all([
  read("fxmanifest.lua"), read("client/callbacks.lua"), read("server/events.lua"), read("config.lua"), read("server/api.lua"),
  read("server/exports.lua"), read("docs/api/API.md"), read("server/repository.lua"), read("server/calls.lua"), read("sql/install.sql"),
  read("shared/constants.lua"), read("ui/package.json"), read("ui/src/App.tsx"), read("bridge/server.lua"), read("integrations/server.lua"), read("server/main.lua"), read("server/logger.lua")
]);

const callbackBlock = callbacks.match(/local callbacks = \{([\s\S]*?)\n\}/)?.[1] ?? "";
const callbackActions = [...callbackBlock.matchAll(/"([A-Za-z]+)"/g)].map((match) => match[1]);
const allowedActions = Object.keys(JSON.parse(await read("shared/api_contracts.json")).actions);

assert.ok(callbackActions.length > 20, "Expected the complete NUI callback inventory");
for (const action of allowedActions) {
  assert.match(config, new RegExp(`\\b${action}\\s*=\\s*\\{\\s*limit\\s*=`), `Missing rate limit for ${action}`);
  assert.match(api, new RegExp(`function Api\\.${action}\\(`), `Missing server API handler for ${action}`);
}
for (const action of callbackActions) assert.ok(allowedActions.includes(action), `NUI callback is not server allow-listed: ${action}`);

assert.match(callbacks, /local answered = false[\s\S]*if answered then return[\s\S]*callback\(response\)/, "Generic callbacks must answer once");
assert.match(app, /const run = async[\s\S]*try \{[\s\S]*catch \{[\s\S]*finally \{[\s\S]*setBusy\(false\)/, "UI actions must recover from rejected NUI calls");
for (const special of ["acceptCall", "openEmployeeContact", "sendCurrentLocation"]) {
  assert.match(callbacks, new RegExp(`RegisterNUICallback\\("${special}"[\\s\\S]*?callback\\(`), `Special callback may not answer: ${special}`);
}
assert.match(events, /pcall\(ServicesPlus\.Api\[action\]/);
assert.match(events, /TriggerClientEvent\("services-plus:client:response"[\s\S]*response\s*\)\s*end\)/);

const exportNames = [...exportsFile.matchAll(/exports\("([A-Za-z]+)"/g)].map((match) => match[1]);
for (const name of exportNames) assert.ok(apiDocs.includes(`| \`${name}\` |`), `Undocumented server export: ${name}`);
for (const eventName of ["requestLifecycle", "requestCreated", "requestUpdated", "requestAccepted", "requestPhaseChanged", "requestReturned", "requestCompleted", "requestCancelled", "requestDeleted", "messageReceived"]) {
  assert.ok(apiDocs.includes(`services-plus:server:${eventName}`) || apiDocs.includes(`\`${eventName}\``), `Undocumented local event: ${eventName}`);
}

assert.match(manifest, /version "0\.6\.0-rc1"/);
assert.doesNotMatch(manifest, /server\/prototypes\.lua/, "Development prototypes are loaded in production");
assert.match(constants, /ApiVersion = 10/);
assert.match(repository, /GetNumberQueue\(numberId, limit\)[\s\S]*LIMIT \?/);
assert.match(calls, /GetNumberQueue\(numberId, Config\.MaxQueueBroadcastEntries\)/);
assert.match(repository, /EndOpenCalls[\s\S]*UPDATE `services_plus_call_history` h[\s\S]*JOIN `services_plus_call_queue` q/);
assert.doesNotMatch(repository.match(/function Repository\.EndOpenCalls[\s\S]*?\nend/)?.[0] ?? "", /for _, row/);
for (const framework of ["qbox", "qbcore", "esx", "standalone"]) assert.ok(bridge.includes(`"${framework}"`), `Framework bridge is missing ${framework}`);
assert.match(bridge, /GetEquippedPhoneNumber/);
assert.match(bridge, /IsPlayerAceAllowed[\s\S]*HasPermission/);
assert.match(integrations, /GetResourceState[\s\S]*not availability\[name\][\s\S]*Logger\.Warn/);
assert.match(main, /RecoverActiveRequests\(\)[\s\S]*RestoreOnlineDuty\(\)/);
assert.match(config, /Config\.LogLevel = "info"/);
for (const level of ["DEBUG", "INFO", "WARNING", "ERROR"]) assert.ok(logger.includes(level), `Logger is missing ${level}`);
assert.match(schema, /UNIQUE KEY `uq_services_plus_request_external`/);
assert.match(exportsFile, /GetRequestByExternal[\s\S]*if existing then return ServicesPlus\.Ok/);

for (const index of [
  "idx_services_plus_requests_company_status", "idx_services_plus_requests_creator", "idx_services_plus_call_queue",
  "idx_services_plus_call_company", "idx_services_plus_inbox_company", "idx_services_plus_inbox_company_number_activity", "idx_services_plus_inbox_messages"
]) assert.ok(schema.includes(index), `Common query index is missing: ${index}`);

const requiredDocs = ["README.md", "docs/INDEX.md", "docs/CHANGELOG.md", "docs/guides/INSTALLATION.md", "docs/guides/CONFIGURATION.md", "docs/reference/COMPATIBILITY.md", "docs/guides/DATABASE.md", "docs/guides/TROUBLESHOOTING.md", "docs/reference/INTEGRATIONS.md", "docs/api/API.md", "docs/development/RELEASE_CHECKLIST.md"];
await Promise.all(requiredDocs.map((path) => read(path)));
assert.match(packageJson, /phase3-contracts\.mjs/);

async function luaFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map((entry) => entry.isDirectory() ? luaFiles(resolve(directory, entry.name)) : extname(entry.name) === ".lua" ? [resolve(directory, entry.name)] : []));
  return nested.flat();
}
for (const path of await luaFiles(root)) {
  const source = await readFile(path, "utf8");
  assert.doesNotMatch(source, /while\s+true\s+do/, `Permanent loop found in ${path}`);
  assert.doesNotMatch(source, /TriggerClientEvent\([^\n]*,\s*-1\s*[,)]/, `Global client broadcast found in ${path}`);
}

console.log("Phase 3 stabilization contracts passed.");
