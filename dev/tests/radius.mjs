// radius.js: which radius a monitor is painted with. Corners.qml (the service)
// and Surface.qml (the settings panel) both call it, so what the panel shows is
// what the corners use. Pure functions, no Qt: loaded the way a `.pragma library`
// file is, into a bare context.
//
//   node dev/tests/radius.mjs
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { fileURLToPath } from 'node:url'

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const G = process.stdout.isTTY ? '\x1b[32m' : '', R = process.stdout.isTTY ? '\x1b[31m' : '', X = process.stdout.isTTY ? '\x1b[0m' : ''
let checks = 0, failures = 0
function check(description, actual, expected) {
  checks++
  const ok = Object.is(actual, expected)
  if (ok) console.log(`  ${G}pass${X}  ${description}`)
  else { failures++; console.log(`  ${R}FAIL${X}  ${description} (expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)})`) }
}

const ctx = vm.createContext({ Math, Object, String, Number, isFinite })
vm.runInContext(fs.readFileSync(path.join(REPO, 'radius.js'), 'utf8').replace(/^\.pragma library/m, ''), ctx, { filename: 'radius.js' })
const Radius = ctx

console.log('follow: a circle bigger than the windows\' own corner')
check('follow(0) is 0', Radius.follow(0), 0)
check('follow(10) is 13 (10 x 1.25, rounded)', Radius.follow(10), 13)
check('follow(20) is 25', Radius.follow(20), 25)
check('a negative Hyprland value follows as 0', Radius.follow(-4), 0)

console.log('stored: a number >= 0, or -1 for "not set"')
for (const [label, value, want] of [
  ['undefined', undefined, -1], ['null', null, -1], ['an empty string', '', -1], ['true', true, -1], ['false', false, -1],
  ['0 is a real value', 0, 0], ['12', 12, 12], ['"12" (a string number)', '12', 12], ['12.6 rounds', 12.6, 13],
  ['a negative', -3, -1], ['NaN text', 'wide', -1], ['Infinity', Infinity, -1]])
  check(`stored(${label})`, Radius.stored(value), want)

console.log('written: the hand-written file, read as 1.0.1 did')
check('written(true) is 1 (Number(true)), not "not set"', Radius.written(true), 1)
check('written(undefined) is -1', Radius.written(undefined), -1)
check('written(30) is 30', Radius.written(30), 30)
check('written(-1) is -1', Radius.written(-1), -1)

console.log('resolve: a monitor\'s own value beats "All monitors", which beats the file, which beats Hyprland')
const hand = { radius: 22, monitors: { 'eDP-1': 28, 'DP-2': 0 } }
check('nothing set anywhere: Hyprland', Radius.resolve({}, {}, 'eDP-1', 9), 9)
check('the file\'s radius beats Hyprland', Radius.resolve({}, { radius: 22 }, 'eDP-1', 9), 22)
check('the file\'s per-monitor value beats the file\'s radius', Radius.resolve({}, hand, 'eDP-1', 9), 28)
check('a per-monitor 0 in the file is square corners', Radius.resolve({}, hand, 'DP-2', 9), 0)
check('a monitor the file does not name takes the file\'s radius', Radius.resolve({}, hand, 'HDMI-A-1', 9), 22)
check('"All monitors" in the panel beats the file, including its per-monitor values', Radius.resolve({ radius: 5 }, hand, 'eDP-1', 9), 5)
check('a monitor\'s own panel value beats "All monitors"', Radius.resolve({ radius: 5, monitors: { 'eDP-1': 7 } }, hand, 'eDP-1', 9), 7)
check('a panel value of 0 is a value', Radius.resolve({ radius: 0 }, hand, 'eDP-1', 9), 0)
check('the "All monitors" row (name "") ignores per-monitor values', Radius.resolve({ monitors: { 'eDP-1': 7 } }, { radius: 22 }, '', 9), 22)
check('a file that is not an object is no file', Radius.resolve({}, null, 'eDP-1', 9), 9)
check('a negative Hyprland value gives 0 at most', Radius.resolve({}, {}, 'eDP-1', -4), 0)

console.log('inherited: what a row falls back to when its own panel value is cleared')
check('a monitor falls back to "All monitors" in the panel', Radius.inherited({ radius: 5 }, hand, 'eDP-1', 9), 5)
check('with none, to its own value in the file', Radius.inherited({}, hand, 'eDP-1', 9), 28)
check('"All monitors" falls back to the file\'s radius', Radius.inherited({ radius: 5 }, hand, '', 9), 22)
check('and to Hyprland when the file has none', Radius.inherited({}, {}, '', 9), 9)

console.log(`\nradius: ${checks - failures} of ${checks} passed`)
process.exit(failures ? 1 : 0)
