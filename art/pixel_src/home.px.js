// The hilltop view behind every screen (art/home/backdrop.tscn), at a quarter
// size: make.py scales each picture up 4x without smoothing, to 1600 x 1000.
// The layers are drawn in white and greys: each layer's Modulate colours it.
include("home_shapes.js")

pal({
  w: "#ffffff", W: "#ececec", S: "#d2d2d2", D: "#b4b4b4",
  // Day sky, top to bottom.
  a: "#7fb8e0", b: "#93c4e5", c: "#a7d0ea", d: "#bbdcef", e: "#cfe7f4", f: "#e1e8e3", g: "#f3e9d2",
  // Night sky.
  n: "#0d1430", o: "#141c3e", p: "#1b244b", q: "#212b55", r: "#26315c", s: "#303861", t: "#3a3f66",
  y: "#ffd25e", Y: "#ffe9a8", m: "#f4f0dc", M: "#d8d2b8", k: "#fff6d8",
})

const W = 400, H = 250

function ground(c, polys, key, rim) {
  for (const pts of polys) c.poly(pts.map(Math.round), key)
  if (!rim) return
  // A lighter pixel along the top edge, where the light catches it.
  for (let x = 0; x < W; x++) {
    for (let y = 0; y < H; y++) {
      if (c.is(x, y, "*")) { if (c.is(x, y, key)) c.px(x, y, rim); break }
    }
  }
}

/** A pine: stacked tiers narrowing to a point, the right side in shade. */
function pine(c, x, base, h, key = "w", shade = "S") {
  x = Math.round(x); base = Math.round(base); h = Math.max(4, Math.round(h))
  c.rect(x, base - Math.round(h * 0.22), 1, Math.round(h * 0.22) + 1, "D")
  const tiers = h > 14 ? 3 : 2
  for (let t = 0; t < tiers; t++) {
    const bottom = base - Math.round(h * (0.15 + 0.24 * t))
    const top = base - Math.round(h * (0.55 + 0.22 * t)) - (t === tiers - 1 ? Math.round(h * 0.23) : 0)
    const half = Math.max(1, Math.round(h * (0.26 - 0.06 * t)))
    c.poly([x - half, bottom + 1, x + 0.5, top, x + 1 + half, bottom + 1], key)
    c.clip((px) => px > x, () => c.poly([x - half, bottom + 1, x + 0.5, top, x + 1 + half, bottom + 1], shade))
  }
}

/** A bare, crooked tree for Halloween's dead forests. */
function deadTree(c, x, base, h, i) {
  x = Math.round(x); base = Math.round(base); h = Math.round(h)
  const lean = (i % 3) - 1
  const top = [x + lean, base - h]
  c.line(x, base, top[0], top[1], "w", h > 16 ? 2 : 1)
  for (let k = 0; k < 4; k++) {
    const y = base - Math.round(h * (0.4 + 0.14 * k))
    const side = (k + i) % 2 ? 1 : -1
    const len = Math.max(2, Math.round(h * (0.3 - 0.05 * k)))
    const fx = x + Math.round(lean * (0.4 + 0.14 * k))
    c.line(fx, y, fx + side * len, y - Math.round(len * 0.8), "w")
    c.px(fx + side * (len - 1), y - len, "w")
  }
}

scene("1_mountains", { w: W, h: H }, (c) => {
  ground(c, SHAPES.mountains.ground, "w")
  // Slopes falling away to the right are in shade.
  const t = []
  for (let x = 0; x < W; x++) { let y = 0; while (y < H && !c.is(x, y, "*")) y++; t.push(y) }
  const smooth = (x) => { let s = 0; for (let k = -8; k <= 8; k++) s += t[Math.max(0, Math.min(W - 1, x + k))]; return s / 17 }
  for (let x = 0; x < W; x++) if (smooth(x + 1) > smooth(x - 1) + 0.15) c.rect(x, t[x] + 1, 1, H - t[x], "W")
})

scene("2_hills", { w: W, h: H }, (c) => ground(c, SHAPES.hills.ground, "W", "w"))

scene("3_forest_far", { w: W, h: H }, (c) => {
  ground(c, SHAPES.forest_far.ground, "w")
  for (const [x, base, h] of SHAPES.forest_far.trees) pine(c, x, base + 1, h, "w", "W")
})

scene("4_forest_near", { w: W, h: H }, (c) => {
  ground(c, SHAPES.forest_near.ground, "w")
  for (const [x, base, h] of SHAPES.forest_near.trees) pine(c, x, base + 1, h)
})

scene("5_hilltop", { w: W, h: H }, (c) => {
  ground(c, SHAPES.hilltop.ground, "W", "w")
  for (const [x, base, h] of SHAPES.hilltop.trees) pine(c, x, base + 1, h)
  // Grass tufts along the hilltop.
  for (let x = 4; x < W; x += 9) for (let y = 150; y < H; y++) if (c.is(x, y, "*")) { c.px(x, y - 1, "W"); c.px(x + 2, y - 1, "W"); c.px(x + 1, y - 2, "W"); break }
})

scene("dead_3_forest_far", { w: W, h: H }, (c) => {
  ground(c, SHAPES.dead_forest_far.ground, "w")
  SHAPES.dead_forest_far.trees.forEach(([x, base, h], i) => deadTree(c, x, base + 1, h, i))
})
scene("dead_4_forest_near", { w: W, h: H }, (c) => {
  ground(c, SHAPES.dead_forest_near.ground, "w")
  SHAPES.dead_forest_near.trees.forEach(([x, base, h], i) => deadTree(c, x, base + 1, h, i))
})
scene("dead_5_hilltop", { w: W, h: H }, (c) => {
  ground(c, SHAPES.dead_hilltop.ground, "W", "w")
  SHAPES.dead_hilltop.trees.forEach(([x, base, h], i) => deadTree(c, x, base + 1, h, i))
})

scene("sky_day", { w: W, h: H }, grad(0, 0, W, 188, "abcde"), grad(0, 188, W, 62, "efg"))

scene("sky_night", { w: W, h: H }, grad(0, 0, W, 200, "nopqr"), grad(0, 200, W, 50, "rst"), (c) => {
  const rnd = c.rng(7)
  for (let i = 0; i < 90; i++) {
    const x = Math.floor(rnd() * W), y = Math.floor(rnd() * 190), b = rnd()
    c.px(x, y, b > 0.8 ? "w" : b > 0.4 ? "m" : "s")
    if (b > 0.95) { c.px(x - 1, y, "s"); c.px(x + 1, y, "s"); c.px(x, y - 1, "s"); c.px(x, y + 1, "s") }
  }
})

sprite("sun", { w: 50, h: 50 }, circ(25, 25, 24, "#ffe9a812"), circ(25, 25, 19, "#ffe9a826"), circ(25, 25, 14, "#ffe9a85a"),
  circ(25, 25, 9, "y"), px(21, 21, "k"), px(22, 20, "k"), px(21, 22, "k"))

sprite("moon", { w: 50, h: 50 }, circ(25, 25, 22, "#f4f0dc10"), circ(25, 25, 15, "#f4f0dc22"),
  clip((x, y) => (x - 29) ** 2 + (y - 22) ** 2 > 64, circ(25, 25, 9, "m")), px(21, 27, "M"), px(22, 30, "M"), px(19, 24, "M"))
