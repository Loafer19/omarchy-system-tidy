// Tiny test harness shared by the node tests: loads the plugin's QML-side
// JS libraries outside QML and counts eq() checks.
const fs = require("fs"), path = require("path"), vm = require("vm")
const dir = path.join(__dirname, "..")

// Loads FILE (a `.pragma library` JS file) into a fresh context. QML's
// `.import "X.js" as Name` lines are dropped; `imports` maps Name to an
// already loaded library.
function load(file, imports) {
  const ctx = Object.assign({}, imports || {})
  vm.createContext(ctx)
  vm.runInContext(fs.readFileSync(path.join(dir, file), "utf8").replace(/^\.(pragma|import).*$/gm, ""), ctx)
  return ctx
}

let pass = 0, fail = 0
function eq(label, got, want) {
  const g = JSON.stringify(got), w = JSON.stringify(want)
  if (g === w) { pass++; console.log("PASS  " + label) } else { fail++; console.log("FAIL  " + label + "\n      got " + g + " want " + w) }
}

function done() {
  console.log(`\n${pass} passed, ${fail} failed`)
  process.exit(fail ? 1 : 0)
}

module.exports = { dir, load, eq, done }
