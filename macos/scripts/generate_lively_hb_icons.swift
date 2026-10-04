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
// Design 1: Authentic Hand-Drawn Chalk Texture (真實手寫粉筆微粒邊緣 + 活潑童趣手繪)
// =========================================================================
let svg1 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow1" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <!-- Organic Chalk / Marker Edge Texture Filter (天然手寫邊緣毛邊微粒) -->
    <filter id="chalkTexture1">
      <feTurbulence type="fractalNoise" baseFrequency="0.045" numOctaves="3" result="noise" />
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="7" xChannelSelector="R" yChannelSelector="G" />
    </filter>
    <linearGradient id="emerald1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#10b981" />
      <stop offset="100%" stop-color="#047857" />
    </linearGradient>
  </defs>

  <!-- Pure Whiteboard Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow1)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Authentic Handwritten "H" and "B" with Chalk Texture (No Pen!) -->
  <g fill="none" stroke="url(#emerald1)" stroke-linecap="round" stroke-linejoin="round" filter="url(#chalkTexture1)">
    <!-- === LETTER H (Natural Slant & Playful Hand Overshoot) === -->
    <!-- Left Hand stroke -->
    <path d="M 265,300 C 255,430 240,550 225,675" stroke-width="82" />
    <!-- Horizontal Crossbar (Natural overshoot across vertical lines) -->
    <path d="M 215,505 C 275,485 335,495 405,480" stroke-width="72" />
    <!-- Right Hand stroke -->
    <path d="M 385,290 C 378,430 370,550 365,680" stroke-width="82" />

    <!-- === LETTER B (Completely Separated with 70px Gap) === -->
    <!-- B Spine -->
    <path d="M 480,290 C 475,430 472,550 468,680" stroke-width="82" />
    <!-- B Upper Cheerful Loop -->
    <path d="M 470,305 C 640,270 705,345 680,455 C 655,510 580,518 472,518" stroke-width="76" />
    <!-- B Lower Cheerful Loop -->
    <path d="M 472,518 C 655,510 745,565 730,655 C 710,725 600,720 465,705" stroke-width="84" />

    <!-- Playful Hand-Drawn Underline Smile / Swoosh -->
    <path d="M 205,745 C 360,785 580,785 755,735" stroke-width="54" />
  </g>
</svg>
"""

// =========================================================================
// Design 2: Bouncy Marker Graffiti (活潑街頭/塗鴉白板筆風，字形彈動圓潤，線條鮮活)
// =========================================================================
let svg2 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow2" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <linearGradient id="emerald2" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#34d399" />
      <stop offset="50%" stop-color="#059669" />
      <stop offset="100%" stop-color="#047857" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow2)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Bouncy, Round, Organic Hand Graffiti (No Pen, 100% Uncluttered) -->
  <g fill="none" stroke="url(#emerald2)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H === -->
    <!-- Playful bowed left stroke -->
    <path d="M 275,295 C 245,435 240,565 215,685" stroke-width="88" />
    <!-- Energetic ascending crossbar -->
    <path d="M 215,510 C 280,480 340,490 400,470" stroke-width="76" />
    <!-- Bouncy right vertical with a joyful little top loop flick -->
    <path d="M 390,285 C 382,435 372,565 365,685" stroke-width="88" />

    <!-- === LETTER B (Distinct, Full of Bounce) === -->
    <!-- B Spine with energetic natural tilt -->
    <path d="M 485,285 C 478,435 470,565 460,685" stroke-width="88" />
    <!-- Top Bubbly Loop -->
    <path d="M 470,300 C 650,265 720,340 690,450 C 665,515 585,520 465,520" stroke-width="82" />
    <!-- Bottom Bubbly Loop kicking out joyfully -->
    <path d="M 465,520 C 670,510 765,570 740,665 C 715,735 595,730 455,705" stroke-width="90" />

    <!-- Dynamic Speed Underline Dash -->
    <path d="M 230,755 C 370,785 580,785 735,745" stroke-width="58" />
  </g>
</svg>
"""

// =========================================================================
// Design 3: Spontaneous Quick Sketch (小朋友放肆揮灑塗鴉手感，筆畫有天然顫動)
// =========================================================================
let svg3 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow3" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="scribbleRough">
      <feTurbulence type="fractalNoise" baseFrequency="0.06" numOctaves="4" result="noise" />
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="5" xChannelSelector="R" yChannelSelector="G" />
    </filter>
    <linearGradient id="emerald3" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#10b981" />
      <stop offset="100%" stop-color="#065f46" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow3)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Lively Spontaneous Handwriting with authentic hand pressure & overshoot -->
  <g fill="none" stroke="url(#emerald3)" stroke-linecap="round" stroke-linejoin="round" filter="url(#scribbleRough)">
    <!-- === LETTER H === -->
    <path d="M 260,310 C 255,440 235,560 215,675" stroke-width="84" />
    <path d="M 205,495 C 275,485 345,495 405,485" stroke-width="74" />
    <path d="M 385,300 C 378,440 368,560 360,675" stroke-width="84" />

    <!-- === LETTER B === -->
    <path d="M 475,300 C 470,440 465,560 460,675" stroke-width="84" />
    <path d="M 465,310 C 630,285 690,345 670,450 C 650,505 580,515 465,515" stroke-width="78" />
    <path d="M 465,515 C 645,510 735,560 720,650 C 700,720 590,720 455,700" stroke-width="86" />

    <!-- Expressive Playful Underline Tail -->
    <path d="M 195,735 Q 460,785 750,730" stroke-width="50" />
  </g>
</svg>
"""

// =========================================================================
// Design 4: Pure Minimalist Graffiti Pop (純粹極致手寫向量 - 圓潤厚實、極遠距離 Dock 秒認)
// =========================================================================
let svg4 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow4" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <linearGradient id="emerald4" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#059669" />
      <stop offset="100%" stop-color="#047857" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow4)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Ultra-Bold, Chunky, Organic Hand-Lettering HB (Iconic at 16px dock) -->
  <g fill="none" stroke="url(#emerald4)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H === -->
    <path d="M 270,305 L 230,685" stroke-width="96" />
    <path d="M 215,505 L 405,480" stroke-width="84" />
    <path d="M 390,295 L 365,685" stroke-width="96" />

    <!-- === LETTER B === -->
    <path d="M 480,295 L 465,685" stroke-width="96" />
    <path d="M 470,310 C 645,280 710,345 685,455 C 660,515 580,520 465,520" stroke-width="88" />
    <path d="M 465,520 C 660,515 750,570 730,660 C 705,730 585,730 455,705" stroke-width="96" />

    <!-- Bold Curved Underline -->
    <path d="M 210,750 C 360,785 580,785 750,740" stroke-width="64" />
  </g>
</svg>
"""

let baseDir = "/Users/bear/Desktop/Code/HeiBan/macos/assets/lively_hb_icons"
let brainDir = "/Users/bear/.gemini/antigravity/brain/0aae9f09-77bc-4a49-9d66-dd3ce13eaf8b"

renderSvgToPng(svgString: svg1, outputPath: "\(baseDir)/lively1_chalk_texture.png")
renderSvgToPng(svgString: svg1, outputPath: "\(brainDir)/lively1_chalk_texture.png")

renderSvgToPng(svgString: svg2, outputPath: "\(baseDir)/lively2_bouncy_marker.png")
renderSvgToPng(svgString: svg2, outputPath: "\(brainDir)/lively2_bouncy_marker.png")

renderSvgToPng(svgString: svg3, outputPath: "\(baseDir)/lively3_handwritten_sketch.png")
renderSvgToPng(svgString: svg3, outputPath: "\(brainDir)/lively3_handwritten_sketch.png")

renderSvgToPng(svgString: svg4, outputPath: "\(baseDir)/lively4_chunky_pop.png")
renderSvgToPng(svgString: svg4, outputPath: "\(brainDir)/lively4_chunky_pop.png")

print("All 4 lively HB icons rendered successfully!")
