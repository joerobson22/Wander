// Pieces of the walk that are pictures rather than drawn layers: the bush a
// pet dives into for its gift (art/walk/bush.png), and the holiday props
// dotted in the grass and on the home view (pumpkins, eggs). make.py scales
// the props up 5x so they keep the size of the pictures they replace.
pal({
  k: "#2b2523", w: "#fff8ec",
  G: "#3f6b3a", g: "#4e7a46", m: "#5f8f52", l: "#6fa45e", L: "#86b874",
  o: "#e8812c", O: "#d9692a", R: "#b9531f", y: "#ffd25e", Y: "#ffeea0", s: "#5b7a34", d: "#3a2a20",
  p: "#f4a6c4", P: "#e0559a", b: "#9cc8ee", B: "#4f8fd0", u: "#bfe3a0", U: "#6aa84a", e: "#ffe27a", E: "#e2a615",
})

// The dive bush: round clumps of leaves, darker underneath, lit along the top.
sprite("bush", { w: 44, h: 42, outline: "k" },
  ...[[9, 31, 9, "g"], [34, 31, 9, "g"], [14, 22, 11, "m"], [30, 21, 12, "m"], [22, 30, 12, "g"], [21, 12, 10, "l"], [33, 26, 8, "m"], [11, 26, 8, "m"]]
    .map(([x, y, r, c]) => circ(x, y, r, c)),
  (c) => {
    // Leaf texture: little arcs of a lighter green on each clump's top.
    const rnd = c.rng(4)
    for (let i = 0; i < 40; i++) {
      const x = 3 + Math.floor(rnd() * 38), y = 4 + Math.floor(rnd() * 34)
      if (!c.is(x, y, "gml")) continue
      const lighter = { g: "m", m: "l", l: "L" }[c.key(x, y)]
      c.px(x, y, lighter); c.px(x + 1, y - 1, lighter)
    }
    for (let x = 0; x < 44; x++) for (let y = 36; y < 42; y++) if (c.is(x, y, "*")) c.px(x, y, "G")
  })

// Halloween.
const pumpkin = (face) => [
  ellipse(6, 12, 6, 7, "O"), ellipse(17, 12, 6, 7, "O"), ellipse(12, 12, 7, 8, "o"),
  line(12, 5, 11, 19, "R"), line(6, 6, 5, 18, "R"), line(18, 6, 19, 18, "R"),
  rect(11, 1, 2, 4, "s"), px(13, 1, "s"), px(14, 0, "s"), ...face]
sprite("pumpkin", { w: 24, h: 20 }, ...pumpkin([px(9, 8, "y"), px(10, 7, "Y")]))
sprite("jack_o_lantern", { w: 24, h: 20 }, ...pumpkin([
  poly([7, 9, 10, 7, 10, 10], "y"), poly([14, 7, 17, 9, 14, 10], "y"),
  poly([6, 13, 18, 13, 16, 16, 8, 16], "y"), px(10, 13, "o"), px(14, 16, "o"), px(12, 9, "Y")]))

// Easter eggs.
function egg(id, main, dark, light) {
  sprite(id, { w: 16, h: 20 }, ellipse(8, 11, 7, 9, main),
    clip((x, y) => (x - 8) ** 2 / 49 + (y - 11) ** 2 / 81 <= 1, (c) => {
      for (let x = 0; x < 16; x++) { const y = 9 + (x % 4 < 2 ? 0 : -1); c.rect(x, y, 1, 2, "w") }
      c.circ(5, 15, 1, dark); c.circ(9, 16, 1, dark); c.circ(12, 14, 1, dark); c.circ(6, 5, 1, dark); c.circ(10, 5, 1, dark)
    }),
    px(4, 6, light), px(5, 5, light))
}
egg("egg_pink", "p", "P", "w")
egg("egg_blue", "b", "B", "w")
egg("egg_green", "u", "U", "w")
egg("egg_yellow", "e", "E", "w")
