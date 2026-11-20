// The panel's tests run with dev/tests/StubTheme.qml standing in for ui/UTheme.qml
// (qmltestrunner has no Quickshell and no qs.Commons). A stub that lacks something the
// panel or the kit reads would make a test pass or fail for the wrong reason, so every
// `theme.<name>` read in CornersPanel.qml and ui/ must be declared in both.
//
//   node dev/tests/stub-surface.mjs
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const G = process.stdout.isTTY ? '\x1b[32m' : '', R = process.stdout.isTTY ? '\x1b[31m' : '', X = process.stdout.isTTY ? '\x1b[0m' : ''
let checks = 0, failures = 0
function check(description, ok, detail = '') {
  checks++
  if (ok) console.log(`  ${G}pass${X}  ${description}`)
  else { failures++; console.log(`  ${R}FAIL${X}  ${description} ${detail}`) }
}

const read = f => fs.readFileSync(path.join(REPO, f), 'utf8').replace(/\/\/.*$/gm, '')
const declared = src => new Set([...src.matchAll(/(?:property\s+(?:readonly\s+)?\w+\s+|function\s+)(\w+)/g)].map(m => m[1]))
const stub = declared(read('dev/tests/StubTheme.qml'))
const real = declared(read('ui/UTheme.qml'))

const files = ['CornersPanel.qml', ...fs.readdirSync(path.join(REPO, 'ui')).filter(f => f.endsWith('.qml') && f !== 'UTheme.qml').map(f => 'ui/' + f)]
const reads = new Set()
for (const f of files) for (const m of read(f).matchAll(/\btheme\.(\w+)/g)) reads.add(m[1])

console.log(`${reads.size} names read through \`theme\` by ${files.length} files`)
const noStub = [...reads].filter(n => !stub.has(n)).sort()
const noReal = [...reads].filter(n => !real.has(n)).sort()
check('every one is declared in dev/tests/StubTheme.qml', noStub.length === 0, noStub.join(', '))
check('every one is declared in ui/UTheme.qml', noReal.length === 0, noReal.join(', '))
check('the panel reads a theme at all', reads.size > 10)

console.log(`\nstub-surface: ${checks - failures} of ${checks} passed`)
process.exit(failures ? 1 : 0)
