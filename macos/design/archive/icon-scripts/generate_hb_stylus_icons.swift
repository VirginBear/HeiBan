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
// Design 1: Electric Azure Marker Writing "HB" (電光藍白板筆流暢寫出 HB)
// =========================================================================
let svg1 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="cardShadow" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="penShadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="12" dy="22" stdDeviation="16" flood-color="#0f172a" flood-opacity="0.28" />
    </filter>
    <linearGradient id="azureGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2563eb" />
      <stop offset="100%" stop-color="#1d4ed8" />
    </linearGradient>
    <linearGradient id="penBody" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#f8fafc" />
      <stop offset="50%" stop-color="#ffffff" />
      <stop offset="100%" stop-color="#e2e8f0" />
    </linearGradient>
  </defs>

  <!-- Pure Whiteboard Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#cardShadow)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Flowing Whiteboard Marker Stroke writing "HB" -->
  <g fill="none" stroke="url(#azureGrad)" stroke-linecap="round" stroke-linejoin="round">
    <!-- H Left Stem -->
    <path d="M 280,330 L 280,690" stroke-width="72" />
    <!-- H Crossbar connecting to H Right Stem -->
    <path d="M 280,510 L 440,510" stroke-width="64" />
    <!-- H Right Stem connecting seamlessly into B -->
    <path d="M 440,330 L 440,690" stroke-width="72" />

    <!-- Letter B: Upper and Lower Lobes flowing from the top of the right stem -->
    <!-- B Upper Loop -->
    <path d="M 440,340 C 600,340 640,400 640,490 C 640,525 580,540 440,540" stroke-width="68" />
    <!-- B Lower Loop curving out to bottom -->
    <path d="M 440,520 C 620,520 680,570 680,650 C 680,710 580,720 440,720" stroke-width="72" />

    <!-- Brush texture dynamic tail flare -->
    <path d="M 440,720 C 370,720 320,690 280,650" stroke-width="48" opacity="0.4" />
  </g>

  <!-- Modern Whiteboard Stylus / Marker angled actively at the lower curve of B -->
  <g transform="translate(680, 650) rotate(-38)" filter="url(#penShadow)">
    <!-- Pen Barrel -->
    <rect x="-24" y="-360" width="48" height="320" rx="20" fill="url(#penBody)" stroke="#cbd5e1" stroke-width="2" />
    <!-- Stylus Grip Accent Ring -->
    <rect x="-24" y="-120" width="48" height="40" fill="#2563eb" />
    <!-- Tapered Cone Tip -->
    <polygon points="-22,-40 22,-40 0,0" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="2" />
    <!-- Active Marker Chisel Nib -->
    <polygon points="-12,-16 12,-16 0,6" fill="#1d4ed8" />
  </g>
</svg>
"""

// =========================================================================
// Design 2: Obsidian Ink Brush Continuous Monogram (深墨極簡手繪連筆 HB)
// =========================================================================
let svg2 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="cardShadow2" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="penShadow2" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="14" dy="24" stdDeviation="16" flood-color="#0f172a" flood-opacity="0.32" />
    </filter>
    <linearGradient id="inkGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0f172a" />
      <stop offset="100%" stop-color="#1e293b" />
    </linearGradient>
    <linearGradient id="pencilBody" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#334155" />
      <stop offset="50%" stop-color="#475569" />
      <stop offset="100%" stop-color="#1e293b" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#cardShadow2)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Single Continuous Brush Stroke writing "HB" with expressive calligraphic line variation -->
  <g fill="none" stroke="url(#inkGrad)" stroke-linecap="round" stroke-linejoin="round">
    <!-- Main Left Stem of H -->
    <path d="M 280,310 L 280,690" stroke-width="78" />

    <!-- Upward loop and crossbar into Right Stem of H -->
    <path d="M 280,510 C 350,510 390,510 440,510" stroke-width="64" />
    <path d="M 440,310 L 440,690" stroke-width="78" />

    <!-- Continuous loop into "B" with pressure taper -->
    <path d="M 440,320 C 620,320 660,390 660,490 C 660,525 610,540 440,540" stroke-width="70" />
    <path d="M 440,530 C 640,530 690,580 690,650 C 690,720 590,720 440,720" stroke-width="76" />
  </g>

  <!-- Modern Matte Black Architect Stylus touching the origin of H -->
  <g transform="translate(280, 310) rotate(135)" filter="url(#penShadow2)">
    <rect x="-20" y="-360" width="40" height="320" rx="18" fill="url(#pencilBody)" stroke="#0f172a" stroke-width="2" />
    <rect x="-20" y="-120" width="40" height="30" fill="#0284c7" />
    <polygon points="-18,-40 18,-40 0,0" fill="#cbd5e1" stroke="#0f172a" stroke-width="2" />
    <polygon points="-8,-12 8,-12 0,6" fill="#0f172a" />
  </g>
</svg>
"""

// =========================================================================
// Design 3: Emerald Chalkboard Heritage Stylus (純白底 + 經典墨綠筆觸 HB)
// =========================================================================
let svg3 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="cardShadow3" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="penShadow3" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="12" dy="22" stdDeviation="16" flood-color="#0f172a" flood-opacity="0.25" />
    </filter>
    <linearGradient id="emeraldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#10b981" />
      <stop offset="100%" stop-color="#047857" />
    </linearGradient>
    <linearGradient id="whitePen" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ffffff" />
      <stop offset="100%" stop-color="#f1f5f9" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#cardShadow3)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Emerald Signature HB Stroke with dynamic brush thickness -->
  <g fill="none" stroke="url(#emeraldGrad)" stroke-linecap="round" stroke-linejoin="round">
    <!-- H Pillar Left -->
    <path d="M 270,330 L 270,690" stroke-width="74" />
    <!-- Crossbar -->
    <path d="M 270,510 L 430,510" stroke-width="64" />
    <!-- H Pillar Right -->
    <path d="M 430,330 L 430,690" stroke-width="74" />

    <!-- B Lobes -->
    <path d="M 430,340 C 600,340 650,400 650,490 C 650,530 580,540 430,540" stroke-width="70" />
    <path d="M 430,530 C 630,530 690,575 690,650 C 690,720 570,720 430,720" stroke-width="76" />
  </g>

  <!-- Apple Pencil style White Stylus with Emerald Tip drawing the crossbar -->
  <g transform="translate(430, 510) rotate(-45)" filter="url(#penShadow3)">
    <rect x="-22" y="-380" width="44" height="340" rx="20" fill="url(#whitePen)" stroke="#cbd5e1" stroke-width="2" />
    <polygon points="-20,-40 20,-40 0,0" fill="#f8fafc" stroke="#cbd5e1" stroke-width="2" />
    <polygon points="-10,-14 10,-14 0,6" fill="#047857" />
    <circle cx="0" cy="-350" r="10" fill="#10b981" />
  </g>
</svg>
"""

// =========================================================================
// Design 4: Ribbon Monogram HB with Pen Drawing the Tail (動態絲帶筆觸 HB)
// =========================================================================
let svg4 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="cardShadow4" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="penShadow4" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="14" dy="22" stdDeviation="16" flood-color="#0f172a" flood-opacity="0.28" />
    </filter>
    <linearGradient id="indigoGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#4f46e5" />
      <stop offset="100%" stop-color="#3730a3" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#cardShadow4)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Ribbon-style connected "H" and "B" in Deep Indigo -->
  <g fill="none" stroke="url(#indigoGrad)" stroke-linecap="round" stroke-linejoin="round">
    <!-- H -->
    <path d="M 280,330 L 280,690" stroke-width="80" />
    <path d="M 280,510 L 450,510" stroke-width="66" />
    <path d="M 450,330 L 450,690" stroke-width="80" />

    <!-- B -->
    <path d="M 450,340 C 620,340 660,400 660,490 C 660,530 590,540 450,540" stroke-width="72" />
    <path d="M 450,530 C 640,530 700,580 700,650 C 700,720 580,720 450,720" stroke-width="80" />

    <!-- Trailing flourishing stroke out of B -->
    <path d="M 700,650 C 730,590 750,500 710,430" stroke-width="48" stroke-dasharray="16 14" opacity="0.65" />
  </g>

  <!-- Modern Stylus finishing the trailing stroke of HB -->
  <g transform="translate(710, 430) rotate(-65)" filter="url(#penShadow4)">
    <rect x="-20" y="-360" width="40" height="320" rx="18" fill="#f8fafc" stroke="#cbd5e1" stroke-width="2" />
    <rect x="-20" y="-120" width="40" height="24" fill="#4f46e5" />
    <polygon points="-18,-40 18,-40 0,0" fill="#e2e8f0" stroke="#cbd5e1" stroke-width="2" />
    <polygon points="-10,-12 10,-12 0,6" fill="#3730a3" />
  </g>
</svg>
"""

let baseDir = "/Users/bear/Desktop/Code/HeiBan/macos/assets/hb_icons"
let brainDir = "/Users/bear/.gemini/antigravity/brain/0aae9f09-77bc-4a49-9d66-dd3ce13eaf8b"

renderSvgToPng(svgString: svg1, outputPath: "\(baseDir)/hb_icon1_azure_marker.png")
renderSvgToPng(svgString: svg1, outputPath: "\(brainDir)/hb_icon1_azure_marker.png")

renderSvgToPng(svgString: svg2, outputPath: "\(baseDir)/hb_icon2_obsidian_stylus.png")
renderSvgToPng(svgString: svg2, outputPath: "\(brainDir)/hb_icon2_obsidian_stylus.png")

renderSvgToPng(svgString: svg3, outputPath: "\(baseDir)/hb_icon3_emerald_chalk.png")
renderSvgToPng(svgString: svg3, outputPath: "\(brainDir)/hb_icon3_emerald_chalk.png")

renderSvgToPng(svgString: svg4, outputPath: "\(baseDir)/hb_icon4_indigo_ribbon.png")
renderSvgToPng(svgString: svg4, outputPath: "\(brainDir)/hb_icon4_indigo_ribbon.png")

print("All 4 HB stylus icons rendered successfully!")
