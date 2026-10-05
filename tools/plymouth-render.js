// Usage (needs Node): npm i @resvg/resvg-js@2, put ChakraPetch-Bold.ttf (Google Fonts) next to this file,
// then: node tools/plymouth-render.js files/system/usr/share/plymouth/themes/goblincakes
// Renders the GOBLINCAKES Plymouth images at 2x (the theme scales them to the screen).
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const out = process.argv[2];

function render(name, svg, opts = {}) {
  const r = new Resvg(svg, {
    background: 'rgba(0,0,0,0)',
    font: { fontFiles: [__dirname + '/ChakraPetch-Bold.ttf'], loadSystemFonts: false, defaultFontFamily: 'Chakra Petch' },
    ...opts,
  });
  const png = r.render();
  fs.writeFileSync(`${out}/${name}`, png.asPng());
  console.log(name, png.width, 'x', png.height);
}

// Logo exactly as in the design's Boot artboard (180 px -> 360 px at 2x)
render('logo.png', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="360" height="360">
<path d="M28 66 C22 58 16 48 10 38 C22 42 30 46 34 50 C38 34 48 24 60 24 C72 24 82 34 86 50 C90 46 98 42 110 38 C104 48 98 58 92 66 Z" fill="#E6ECF5"/>
<path d="M43 45 L55 50 L52 55 Z" fill="#000000"/>
<path d="M77 45 L65 50 L68 55 Z" fill="#000000"/>
<path d="M30 70 H90 L81 106 H39 Z" fill="#2F6FED"/>
<path d="M49 73 L51 103 M60 73 V103 M71 73 L69 103" stroke="#000000" stroke-width="3" stroke-linecap="round" fill="none" opacity="0.45"/>
</svg>`);

// "GOBLINCAKES": Chakra Petch Bold 40 px, letter-spacing 10 px (x2), Frost
render('title.png', `<svg xmlns="http://www.w3.org/2000/svg" width="800" height="104">
<text x="400" y="74" text-anchor="middle" font-family="Chakra Petch" font-weight="700" font-size="80" letter-spacing="20" fill="#E6ECF5">GOBLINCAKES</text>
</svg>`, { fitTo: { mode: 'original' } });

// Padlock for the disk-password box (line icon, Frost)
render('lock.png', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="48" height="48">
<g fill="none" stroke="#E6ECF5" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
<rect x="5" y="11" width="14" height="10"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></g></svg>`);

// 1x1 colour pixels, stretched by the script
const px = (name, c) => render(name, `<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1" fill="${c}"/></svg>`);
px('bar-bg.png', '#12203A');   // progress track (Deep)
px('bar-fg.png', '#2F6FED');   // progress (Accent)
px('box.png', '#0E1420');      // password box (Night)
px('box-border.png', '#1E2A40'); // password box frame
px('bullet.png', '#E6ECF5');   // password bullet (square, Frost)
