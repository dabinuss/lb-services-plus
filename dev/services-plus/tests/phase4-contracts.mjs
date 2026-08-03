import assert from "node:assert/strict";
import { access, readFile, readdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => readFile(resolve(root, path), "utf8");
const [docs, exportsFile, events, callbacks, config, requests, constants, manifest, readme, changelog] = await Promise.all([
  read("docs/api/API.md"), read("server/exports.lua"), read("server/events.lua"), read("client/callbacks.lua"), read("config.lua"),
  read("server/requests.lua"), read("shared/constants.lua"), read("fxmanifest.lua"), read("README.md"), read("docs/CHANGELOG.md")
]);

assert.match(constants, /ApiVersion = 9/);
assert.match(manifest, /version "0\.5\.0-rc1"/);
assert.match(docs, /API version: `9`/);
assert.match(changelog, /API version from 8 to 9/);

const exportsList = [...exportsFile.matchAll(/exports\("([A-Za-z]+)"/g)].map((match) => match[1]);
assert.equal(exportsList.length, 11);
for (const name of exportsList) assert.ok(docs.includes(`| \`${name}\` |`), `API reference is missing export ${name}`);

const actions = Object.keys(JSON.parse(await read("shared/api_contracts.json")).actions);
assert.equal(actions.length, 37);
for (const action of actions) {
  assert.ok(docs.includes(`\`${action} `) || docs.includes(`\`${action} {`) || docs.includes(`\`${action}\``), `API reference is missing action ${action}`);
  assert.match(config, new RegExp(`\\b${action}\\s*=\\s*\\{\\s*limit\\s*=`), `Action ${action} has no configured rate limit`);
}

for (const helper of ["openEmployeeContact", "sendCurrentLocation"]) {
  assert.ok(callbacks.includes(`RegisterNUICallback("${helper}"`));
  assert.ok(docs.includes(`\`${helper}`), `API reference is missing local helper ${helper}`);
}

const localEvents = ["requestLifecycle", "requestCreated", "requestUpdated", "requestAccepted", "requestPhaseChanged", "requestReturned", "requestCompleted", "requestCancelled", "requestDeleted", "messageReceived"];
for (const event of localEvents) assert.ok(docs.includes(`services-plus:server:${event}`), `API reference is missing event ${event}`);
assert.match(requests, /requestCreated", Requests\.ToIntegration\(request\)/);
assert.match(requests, /local integration = Requests\.ToIntegration\(request\)[\s\S]*requestUpdated", integration/);

const pushTypes = [
  "company.updated", "company.deleted", "settings.updated", "category.updated", "employee.updated", "employee.removed", "session.invalidated",
  "call.offer", "call.offer.removed", "call.accepted.local", "call.queue", "request.offer", "request.offer.removed", "request.updated",
  "request.citizen.updated", "inbox.message", "inbox.reaction", "inbox.deleted", "inbox.message.deleted"
];
for (const type of pushTypes) assert.ok(docs.includes(`\`${type}\``), `API reference is missing push type ${type}`);

for (const section of ["Response Envelope", "Entity Reference", "Trusted Server Exports", "Local Server Events", "Request Lifecycle", "Call Lifecycle", "Message and Shared-Inbox Flow", "App Action Contracts", "Custom App Push Messages", "Permissions Matrix", "Optional Adapter Hooks", "Security Rules for Consumers"]) {
  assert.ok(docs.includes(`## ${section}`), `API reference is missing section ${section}`);
}
assert.match(docs, /```mermaid[\s\S]*stateDiagram-v2/);
for (const example of [":GetCompany(", ":GetCompanyNumbers(", ":GetCompanyEmployees(", ":GetCompanyRequests(", ":CreateRequest(", ":AcceptRequest(", ":DeclineRequest(", ":TransitionRequest(", ":ReturnRequest(", "requestLifecycle"]) {
  assert.ok(docs.includes(example), `API reference is missing example ${example}`);
}
assert.doesNotMatch(docs, /TriggerServerEvent\("services-plus:server:request"/);

const rootMarkdown = (await readdir(root, { withFileTypes: true })).filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".md")).map((entry) => entry.name);
assert.deepEqual(rootMarkdown, ["README.md"], "Only README.md may remain in the resource root");

async function markdownFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const groups = await Promise.all(entries.map((entry) => entry.isDirectory() ? markdownFiles(resolve(directory, entry.name)) : entry.name.endsWith(".md") ? [resolve(directory, entry.name)] : []));
  return groups.flat();
}

for (const file of [resolve(root, "README.md"), ...await markdownFiles(resolve(root, "docs"))]) {
  const source = await readFile(file, "utf8");
  for (const match of source.matchAll(/\[[^\]]+\]\(([^)]+\.md(?:#[^)]+)?)\)/g)) {
    const target = match[1].split("#")[0];
    await access(resolve(dirname(file), target)).catch(() => assert.fail(`Broken Markdown link in ${file}: ${match[1]}`));
  }
}

for (const link of ["docs/INDEX.md", "docs/api/API.md", "docs/guides/INSTALLATION.md", "docs/reference/INTEGRATIONS.md", "docs/development/RELEASE_CHECKLIST.md", "docs/CHANGELOG.md"]) {
  assert.ok(readme.includes(`](${link})`), `README is missing documentation link ${link}`);
}

console.log("Phase 4 documentation contracts passed.");
