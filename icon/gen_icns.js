const sharp = require("sharp");
const fs = require("fs");
const path = require("path");

const SIZES = {
  "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
  "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
  "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
  "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
  "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
};

function shieldIconSvg(s) {
  const m = s * 0.08;
  const r = s * 0.22;
  const cx = s / 2, cy = s * 0.44;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${s}" height="${s}" viewBox="0 0 ${s} ${s}">
    <defs>
      <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:#0F1B2D"/>
        <stop offset="100%" style="stop-color:#060B14"/>
      </linearGradient>
      <linearGradient id="bolt" x1="0%" y1="100%" x2="0%" y2="0%">
        <stop offset="0%" style="stop-color:#FF6238"/>
        <stop offset="100%" style="stop-color:#FFB088"/>
      </linearGradient>
      <linearGradient id="shieldG" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:#00D4AA"/>
        <stop offset="100%" style="stop-color:#00A080"/>
      </linearGradient>
      <filter id="sh" x="-20%" y="-20%" width="140%" height="140%">
        <feDropShadow dx="0" dy="0" stdDeviation="${s*0.03}" flood-color="#000" flood-opacity="0.5"/>
      </filter>
    </defs>
    <rect x="${m}" y="${m}" width="${s-m*2}" height="${s-m*2}" rx="${r}" ry="${r}" fill="url(#bg)" filter="url(#sh)"/>
    <g transform="translate(${cx},${cy})">
      <path d="M 0 ${-s*0.28} L ${s*0.22} ${-s*0.24} L ${s*0.24} ${-s*0.08} C ${s*0.24} ${s*0.12} ${s*0.08} ${s*0.26} 0 ${s*0.30} C ${-s*0.08} ${s*0.26} ${-s*0.24} ${s*0.12} ${-s*0.24} ${-s*0.08} L ${-s*0.22} ${-s*0.24} Z"
            fill="none" stroke="url(#shieldG)" stroke-width="${s*0.035}" stroke-linejoin="round"/>
      <path d="M ${-s*0.02} ${-s*0.16} L ${s*0.08} ${-s*0.02} L ${s*0.02} ${-s*0.01} L ${s*0.06} ${s*0.14} L ${-s*0.06} ${s*0.02} L 0 ${s*0.03} L ${-s*0.08} ${-s*0.16} Z" fill="url(#bolt)"/>
    </g>
    <circle cx="${s*0.25}" cy="${s*0.72}" r="${s*0.01}" fill="#00D4AA" opacity="0.3"/>
    <circle cx="${s*0.75}" cy="${s*0.25}" r="${s*0.008}" fill="white" opacity="0.15"/>
  </svg>`;
}

async function main() {
  const setName = process.argv[2] || "shield_bolt";
  const iconsetDir = path.join(__dirname, `${setName}.iconset`);
  fs.mkdirSync(iconsetDir, { recursive: true });

  for (const [name, size] of Object.entries(SIZES)) {
    console.log(`${name} (${size}x${size})`);
    const svg = shieldIconSvg(size);
    const png = await sharp(Buffer.from(svg)).png().toBuffer();
    fs.writeFileSync(path.join(iconsetDir, name), png);
  }

  const icnsPath = path.join(__dirname, `${setName}.icns`);
  const { execSync } = require("child_process");
  execSync(`iconutil -c icns "${iconsetDir}" -o "${icnsPath}"`);
  console.log(`Done: ${icnsPath}`);
}

main().catch(console.error);
