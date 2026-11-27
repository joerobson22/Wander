// Every gift's picture, 16 x 16 with a dark outline (18 x 18 in the end).
// The game scales them up without smoothing (art/gifts/<gift id>.png).
pal({
  k: "#2b2523", e: "#121212", w: "#fff8ec", W: "#e2d6c2", s: "#b4b4bf", S: "#73737f", d: "#4a4048",
  y: "#ffd54a", Y: "#d4921c", o: "#f08a2c", O: "#b4561a",
  r: "#e0443a", R: "#962828", p: "#f7a8c8", P: "#cc6496", m: "#ffd2e2",
  g: "#7cc456", G: "#3d8a3a", l: "#c6ea8c", h: "#245a2c",
  b: "#5aa0e6", B: "#2f5fa8", c: "#a8e2f2", u: "#1c3a70",
  v: "#a274d6", V: "#64409c", n: "#a8744a", N: "#6b4428", t: "#ddb47c", T: "#8a6a40", x: "#3a2a20",
})
ramps("xNnt", "TtW", "OYy", "Oo", "Rr", "hGgl", "uBbc", "Vv", "PpmW", "dSsw")

const G16 = { w: 16, h: 16, outline: "k" }
const gift = (id, ...items) => sprite(id, G16, ...items)
const shine = (x, y) => [px(x, y, "w"), px(x + 1, y, "w"), px(x, y + 1, "w")]

// ---------------------------------------------------------------- shared shapes

function ball(id, main, dark, extra = []) {
  gift(id, circ(7, 8, 6, main), clip((x, y) => x + y > 17, circ(7, 8, 6, dark)), ...extra, ...shine(4, 5))
}
function berry(cx, cy, col, dark) { return [circ(cx, cy, 2, col), px(cx + 1, cy + 1, dark), px(cx - 1, cy - 1, "w")] }
function leafShape(id, main, dark, vein, opts = {}) {
  gift(id, poly([2, 14, 4, 6, 9, 2, 14, 1, 13, 7, 9, 12], main),
    clip((x, y) => x > y - 2, poly([2, 14, 4, 6, 9, 2, 14, 1, 13, 7, 9, 12], dark)),
    line(2, 14, 12, 3, vein), line(1, 15, 3, 13, opts.stem ?? "N"), ...(opts.extra ?? []))
}
function feather(id, main, dark, tip, extra = []) {
  gift(id, poly([2, 15, 4, 9, 9, 3, 14, 0, 12, 6, 7, 12], main),
    clip((x, y) => x + y > 14, poly([2, 15, 4, 9, 9, 3, 14, 0, 12, 6, 7, 12], dark)),
    poly([11, 2, 14, 0, 13, 4], tip), line(1, 15, 12, 2, "W"), ...extra)
}
function egg(id, main, dark, extra = []) {
  gift(id, ellipse(8, 9, 5, 6, main), clip((x, y) => x > 9 || y > 12, ellipse(8, 9, 5, 6, dark)), ...extra, ...shine(5, 5))
}
function pebble(id, main, dark, extra = []) {
  gift(id, ellipse(8, 10, 6, 4, main), clip((x, y) => y > 11, ellipse(8, 10, 6, 4, dark)), ...extra, px(5, 8, "w"), px(6, 8, "w"))
}
function bone(id, main, dark, extra = []) {
  gift(id, line(4, 11, 11, 4, main, 3), circ(3, 11, 2, main), circ(4, 13, 2, main), circ(11, 2, 2, main), circ(13, 4, 2, main),
    line(5, 12, 12, 5, dark), ...extra)
}
function coin(id, main, dark, mark, extra = []) {
  gift(id, circ(8, 8, 6, dark), circ(8, 8, 5, main), ...(mark ?? [rect(7, 5, 2, 6, dark)]), ...extra, px(5, 5, "w"), px(6, 4, "w"))
}
function flower(id, petal, dark, centre, stem = "G") {
  gift(id, line(8, 9, 7, 15, stem, 1), poly([7, 13, 3, 11, 6, 15], "g"),
    circ(8, 3, 3, petal), circ(4, 6, 3, petal), circ(12, 6, 3, petal), circ(5, 10, 2, petal), circ(11, 10, 2, petal),
    px(8, 1, dark), px(3, 8, dark), px(13, 8, dark), circ(8, 7, 2, centre), px(7, 6, "w"))
}
function bottle(id, glass, dark, inside, extra = []) {
  gift(id, rect(6, 1, 4, 2, "n"), rect(6, 3, 4, 3, glass), rect(3, 6, 10, 9, glass), rect(4, 14, 8, 1, dark),
    rect(4, 7, 8, 7, dark), rect(5, 7, 6, 6, glass), ...inside, vline(4, 7, 6, "w"), ...extra)
}

// Wearables.
// Grids for the wearables, painted in stand-in keys and swapped per gift:
// X main, Z its shade, J stripe or trim, C cuff, D cuff shade.
pal({ X: "#ff00ff", Z: "#aa00aa", J: "#00ffff", C: "#ffff00", D: "#aaaa00" })
sprite("_scarf", `
  ................
  ....XXXXXXXX....
  ..XXZZZZZZZZXX..
  .XJXXXJXXXJXXJX.
  .XJXXXJXXXJXXJX.
  ..XXXXXXXXXXXX..
  ....XXXXXXXXX...
  .........XXXX...
  ........XXXXXZ..
  ........XJJJXZ..
  .......XXXXXXZ..
  .......XXXXXZ...
  .......XJJJXZ...
  .......XXXXXZ...
  .......J.J.J....`)
sprite("_mitten", `
  .....XXXXX......
  ....XXXXXXX.....
  ...XXXXXXXXZ....
  ...XXXXXXXXZ....
  .X.XXXXXXXXZ....
  XXXXXXXXXXXZ....
  XXXXXXXXXXXZ....
  .XXXXXXXXXXZ....
  ..XXXXXXXXXZ....
  ...XXXXXXXZ.....
  ..CCCCCCCCCC....
  ..CDCDCDCDCD....
  ..CCCCCCCCCC....`)
function scarf(id, a, sh, b, stripes = true) {
  gift(id, stamp("_scarf", 0, 0, { swap: { X: a, Z: sh, J: stripes ? b : a } }), px(4, 3, "w"), px(5, 3, "w"))
}
function mitten(id, main, cuff, extra = []) {
  gift(id, stamp("_mitten", 1, 2, { swap: { X: main, Z: main, C: cuff, D: cuff } }), shade([12, 2, 4, 10]), shade([3, 13, 12, 1]),
    ...extra, px(6, 3, "w"), px(5, 4, "w"))
}
function ring(id, band, bandDark, gem, gemDark) {
  gift(id, ring_(8, 10, 5, band), ring_(8, 10, 4, band), clip((x, y) => y > 11, ring_(8, 10, 5, bandDark)),
    poly([5, 4, 8, 1, 11, 4, 8, 7], gem), poly([8, 4, 11, 4, 8, 7], gemDark), px(7, 3, "w"))
}
function ring_(cx, cy, r, c) { return ellipse(cx, cy, r, r - 1, c, true) }
function boot(id, main, dark, sole, extra = []) {
  gift(id, rect(3, 1, 6, 9, main), rect(3, 9, 11, 4, main), ellipse(12, 11, 3, 2, main), rect(2, 13, 13, 2, sole),
    vline(8, 1, 9, dark), hline(3, 1, 6, dark), ...extra, vline(4, 2, 7, "w"))
}
function shoe(id, main, dark, sole, extra = []) {
  gift(id, poly([1, 8, 7, 6, 10, 8, 15, 10, 15, 13, 1, 13], main), rect(1, 13, 15, 2, sole),
    poly([1, 8, 4, 7, 4, 13, 1, 13], dark), ...extra, hline(5, 8, 3, "w"))
}
function sandal(id, sole, strap, extra = []) {
  gift(id, ellipse(8, 12, 7, 2, sole), hline(2, 13, 13, "N"), line(4, 11, 9, 6, strap, 2), line(9, 6, 13, 11, strap, 2), ...extra)
}
function slipper(id, main, dark, face) {
  gift(id, ellipse(8, 10, 7, 4, main), clip((x, y) => y > 11, ellipse(8, 10, 7, 4, dark)), ellipse(5, 9, 3, 2, "W"), ...face)
}
function stick(id, wood, dark, top) {
  gift(id, line(3, 15, 11, 3, wood, 2), line(4, 15, 12, 3, dark), ...top)
}
function cape(id, main, dark, lining, extra = []) {
  gift(id, poly([5, 1, 11, 1, 15, 15, 1, 15], main), poly([11, 1, 15, 15, 10, 15], dark), poly([5, 1, 11, 1, 10, 3, 6, 3], lining),
    rect(7, 2, 2, 2, "y"), ...extra)
}
function top(id, main, dark, extra = []) {
  gift(id, poly([4, 1, 12, 1, 16, 5, 13, 8, 12, 6, 12, 15, 4, 15, 4, 6, 3, 8, 0, 5], main),
    rect(5, 1, 6, 1, dark), rect(4, 14, 8, 1, dark), poly([6, 1, 10, 1, 8, 3], "W"), ...extra)
}
function hatBase(id, ...items) { gift(id, ...items) }

// ---------------------------------------------------------------- dog
ball("dog_common", "l", "g", [line(1, 6, 7, 14, "w"), line(8, 2, 14, 10, "w")])
gift("dog_rare", ellipse(8, 9, 5, 6, "n"), ...[3, 6, 9, 12].flatMap((y, i) => [hline(4 + (i % 2), y, 8 - (i % 2) * 2, "N"), px(5 + (i % 2) * 2, y + 1, "t"), px(9, y + 1, "t")]), rect(7, 1, 2, 3, "G"))
bone("dog_epic", "w", "W", [px(12, 3, "p")])
gift("dog_legendary", ellipse(8, 7, 7, 5, "y", true), ellipse(8, 7, 6, 4, "Y", true), rect(6, 10, 4, 4, "y"), rect(7, 11, 2, 2, "Y"), px(3, 4, "w"), px(6, 11, "w"))
top("dog_legendary2", "o", "O", [hline(4, 9, 8, "r"), hline(4, 10, 8, "y"), px(6, 5, "y"), px(9, 6, "r")])

// ---------------------------------------------------------------- cat
feather("cat_common", "W", "s", "p")
gift("cat_rare", ellipse(8, 9, 5, 6, "G"), ellipse(8, 9, 4, 5, "g"), vline(8, 4, 11, "h"), ellipse(8, 3, 2, 2, "h"),
  line(3, 7, 1, 5, "k"), line(3, 11, 1, 13, "k"), line(13, 7, 15, 5, "k"), line(13, 11, 15, 13, "k"), px(6, 6, "l"), px(6, 7, "w"))
gift("cat_epic", circ(7, 8, 6, "v"), ...[[3, 5, 10, 12], [2, 9, 9, 14], [5, 2, 12, 9]].map(([a, b, c2, d]) => line(a, b, c2, d, "V")), line(12, 12, 15, 15, "v"), px(5, 5, "w"))
gift("cat_legendary", rect(2, 6, 12, 8, "s"), ellipse(8, 7, 6, 4, "s"), poly([2, 5, 3, 0, 6, 4], "s"), poly([10, 4, 13, 0, 14, 5], "s"),
  px(3, 2, "p"), px(12, 2, "p"), rect(2, 12, 12, 3, "S"), ...[3, 6, 9, 12].map((x) => vline(x, 12, 3, "d")))
ring("cat_legendary2", "y", "Y", "g", "G")

// ---------------------------------------------------------------- rabbit
gift("rabbit_common", poly([3, 7, 7, 4, 13, 14], "o"), poly([6, 5, 13, 14, 8, 6], "O"), line(5, 8, 7, 7, "O"), line(8, 10, 9, 9, "O"),
  poly([4, 5, 2, 0, 5, 3], "g"), poly([5, 4, 6, 0, 7, 4], "G"), poly([5, 5, 9, 1, 8, 5], "g"))
gift("rabbit_rare", ...[4, 7, 10].map((x, i) => line(x, 15, x + 2 - i, 2, i === 1 ? "g" : "l", 2)), poly([3, 2, 6, 0, 7, 3], "g"), poly([9, 1, 11, 0, 11, 3], "G"), line(7, 15, 8, 3, "G"))
gift("rabbit_epic", poly([3, 7, 7, 4, 13, 14], "y"), poly([6, 5, 13, 14, 8, 6], "Y"), line(5, 8, 7, 7, "Y"), line(8, 10, 9, 9, "Y"),
  poly([4, 5, 2, 0, 5, 3], "g"), poly([5, 4, 6, 0, 7, 4], "G"), px(5, 7, "w"), px(1, 10, "w"), px(14, 5, "w"), px(13, 6, "y"))
gift("rabbit_legendary", rect(4, 1, 8, 10, "d"), rect(4, 8, 8, 2, "r"), ellipse(8, 12, 7, 2, "d"), hline(1, 12, 14, "e"), vline(5, 2, 6, "S"),
  ellipse(13, 2, 1, 2, "w"), ellipse(14, 1, 1, 2, "w"))
ring("rabbit_legendary2", "s", "S", "r", "R")

// ---------------------------------------------------------------- sheep
gift("sheep_common", circ(5, 9, 4, "w"), circ(10, 8, 4, "w"), circ(8, 5, 3, "w"), circ(11, 12, 3, "W"), circ(5, 12, 3, "W"), px(7, 8, "W"), px(10, 6, "W"), px(5, 10, "s"))
gift("sheep_rare", ...[[5, 4], [11, 4], [5, 10], [11, 10]].map(([x, y]) => circ(x, y, 3, "g")), ...[[5, 4], [11, 4], [5, 10], [11, 10]].map(([x, y]) => line(x, y, 8, 7, "G")), line(8, 8, 11, 15, "G"), px(4, 3, "l"))
gift("sheep_epic", rect(2, 2, 12, 5, "n"), hline(2, 2, 12, "t"), ...[3, 5, 7, 9, 11, 13].map((x) => vline(x, 7, 7, "s")), ...[3, 7, 11].map((x) => px(x, 14, "S")))
stick("sheep_legendary", "n", "N", [ring_(12, 4, 3, "n"), px(15, 7, "_"), px(14, 7, "n")])
mitten("sheep_legendary2", "W", "s", [px(6, 6, "s"), px(9, 4, "s"), px(8, 8, "s")])

// ---------------------------------------------------------------- bird
gift("bird_common", line(3, 1, 9, 6, "G"), line(9, 6, 13, 3, "G"), ...berry(5, 9, "r", "R"), ...berry(10, 11, "r", "R"), ...berry(8, 6, "r", "R"), poly([12, 2, 15, 1, 14, 4], "g"))
egg("bird_rare", "c", "b", [px(6, 11, "B"), px(10, 7, "B"), px(9, 12, "B")])
feather("bird_epic", "b", "B", "y", [px(6, 9, "y"), px(9, 6, "c"), px(4, 12, "c")])
cape("bird_legendary", "b", "B", "c", [...[4, 7, 10].flatMap((y) => [line(4 + y / 3, y + 2, 7, y, "c")])])
gift("bird_legendary2", ellipse(8, 10, 7, 4, "n"), ellipse(8, 9, 5, 2, "N"), ...[[2, 9, 6, 13], [5, 8, 11, 13], [9, 8, 14, 11], [1, 11, 6, 9]].map(([a, b, c2, d]) => line(a, b, c2, d, "t")),
  ellipse(6, 7, 2, 2, "c"), ellipse(10, 7, 2, 2, "c"), px(5, 6, "w"), px(9, 6, "w"))

// ---------------------------------------------------------------- pig
gift("pig_common", ellipse(8, 10, 5, 5, "n"), ellipse(8, 5, 5, 2, "N"), rect(7, 1, 2, 3, "N"), ...[[4, 12], [11, 9], [7, 13]].map(([x, y]) => rect(x, y, 2, 1, "x")), px(5, 8, "t"))
gift("pig_rare", circ(5, 10, 4, "N"), circ(10, 9, 5, "N"), circ(8, 6, 3, "x"), ...[[4, 9], [8, 7], [11, 11], [6, 12], [12, 7]].map(([x, y]) => px(x, y, "n")), px(9, 5, "N"))
gift("pig_epic", ellipse(8, 13, 7, 2, "s"), ellipse(8, 13, 6, 1, "w"), circ(6, 9, 4, "N"), circ(10, 8, 4, "N"), ...[[5, 8], [10, 7], [8, 10]].map(([x, y]) => px(x, y, "n")), px(12, 2, "y"), px(3, 3, "y"), px(13, 5, "w"))
boot("pig_legendary", "g", "G", "N", [rect(9, 11, 5, 2, "n"), px(11, 12, "N"), rect(3, 12, 3, 1, "N")])
scarf("pig_legendary2", "p", "P", "v")

// ---------------------------------------------------------------- snail
gift("snail_common", poly([2, 14, 3, 8, 6, 5, 10, 6, 13, 9, 14, 14], "l"), circ(8, 9, 4, "g"), px(6, 7, "w"), px(7, 6, "w"), circ(3, 4, 1, "l"), px(12, 3, "g"), hline(1, 15, 14, "g"))
gift("snail_rare", ellipse(8, 5, 7, 3, "Y"), rect(1, 5, 15, 2, "y"), rect(1, 7, 15, 2, "g"), rect(1, 9, 15, 3, "N"), rect(1, 12, 15, 1, "o"), ellipse(8, 13, 7, 2, "Y"),
  ...[[4, 3], [7, 2], [10, 3], [12, 4]].map(([x, y]) => px(x, y, "w")))
gift("snail_epic", circ(8, 8, 7, "t"), ring_(8, 8, 5, "n"), ring_(9, 8, 3, "N"), circ(9, 8, 1, "n"), px(5, 4, "w"), px(4, 5, "w"))
slipper("snail_legendary", "t", "n", [circ(11, 7, 3, "n"), ring_(11, 7, 1, "N"), line(14, 9, 15, 5, "t"), px(15, 4, "e")])
gift("snail_legendary2", poly([1, 4, 7, 7, 1, 11], "v"), poly([15, 4, 9, 7, 15, 11], "v"), rect(6, 6, 4, 4, "V"), line(2, 5, 2, 10, "V"), line(14, 5, 14, 10, "V"), px(3, 6, "w"))

// ---------------------------------------------------------------- tortoise
flower("tortoise_common", "y", "Y", "o")
gift("tortoise_rare", poly([3, 6, 8, 2, 13, 5, 14, 11, 8, 14, 2, 11], "c"), poly([8, 8, 13, 5, 14, 11, 8, 14], "b"), poly([3, 6, 8, 2, 8, 8], "w"), px(6, 5, "w"))
gift("tortoise_epic", rect(1, 2, 14, 12, "t"), rect(1, 2, 2, 12, "T"), rect(13, 2, 2, 12, "T"), line(4, 11, 7, 7, "R"), line(7, 7, 9, 9, "R"), line(9, 9, 11, 5, "R"),
  line(10, 4, 12, 6, "r"), line(12, 4, 10, 6, "r"), circ(5, 5, 1, "G"), hline(4, 12, 3, "b"))
stick("tortoise_legendary", "N", "x", [circ(12, 3, 3, "g"), circ(12, 3, 1, "c"), px(11, 2, "w")])
gift("tortoise_legendary2", ellipse(8, 6, 6, 5, "W", true), ...[[3, 9], [6, 11], [10, 11], [13, 9]].map(([x, y]) => [circ(x, y, 1, "p"), px(x, y + 1, "P")]).flat(), circ(8, 12, 2, "t"), px(8, 12, "n"))

// ---------------------------------------------------------------- bear
gift("bear_common", ...[[6, 6], [9, 6], [5, 9], [8, 9], [11, 9], [7, 12], [10, 12]].map(([x, y]) => circ(x, y, 2, "V")), ...[[5, 5], [8, 5], [4, 8], [7, 8], [10, 8], [6, 11]].map(([x, y]) => px(x, y, "v")), line(8, 4, 9, 0, "G"), poly([9, 2, 13, 0, 12, 3], "g"))
gift("bear_rare", line(8, 0, 8, 2, "N"), ellipse(8, 9, 6, 7, "y"), ...[5, 8, 11, 14].map((y) => hline(2, y, 13, "Y")), ellipse(8, 12, 2, 2, "x"),
  ...[[13, 3], [2, 5]].map(([x, y]) => [px(x, y, "e"), px(x - 1, y - 1, "w"), px(x + 1, y - 1, "w")]).flat())
gift("bear_epic", rect(3, 5, 10, 10, "o"), ellipse(8, 5, 6, 2, "O"), rect(2, 3, 12, 2, "W"), rect(2, 3, 12, 1, "w"), poly([3, 5, 7, 5, 6, 9, 5, 7], "y"), poly([10, 5, 13, 5, 12, 8], "y"), rect(5, 9, 6, 4, "w"), hline(6, 10, 4, "O"), vline(4, 6, 8, "y"))
gift("bear_legendary", poly([1, 9, 4, 5, 10, 4, 14, 6, 15, 9, 11, 11, 4, 11], "o"), poly([1, 9, 4, 11, 11, 11, 15, 9, 13, 13, 3, 13], "r"), poly([0, 6, 2, 8, 0, 11], "O"), circ(12, 7, 1, "e"), ...[6, 8, 10].map((x) => px(x, 7, "O")), hline(2, 14, 13, "s"))
stick("bear_legendary2", "N", "x", [circ(12, 3, 3, "n"), circ(10, 1, 1, "n"), circ(14, 1, 1, "n"), px(11, 3, "e"), px(13, 3, "e"), px(12, 4, "x")])

// ---------------------------------------------------------------- frog
gift("frog_common", circ(8, 9, 7, "g"), clip((x, y) => x > 8 && y < 9, circ(8, 9, 7, "_")), line(8, 9, 3, 13, "G"), line(8, 9, 2, 7, "G"), px(5, 13, "l"), px(3, 10, "l"), px(12, 12, "G"))
gift("frog_rare", line(2, 9, 14, 7, "b", 2), line(10, 8, 14, 7, "B"), ellipse(6, 4, 4, 2, "c"), ellipse(10, 4, 3, 2, "c"), ellipse(6, 12, 4, 2, "c"), ellipse(10, 12, 3, 2, "c"), circ(14, 7, 1, "B"), px(14, 6, "w"))
gift("frog_epic", circ(8, 10, 6, "G"), clip((x, y) => x > 8 && y < 10, circ(8, 10, 6, "_")), line(8, 10, 3, 13, "h"), flower_("p", 11, 5))
function flower_(c, x, y) { return (cv) => { cv.circ(x, y - 2, 1, c); cv.circ(x - 2, y, 1, c); cv.circ(x + 2, y, 1, c); cv.circ(x, y + 1, 1, c); cv.px(x, y - 1, "y"); cv.px(x, y, "y") } }
gift("frog_legendary", ellipse(8, 8, 6, 5, "g"), ellipse(8, 12, 8, 2, "g"), hline(2, 9, 12, "G"), clip((x, y) => y > 12, ellipse(8, 12, 8, 2, "G")), circ(4, 3, 2, "g"), circ(12, 3, 2, "g"), px(4, 3, "e"), px(12, 3, "e"), px(3, 2, "w"))
top("frog_legendary2", "g", "G", [poly([4, 1, 12, 1, 12, 4, 4, 4], "G"), rect(5, 9, 6, 3, "G"), px(7, 5, "W"), px(9, 5, "W")])

// ---------------------------------------------------------------- fox
gift("fox_common", poly([3, 15, 6, 1, 11, 2, 9, 15], "y"), poly([7, 1, 11, 2, 9, 15, 7, 15], "Y"), hline(5, 3, 5, "o"), px(6, 7, "t"))
mitten("fox_rare", "r", "W", [rect(7, 0, 2, 1, "r"), px(8, 5, "o")])
egg("fox_epic", "t", "n", [px(10, 10, "N"), px(6, 12, "N")])
slipper("fox_legendary", "o", "O", [poly([10, 7, 15, 8, 12, 11], "o"), poly([9, 5, 10, 3, 11, 6], "o"), px(14, 8, "e"), px(11, 7, "e"), poly([13, 9, 15, 8, 14, 10], "w")])
scarf("fox_legendary2", "o", "O", "w")

// ---------------------------------------------------------------- parakeet
gift("parakeet_common", ellipse(8, 8, 4, 7, "d"), ellipse(7, 8, 2, 5, "S"), vline(8, 2, 12, "w"), px(6, 4, "w"), px(10, 12, "e"))
coin("parakeet_rare", "r", "R", [ring_(8, 8, 3, "w")], [...[2, 5, 9, 12].map((x) => px(x, x < 8 ? 3 : 13, "R"))])
gift("parakeet_epic", circ(8, 7, 6, "y"), circ(8, 7, 5, "c"), clip((x, y) => x + y > 15, circ(8, 7, 5, "b")), line(5, 5, 7, 3, "w"), rect(7, 13, 2, 3, "Y"), rect(5, 15, 6, 1, "Y"))
cape("parakeet_legendary", "g", "G", "r", [...[5, 8, 11].map((y) => hline(4, y, 3, "y")), ...[6, 9, 12].map((y) => hline(9, y, 3, "b"))])
mitten("parakeet_legendary2", "g", "y", [line(3, 3, 6, 8, "r"), line(7, 2, 9, 8, "b"), px(11, 4, "y")])

// ---------------------------------------------------------------- spider
gift("spider_common", poly([8, 1, 13, 9, 11, 14, 5, 14, 3, 9], "c"), clip((x, y) => x > 8, poly([8, 1, 13, 9, 11, 14, 5, 14, 3, 9], "b")), px(6, 6, "w"), px(6, 7, "w"), px(5, 8, "w"))
gift("spider_rare", ellipse(8, 9, 4, 6, "W"), ...[5, 8, 11].map((y) => line(4, y - 1, 12, y + 1, "s")), poly([4, 2, 1, 0, 2, 4], "c"), poly([12, 2, 15, 0, 14, 4], "c"), px(7, 2, "e"), px(9, 2, "e"))
gift("spider_epic", ...[0, 1, 2, 3].map((i) => line(8, 8, 8 + Math.round(7 * Math.cos(i * Math.PI / 4)), 8 + Math.round(7 * Math.sin(i * Math.PI / 4)), "s")),
  ...[0, 1, 2, 3].map((i) => line(8, 8, 8 - Math.round(7 * Math.cos(i * Math.PI / 4)), 8 - Math.round(7 * Math.sin(i * Math.PI / 4)), "s")), ring_(8, 8, 3, "W"), ring_(8, 8, 6, "W"),
  circ(3, 4, 1, "c"), circ(12, 11, 1, "c"), px(11, 3, "c"), px(2, 4, "w"))
stick("spider_legendary", "d", "e", [poly([12, 0, 13, 3, 16, 3, 14, 5, 15, 8, 12, 6, 9, 8, 10, 5, 8, 3, 11, 3], "v"), px(12, 3, "w")])
mitten("spider_legendary2", "w", "W", [line(4, 4, 12, 10, "s"), line(12, 3, 5, 10, "s")])

// ---------------------------------------------------------------- hyrax
pebble("hyrax_common", "s", "S")
leafShape("hyrax_rare", "t", "T", "n", { stem: "n" })
pebble("hyrax_epic", "o", "O", [...[[4, 4], [7, 3], [10, 4]].map(([x, y]) => line(x, y + 3, x + 1, y, "r"))])
sandal("hyrax_legendary", "t", "n", [px(9, 6, "o")])
top("hyrax_legendary2", "t", "T", [circ(8, 9, 2, "y"), ...[[8, 5], [8, 13], [4, 9], [12, 9]].map(([x, y]) => px(x, y, "y"))])

// ---------------------------------------------------------------- lizard
coin("lizard_common", "W", "t", [px(8, 5, "n"), px(5, 8, "n"), px(11, 8, "n"), px(6, 11, "n"), px(10, 11, "n"), px(8, 8, "t")])
gift("lizard_rare", poly([1, 12, 4, 6, 9, 4, 14, 3, 12, 7, 7, 10], "W"), ...[[4, 9], [6, 7], [8, 6], [10, 5], [7, 9]].map(([x, y]) => px(x, y, "t")), line(1, 12, 0, 15, "W"))
gift("lizard_epic", poly([0, 14, 3, 8, 8, 4, 15, 2, 12, 8, 6, 12], "l"), ...[[3, 11], [5, 9], [7, 7], [9, 6], [11, 5], [6, 10], [9, 8]].map(([x, y]) => px(x, y, "g")), px(13, 3, "w"))
gift("lizard_legendary", ...[0, 1, 2, 3, 4, 5, 6].map((i) => poly([8, 14, 8 + Math.round(8 * Math.cos(Math.PI * (0.05 + i * 0.15))), 14 - Math.round(12 * Math.sin(Math.PI * (0.05 + i * 0.15))), 8 + Math.round(8 * Math.cos(Math.PI * (0.12 + i * 0.15))), 14 - Math.round(12 * Math.sin(Math.PI * (0.12 + i * 0.15)))], i % 2 ? "o" : "y")), circ(8, 14, 3, "g"))
ring("lizard_legendary2", "g", "G", "l", "g")

// ---------------------------------------------------------------- snake
pebble("snake_common", "W", "s")
gift("snake_rare", ...[0, 1, 2, 3, 4].map((i) => ellipse(4 + i * 2, 12 - i * 2, 3, 2, i % 2 ? "t" : "W")), ...[0, 1, 2, 3, 4].map((i) => px(4 + i * 2, 13 - i * 2, "T")))
gift("snake_epic", ...[[8, 4, 4], [4, 8, 3], [12, 8, 3], [6, 12, 3], [10, 12, 3]].map(([x, y, r]) => ellipse(x, y, r, 2, "t")), ...[[8, 4], [4, 8], [12, 8], [6, 12], [10, 12]].map(([x, y]) => hline(x - 2, y + 1, 4, "T")), circ(8, 9, 2, "n"))
stick("snake_legendary", "N", "x", [line(10, 2, 12, 5, "g", 2), line(12, 5, 14, 2, "g", 2), circ(14, 1, 1, "g"), px(14, 1, "e"), px(15, 0, "r")])
gift("snake_legendary2", ...[0, 1, 2, 3, 4, 5, 6].map((i) => circ(2 + i * 2, 8 + Math.round(Math.sin(i * 1.1) * 4), 2, i % 2 ? "G" : "g")), circ(14, 8 + Math.round(Math.sin(6.6) * 4), 2, "g"), px(15, 6, "e"), px(14, 5, "w"))

// ---------------------------------------------------------------- monkey
gift("monkey_common", line(3, 13, 6, 5, "y", 3), line(6, 5, 12, 1, "y", 3), line(4, 14, 8, 5, "Y"), rect(12, 0, 2, 2, "N"), rect(2, 13, 2, 2, "x"), px(7, 8, "n"))
gift("monkey_rare", circ(8, 8, 7, "N"), clip((x, y) => y > x + 2, circ(8, 8, 7, "x")), circ(8, 8, 5, "w"), ring_(8, 8, 5, "W"), px(5, 5, "n"), px(10, 4, "n"), px(7, 3, "n"))
gift("monkey_epic", ...[0, 1, 2, 3].map((i) => line(3 + i * 2, 13 - i, 7 + i * 2, 3 + i, i % 2 ? "Y" : "y", 2)), rect(9, 1, 3, 3, "G"), rect(10, 0, 2, 1, "N"))
mitten("monkey_legendary", "n", "N", [...[5, 8, 11].map((x) => px(x, 7, "t")), ...[5, 8, 11].map((x) => px(x, 9, "t"))])
sandal("monkey_legendary2", "g", "G", [px(6, 9, "l"), px(11, 9, "l"), line(9, 6, 9, 3, "G"), px(10, 3, "g")])

// ---------------------------------------------------------------- gorilla
gift("gorilla_common", rect(6, 3, 4, 12, "l"), rect(6, 6, 4, 1, "g"), rect(6, 10, 4, 1, "g"), rect(9, 3, 1, 12, "g"), poly([7, 3, 8, 0, 9, 3], "g"), poly([6, 7, 1, 4, 5, 9], "g"))
leafShape("gorilla_rare", "g", "G", "l", { extra: [line(6, 9, 4, 6, "l"), line(8, 7, 10, 10, "l")] })
gift("gorilla_epic", rect(4, 4, 3, 11, "l"), rect(9, 2, 3, 13, "l"), hline(4, 8, 3, "g"), hline(9, 6, 3, "g"), hline(9, 11, 3, "g"), poly([5, 4, 5, 0, 6, 4], "g"), poly([10, 2, 10, 0, 11, 2], "g"), poly([12, 6, 15, 3, 13, 7], "g"))
stick("gorilla_legendary", "n", "N", [line(9, 6, 14, 1, "g", 2), poly([12, 3, 15, 4, 13, 6], "l"), poly([9, 5, 7, 2, 11, 3], "g")])
top("gorilla_legendary2", "G", "h", [poly([6, 7, 10, 7, 8, 11], "g"), vline(8, 8, 5, "l")])

// ---------------------------------------------------------------- tiger
gift("tiger_common", ellipse(8, 9, 6, 6, "y"), clip((x, y) => x + y < 15, ellipse(8, 9, 6, 6, "r")), clip((x, y) => x > 10, ellipse(8, 9, 6, 6, "o")), rect(8, 1, 1, 3, "N"), poly([9, 2, 13, 0, 12, 3], "g"))
flower("tiger_rare", "v", "V", "w", "G")
pebble("tiger_epic", "o", "O", [line(5, 7, 4, 12, "x"), line(9, 7, 8, 13, "x"), line(12, 8, 12, 12, "x")])
mitten("tiger_legendary", "o", "w", [line(6, 3, 6, 7, "x"), line(10, 3, 10, 7, "x"), line(8, 2, 8, 5, "x")])
scarf("tiger_legendary2", "o", "O", "x")

// ---------------------------------------------------------------- giraffe
leafShape("giraffe_common", "g", "G", "l")
gift("giraffe_rare", line(2, 15, 14, 1, "n", 2), line(3, 15, 14, 2, "N"), line(7, 9, 4, 5, "n"), line(10, 6, 13, 8, "n"), poly([4, 5, 1, 4, 3, 2], "g"))
gift("giraffe_epic", line(3, 15, 10, 4, "N"), ...[[6, 10], [8, 7], [10, 4], [5, 13], [12, 6]].map(([x, y]) => [circ(x - 2, y, 2, "g"), circ(x + 2, y - 1, 2, "l")]).flat(), px(11, 2, "y"), px(4, 8, "y"))
stick("giraffe_legendary", "t", "n", [ring_(12, 4, 3, "t"), px(15, 7, "_"), ...[[6, 10], [8, 7], [10, 5]].map(([x, y]) => px(x, y, "N"))])
top("giraffe_legendary2", "y", "Y", [...[[5, 4], [9, 6], [6, 9], [10, 11], [5, 13], [11, 3]].map(([x, y]) => rect(x, y, 2, 2, "n"))])

// ---------------------------------------------------------------- elephant
gift("elephant_common", ellipse(8, 8, 4, 7, "t"), hline(5, 8, 7, "T"), ...[[7, 4], [9, 6], [7, 11], [9, 12]].map(([x, y]) => px(x, y, "n")), px(6, 3, "W"))
flower("elephant_rare", "m", "p", "y", "G")
gift("elephant_epic", poly([3, 15, 2, 6, 6, 3, 10, 3, 14, 6, 13, 15], "t"), rect(5, 1, 6, 2, "n"), clip((x, y) => x > 9, poly([3, 15, 2, 6, 6, 3, 10, 3, 14, 6, 13, 15], "T")), ...[[5, 8], [9, 10], [6, 12]].map(([x, y]) => [ellipse(x, y, 2, 1, "n"), px(x, y, "N")]).flat())
stick("elephant_legendary", "n", "N", [line(11, 3, 14, 1, "W", 2), px(15, 1, "W"), rect(10, 4, 3, 2, "y")])
top("elephant_legendary2", "s", "S", [circ(8, 8, 2, "W"), line(9, 9, 10, 12, "W"), ellipse(6, 8, 1, 2, "p")])

// ---------------------------------------------------------------- rhino
ball("rhino_common", "N", "x", [px(9, 10, "n"), px(5, 11, "n"), px(10, 6, "n")])
feather("rhino_rare", "N", "x", "r")
ball("rhino_epic", "n", "N", [circ(5, 13, 2, "N"), circ(12, 4, 2, "N"), px(8, 9, "x"), px(13, 12, "x"), px(2, 4, "N")])
boot("rhino_legendary", "s", "S", "d", [poly([12, 9, 14, 5, 14, 10], "W")])
mitten("rhino_legendary2", "s", "S", [...[[5, 5], [9, 4], [7, 8], [11, 8]].map(([x, y]) => rect(x, y, 2, 2, "S"))])

// ---------------------------------------------------------------- leopard
gift("leopard_common", line(2, 14, 13, 3, "n", 2), poly([11, 1, 15, 1, 15, 5], "t"), poly([12, 3, 15, 1, 14, 5], "W"), line(3, 14, 13, 4, "N"))
feather("leopard_rare", "y", "Y", "N", [...[[5, 10], [8, 7], [10, 5], [6, 12]].map(([x, y]) => px(x, y, "N"))])
leafShape("leopard_epic", "g", "G", "l", { extra: [...[[6, 7], [9, 4], [11, 6], [5, 10]].map(([x, y]) => px(x, y, "h"))] })
cape("leopard_legendary", "y", "Y", "r", [...[[4, 6], [7, 9], [10, 7], [5, 12], [11, 12], [8, 5]].map(([x, y]) => [px(x, y, "N"), px(x + 1, y, "N"), px(x, y + 1, "N")]).flat()])
shoe("leopard_legendary2", "y", "Y", "w", [...[[6, 9], [9, 10], [12, 11]].map(([x, y]) => px(x, y, "N"))])

// ---------------------------------------------------------------- lion
gift("lion_common", ...[3, 5, 7, 9, 11, 13].map((x, i) => line(8, 15, x, 2 + (i % 2) * 2, i % 2 ? "Y" : "y")), hline(6, 15, 5, "Y"))
gift("lion_rare", poly([4, 2, 12, 2, 11, 8, 9, 15, 7, 15, 5, 8], "w"), poly([9, 2, 12, 2, 11, 8, 9, 15], "W"), hline(4, 2, 8, "p"), px(6, 4, "w"))
gift("lion_epic", ...[0, 1, 2, 3, 4].map((i) => line(4 + i * 2, 15, 2 + i * 3, 2, i % 2 ? "O" : "o", 2)), rect(4, 12, 8, 3, "Y"))
gift("lion_legendary", rect(2, 7, 12, 7, "y"), poly([2, 7, 2, 2, 5, 6, 8, 1, 11, 6, 14, 2, 14, 7], "y"), hline(2, 13, 12, "Y"), rect(2, 8, 12, 1, "Y"), circ(8, 10, 1, "r"), circ(4, 10, 1, "b"), circ(12, 10, 1, "g"), px(3, 3, "w"))
mitten("lion_legendary2", "y", "o", [ellipse(8, 7, 3, 2, "t"), ...[5, 8, 11].map((x) => circ(x, 3, 1, "t"))])

// ---------------------------------------------------------------- eagle
gift("eagle_common", line(2, 14, 13, 3, "N"), line(7, 9, 4, 4, "N"), line(10, 6, 14, 8, "N"), circ(13, 3, 1, "w"), circ(4, 4, 1, "w"), circ(14, 8, 1, "w"), hline(5, 9, 3, "w"))
feather("eagle_rare", "n", "N", "w")
egg("eagle_epic", "W", "t", [px(6, 11, "n"), px(10, 8, "n"), px(9, 12, "n"), px(7, 7, "n")])
mitten("eagle_legendary", "N", "n", [hline(3, 11, 10, "x"), px(7, 6, "x")])
cape("eagle_legendary2", "s", "S", "w", [line(4, 15, 7, 8, "W"), line(9, 15, 10, 9, "W")])

// ---------------------------------------------------------------- red panda
gift("red_panda_common", line(8, 1, 6, 8, "G"), line(8, 1, 11, 7, "G"), ...berry(5, 11, "r", "R"), ...berry(11, 10, "r", "R"), poly([8, 1, 12, 0, 11, 2], "g"))
flower("red_panda_rare", "m", "p", "P", "N")
gift("red_panda_epic", line(8, 1, 4, 8, "G"), line(8, 1, 8, 8, "G"), line(8, 1, 12, 7, "G"), ...berry(4, 11, "r", "R"), ...berry(8, 12, "r", "R"), ...berry(12, 10, "r", "R"), rect(6, 0, 5, 2, "p"))
stick("red_panda_legendary", "N", "x", [...[[11, 2], [13, 4], [9, 4], [13, 1]].map(([x, y]) => [circ(x, y, 1, "m"), px(x, y, "p")]).flat()])
stick("red_panda_legendary2", "l", "g", [hline(6, 10, 3, "G"), hline(9, 6, 3, "G"), poly([11, 3, 15, 1, 13, 4], "g")])

// ---------------------------------------------------------------- mammoth
gift("mammoth_common", ...[4, 6, 8, 10, 12].map((x, i) => line(x, 14, x + (i % 2 ? 2 : -1), 2 + i % 3, i % 2 ? "N" : "n", 2)), hline(3, 14, 11, "N"))
gift("mammoth_rare", poly([2, 4, 9, 1, 14, 4, 14, 12, 7, 15, 2, 12], "c"), poly([9, 1, 14, 4, 14, 12, 7, 15], "b"), poly([5, 7, 9, 6, 9, 10, 6, 11], "t"), px(7, 8, "n"), poly([3, 4, 7, 2, 5, 6], "w"))
gift("mammoth_epic", poly([4, 15, 3, 7, 5, 2, 8, 1, 11, 2, 13, 7, 12, 15], "W"), poly([8, 1, 11, 2, 13, 7, 12, 15, 9, 15], "s"), hline(3, 6, 10, "S"), hline(4, 10, 8, "S"), px(6, 3, "w"))
stick("mammoth_legendary", "W", "s", [ellipse(12, 2, 3, 2, "W"), poly([14, 1, 16, 4, 14, 4], "W"), hline(9, 6, 3, "N")])
scarf("mammoth_legendary2", "n", "N", "t")

// ---------------------------------------------------------------- fish
gift("fish_common", poly([3, 6, 8, 2, 13, 5, 14, 11, 8, 14, 2, 11], "g"), poly([8, 8, 13, 5, 14, 11, 8, 14], "G"), poly([3, 6, 8, 2, 8, 8], "l"), px(6, 5, "w"))
gift("fish_rare", ellipse(8, 11, 7, 4, "s"), ellipse(8, 11, 6, 3, "S"), ellipse(8, 5, 7, 4, "W"), circ(8, 10, 3, "w"), px(7, 9, "c"), clip((x, y) => y < 6, ellipse(8, 5, 7, 4, "s")))
bottle("fish_epic", "c", "b", [rect(6, 8, 4, 4, "W"), hline(6, 9, 3, "s"), hline(6, 11, 2, "s")])
gift("fish_legendary", poly([1, 4, 7, 4, 15, 12, 15, 15, 1, 15], "b"), poly([9, 7, 15, 12, 15, 15, 7, 15], "B"), ...[3, 5, 7].map((x) => vline(x, 5, 10, "c")), hline(1, 15, 15, "u"))
stick("fish_legendary2", "y", "Y", [ring_(12, 4, 3, "y"), ...[[5, 5], [3, 2], [8, 1]].map(([x, y]) => ring_(x, y, 1, "c")), circ(12, 4, 2, "c")])

// ---------------------------------------------------------------- crab
coin("crab_common", "t", "n", [px(8, 5, "N"), px(5, 8, "N"), px(11, 8, "N"), px(6, 11, "N"), px(10, 11, "N")])
gift("crab_rare", poly([2, 14, 4, 7, 9, 2, 14, 6, 13, 13], "p"), ring_(9, 8, 3, "P"), ring_(9, 8, 1, "P"), poly([2, 14, 13, 13, 8, 15], "P"), px(6, 5, "w"))
coin("crab_epic", "y", "Y", [ring_(8, 8, 3, "Y")], [px(12, 13, "G"), px(3, 12, "G"), px(4, 13, "h")])
mitten("crab_legendary", "r", "R", [line(7, 1, 7, 7, "R"), poly([7, 0, 9, 1, 8, 2], "_")])
sandal("crab_legendary2", "y", "b", [px(9, 6, "r")])

// ---------------------------------------------------------------- whale
gift("whale_common", ...[[4, 5], [9, 4], [12, 8], [6, 10], [10, 12], [3, 13], [13, 3]].map(([x, y]) => [ellipse(x, y, 2, 1, "p"), px(x + 2, y, "P")]).flat())
gift("whale_rare", circ(8, 10, 6, "W"), clip((x, y) => y > 11, circ(8, 10, 6, "s")), ellipse(8, 5, 3, 2, "s"), ellipse(8, 4, 2, 1, "S"), line(3, 9, 6, 13, "W"), line(13, 9, 10, 13, "W"))
gift("whale_epic", poly([2, 13, 3, 6, 8, 2, 13, 6, 14, 13], "c"), ...[4, 6, 8, 10, 12].map((x) => line(8, 13, x, 4 + Math.abs(x - 8) / 2, "b")), hline(2, 13, 13, "B"), px(5, 6, "w"))
boot("whale_legendary", "b", "B", "u", [...[4, 7].map((y) => hline(3, y, 5, "c")), px(11, 10, "c"), px(13, 11, "c")])
boot("whale_legendary2", "B", "u", "d", [...[[4, 5], [6, 8], [11, 10], [5, 11]].map(([x, y]) => [circ(x, y, 1, "W"), px(x, y, "s")]).flat()])

// ---------------------------------------------------------------- pterodactyl
gift("pterodactyl_common", poly([3, 8, 9, 4, 13, 8, 9, 12], "s"), poly([13, 8, 16, 5, 16, 11], "s"), clip((x, y) => y > 8, poly([3, 8, 9, 4, 13, 8, 9, 12], "S")), px(5, 7, "e"), line(8, 6, 8, 10, "S"), px(6, 6, "w"))
pebble("pterodactyl_rare", "t", "T", [px(10, 10, "W")])
gift("pterodactyl_epic", rect(1, 2, 14, 13, "W"), rect(2, 3, 12, 11, "t"), line(3, 11, 8, 6, "w"), line(8, 6, 13, 4, "w"), line(8, 6, 12, 11, "w"), line(8, 6, 7, 12, "w"), px(4, 4, "T"))
gift("pterodactyl_legendary", ellipse(8, 13, 7, 2, "y"), poly([3, 13, 6, 5, 10, 4, 13, 13], "y"), poly([10, 4, 16, 1, 13, 7], "Y"), clip((x, y) => x > 9, poly([3, 13, 6, 5, 10, 4, 13, 13], "Y")), px(6, 8, "w"))
cape("pterodactyl_legendary2", "n", "N", "t", [line(3, 14, 8, 4, "N"), line(13, 14, 8, 4, "N")])
// ---------------------------------------------------------------- triceratops
leafShape("triceratops_common", "g", "G", "l", { extra: [line(5, 10, 3, 8, "l"), line(8, 7, 6, 5, "l"), line(7, 9, 9, 11, "l")] })
gift("triceratops_rare", poly([3, 15, 6, 6, 12, 1, 9, 9, 8, 15], "W"), poly([9, 9, 12, 1, 8, 15], "s"), hline(3, 14, 6, "T"), px(7, 7, "w"))
gift("triceratops_epic", ellipse(8, 10, 7, 6, "o"), clip((x, y) => y > 11, ellipse(8, 10, 7, 6, "O")), ellipse(8, 12, 3, 2, "n"), ...[[3, 6], [6, 4], [10, 4], [13, 6]].map(([x, y]) => px(x, y, "O")), px(5, 7, "w"))
gift("triceratops_legendary", ellipse(8, 11, 6, 4, "w"), clip((x, y) => y > 12, ellipse(8, 11, 6, 4, "W")), line(4, 8, 1, 1, "w", 2), line(12, 8, 15, 1, "w", 2), poly([7, 8, 8, 4, 9, 8], "W"), rect(2, 13, 12, 2, "o"))
mitten("triceratops_legendary2", "o", "O", [...[4, 7, 10].map((x) => px(x, 4, "y"))])
// ---------------------------------------------------------------- stegosaurus
gift("stegosaurus_common", ellipse(8, 9, 5, 6, "n"), ...[4, 7, 10, 13].flatMap((y) => [hline(5, y, 6, "N"), px(7 + (y % 2), y + 1, "t")]), poly([6, 3, 8, 0, 10, 3], "g"))
gift("stegosaurus_rare", poly([2, 14, 8, 1, 14, 14], "o"), poly([8, 1, 14, 14, 9, 14], "O"), line(8, 4, 8, 13, "O"), hline(2, 14, 13, "N"), px(6, 9, "y"))
gift("stegosaurus_epic", poly([2, 15, 4, 12, 14, 1, 7, 14], "W"), poly([14, 1, 7, 14, 6, 13], "s"), rect(1, 13, 5, 3, "G"), px(10, 5, "w"))
top("stegosaurus_legendary", "g", "G", [...[3, 6, 9].map((y) => poly([12, y + 1, 15, y + 2, 12, y + 3], "o"))])
gift("stegosaurus_legendary2", ellipse(8, 9, 6, 5, "N", true), ellipse(8, 9, 5, 4, "N", true), ...[[2, 6], [5, 3], [11, 3], [14, 6], [8, 2]].map(([x, y]) => poly([x - 1, y + 1, x, y - 2, x + 1, y + 1], "o")), rect(7, 13, 2, 2, "s"))
// ---------------------------------------------------------------- diplodocus
gift("diplodocus_common", line(8, 15, 8, 5, "N"), ...[[4, 4], [11, 3], [5, 9], [11, 9], [8, 2]].map(([x, y]) => [ellipse(x, y, 3, 2, "g"), px(x - 1, y - 1, "l")]).flat())
pebble("diplodocus_rare", "s", "S", [px(9, 11, "d"), px(11, 9, "d")])
gift("diplodocus_epic", ellipse(8, 11, 7, 4, "t"), ellipse(8, 11, 5, 3, "T"), ...[[2, 5], [6, 3], [10, 3], [14, 5]].map(([x, y]) => circ(x, y, 1, "T")))
scarf("diplodocus_legendary", "s", "S", "b")
stick("diplodocus_legendary2", "s", "S", [line(11, 3, 13, 0, "s", 2), circ(13, 1, 2, "s"), px(14, 0, "e")])
// ---------------------------------------------------------------- t. rex
bone("t_rex_common", "W", "t")
gift("t_rex_rare", poly([5, 2, 11, 2, 14, 8, 11, 15, 5, 15, 2, 8], "y"), clip((x, y) => x + y > 17, poly([5, 2, 11, 2, 14, 8, 11, 15, 5, 15, 2, 8], "Y")), ellipse(8, 9, 2, 1, "x"), line(6, 8, 5, 6, "x"), line(10, 8, 11, 6, "x"), px(5, 4, "w"), px(6, 4, "w"))
egg("t_rex_epic", "l", "g", [...[[6, 7], [10, 9], [7, 12], [11, 5]].map(([x, y]) => px(x, y, "G"))])
mitten("t_rex_legendary", "g", "G", [...[4, 7, 10].map((x) => poly([x, 2, x + 1, 0, x + 2, 2], "w"))])
boot("t_rex_legendary2", "G", "h", "d", [...[[10, 10], [13, 11]].map(([x, y]) => poly([x, y, x + 1, y - 2, x + 2, y], "w"))])

// ---------------------------------------------------------------- skeleton dog (Halloween)
gift("skeleton_dog_common", line(3, 13, 13, 4, "w", 2), circ(2, 13, 2, "w"), circ(14, 3, 2, "w"), line(4, 14, 13, 6, "W"))
gift("skeleton_dog_rare", rect(5, 1, 6, 2, "d"), rect(7, 0, 2, 1, "d"), rect(4, 3, 8, 11, "d"), rect(5, 4, 6, 9, "y"), rect(6, 5, 4, 7, "w"), circ(8, 9, 1, "o"), rect(3, 14, 10, 2, "d"))
bone("skeleton_dog_epic", "l", "g", [px(3, 11, "w"), px(12, 3, "w")])
gift("skeleton_dog_legendary", poly([1, 13, 7, 0, 12, 13], "v"), poly([8, 2, 12, 13, 9, 13], "V"), ellipse(8, 13, 8, 2, "v"), hline(4, 11, 8, "o"), rect(7, 10, 2, 2, "y"))
gift("skeleton_dog_legendary2", ellipse(8, 6, 6, 5, "N", true), ...[[3, 9], [6, 11], [10, 11], [13, 9]].map(([x, y]) => [line(x - 1, y, x + 1, y + 2, "w"), px(x - 1, y + 2, "w"), px(x + 1, y, "w")]).flat(), bone_(8, 13))
function bone_(x, y) { return (c) => { c.rect(x - 2, y, 5, 1, "w"); c.px(x - 3, y - 1, "w"); c.px(x - 3, y + 1, "w"); c.px(x + 3, y - 1, "w"); c.px(x + 3, y + 1, "w") } }

// ---------------------------------------------------------------- reindeer (Christmas)
gift("reindeer_common", circ(8, 9, 6, "o"), clip((x, y) => x + y > 18, circ(8, 9, 6, "O")), ...[[6, 7], [10, 9], [8, 12]].map(([x, y]) => px(x, y, "O")), rect(7, 2, 2, 2, "N"), poly([9, 2, 13, 0, 12, 3], "g"), px(5, 6, "y"))
gift("reindeer_rare", circ(8, 9, 6, "y"), clip((x, y) => y > 10, circ(8, 9, 6, "Y")), hline(2, 9, 13, "Y"), circ(8, 12, 1, "x"), ring_(8, 2, 1, "s"), px(5, 6, "w"), px(6, 5, "w"))
gift("reindeer_epic", circ(5, 10, 4, "s"), circ(11, 8, 4, "y"), clip((x, y) => y > 9, circ(5, 10, 4, "S")), clip((x, y) => y > 8, circ(11, 8, 4, "Y")), circ(5, 12, 1, "x"), circ(11, 10, 1, "x"), line(7, 3, 9, 6, "r"), px(10, 2, "r"), px(12, 6, "w"))
gift("reindeer_legendary", ellipse(8, 13, 7, 3, "r", true), line(3, 11, 2, 4, "n", 2), line(2, 7, 0, 5, "n"), line(2, 4, 4, 1, "n"), line(13, 11, 14, 4, "n", 2), line(14, 7, 16, 5, "n"), line(14, 4, 12, 1, "n"))
top("reindeer_legendary2", "r", "R", [hline(4, 8, 8, "w"), ...[5, 7, 9, 11].map((x) => px(x, 9, "g")), circ(8, 12, 1, "w"), px(6, 5, "w"), px(10, 5, "w")])

// ---------------------------------------------------------------- Easter egg
coin("easter_egg_common", "y", "Y", [ring_(8, 8, 3, "Y"), px(8, 8, "Y")], [rect(3, 2, 2, 1, "N")])
egg("easter_egg_rare", "c", "b", [hline(3, 7, 10, "p"), hline(3, 8, 10, "p"), ...[4, 7, 10, 13].map((x) => px(x, 11, "y")), hline(4, 13, 8, "v")])
coin("easter_egg_epic", "Y", "N", [ring_(8, 8, 3, "y")], [hline(3, 13, 10, "N")])
shoe("easter_egg_legendary", "m", "p", "w", [hline(6, 10, 6, "c"), px(13, 11, "y")])
scarf("easter_egg_legendary2", "c", "b", "m")

// ---------------------------------------------------------------- birthday cake
gift("birthday_cake_common", rect(6, 6, 4, 9, "p"), ...[7, 9, 11, 13].map((y) => hline(6, y, 4, "w")), vline(8, 4, 2, "e"), ellipse(8, 2, 1, 2, "y"), px(8, 1, "o"), px(8, 3, "w"))
gift("birthday_cake_rare", poly([2, 15, 9, 8, 12, 11], "v"), line(3, 14, 8, 9, "y"), ...[[11, 3], [14, 6], [8, 2], [13, 1], [15, 3], [10, 6]].map(([x, y], i) => px(x, y, "rgbyp"[i % 5])), line(10, 8, 13, 5, "y"))
gift("birthday_cake_epic", ellipse(8, 13, 6, 2, "s"), rect(6, 9, 4, 4, "c"), hline(6, 10, 4, "w"), vline(8, 7, 2, "e"), ellipse(8, 5, 1, 2, "y"), px(8, 4, "o"), poly([5, 9, 6, 10, 5, 12], "c"))
gift("birthday_cake_legendary", rect(2, 8, 12, 6, "y"), poly([2, 8, 2, 3, 5, 6, 8, 2, 11, 6, 14, 3, 14, 8], "y"), hline(2, 13, 12, "Y"), circ(5, 10, 1, "p"), circ(8, 10, 1, "c"), circ(11, 10, 1, "g"), px(8, 2, "w"))
gift("birthday_cake_legendary2", poly([1, 4, 7, 7, 1, 11], "r"), poly([15, 4, 9, 7, 15, 11], "b"), rect(6, 6, 4, 4, "y"), px(3, 6, "y"), px(3, 9, "g"), px(13, 6, "g"), px(12, 9, "y"))

// ---------------------------------------------------------------- holiday presents
gift("bunny_ears", ellipse(8, 14, 7, 2, "w", true), ellipse(4, 6, 2, 6, "w"), ellipse(12, 6, 2, 6, "w"), ellipse(4, 6, 1, 4, "m"), ellipse(12, 6, 1, 4, "m"))
gift("party_hat", poly([2, 15, 8, 0, 14, 15], "v"), ...[4, 8, 12].map((y) => line(8 - y / 2.5, y, 8 + y / 2.5, y + 1, "y")), circ(8, 1, 2, "p"), hline(1, 15, 15, "V"))
gift("pumpkin_head", ellipse(8, 9, 7, 6, "o"), ellipse(8, 9, 3, 6, "O", true), clip((x, y) => x > 11, ellipse(8, 9, 7, 6, "O")), rect(7, 1, 2, 3, "G"),
  poly([4, 7, 6, 6, 6, 8], "e"), poly([10, 6, 12, 7, 10, 8], "e"), poly([4, 11, 12, 11, 11, 13, 5, 13], "e"), px(7, 11, "o"), px(9, 13, "o"))
gift("tree_costume", poly([8, 0, 14, 7, 11, 7, 15, 13, 1, 13, 5, 7, 2, 7], "G"), clip((x, y) => x > 8, poly([8, 0, 14, 7, 11, 7, 15, 13, 1, 13, 5, 7, 2, 7], "h")), rect(7, 13, 2, 3, "N"),
  px(8, 0, "y"), ...[[6, 5, "r"], [10, 9, "y"], [5, 11, "b"], [11, 12, "r"], [8, 8, "p"]].map(([x, y, c]) => px(x, y, c)))
