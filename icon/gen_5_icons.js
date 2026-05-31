const sharp = require("sharp");
const fs = require("fs");
const path = require("path");

const S = 1024;
const M = S * 0.08;
const R = S * 0.22;

// Background for all icons: dark rounded rect
function bgSvg() {
  return `
    <defs>
      <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:#0F1B2D"/>
        <stop offset="100%" style="stop-color:#060B14"/>
      </linearGradient>
      <filter id="sh" x="-20%" y="-20%" width="140%" height="140%">
        <feDropShadow dx="0" dy="0" stdDeviation="30" flood-color="#000" flood-opacity="0.5"/>
      </filter>
    </defs>
    <rect x="${M}" y="${M}" width="${S-M*2}" height="${S-M*2}" rx="${R}" ry="${R}" fill="url(#bg)" filter="url(#sh)"/>`;
}

async function renderIcon(name, svgContent) {
  const full = `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">${svgContent}</svg>`;
  return sharp(Buffer.from(full)).png().toBuffer();
}

// ========== ICON 1: SWEEP ARC ==========
const icon1 = `
  ${bgSvg()}
  <defs>
    <linearGradient id="sweep" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FF6238"/>
      <stop offset="100%" style="stop-color:#FF8A50"/>
    </linearGradient>
  </defs>
  <g transform="translate(${S/2},${S/2})">
    <circle cx="0" cy="0" r="${S*0.30}" fill="none" stroke="rgba(255,255,255,0.07)" stroke-width="${S*0.04}"/>
    <path d="M ${-S*0.26} ${-S*0.15} A ${S*0.30} ${S*0.30} 0 1 1 ${S*0.15} ${S*0.26}" fill="none" stroke="url(#sweep)" stroke-width="${S*0.048}" stroke-linecap="round"/>
    <circle cx="${S*0.17}" cy="${S*0.24}" r="${S*0.042}" fill="#FF6238"/>
    <circle cx="${S*0.17}" cy="${S*0.24}" r="${S*0.062}" fill="#FF6238" opacity="0.3"/>
    <g transform="rotate(-12)">
      <path d="M ${-S*0.05} ${S*0.035} L 0 ${-S*0.10} L ${S*0.05} ${S*0.035}" fill="none" stroke="white" stroke-width="${S*0.032}" stroke-linecap="round" stroke-linejoin="round"/>
    </g>
    <circle cx="0" cy="0" r="${S*0.022}" fill="white"/>
  </g>
  <circle cx="${S*0.78}" cy="${S*0.72}" r="${S*0.01}" fill="#00D4AA" opacity="0.4"/>
  <circle cx="${S*0.22}" cy="${S*0.22}" r="${S*0.012}" fill="#FF6238" opacity="0.4"/>`;

// ========== ICON 2: SHIELD BOLT ==========
const icon2 = `
  ${bgSvg()}
  <defs>
    <linearGradient id="bolt" x1="0%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" style="stop-color:#FF6238"/>
      <stop offset="100%" style="stop-color:#FFB088"/>
    </linearGradient>
    <linearGradient id="shieldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#00D4AA"/>
      <stop offset="100%" style="stop-color:#00A080"/>
    </linearGradient>
  </defs>
  <g transform="translate(${S/2},${S*0.44})">
    <!-- Shield outline -->
    <path d="M 0 ${-S*0.28} L ${S*0.22} ${-S*0.24} L ${S*0.24} ${-S*0.08} C ${S*0.24} ${S*0.12} ${S*0.08} ${S*0.26} 0 ${S*0.30} C ${-S*0.08} ${S*0.26} ${-S*0.24} ${S*0.12} ${-S*0.24} ${-S*0.08} L ${-S*0.22} ${-S*0.24} Z"
          fill="none" stroke="url(#shieldGrad)" stroke-width="${S*0.035}" stroke-linejoin="round"/>
    <!-- Lightning bolt -->
    <path d="M ${-S*0.02} ${-S*0.16} L ${S*0.08} ${-S*0.02} L ${S*0.02} ${-S*0.01} L ${S*0.06} ${S*0.14} L ${-S*0.06} ${S*0.02} L 0 ${S*0.03} L ${-S*0.08} ${-S*0.16} Z"
          fill="url(#bolt)"/>
  </g>
  <circle cx="${S*0.25}" cy="${S*0.72}" r="${S*0.01}" fill="#00D4AA" opacity="0.3"/>
  <circle cx="${S*0.75}" cy="${S*0.25}" r="${S*0.008}" fill="white" opacity="0.15"/>`;

// ========== ICON 3: MONOGRAM D ==========
const icon3 = `
  ${bgSvg()}
  <defs>
    <linearGradient id="dGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FF6238"/>
      <stop offset="50%" style="stop-color:#FF7B50"/>
      <stop offset="100%" style="stop-color:#00D4AA"/>
    </linearGradient>
  </defs>
  <g transform="translate(${S/2},${S/2})">
    <!-- Stylized D letterform with cut -->
    <path d="M ${-S*0.08} ${-S*0.22}
             L ${S*0.10} ${-S*0.22}
             C ${S*0.25} ${-S*0.22} ${S*0.28} 0 ${S*0.18} ${S*0.10}
             C ${S*0.10} ${S*0.18} ${-S*0.02} ${S*0.22} ${-S*0.08} ${S*0.22}
             Z"
          fill="none" stroke="url(#dGrad)" stroke-width="${S*0.045}" stroke-linecap="round" stroke-linejoin="round"/>
    <!-- Inner accent line -->
    <line x1="${-S*0.07}" y1="${-S*0.08}" x2="${S*0.08}" y2="${-S*0.08}" stroke="#FF6238" stroke-width="${S*0.025}" stroke-linecap="round" opacity="0.6"/>
    <!-- Dot -->
    <circle cx="${S*0.22}" cy="${-S*0.22}" r="${S*0.02}" fill="#00D4AA"/>
  </g>
  <circle cx="${S*0.20}" cy="${S*0.75}" r="${S*0.01}" fill="white" opacity="0.2"/>
  <circle cx="${S*0.78}" cy="${S*0.20}" r="${S*0.008}" fill="#FF6238" opacity="0.3"/>`;

// ========== ICON 4: ROCKET / ARROW UP ==========
const icon4 = `
  ${bgSvg()}
  <defs>
    <linearGradient id="rocketGrad" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#FF6238"/>
      <stop offset="100%" style="stop-color:#FFB070"/>
    </linearGradient>
    <linearGradient id="trailGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#00D4AA;stop-opacity:0.8"/>
      <stop offset="100%" style="stop-color:#00D4AA;stop-opacity:0"/>
    </linearGradient>
  </defs>
  <g transform="translate(${S/2},${S/2})">
    <!-- Speed trails -->
    <line x1="${-S*0.15}" y1="${S*0.28}" x2="${-S*0.10}" y2="${S*0.14}" stroke="url(#trailGrad)" stroke-width="${S*0.025}" stroke-linecap="round"/>
    <line x1="0" y1="${S*0.30}" x2="0" y2="${S*0.16}" stroke="url(#trailGrad)" stroke-width="${S*0.025}" stroke-linecap="round"/>
    <line x1="${S*0.15}" y1="${S*0.28}" x2="${S*0.10}" y2="${S*0.14}" stroke="url(#trailGrad)" stroke-width="${S*0.025}" stroke-linecap="round"/>

    <!-- Rocket/arrow body -->
    <path d="M ${-S*0.12} ${S*0.06} L ${-S*0.09} ${-S*0.05} L 0 ${-S*0.24} L ${S*0.09} ${-S*0.05} L ${S*0.12} ${S*0.06} Z"
          fill="url(#rocketGrad)" stroke="white" stroke-width="${S*0.015}" stroke-linejoin="round"/>

    <!-- Center line -->
    <line x1="0" y1="${-S*0.12}" x2="0" y2="${S*0.02}" stroke="white" stroke-width="${S*0.016}" stroke-linecap="round" opacity="0.8"/>
  </g>
  <circle cx="${S*0.22}" cy="${S*0.22}" r="${S*0.01}" fill="white" opacity="0.3"/>
  <circle cx="${S*0.78}" cy="${S*0.72}" r="${S*0.012}" fill="#00D4AA" opacity="0.3"/>`;

// ========== ICON 5: GEOMETRIC CUBE / HEX CIRCUIT ==========
const icon5 = `
  ${bgSvg()}
  <defs>
    <linearGradient id="hexGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FF6238"/>
      <stop offset="100%" style="stop-color:#00D4AA"/>
    </linearGradient>
  </defs>
  <g transform="translate(${S/2},${S/2})">
    <!-- Outer hexagon -->
    <polygon points="0,${-S*0.30} ${S*0.26},${-S*0.13} ${S*0.26},${S*0.13} 0,${S*0.30} ${-S*0.26},${S*0.13} ${-S*0.26},${-S*0.13}"
             fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="${S*0.025}"/>
    <!-- Inner hex -->
    <polygon points="0,${-S*0.18} ${S*0.16},${-S*0.08} ${S*0.16},${S*0.08} 0,${S*0.18} ${-S*0.16},${S*0.08} ${-S*0.16},${-S*0.08}"
             fill="none" stroke="url(#hexGrad)" stroke-width="${S*0.04}" stroke-linejoin="round"/>
    <!-- Center dot -->
    <circle cx="0" cy="0" r="${S*0.045}" fill="url(#hexGrad)"/>
    <circle cx="0" cy="0" r="${S*0.025}" fill="white"/>
    <!-- Connecting lines -->
    <line x1="${-S*0.16}" y1="${-S*0.08}" x2="${-S*0.24}" y2="${-S*0.12}" stroke="#FF6238" stroke-width="${S*0.02}" stroke-linecap="round" opacity="0.5"/>
    <line x1="${S*0.16}" y1="${S*0.08}" x2="${S*0.24}" y2="${S*0.12}" stroke="#00D4AA" stroke-width="${S*0.02}" stroke-linecap="round" opacity="0.5"/>
  </g>
  <circle cx="${S*0.20}" cy="${S*0.20}" r="${S*0.01}" fill="#FF6238" opacity="0.4"/>
  <circle cx="${S*0.80}" cy="${S*0.78}" r="${S*0.008}" fill="white" opacity="0.2"/>`;

// ========== RENDER ALL 5 ==========
const icons = [
  { name: "01_sweep_arc", svg: icon1, desc: "Sweep Arc — 清扫弧线 + 优化箭头" },
  { name: "02_shield_bolt", svg: icon2, desc: "Shield Bolt — 盾牌 + 闪电" },
  { name: "03_monogram_d", svg: icon3, desc: "Monogram D — 极简 D 字母" },
  { name: "04_rocket_arrow", svg: icon4, desc: "Rocket Arrow — 火箭 + 加速轨迹" },
  { name: "05_geometric_hex", svg: icon5, desc: "Geometric Hex — 六边形 + 科技电路" },
];

async function main() {
  const previewDir = path.join(__dirname, "previews");
  fs.mkdirSync(previewDir, { recursive: true });

  for (const icon of icons) {
    console.log(`Generating ${icon.name} — ${icon.desc}...`);
    const png = await renderIcon(icon.name, icon.svg);
    const previewPath = path.join(previewDir, `${icon.name}.png`);
    fs.writeFileSync(previewPath, png);
    console.log(`  -> ${previewPath}`);
  }
  console.log("\nAll 5 icons generated in icon/previews/");
}

main().catch(console.error);
