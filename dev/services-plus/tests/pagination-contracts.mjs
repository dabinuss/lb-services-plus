import assert from "node:assert/strict";

const makeRows = (count) => Array.from({ length: count }, (_, index) => ({
  id: count - index,
  lastMessageAt: new Date(Date.UTC(2026, 7, 3, 12, 0, -index)).toISOString().slice(0, 19).replace("T", " ")
}));
const after = (row, cursor) => row.lastMessageAt < cursor.lastMessageAt || row.lastMessageAt === cursor.lastMessageAt && row.id < cursor.id;
const page = (rows, cursor, limit = 24) => {
  const visible = cursor ? rows.filter((row) => after(row, cursor)) : rows;
  const items = visible.slice(0, limit);
  return { items, cursor: items.at(-1), hasMore: visible.length > limit };
};

const source = makeRows(127);
const collected = [];
let cursor;
do {
  const result = page(source, cursor);
  collected.push(...result.items);
  cursor = result.cursor;
  if (!result.hasMore) break;
  if (collected.length === 24) source.unshift({ id: 1000, lastMessageAt: "2026-08-03 13:00:00" });
} while (true);

assert.equal(collected.length, 127);
assert.equal(new Set(collected.map((row) => row.id)).size, 127);
assert.deepEqual(collected.map((row) => row.id), makeRows(127).map((row) => row.id));
console.log("Workspace pagination contracts passed.");
