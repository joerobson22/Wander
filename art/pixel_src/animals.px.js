// Every animal, as a strip of 7 frames: walk 0-3, stand, blink, sad.
// Build: see README.md. 1 pixel here is 3 pixels on a 720-tall screen, whatever
// the animal's size, so every animal shares one pixel grid.
// Red = the animal's first colour (animals.json "parts"), green its second,
// blue its third; r/Q, g/H, b/N are darker shades. k outline, e eyes, w shine.
include("common.px.js")

const STAND = 4, BLINK = 5, SAD = 6
// How far the whole animal rises in each frame, by gait.
const MOVES = {
  walk: [0, -1, 0, -1, 0, 0, 1],
  hop: [0, -3, -5, -2, 0, 0, 1],
  crawl: [0, 0, 0, 0, 0, 0, 0],
  swim: [0, -1, -2, -1, 0, -1, 1],
}
// Markers for the Godot rig (neck = lead, mouth = held gift), in canvas pixels
// at the standing pose; printed for tools/make_pixel_art.py.
const MARKS = {}

const step = (f, ph) => (f > 3 ? -1 : (f + ph) % 4)
const legDX = (f, ph) => [1, 0, -1, 0][step(f, ph)] ?? 0
const legLift = (f, ph) => [0, 0, 0, 1][step(f, ph)] ?? 0
const swing = (f, a = 1) => (f > 3 ? 0 : [a, 0, -a, 0][f])
const closed = (f) => f === BLINK || f === SAD

/** A bent leg from hip (x, top) to the ground row g, stepping with the frame. */
function leg(c, x, top, g, w, f, ph, col, paw) {
  const lift = legLift(f, ph), dx = legDX(f, ph)
  const bottom = g - lift
  const mid = Math.max(top, Math.floor((top + bottom) / 2))
  c.rect(x, top, w, mid - top + 1, col)
  c.rect(x + dx, mid, w, bottom - mid + 1, col)
  if (paw) c.rect(x + dx, bottom, w, 1, paw)
}

/** An eye: open with a shine (size 2), or a closed line when blinking or sad. */
function eye(c, x, y, f, size = 1) {
  if (closed(f)) {
    c.hline(x, y + size - 1, size, "e")
    if (f === SAD && size > 1) c.px(x + size - 1, y + size, "e")
    return
  }
  c.rect(x, y, size, size, "e")
  if (size > 1) c.px(x, y, "w")
}

function animal(id, size, move, draw) {
  MARKS[id] = { w: size[0], h: size[1], ax: size[2], move: MOVES[move], neck: size[3], mouth: size[4] }
  anim(id, { w: size[0], h: size[1], frames: 7, fps: 6, outline: "k" }, (c) => {
    const f = c.frame
    draw(c, f, MOVES[move][f], f === SAD ? 2 : 0, size[1] - 1)
  })
}

/** Four legs, a body, a head and a tail: the plan most animals share.
 *  o.body [cx, cy, rx, ry], o.hips [back x, front x], o.legW, o.near/far keys,
 *  o.tail(c, f, b, sad), o.head(c, f, b, sad), o.under/over(c, f, b). */
function quad(c, f, b, sad, g, o) {
  const [cx, cy, rx, ry] = o.body
  const top = cy + b + Math.max(0, ry - 3)
  const w = o.legW ?? 3, gap = o.legGap ?? 2
  const far = o.far ?? "r", near = o.near ?? "R"
  for (const [i, hx] of o.hips.entries()) leg(c, hx + gap, top, g, w, f, i ? 0 : 2, far, o.paw && "Q")
  if (o.tail) o.tail(c, f, b, sad)
  if (o.under) o.under(c, f, b, sad)
  c.ellipse(cx, cy + b, rx, ry, o.bodyKey ?? "G")
  if (o.belly) o.belly(c, f, b, sad)
  for (const [i, hx] of o.hips.entries()) leg(c, hx, top, g, w, f, i ? 2 : 0, near, o.paw && "r")
  if (o.head) o.head(c, f, b, sad)
  if (o.over) o.over(c, f, b, sad)
}

// ---------------------------------------------------------------- dogs, wolves, foxes

// A beagle: floppy ears in the leg colour, a pale muzzle and chest.
animal("dog1", [40, 26, 17, [27, 9], [37, 15]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [16, 14, 11, 5], hips: [7, 22], paw: true,
  tail: (c, f, b, sad) => sad ? c.line(5, 12 + b, 2, 17 + b, "R", 2) : c.line(5, 12 + b, 2 + swing(f), 5 + b, "R", 2),
  belly: (c, f, b) => c.ellipse(23, 16 + b, 4, 3, "B"),
  head: (c, f, b, sad) => {
    const x = 27 - sad, y = 4 + b + sad
    c.rect(x - 3, y + 5, 5, 6, "G")
    c.ellipse(x + 2, y + 4, 4, 4, "G")
    c.rect(x + 5, y + 5, 5, 4, "B")
    c.px(x + 10, y + 5, "e")
    c.px(x + 9, y + 5, "e")
    c.rect(x - 2, y + 1 + sad, 3, 7, "R")
    c.px(x - 2, y + 8 + sad, "r")
    eye(c, x + 3, y + 2, f, 2)
    c.hline(x + 6, y + 8, 3, "g")
  },
}))

// A spitz: pointed ears, a curled tail and a pale face.
animal("dog2", [42, 28, 17, [28, 10], [38, 16]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [17, 16, 12, 6], hips: [7, 23], paw: true,
  tail: (c, f, b, sad) => {
    if (sad) { c.line(5, 14 + b, 2, 19 + b, "G", 3); return }
    c.ellipse(6, 9 + b, 4, 4, "G"); c.ellipse(6, 9 + b, 2, 2, "B"); c.px(7 + swing(f), 5 + b, "G")
  },
  belly: (c, f, b) => { c.ellipse(24, 19 + b, 5, 3, "B") },
  head: (c, f, b, sad) => {
    const x = 28 - sad, y = 5 + b + sad
    c.rect(x - 3, y + 5, 6, 7, "G")
    c.ellipse(x + 2, y + 4, 5, 4, "G")
    c.ellipse(x + 3, y + 6, 4, 2, "B")
    c.rect(x + 6, y + 5, 4, 3, "B")
    c.px(x + 10, y + 5, "e")
    if (sad) { c.poly([x - 2, y + 1, x + 2, y, x + 1, y + 2], "R") }
    else { c.poly([x - 2, y + 1, x, y - 4, x + 2, y + 1], "G"); c.poly([x + 2, y + 1, x + 4, y - 4, x + 5, y + 1], "G"); c.px(x + 3, y - 1, "R") }
    eye(c, x + 4, y + 2, f, 2)
  },
}))

// A fox: long nose, big pointed ears, a bushy tail with a pale tip.
animal("fox", [36, 22, 14, [24, 8], [34, 13]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [14, 12, 10, 4], hips: [6, 19], legW: 2, near: "R", far: "Q",
  tail: (c, f, b, sad) => {
    const ty = sad ? 16 : 9 + swing(f)
    c.line(5, 11 + b, 1, ty + b, "G", 4); c.ellipse(1, ty + b, 2, 2, "B")
  },
  belly: (c, f, b) => c.ellipse(19, 14 + b, 4, 2, "B"),
  head: (c, f, b, sad) => {
    const x = 23 - sad, y = 3 + b + sad
    c.rect(x - 2, y + 5, 4, 5, "G")
    c.ellipse(x + 3, y + 5, 4, 3, "G")
    c.poly([x + 5, y + 4, x + 11, y + 7, x + 5, y + 8], "G")
    c.poly([x + 3, y + 7, x + 11, y + 7, x + 6, y + 9], "B")
    c.px(x + 11, y + 7, "e")
    if (sad) c.poly([x - 1, y + 3, x + 3, y + 2, x + 1, y + 5], "G")
    else { c.poly([x, y + 3, x + 1, y - 2, x + 3, y + 3], "G"); c.poly([x + 3, y + 3, x + 5, y - 2, x + 6, y + 3], "G"); c.px(x + 1, y + 1, "R"); c.px(x + 4, y + 1, "R") }
    eye(c, x + 5, y + 4, f)
  },
}))

// A skeleton dog: bones in the bone colour, its shadowy inside in the third.
animal("skeleton_dog", [40, 26, 17, [27, 9], [37, 15]], "walk", (c, f, b, sad, g) => {
  const top = 17 + b
  for (const [i, hx] of [[0, 9], [1, 24]]) { c.rect(hx, top, 2, 1, "r"); leg(c, hx, top, g, 2, f, i ? 0 : 2, "r") }
  c.ellipse(16, 14 + b, 10, 5, "B")
  c.hline(5, 10 + b, 22, "G"); c.hline(5, 11 + b, 22, "G")
  for (let x = 9; x <= 22; x += 3) c.line(x, 11 + b, x - 1, 17 + b, "G")
  c.ellipse(8, 15 + b, 3, 2, "G")
  if (sad) c.line(4, 11 + b, 1, 17 + b, "G") ; else c.line(4, 10 + b, 1 + swing(f), 4 + b, "G")
  for (const [i, hx] of [[0, 7], [1, 22]]) leg(c, hx, top, g, 2, f, i ? 2 : 0, "R")
  const x = 27 - sad, y = 4 + b + sad
  c.rect(x - 2, y + 6, 3, 5, "G")
  c.ellipse(x + 2, y + 4, 4, 4, "G"); c.rect(x + 5, y + 5, 5, 4, "G")
  c.px(x + 10, y + 5, "e"); c.hline(x + 6, y + 7, 4, "B")
  c.rect(x - 1, y + 1 + sad, 2, 5, "r")
  if (closed(f)) c.hline(x + 2, y + 4, 3, "B"); else { c.rect(x + 2, y + 2, 3, 3, "B"); c.px(x + 3, y + 3, "w") }
})

// ---------------------------------------------------------------- cats

function cat(id, size, o) {
  const [w, h, ax] = size
  animal(id, size, "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
    body: o.body, hips: o.hips, legW: o.legW ?? 2,
    tail: (c, f, b, sad) => {
      const [cx, cy, rx] = o.body, x0 = cx - rx + 1, y0 = cy - 2 + b
      if (sad) { c.line(x0, y0, x0 - 4, y0 + 7, "G", o.tailW ?? 2); return }
      c.line(x0, y0, x0 - 3, y0 - 6, "G", o.tailW ?? 2); c.line(x0 - 3, y0 - 6, x0 - 1 + swing(f), y0 - 10, "G", o.tailW ?? 2)
      if (o.tailTip) o.tailTip(c, x0 - 1 + swing(f), y0 - 10)
    },
    belly: (c, f, b, sad) => o.marks && o.marks(c, b),
    head: (c, f, b, sad) => {
      const [hx, hy, hr] = o.head
      const x = hx - sad, y = hy + b + sad
      if (o.mane) o.mane(c, x, y, sad)
      c.ellipse(x, y, hr + 1, hr, "G")
      if (sad) { c.poly([x - hr, y - hr + 2, x - hr - 2, y - hr + 4, x - hr + 1, y - hr + 4], "G"); c.poly([x + hr - 1, y - hr + 2, x + hr + 2, y - hr + 4, x + hr, y - hr + 4], "G") }
      else { c.poly([x - hr, y - 1, x - hr + 1, y - hr - 2, x - 1, y - hr + 1], "G"); c.poly([x + 1, y - hr + 1, x + hr - 1, y - hr - 2, x + hr, y - 1], "G"); c.px(x - hr + 1, y - hr, "r"); c.px(x + hr - 1, y - hr, "r") }
      c.ellipse(x + 2, y + 2, 2, 1, o.muzzle ?? "G")
      c.px(x + 3, y + 1, "e")
      if (o.face) o.face(c, x, y, f)
      // Cat eyes take the third colour: B with a black slit.
      if (closed(f)) { c.hline(x - 2, y, 2, "e"); c.hline(x + 1, y, 2, "e") }
      else { c.rect(x - 2, y - 1, 2, 2, "B"); c.px(x - 1, y - 1, "e"); c.rect(x + 1, y - 1, 2, 2, "B"); c.px(x + 2, y - 1, "e") }
      c.px(x + hr + 1, y + 2, "e")
    },
  }))
  MARKS[id].neck = [o.head[0] - o.head[2] - 1, o.head[1] + 2]
  MARKS[id].mouth = [o.head[0] + o.head[2] + 1, o.head[1] + o.head[2]]
}

cat("cat", [30, 20, 13, 0, 0], { body: [13, 11, 8, 4], hips: [6, 17], head: [22, 7, 4] })
cat("tiger", [50, 30, 21, 0, 0], {
  body: [21, 16, 14, 6], hips: [9, 29], legW: 3, head: [37, 10, 6], tailW: 3,
  marks: (c, b) => { for (let x = 11; x <= 31; x += 4) c.line(x, 11 + b, x + 1, 15 + b, "Q", 1); c.ellipse(30, 19 + b, 4, 2, "R") },
  face: (c, x, y) => { c.px(x - 4, y - 2, "Q"); c.px(x - 5, y, "Q"); c.ellipse(x + 2, y + 3, 3, 2, "R"); c.px(x + 3, y + 1, "e") },
  tailTip: (c, x, y) => c.rect(x - 1, y - 1, 3, 2, "Q"),
})
cat("leopard", [42, 24, 17, 0, 0], {
  body: [17, 13, 12, 5], hips: [7, 24], head: [31, 8, 5],
  marks: (c, b) => { for (const [x, y] of [[9, 11], [13, 14], [17, 10], [20, 14], [24, 11], [12, 9], [27, 14]]) { c.px(x, y + b, "Q"); c.px(x + 1, y + b, "Q"); c.px(x, y + b + 1, "Q") } },
  face: (c, x, y) => { c.px(x - 3, y - 3, "Q"); c.px(x - 1, y - 4, "Q") },
})
cat("lion", [48, 32, 20, 0, 0], {
  body: [20, 18, 13, 6], hips: [9, 28], legW: 3, head: [36, 12, 5], tailW: 2,
  mane: (c, x, y, sad) => { c.ellipse(x - 1, y + 1, 8, 8, "R"); c.ellipse(x - 2, y + 2, 7, 7, "r") },
  muzzle: "B", face: (c, x, y) => c.px(x + 3, y + 1, "e"),
  tailTip: (c, x, y) => c.ellipse(x, y, 2, 2, "R"),
})

// A red panda: round face with white cheeks, a ringed tail, dark legs.
animal("red_panda", [30, 20, 12, [21, 7], [28, 12]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [12, 11, 8, 4], hips: [6, 16], legW: 2,
  tail: (c, f, b, sad) => {
    const end = sad ? [0, 17] : [0 + swing(f), 6]
    c.line(5, 10 + b, end[0], end[1] + b, "G", 4)
    for (let i = 1; i < 4; i++) { const x = Math.round(5 + (end[0] - 5) * i / 4), y = Math.round(10 + (end[1] - 10) * i / 4) + b; c.line(x - 2, y, x + 2, y, "g", 1) }
  },
  head: (c, f, b, sad) => {
    const x = 22 - sad, y = 6 + b + sad
    c.ellipse(x, y, 5, 4, "G")
    if (!sad) { c.ellipse(x - 4, y - 4, 2, 2, "G"); c.ellipse(x + 3, y - 4, 2, 2, "G"); c.px(x - 4, y - 4, "w"); c.px(x + 3, y - 4, "w") }
    c.ellipse(x + 2, y + 2, 3, 2, "w"); c.px(x - 3, y + 1, "w"); c.px(x - 4, y, "w")
    c.px(x + 5, y + 2, "e")
    c.line(x - 2, y + 1, x - 1, y + 3, "B")
    eye(c, x, y - 1, f, 2)
  },
}))

// ---------------------------------------------------------------- big beasts

animal("bear", [54, 36, 22, [39, 13], [51, 22]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [22, 18, 17, 9], hips: [9, 33], legW: 5, paw: true, near: "R", far: "r", bodyKey: "G",
  tail: (c, f, b) => c.ellipse(5, 14 + b, 2, 2, "G"),
  belly: (c, f, b) => { c.ellipse(28, 23 + b, 8, 3, "B"); c.ellipse(16, 11 + b, 10, 2, "g"); c.ellipse(16, 12 + b, 10, 2, "G") },
  head: (c, f, b, sad) => {
    const x = 42 - sad, y = 11 + b + sad * 2
    c.rect(x - 7, y - 1, 7, 9, "G")
    c.ellipse(x, y + 2, 6, 6, "G")
    c.ellipse(x - 3, y - 4, 2, 2, "G"); c.px(x - 3, y - 4, "B")
    c.ellipse(x + 6, y + 4, 4, 3, "B"); c.rect(x + 9, y + 2, 2, 2, "e")
    c.hline(x + 6, y + 7, 3, "N")
    eye(c, x + 1, y, f, 2)
  },
}))

animal("mammoth", [58, 46, 22, [38, 14], [52, 32]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [22, 23, 18, 12], hips: [8, 32], legW: 6, near: "R", far: "r",
  tail: (c, f, b) => c.line(4, 22 + b, 2, 30 + b, "R", 2),
  belly: (c, f, b) => { for (let x = 6; x < 40; x += 3) c.line(x, 30 + b, x + 1, 35 + b, "g") },
  head: (c, f, b, sad) => {
    const x = 40 - sad, y = 14 + b + sad
    c.ellipse(x, y, 8, 9, "G")
    c.ellipse(x - 2, y - 7, 6, 3, "g")
    c.line(x + 6, y + 2, x + 9, y + 14, "G", 4); c.line(x + 9, y + 14, x + 12 + swing(f), y + 20, "G", 3)
    c.line(x + 4, y + 8, x + 12, y + 16, "B", 2); c.line(x + 12, y + 16, x + 14, y + 13, "B", 2)
    c.ellipse(x - 3, y + 2, 4, 5, "g")
    eye(c, x + 3, y - 1, f, 2)
  },
}))

animal("elephant", [64, 46, 26, [40, 17], [58, 33]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [24, 22, 19, 11], hips: [9, 34], legW: 7, near: "R", far: "r",
  tail: (c, f, b) => { c.line(5, 20 + b, 3 + swing(f), 30 + b, "R"); c.px(3 + swing(f), 31 + b, "e") },
  head: (c, f, b, sad) => {
    const x = 44 - sad, y = 17 + b + sad
    c.ellipse(x, y, 9, 9, "G")
    c.line(x + 7, y + 2, x + 11, y + 14, "G", 5); c.line(x + 11, y + 14, x + 14 + swing(f), y + 22, "G", 4)
    c.line(x + 5, y + 7, x + 10, y + 11, "w", 2)
    c.ellipse(x - 5, y + 1, 6, 9, "B"); c.ellipse(x - 5, y + 2, 4, 6, "b")
    eye(c, x + 3, y - 2, f, 2)
  },
}))

animal("rhino", [56, 34, 22, [38, 14], [53, 23]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [22, 18, 17, 9], hips: [9, 32], legW: 5, near: "R", far: "r",
  tail: (c, f, b) => c.line(5, 15 + b, 3 + swing(f), 23 + b, "R"),
  belly: (c, f, b) => { c.line(14, 10 + b, 13, 25 + b, "g"); c.line(30, 10 + b, 31, 25 + b, "g") },
  head: (c, f, b, sad) => {
    const x = 41 - sad, y = 15 + b + sad
    c.poly([x - 5, y - 6, x + 6, y - 3, x + 13, y + 3, x + 12, y + 8, x + 2, y + 9, x - 5, y + 7], "G")
    c.poly([x + 9, y + 1, x + 15, y - 7, x + 13, y + 3], "B")
    c.poly([x + 5, y - 2, x + 8, y - 6, x + 8, y], "B")
    c.poly([x - 4, y - 6, x - 2, y - 10, x, y - 5], "G")
    eye(c, x + 4, y + 1, f)
  },
}))

animal("giraffe", [42, 62, 16, [26, 14], [38, 8]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [16, 32, 11, 7], hips: [7, 21], legW: 3, near: "R", far: "r", paw: true,
  tail: (c, f, b) => { c.line(5, 31 + b, 3 + swing(f), 40 + b, "R"); c.rect(2 + swing(f), 40 + b, 2, 2, "B") },
  belly: (c, f, b) => { for (const [x, y] of [[10, 29], [15, 33], [20, 29], [12, 35], [21, 35]]) c.rect(x, y + b, 3, 2, "B") },
  head: (c, f, b, sad) => {
    const x = 31 - sad * 2, y = 4 + b + sad * 2
    c.poly([20, 28 + b, 24, 26 + b, x + 1, y + 6, x - 2, y + 6], "G")
    for (const t of [0.2, 0.45, 0.7]) c.rect(Math.round(22 + (x - 22) * t) - 1, Math.round(27 + (y + 6 - 27) * t) + b * (1 - t), 2, 2, "B")
    c.ellipse(x + 2, y + 3, 4, 3, "G"); c.rect(x + 3, y + 3, 5, 3, "G"); c.px(x + 8, y + 4, "e")
    c.vline(x - 1, y - 3, 3, "R"); c.vline(x + 1, y - 3, 3, "R"); c.px(x - 1, y - 4, "Q"); c.px(x + 1, y - 4, "Q")
    c.px(x - 3, y + 1 + sad, "G"); c.px(x - 4, y + 1 + sad, "G")
    eye(c, x + 2, y + 1, f)
  },
}))

animal("reindeer", [46, 44, 18, [32, 22], [42, 26]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [18, 27, 12, 6], hips: [8, 24], legW: 3, near: "R", far: "r", paw: true,
  tail: (c, f, b) => c.ellipse(6, 23 + b, 2, 2, "B"),
  belly: (c, f, b) => c.ellipse(26, 29 + b, 4, 3, "B"),
  head: (c, f, b, sad) => {
    const x = 33 - sad, y = 15 + b + sad * 2
    c.rect(x - 3, y + 3, 5, 9, "G")
    c.ellipse(x + 1, y + 2, 4, 4, "G"); c.rect(x + 3, y + 2, 6, 3, "G")
    c.ellipse(x + 9, y + 3, 1, 1, "e")
    // Antlers in the third colour.
    c.line(x - 1, y - 2, x - 5, y - 12, "B"); c.line(x - 3, y - 7, x - 8, y - 9, "B"); c.line(x - 4, y - 10, x - 2, y - 14, "B")
    c.line(x + 1, y - 2, x + 3, y - 11, "B"); c.line(x + 2, y - 7, x + 6, y - 10, "B")
    c.px(x - 2, y + sad, "G"); c.px(x - 3, y + sad, "G")
    eye(c, x + 2, y + 1, f)
  },
}))

// ---------------------------------------------------------------- farm

animal("sheep", [36, 26, 15, [25, 9], [33, 15]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [15, 13, 11, 6], hips: [7, 20], legW: 2, near: "R", far: "Q", bodyKey: "G",
  belly: (c, f, b) => { for (const [x, y] of [[6, 9], [10, 7], [15, 6], [20, 7], [24, 9], [5, 14], [25, 14], [9, 18], [14, 19], [19, 18]]) c.circ(x, y + b, 3, "G"); for (const [x, y] of [[9, 9], [14, 8], [19, 10], [12, 14], [18, 15]]) c.px(x, y + b, "g") },
  tail: (c, f, b) => c.circ(3, 11 + b, 2, "G"),
  head: (c, f, b, sad) => {
    const x = 27 - sad, y = 8 + b + sad * 2
    c.ellipse(x + 1, y + 2, 4, 4, "B"); c.rect(x + 2, y + 3, 4, 3, "B")
    c.ellipse(x - 1, y - 2, 4, 2, "G")
    c.line(x - 4, y + sad, x - 6, y + 2 + sad, "B", 2)
    c.px(x + 5, y + 4, "e")
    eye(c, x + 1, y + 1, f, 2)
  },
}))

animal("pig", [34, 22, 15, [23, 9], [32, 13]], "walk", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [15, 12, 12, 6], hips: [7, 21], legW: 3, near: "R", far: "r",
  tail: (c, f, b, sad) => { if (sad) c.line(3, 10 + b, 2, 14 + b, "R"); else { c.ring(2, 8 + b, 1, "R"); c.px(3, 10 + b, "R") } },
  head: (c, f, b, sad) => {
    const x = 26 - sad, y = 8 + b + sad * 2
    c.ellipse(x, y + 1, 5, 5, "G")
    c.ellipse(x + 5, y + 3, 2, 2, "B"); c.px(x + 5, y + 2, "e"); c.px(x + 5, y + 4, "e")
    if (sad) c.poly([x - 4, y - 2, x, y - 3, x - 2, y + 2], "R"); else c.poly([x - 3, y - 2, x - 1, y - 7, x + 1, y - 3], "R")
    eye(c, x + 1, y - 1, f, 2)
    c.px(x - 2, y + 3, "B")
  },
}))

animal("rabbit", [24, 24, 10, [15, 12], [22, 17]], "hop", (c, f, b, sad, g) => {
  const up = f > 3 ? 0 : [0, 1, 1, 0][f]
  const y = b
  // Back leg: a big folded foot, stretched out mid-hop.
  if (up) { c.rect(2, 20 + y, 6, 2, "r"); c.line(4, 17 + y, 2, 21 + y, "R", 2) } else { c.ellipse(6, 20, 5, 3, "R"); c.rect(3, 22, 7, 1, "r") }
  c.circ(2, 15 + y, 2, "B")
  c.ellipse(9, 16 + y, 7, 5, "G")
  c.ellipse(11, 18 + y, 4, 3, "B")
  c.rect(14, 19 + y, 2, up ? 4 : 4, "R")
  const x = 16 - sad, hy = 11 + y + sad
  c.ellipse(x, hy, 4, 4, "G")
  if (sad) { c.line(x - 3, hy - 2, x - 8, hy + 2, "G", 2); c.line(x - 2, hy - 3, x - 7, hy, "G", 2) }
  else { c.line(x - 2, hy - 3, x - 4, hy - 10, "G", 2); c.line(x, hy - 3, x + 1, hy - 10, "G", 2); c.px(x - 3, hy - 7, "B"); c.px(x + 1, hy - 7, "B") }
  c.px(x + 4, hy + 1, "e"); c.ellipse(x + 3, hy + 2, 1, 1, "B")
  eye(c, x + 1, hy - 1, f)
})

// ---------------------------------------------------------------- small and low

animal("bird", [18, 20, 8, [10, 9], [17, 11]], "hop", (c, f, b, sad, g) => {
  const y = b, x = 8
  c.line(x - 1, 16, x - 2, g, "B"); c.line(x + 1, 16, x + 2, g, "B")
  c.poly([x - 6, 11 + y, x - 9, 14 + y + (sad ? 2 : 0), x - 4, 13 + y], "R")
  c.ellipse(x, 11 + y, 5, 5, "G")
  c.ellipse(x + 1, 13 + y, 3, 3, "B")
  c.ellipse(x - 2, 11 + y, 4, 2 + (f === 1 || f === 2 ? 1 : 0), "R")
  const hx = x + 3, hy = 7 + y + sad
  c.circ(hx, hy, 3, "G")
  c.poly([hx + 3, hy, hx + 6, hy + 1, hx + 3, hy + 2], "B")
  eye(c, hx + 1, hy - 1, f)
})

animal("parakeet", [14, 22, 6, [8, 9], [13, 11]], "hop", (c, f, b, sad, g) => {
  const y = b, x = 6
  c.line(x - 1, 18, x - 1, g, "s"); c.line(x + 1, 18, x + 1, g, "s")
  c.line(x - 3, 15 + y, x - 6, 21 + y, "R", 2)
  c.ellipse(x, 12 + y, 4, 6, "G")
  c.ellipse(x - 2, 13 + y, 2, 4 + (f === 2 ? 1 : 0), "R")
  for (let i = 0; i < 3; i++) c.hline(x - 3, 11 + i * 2 + y, 2, "r")
  const hx = x + 2, hy = 7 + y + sad
  c.circ(hx, hy, 3, "G")
  c.poly([hx + 2, hy, hx + 5, hy + 1, hx + 3, hy + 4], "B")
  c.px(hx + 4, hy + 2, "N")
  c.px(hx - 1, hy + 2, "B")
  eye(c, hx + 1, hy - 1, f)
})

animal("eagle", [26, 28, 11, [14, 11], [23, 14]], "hop", (c, f, b, sad, g) => {
  const y = b, x = 11
  c.rect(x - 2, 22, 2, 5, "B"); c.rect(x + 1, 22, 2, 5, "B"); c.hline(x - 3, g, 7, "B")
  c.poly([x - 7, 16 + y, x - 12, 23 + y, x - 5, 21 + y], "G")
  c.ellipse(x, 16 + y, 6, 7, "G")
  const flap = f === 1 || f === 2
  c.poly([x - 6, 11 + y, x + 3, 12 + y, x - 2, 22 + y, x - 10, 21 + y - (flap ? 4 : 0)], "R")
  for (let i = 0; i < 3; i++) c.line(x - 7 + i * 2, 20 + y, x - 5 + i * 2, 15 + y, "r")
  const hx = x + 3, hy = 9 + y + sad
  c.ellipse(hx, hy, 4, 4, "B")
  c.rect(hx - 4, hy + 2, 6, 4, "B")
  c.poly([hx + 3, hy - 1, hx + 8, hy + 1, hx + 6, hy + 4, hx + 3, hy + 2], "s")
  c.px(hx + 7, hy + 3, "d")
  eye(c, hx + 1, hy - 1, f)
  c.hline(hx, hy - 2, 3, "N")
})

animal("snail", [24, 16, 10, [12, 10], [22, 12]], "crawl", (c, f, b, sad, g) => {
  const s = f > 3 ? 0 : [0, 1, 1, 0][f]
  c.poly([1, g, 2, g - 3, 18 + s, g - 3, 22 + s, g - 1, 22 + s, g], "R")
  c.rect(17 + s, g - 8 + sad, 3, 6 - sad, "R")
  const hx = 18 + s, hy = g - 8 + sad
  if (sad) { c.line(hx + 1, hy, hx + 4, hy + 2, "R"); c.line(hx, hy, hx + 2, hy + 3, "R") }
  else { c.line(hx + 1, hy, hx + 3, hy - 5, "R"); c.line(hx, hy, hx, hy - 4, "R"); c.px(hx + 3, hy - 5, "e"); c.px(hx, hy - 4, "e") }
  eye(c, hx + 1, hy + 1, f)
  c.circ(9, g - 8, 7, "G")
  c.ring(9, g - 8, 4, "g"); c.ring(10, g - 8, 2, "B"); c.px(10, g - 8, "g")
})

animal("tortoise", [32, 16, 14, [22, 9], [30, 11]], "crawl", (c, f, b, sad, g) => {
  for (const [i, x] of [[0, 7], [1, 21]]) leg(c, x + 2, g - 4, g, 3, f, i ? 0 : 2, "r")
  c.poly([2, g - 4, 0, g - 2, 4, g - 3], "R")
  c.clip([0, 0, 32, g - 2], () => c.ellipse(15, g - 2, 12, 9, "G"))
  c.hline(3, g - 3, 25, "H")
  for (const [x, y] of [[10, g - 7], [16, g - 9], [21, g - 6], [13, g - 4], [7, g - 4]]) { c.ellipse(x, y, 2, 1, "B") }
  for (const [i, x] of [[0, 6], [1, 20]]) leg(c, x, g - 4, g, 3, f, i ? 2 : 0, "R")
  const hx = 27 - sad, hy = g - 6 + sad * 2
  c.rect(hx - 2, hy + 1, 3, 3, "R")
  c.ellipse(hx + 1, hy, 3, 2, "R")
  c.px(hx + 4, hy + 1, "e")
  eye(c, hx + 1, hy - 1, f)
})

animal("lizard", [30, 8, 14, [22, 3], [29, 6]], "crawl", (c, f, b, sad, g) => {
  const wig = f > 3 ? 0 : [0, 1, 0, -1][f]
  for (const [i, x] of [[0, 8], [1, 19]]) { const dx = legDX(f, i ? 2 : 0); c.line(x, g - 3, x + dx - 1, g, "R"); c.line(x + 1, g - 3, x + dx + 2, g, "R") }
  c.line(9, g - 3, 1, g - 2 + wig, "G", 2); c.px(0, g - 1 + wig, "G")
  c.ellipse(14, g - 3, 7, 2, "G")
  for (let x = 9; x < 21; x += 3) c.px(x, g - 4, "B")
  const hx = 22, hy = g - 4 + sad
  c.ellipse(hx + 2, hy, 4, 2, "G"); c.px(hx + 6, hy + 1, "e")
  eye(c, hx + 2, hy - 1, f)
  if (f === 2) { c.hline(hx + 6, hy + 1, 2, "B") }
})

animal("snake", [38, 12, 18, [30, 4], [37, 8]], "crawl", (c, f, b, sad, g) => {
  const ph = f > 3 ? 0 : f
  for (let x = 1; x < 30; x++) {
    const y = Math.round(g - 2 - Math.sin((x + ph * 2) / 3.5) * 1.5)
    c.rect(x, y - 1, 1, 3, x < 6 ? "G" : "G"); c.px(x, y + 1, "R")
    if ((x + ph * 2) % 6 === 0) c.rect(x, y - 1, 2, 2, "B")
  }
  const hx = 32 - sad, hy = g - 6 + sad * 3
  c.line(28, g - 2, hx - 1, hy + 1, "G", 3)
  c.ellipse(hx + 1, hy, 4, 3, "G"); c.hline(hx - 2, hy + 2, 6, "R")
  c.px(hx + 5, hy + 1, "e")
  if (f === 1 || f === 3) { c.hline(hx + 5, hy + 2, 2, "s"); c.px(hx + 7, hy + 3, "s") }
  eye(c, hx + 1, hy - 1, f)
})

animal("spider", [26, 14, 12, [12, 6], [20, 9]], "crawl", (c, f, b, sad, g) => {
  for (let i = 0; i < 4; i++) {
    const x = 5 + i * 5, dx = legDX(f, i % 2 ? 2 : 0), kx = x + (i < 2 ? -2 : 2)
    c.line(x + 1, g - 6, kx, g - 9 + (sad ? 2 : 0), "R"); c.line(kx, g - 9 + (sad ? 2 : 0), kx + dx + (i < 2 ? -2 : 2), g, "R")
  }
  c.ellipse(8, g - 7, 6, 5, "G")
  c.px(7, g - 9, "B"); c.px(8, g - 8, "B"); c.px(9, g - 9, "B"); c.px(8, g - 6, "B")
  c.ellipse(16, g - 6, 4, 3, "G")
  if (closed(f)) { c.hline(17, g - 7, 2, "e"); c.hline(19, g - 7, 1, "e") }
  else { c.px(17, g - 7, "w"); c.px(19, g - 7, "w"); c.px(18, g - 8, "w"); c.px(18, g - 6, "e") }
})

animal("crab", [26, 16, 13, [12, 7], [14, 4]], "crawl", (c, f, b, sad, g) => {
  for (let i = 0; i < 3; i++) {
    const dx = legDX(f, i % 2 ? 2 : 0)
    c.line(7 - i * 2, g - 5, 3 - i * 2 + dx, g, "R"); c.line(18 + i * 2, g - 5, 22 + i * 2 + dx, g, "R")
  }
  const up = sad ? 3 : swing(f)
  c.line(6, g - 7, 3, g - 11 + up, "R", 2); c.line(19, g - 7, 22, g - 11 - up, "R", 2)
  c.ellipse(3, g - 13 + up, 3, 2, "B"); c.px(4, g - 15 + up, "_"); c.px(5, g - 14 + up, "_")
  c.ellipse(22, g - 13 - up, 3, 2, "B"); c.px(21, g - 15 - up, "_"); c.px(20, g - 14 - up, "_")
  c.ellipse(13, g - 5, 8, 4, "G"); c.hline(7, g - 2, 13, "g")
  c.vline(11, g - 11 + sad, 3, "R"); c.vline(15, g - 11 + sad, 3, "R")
  eye(c, 11, g - 12 + sad, f); eye(c, 15, g - 12 + sad, f)
  if (!closed(f)) { c.px(11, g - 12, "e"); c.px(15, g - 12, "e") }
})

animal("frog", [20, 14, 9, [10, 5], [18, 9]], "hop", (c, f, b, sad, g) => {
  const air = f === 1 || f === 2
  if (air) { c.line(5, 9 + b, 0, 12 + b, "R", 2); c.rect(0, 12 + b, 3, 1, "R") } else { c.ellipse(5, 11, 4, 2, "R"); c.rect(2, 12, 7, 1, "r") }
  c.ellipse(9, 8 + b, 7, 4, "G")
  c.ellipse(11, 10 + b, 5, 2, "B")
  c.rect(14, 10 + b, 2, air ? 3 : 3, "R")
  c.circ(11, 4 + b + sad, 2, "G"); c.circ(16, 4 + b + sad, 2, "G")
  eye(c, 11, 4 + b + sad, f); eye(c, 16, 4 + b + sad, f)
  if (!closed(f)) { c.px(16, 4 + b, "e") }
  c.hline(13, 8 + b + sad, 4, "H")
})

animal("hyrax", [22, 14, 9, [15, 5], [21, 9]], "hop", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [9, 7, 7, 4], hips: [4, 12], legW: 2,
  head: (c, f, b, sad) => {
    const x = 16 - sad, y = 6 + b + sad
    c.ellipse(x, y, 4, 3, "G"); c.rect(x + 2, y, 3, 2, "G"); c.px(x + 5, y, "e")
    c.circ(x - 2, y - 3, 1, "G"); c.px(x - 2, y - 3, "B")
    c.ellipse(x + 1, y + 2, 2, 1, "B")
    eye(c, x + 1, y - 1, f)
  },
  belly: (c, f, b) => c.ellipse(10, 9 + b, 4, 1, "B"),
}))

animal("monkey", [28, 28, 12, [18, 12], [26, 15]], "hop", (c, f, b, sad, g) => quad(c, f, b, sad, g, {
  body: [12, 15, 7, 5], hips: [7, 15], legW: 2, near: "R", far: "r",
  tail: (c, f, b, sad) => { if (sad) { c.line(5, 13 + b, 1, 20 + b, "R") } else { c.line(5, 13 + b, 1, 6 + b, "R"); c.ring(3, 4 + b, 2, "R"); c.px(5, 4 + b, "_") } },
  head: (c, f, b, sad) => {
    const x = 19 - sad, y = 10 + b + sad * 2
    c.circ(x - 4, y - 1, 2, "G"); c.px(x - 4, y - 1, "B")
    c.circ(x, y, 5, "G")
    c.ellipse(x + 2, y + 1, 3, 3, "B"); c.ellipse(x + 1, y - 2, 2, 1, "B"); c.ellipse(x + 3, y - 2, 1, 1, "B")
    c.px(x + 4, y + 1, "e"); c.hline(x + 2, y + 3, 2, "b")
    eye(c, x + 1, y - 2, f); eye(c, x + 3, y - 2, f)
  },
}))

animal("gorilla", [46, 40, 20, [30, 13], [40, 21]], "walk", (c, f, b, sad, g) => {
  const y = b
  // Short back legs, long front arms walking on their knuckles.
  leg(c, 12, 26 + y, g, 5, f, 0, "r"); leg(c, 30, 16 + y, g, 5, f, 2, "r")
  c.ellipse(19, 21 + y, 14, 10, "G")
  c.ellipse(25, 22 + y, 6, 6, "B")
  c.ellipse(12, 15 + y, 8, 4, "g")
  leg(c, 9, 26 + y, g, 6, f, 2, "R"); leg(c, 27, 18 + y, g, 6, f, 0, "R")
  c.rect(27 + legDX(f, 0), g - 1, 7, 2, "Q")
  const x = 33 - sad, hy = 12 + y + sad * 2
  c.circ(x, hy, 6, "G"); c.ellipse(x - 1, hy - 5, 4, 3, "G")
  c.ellipse(x + 2, hy + 1, 4, 4, "B")
  c.hline(x - 1, hy - 2, 7, "b")
  c.px(x + 4, hy + 1, "e"); c.px(x + 5, hy + 1, "e"); c.hline(x + 2, hy + 4, 3, "N")
  eye(c, x + 1, hy - 1, f); eye(c, x + 4, hy - 1, f)
})

// ---------------------------------------------------------------- water

animal("fish", [22, 26, 11, [8, 8], [19, 11]], "swim", (c, f, b, sad, g) => {
  const y = b, tail = f > 3 ? 0 : [1, 0, -1, 0][f]
  c.poly([4, 8 + y, 0, 4 + y + tail, 0, 14 + y + tail, 4, 10 + y], "R")
  c.poly([9, 4 + y, 13, 1 + y, 14, 5 + y], "R")
  c.ellipse(11, 9 + y, 8, 5, "G")
  c.vline(8, 5 + y, 9, "B"); c.vline(9, 5 + y, 9, "B"); c.vline(14, 5 + y, 8, "B")
  c.poly([11, 11 + y, 9, 14 + y + tail, 13, 12 + y], "R")
  c.px(19, 10 + y, "e")
  eye(c, 16, 7 + y + (sad ? 1 : 0), f, 2)
})

// The whale is drawn half as big again as its outline below suggests (q),
// so it towers over the reef.
const q = (n) => Math.round(n * 1.5)
const qs = (pts) => pts.map(q)
animal("whale", [150, 90, 72, [96, 12], [138, 33]], "swim", (c, f, b, sad, g) => {
  const y = b, tail = f > 3 ? 0 : [2, 0, -2, 0][f]
  c.poly(qs([18, 20 + y, 6, 12 + y + tail, 0, 4 + y + tail, 4, 18 + y + tail, 0, 30 + y + tail, 8, 26 + y + tail, 18, 26 + y]), "G")
  c.ellipse(q(52), q(20 + y), q(38), q(14), "G")
  c.ellipse(q(76), q(18 + y), q(20), q(13), "G")
  c.clip([q(14), q(22 + y), q(86), q(20)], () => { c.ellipse(q(56), q(21 + y), q(36), q(12), "B"); for (let x = 30; x < 90; x += 4) c.vline(q(x), q(26 + y), q(8), "b") })
  c.ellipse(q(52), q(34 + y), q(6), q(3), "R"); c.poly(qs([50, 33 + y, 60, 33 + y, 44, 41 + y + tail]), "R")
  c.hline(q(70), q(26 + y), q(22), "H")
  // Barnacles and a highlight along its back.
  for (const [x, yy] of [[40, 9], [44, 8], [58, 7]]) c.px(q(x), q(yy + y), "g")
  c.hline(q(46), q(7 + y), q(24), "g")
  c.px(q(64), q(7 + y), "s"); c.px(q(63), q(5 + y) - Math.abs(tail), "s"); c.px(q(66), q(5 + y) - Math.abs(tail), "s")
  eye(c, q(78), q(18 + y) + (sad ? 1 : 0), f, 3)
})

// ---------------------------------------------------------------- holiday pets

animal("easter_egg", [20, 26, 10, [6, 8], [16, 14]], "hop", (c, f, b, sad, g) => {
  const y = b
  leg(c, 6, 19 + y, g, 2, f, 0, "R"); leg(c, 12, 19 + y, g, 2, f, 2, "R")
  c.rect(5 + legDX(f, 0), g, 4, 1, "R"); c.rect(11 + legDX(f, 2), g, 4, 1, "R")
  c.ellipse(10, 12 + y, 7, 9, "G")
  c.clip([3, 0, 15, 26], () => { c.hline(2, 8 + y, 16, "B"); c.hline(2, 9 + y, 16, "B"); for (let x = 3; x < 18; x += 3) c.px(x, 14 + y, "B"), c.px(x + 1, 15 + y, "B"); c.hline(2, 17 + y, 16, "B") })
  c.px(6, 5 + y, "w"); c.px(5, 6 + y, "w")
  eye(c, 10, 11 + y + sad, f); eye(c, 14, 11 + y + sad, f)
  if (sad) c.hline(11, 14 + y, 3, "k"); else { c.px(11, 13 + y, "k"); c.px(12, 14 + y, "k"); c.px(13, 13 + y, "k") }
})

animal("birthday_cake", [24, 26, 12, [6, 12], [18, 16]], "walk", (c, f, b, sad, g) => {
  const y = b
  leg(c, 7, 21 + y, g, 2, f, 0, "R"); leg(c, 14, 21 + y, g, 2, f, 2, "R")
  c.rect(6 + legDX(f, 0), g, 4, 1, "R"); c.rect(13 + legDX(f, 2), g, 4, 1, "R")
  c.rect(2, 10 + y, 20, 12, "G")
  c.hline(2, 15 + y, 20, "B"); c.hline(2, 16 + y, 20, "b")
  c.rect(2, 9 + y, 20, 3, "B")
  for (let x = 3; x < 22; x += 4) c.rect(x, 12 + y, 2, 2 + (x % 8 === 3 ? 1 : 0), "B")
  c.ellipse(12, 21 + y, 11, 1, "s")
  c.rect(11, 3 + y, 2, 6, "w"); c.px(11, 5 + y, "s"); c.px(12, 7 + y, "s")
  if (sad) c.px(11, 2 + y, "d"); else { c.px(11 + swing(f), 1 + y, "R"); c.px(11, 2 + y, "R"); c.px(12, 2 + y, "w") }
  eye(c, 13, 17 + y + sad, f); eye(c, 17, 17 + y + sad, f)
  if (!sad) { c.px(14, 19 + y, "k"); c.px(15, 20 + y, "k"); c.px(16, 19 + y, "k") } else c.hline(14, 20 + y, 3, "k")
})

console.log("@@MARKS " + JSON.stringify(MARKS))
