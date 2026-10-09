import Foundation
import AppKit

func renderSvgToPng(svgString: String, outputPath: String) {
    guard let data = svgString.data(using: .utf8),
          let image = NSImage(data: data) else {
        print("Error: Could not parse SVG for \(outputPath)")
        return
    }

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1024,
        pixelsHigh: 1024,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: 1024, height: 1024)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
    NSGraphicsContext.restoreGraphicsState()

    if let pngData = rep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("✓ Generated: \(outputPath)")
    }
}

// =========================================================================
// Design 1: Centered Balanced Coral Graffiti with Dynamic Underline (絕對居中 + 均勻色彩分佈)
// =========================================================================
// 左右邊界：H 左側 200px，B 右側 824px，總寬 624px，正中心點剛好在 512px！
let svg1 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow1" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <!-- Radiant Coral to Crimson Gradient (橫貫整個 H 與 B，均勻飽滿) -->
    <linearGradient id="coralGrad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#f97316" />
      <stop offset="35%" stop-color="#ea580c" />
      <stop offset="70%" stop-color="#dc2626" />
      <stop offset="100%" stop-color="#b91c1c" />
    </linearGradient>
  </defs>

  <!-- Pure Whiteboard Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow1)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Mathematically Centered Graffiti "H" and "B" (No Pen, 100% Uncluttered) -->
  <g fill="none" stroke="url(#coralGrad1)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H (Left side: 200px to 460px) === -->
    <!-- Left Stem: bold energetic downstroke -->
    <path d="M 255,295 C 240,435 225,560 205,685" stroke-width="84" />
    <!-- Crossbar: dynamic slash with lively overshoot -->
    <path d="M 195,500 C 270,480 340,485 410,475" stroke-width="72" />
    <!-- Right Stem: strong vertical stroke with balanced flick -->
    <path d="M 400,285 C 390,430 380,555 375,685" stroke-width="84" />

    <!-- === GAP: 460px to 564px (Centered exactly across X=512) === -->

    <!-- === LETTER B (Right side: 564px to 824px) === -->
    <!-- B Backbone Spine -->
    <path d="M 550,285 C 545,435 540,560 535,685" stroke-width="84" />
    <!-- Upper Loop: sweeping expressive arc -->
    <path d="M 545,295 C 720,265 790,340 765,450 C 740,510 660,518 545,518" stroke-width="78" />
    <!-- Lower Loop: energetic bold curve kicking out to 820px -->
    <path d="M 545,518 C 730,510 825,565 805,660 C 785,730 670,730 530,710" stroke-width="86" />

    <!-- Balanced Dynamic Underline Smile (Symmetrically spanning 190px to 834px) -->
    <path d="M 190,755 C 360,795 660,795 834,745" stroke-width="60" />
  </g>
</svg>
"""

// =========================================================================
// Design 2: High-Density Pure Monogram (無底線、極致均勻對稱雙塊面、色塊最聚焦)
// =========================================================================
let svg2 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow2" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <linearGradient id="coralGrad2" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#fb923c" />
      <stop offset="30%" stop-color="#f97316" />
      <stop offset="70%" stop-color="#ea580c" />
      <stop offset="100%" stop-color="#c2410c" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow2)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Pure Centered Graffiti HB without underline (Extreme focus on the two letters) -->
  <g fill="none" stroke="url(#coralGrad2)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H (Centered around X = 330) === -->
    <path d="M 260,285 C 245,440 230,575 210,715" stroke-width="92" />
    <path d="M 195,510 C 275,485 345,495 425,480" stroke-width="78" />
    <path d="M 405,275 C 395,435 385,570 380,715" stroke-width="92" />

    <!-- === LETTER B (Centered around X = 694) === -->
    <path d="M 555,275 C 550,435 545,570 540,715" stroke-width="92" />
    <path d="M 550,285 C 735,255 805,335 780,450 C 755,515 670,522 550,522" stroke-width="84" />
    <path d="M 550,522 C 745,515 840,575 820,675 C 795,750 675,745 535,725" stroke-width="94" />
  </g>
</svg>
"""

// =========================================================================
// Design 3: Authentic Hand-Drawn Chalk Edge Coral (真實手寫微粒邊緣 + 居中平衡)
// =========================================================================
let svg3 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow3" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <!-- Organic Hand Chalk Texture Filter -->
    <filter id="chalkTexture3">
      <feTurbulence type="fractalNoise" baseFrequency="0.045" numOctaves="3" result="noise" />
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="6" xChannelSelector="R" yChannelSelector="G" />
    </filter>
    <linearGradient id="coralGrad3" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#f97316" />
      <stop offset="40%" stop-color="#ea580c" />
      <stop offset="80%" stop-color="#dc2626" />
      <stop offset="100%" stop-color="#991b1b" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow3)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Hand-drawn Chalk Textured HB Perfectly Centered -->
  <g fill="none" stroke="url(#coralGrad3)" stroke-linecap="round" stroke-linejoin="round" filter="url(#chalkTexture3)">
    <!-- === LETTER H === -->
    <path d="M 255,295 C 240,435 225,560 205,685" stroke-width="84" />
    <path d="M 195,500 C 270,480 340,485 410,475" stroke-width="74" />
    <path d="M 400,285 C 390,430 380,555 375,685" stroke-width="84" />

    <!-- === LETTER B === -->
    <path d="M 550,285 C 545,435 540,560 535,685" stroke-width="84" />
    <path d="M 545,295 C 720,265 790,340 765,450 C 740,510 660,518 545,518" stroke-width="78" />
    <path d="M 545,518 C 730,510 825,565 805,660 C 785,730 670,730 530,710" stroke-width="86" />

    <!-- Playful Hand Underline -->
    <path d="M 190,755 C 360,795 660,795 834,745" stroke-width="58" />
  </g>
</svg>
"""

// =========================================================================
// Design 4: Super Pop Street Flourish (高飽和活力爆發，兩側對稱張力，完全居中)
// =========================================================================
let svg4 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow4" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <linearGradient id="coralGrad4" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ff7a18" />
      <stop offset="50%" stop-color="#ea580c" />
      <stop offset="100%" stop-color="#c026d3" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow4)" stroke="#e2e8f0" stroke-width="3" />

  <g fill="none" stroke="url(#coralGrad4)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H === -->
    <path d="M 255,290 C 240,430 225,560 205,680" stroke-width="88" />
    <path d="M 195,495 C 270,475 345,480 415,470" stroke-width="76" />
    <path d="M 405,280 C 395,425 385,555 380,680" stroke-width="88" />

    <!-- === LETTER B === -->
    <path d="M 545,280 C 540,425 535,555 530,680" stroke-width="88" />
    <path d="M 540,290 C 720,260 795,335 770,445 C 745,505 660,512 540,512" stroke-width="80" />
    <path d="M 540,512 C 730,505 830,560 810,655 C 790,725 670,725 530,705" stroke-width="88" />

    <!-- Dual Flourish Wings (Balanced Left & Right) -->
    <path d="M 185,745 C 360,790 660,790 835,740" stroke-width="62" />
  </g>
</svg>
"""

let baseDir = "/Users/bear/Desktop/Code/HeiBan/macos/assets/centered_coral_icons"
let brainDir = "/Users/bear/.gemini/antigravity/brain/0aae9f09-77bc-4a49-9d66-dd3ce13eaf8b"

renderSvgToPng(svgString: svg1, outputPath: "\(baseDir)/centered_coral1_balanced.png")
renderSvgToPng(svgString: svg1, outputPath: "\(brainDir)/centered_coral1_balanced.png")

renderSvgToPng(svgString: svg2, outputPath: "\(baseDir)/centered_coral2_pure_monogram.png")
renderSvgToPng(svgString: svg2, outputPath: "\(brainDir)/centered_coral2_pure_monogram.png")

renderSvgToPng(svgString: svg3, outputPath: "\(baseDir)/centered_coral3_chalk_texture.png")
renderSvgToPng(svgString: svg3, outputPath: "\(brainDir)/centered_coral3_chalk_texture.png")

renderSvgToPng(svgString: svg4, outputPath: "\(baseDir)/centered_coral4_sunset_pop.png")
renderSvgToPng(svgString: svg4, outputPath: "\(brainDir)/centered_coral4_sunset_pop.png")

print("All 4 centered coral icons rendered successfully!")
