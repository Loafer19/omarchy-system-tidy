.pragma library

// Keyboard cursor for the panel, as pure functions. The cursor lives in one
// of three sections: "tabs" (the tab chips), "filters" (the active tab's
// filter chips) or "rows" (the active list), plus an index in it.
//
// ctx describes the active tab:
//   { tabs, activeTab, chips, filterKey, itemCount }
// A move returns what the panel must apply, in this order: section, index,
// then tab (switch tab) or filter (apply that filter key), then position
// (scroll the list to the index). null means "nothing changes".

function indexOfKey(list, key) {
  for (var i = 0; i < list.length; i++) {
    if (String(list[i].key) === String(key)) return i
  }
  return 0
}

function clampIndex(i, len) {
  if (len <= 0) return 0
  if (i < 0) return 0
  if (i >= len) return len - 1
  return i
}

function tabsCursor(ctx) { return { section: "tabs", index: indexOfKey(ctx.tabs, ctx.activeTab) } }
function filtersCursor(ctx) { return { section: "filters", index: indexOfKey(ctx.chips, ctx.filterKey) } }
function rowsCursor() { return { section: "rows", index: 0 } }

// Where the cursor appears on the first key press: the list, else the
// filters, else the tabs.
function initialCursor(ctx) {
  if (ctx.itemCount > 0) return rowsCursor()
  if (ctx.chips.length > 0) return filtersCursor(ctx)
  return tabsCursor(ctx)
}

function moveVertical(cur, dy, ctx) {
  if (cur.section === "tabs") {
    if (dy <= 0) return null
    if (ctx.chips.length > 0) return filtersCursor(ctx)
    if (ctx.itemCount > 0) return rowsCursor()
    return null
  }
  if (cur.section === "filters") {
    if (dy > 0) return ctx.itemCount > 0 ? rowsCursor() : null
    return tabsCursor(ctx)
  }
  var next
  if (dy > 0) next = { section: "rows", index: clampIndex(cur.index + 1, ctx.itemCount) }
  else if (cur.index > 0) next = { section: "rows", index: cur.index - 1 }
  else if (ctx.chips.length > 0) next = filtersCursor(ctx)
  else next = tabsCursor(ctx)
  next.position = true
  return next
}

function moveHorizontal(cur, dx, ctx) {
  var i
  if (cur.section === "tabs") {
    i = clampIndex(cur.index + dx, ctx.tabs.length)
    return { section: "tabs", index: i, tab: ctx.tabs[i].key }
  }
  if (cur.section === "filters" && ctx.chips.length > 0) {
    i = clampIndex(cur.index + dx, ctx.chips.length)
    return { section: "filters", index: i, filter: ctx.chips[i].key }
  }
  return null
}

function move(cur, dx, dy, ctx) {
  if (dy !== 0) return moveVertical(cur, dy, ctx)
  if (dx !== 0) return moveHorizontal(cur, dx, ctx)
  return null
}

// Tab / Shift+Tab: next or previous tab, wrapping around.
function cycleIndex(tabs, activeTab, direction) {
  var n = tabs.length
  if (n === 0) return -1
  var i = (indexOfKey(tabs, activeTab) + direction) % n
  return i < 0 ? i + n : i
}
