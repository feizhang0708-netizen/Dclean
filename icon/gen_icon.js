const sharp = require("sharp");
const fs = require("fs");
const path = require("path");

const SIZES = {
  "icon_16x16.png": 16,
  "icon_16x16@2x.png": 32,
  "icon_32x32.png": 32,
  "icon_32x32@2x.png": 64,
  "icon_128x128.png": 128,
  "icon_128x128@2x.png": 256,
  "icon_256x256.png": 256,
  "icon_256x256@2x.png": 512,
  "icon_512x512.png": 512,
  "icon_512x512@2x.png": 1024,
};

async function generateIcon(size) {
  const s = size;
  const m = s * 0.08;   // margin
  const r = s * 0.22;   // corner radius

  // Modern, Apple-style system cleaner icon
  // Dark background with sweeping clean arc + geometric accents
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${s}" height="${s}" viewBox="0 0 ${s} ${s}">
    <defs>
      <!-- Background gradient -->
      <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:#0F1B2D"/>
        <stop offset="100%" style="stop-color:#060B14"/>
      </linearGradient>
      <!-- Sweep gradient -->
      <linearGradient id="sweepGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:#FF6238"/>
        <stop offset="100%" style="stop-color:#FF8A50"/>
      </linearGradient>
      <!-- Teal glow -->
      <radialGradient id="tealGlow" cx="30%" cy="70%" r="50%">
        <stop offset="0%" style="stop-color:#00D4AA;stop-opacity:0.3"/>
        <stop offset="100%" style="stop-color:#00D4AA;stop-opacity:0"/>
      </radialGradient>
      <!-- Shadow -->
      <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
        <feDropShadow dx="0" dy="0" stdDeviation="${s*0.03}" flood-color="#000000" flood-opacity="0.5"/>
      </filter>
    </defs>

    <!-- Rounded background -->
    <rect x="${m}" y="${m}" width="${s-m*2}" height="${s-m*2}" rx="${r}" ry="${r}" fill="url(#bgGrad)" filter="url(#shadow)"/>

    <!-- Subtle teal glow spot -->
    <circle cx="${s*0.3}" cy="${s*0.7}" r="${s*0.35}" fill="url(#tealGlow)"/>

    <!-- Main sweep arc - stylized cleaning swoosh -->
    <g transform="translate(${s/2},${s/2})">
      <!-- Outer track ring -->
      <circle cx="0" cy="0" r="${s*0.32}" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="${s*0.04}" />

      <!-- Sweep progress arc (280 degrees, gap at bottom-right) -->
      <path d="M ${-s*0.28} ${-s*0.16}
               A ${s*0.32} ${s*0.32} 0 1 1 ${s*0.16} ${s*0.28}"
            fill="none" stroke="url(#sweepGrad)" stroke-width="${s*0.05}" stroke-linecap="round"/>

      <!-- Sweep head dot -->
      <circle cx="${s*0.18}" cy="${s*0.26}" r="${s*0.045}" fill="#FF6238"/>
      <circle cx="${s*0.18}" cy="${s*0.26}" r="${s*0.065}" fill="#FF6238" opacity="0.3"/>

      <!-- Center: stylized "D" or speed arrow -->
      <!-- Arrow-up motif (optimization / speed) -->
      <g transform="rotate(-15)">
        <path d="M ${-s*0.06} ${s*0.04}
                 L 0 ${-s*0.12}
                 L ${s*0.06} ${s*0.04}"
              fill="none" stroke="white" stroke-width="${s*0.035}" stroke-linecap="round" stroke-linejoin="round"/>
      </g>
      <circle cx="0" cy="0" r="${s*0.025}" fill="white"/>
    </g>

    <!-- Small decorative dots -->
    <circle cx="${s*0.22}" cy="${s*0.22}" r="${s*0.012}" fill="#FF6238" opacity="0.5"/>
    <circle cx="${s*0.78}" cy="${s*0.75}" r="${s*0.01}" fill="#00D4AA" opacity="0.4"/>
    <circle cx="${s*0.75}" cy="${s*0.2}" r="${s*0.008}" fill="white" opacity="0.15"/>
  </svg>`;

  const png = await sharp(Buffer.from(svg)).png().toBuffer();
  return png;
}

async function main() {
  const iconsetDir = path.join(__dirname, "Dclean.iconset");

  for (const [name, size] of Object.entries(SIZES)) {
    console.log(`Generating ${name} (${size}x${size})...`);
    const png = await generateIcon(size);
    fs.writeFileSync(path.join(iconsetDir, name), png);
  }

  console.log("Done! Now run: iconutil -c icns Dclean.iconset -o Dclean.icns");
}

main().catch(console.error);
