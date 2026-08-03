import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => readFile(resolve(root, path), "utf8");
const [metadataSource, api, callbacks, exportsFile, config, constants, inventory, events, repository, inboxes, clientApp, rateLimiter, main] = await Promise.all([
  read("shared/api_contracts.json"), read("server/api.lua"), read("client/callbacks.lua"), read("server/exports.lua"), read("config.lua"), read("shared/constants.lua"), read("docs/api/CONTRACT_INVENTORY.md"),
  read("server/events.lua"), read("server/repository.lua"), read("server/inboxes.lua"), read("client/app.lua"), read("server/rate_limiter.lua"), read("server/main.lua")
]);
const metadata = JSON.parse(metadataSource);
assert.match(constants, new RegExp(`ApiVersion = ${metadata.version}`));

for (const [name, contract] of Object.entries(metadata.actions)) {
  assert.equal(contract.inputSchema?.type, "object", `Missing object input schema for ${name}`);
  assert.match(api, new RegExp(`function Api\\.${name}\\(`), `Missing API handler ${name}`);
  assert.ok(callbacks.includes(`"${name}"`) || name === "acceptCall", `Missing NUI callback ${name}`);
  assert.match(config, new RegExp(`\\b${contract.rate}\\s*=\\s*\\{\\s*limit\\s*=`), `Missing rate rule ${contract.rate}`);
  assert.ok(inventory.includes(`| \`${name}\` |`), `Missing generated action ${name}`);
}

for (const [name, contract] of Object.entries(metadata.exports)) {
  assert.ok(exportsFile.includes(`exports("${name}"`), `Missing export ${name}`);
  assert.match(config, new RegExp(`\\b${contract.rate}\\s*=\\s*\\{\\s*limit\\s*=`), `Missing export rate rule ${contract.rate}`);
  assert.ok(inventory.includes(`| \`${name}\` |`), `Missing generated export ${name}`);
}

assert.match(api, /payload\.sections[\s\S]*cursors\.conversations[\s\S]*limit \+ 1/);
assert.match(api, /lastMessageAt[\s\S]*cursorBuilder\(last\)[\s\S]*hasMore = hasMore/);
assert.match(api, /GetCompanyUnreadCounts[\s\S]*CountVisibleUnansweredRequests/);
assert.match(events, /ValidateActionPayload\(action, payload\)/);
assert.match(events, /phoneChanged[\s\S]*RateLimiter\.Allow\(requestSource, "phoneChanged"\)/);
assert.doesNotMatch(callbacks, /RegisterNUICallback\("appClosed"/);
assert.doesNotMatch(clientApp, /SendCustomAppMessage[\s\S]*app\.closed/);
assert.match(repository, /GetRequestById\(requestId\)[\s\S]*getRequestById\(requestId, false\)/);
assert.match(repository, /deleted_at` IS NULL/);
assert.match(exportsFile, /guarded\(handler, rateAction\)[\s\S]*"resource:" \.\. resource/);
assert.match(inboxes, /mediaHostAllowed[\s\S]*Config\.AllowedMediaDomains[\s\S]*cleanAttachments/);
assert.match(inboxes, /function Inboxes\.ValidateConfiguration\(\)/);
assert.match(main, /Inboxes\.ValidateConfiguration\(\)/);
assert.match(rateLimiter, /Rate limit rejection summary[\s\S]*SetTimeout[\s\S]*recordRejection/);
await assert.rejects(access(resolve(root, "server/prototypes.lua")), "Obsolete prototype module still exists");

console.log("Central API metadata contracts passed.");
