// Shared palette for every pixel-art file. Animals are painted in pure red, green
// and blue (and darker shades of them): art/animal_colours.gdshader swaps those
// for the animal's three colours. Pure greys (equal red, green and blue) are drawn
// as they are, so outlines, eyes and eye shines stay black and white.
pal({
  R: "#ff0000", r: "#c40000", Q: "#8a0000",
  G: "#00ff00", g: "#00c400", H: "#008a00",
  B: "#0000ff", b: "#0000c4", N: "#00008a",
  k: "#262626", e: "#111111", w: "#ffffff", s: "#9e9e9e", d: "#5e5e5e",
})
ramps("QrR", "HgG", "NbB", "kdsw")
