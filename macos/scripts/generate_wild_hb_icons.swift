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
// Design 1: Electric Azure Wild Brush (電光藍奔放筆觸，H與B徹底分開，筆在右下側邊)
// =========================================================================
let svg1 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow1" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="penShadow1" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="14" dy="22" stdDeviation="16" flood-color="#0f172a" flood-opacity="0.25" />
    </filter>
    <linearGradient id="azureGrad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2563eb" />
      <stop offset="100%" stop-color="#1d4ed8" />
    </linearGradient>
    <linearGradient id="penBody1" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#f8fafc" />
      <stop offset="50%" stop-color="#ffffff" />
      <stop offset="100%" stop-color="#cbd5e1" />
    </linearGradient>
  </defs>

  <!-- Pure Whiteboard Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow1)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Expressive Brush Strokes: Independent "H" (Left) and "B" (Right) -->
  <g fill="none" stroke="url(#azureGrad1)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H (Independent, Unrestrained Slant) === -->
    <!-- H Left Stem: dynamic angled downstroke -->
    <path d="M 270,300 C 255,440 240,560 220,680" stroke-width="76" />
    <!-- H Crossbar: vigorous upward slash -->
    <path d="M 245,490 C 290,475 340,480 385,470" stroke-width="64" />
    <!-- H Right Stem: strong vertical stroke with dynamic bottom lift-off -->
    <path d="M 390,290 C 380,430 370,550 365,680 C 365,695 380,700 395,685" stroke-width="76" />

    <!-- === LETTER B (Independent, Distinct Separation Gap) === -->
    <!-- B Vertical Spine: confident straight backbone -->
    <path d="M 480,290 C 475,440 470,560 465,680" stroke-width="76" />
    <!-- B Upper Loop: expressive sweeping arc -->
    <path d="M 475,300 C 640,270 700,340 680,450 C 660,505 590,515 475,515" stroke-width="70" />
    <!-- B Lower Loop: large bold flourish curving out and down -->
    <path d="M 475,515 C 650,510 740,565 725,660 C 715,725 610,725 470,710" stroke-width="76" />

    <!-- Underline Swoosh from B flowing out to the right margin (Leaves letters completely unobstructed!) -->
    <path d="M 480,725 C 570,740 680,745 770,720" stroke-width="52" stroke-linecap="round" />
  </g>

  <!-- Modern Whiteboard Stylus positioned in the bottom-right corner drawing the tail of the underline -->
  <!-- 筆完全在字體右下方，絕對不遮擋任何 H 或 B 筆劃！ -->
  <g transform="translate(805, 715) rotate(-35)" filter="url(#penShadow1)">
    <rect x="-20" y="-340" width="40" height="300" rx="18" fill="url(#penBody1)" stroke="#94a3b8" stroke-width="2" />
    <rect x="-20" y="-100" width="40" height="36" fill="#2563eb" />
    <polygon points="-18,-40 18,-40 0,0" fill="#f1f5f9" stroke="#94a3b8" stroke-width="2" />
    <polygon points="-10,-14 10,-14 0,6" fill="#1d4ed8" />
  </g>
</svg>
"""

// =========================================================================
// Design 2: Obsidian Calligraphy Brush (深墨霸氣狂草風，H與B獨立，筆懸於右上角)
// =========================================================================
let svg2 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow2" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="penShadow2" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="14" dy="24" stdDeviation="16" flood-color="#0f172a" flood-opacity="0.28" />
    </filter>
    <linearGradient id="inkGrad2" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0f172a" />
      <stop offset="100%" stop-color="#1e293b" />
    </linearGradient>
    <linearGradient id="darkPen" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#334155" />
      <stop offset="50%" stop-color="#475569" />
      <stop offset="100%" stop-color="#1e293b" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow2)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Bold Expressive Ink Strokes: Independent H and B -->
  <g fill="none" stroke="url(#inkGrad2)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H === -->
    <path d="M 260,310 C 250,450 235,570 215,690" stroke-width="82" />
    <path d="M 235,500 C 285,485 335,490 380,480" stroke-width="68" />
    <path d="M 385,295 C 375,445 365,565 355,690" stroke-width="82" />

    <!-- === LETTER B (Clear 70px separation) === -->
    <path d="M 470,295 C 465,445 460,565 455,690" stroke-width="82" />
    <!-- B Loops with sharp, dynamic chisel calligraphy -->
    <path d="M 465,305 C 640,270 710,345 685,455 C 665,510 590,520 465,520" stroke-width="74" />
    <path d="M 465,520 C 655,515 750,570 735,665 C 720,735 605,735 460,715" stroke-width="82" />

    <!-- Expressive ink slash dash -->
    <path d="M 490,735 C 570,750 660,750 740,730" stroke-width="44" stroke-dasharray="24 16" opacity="0.6" />
  </g>

  <!-- Precision Architect Stylus floating dynamically in the top-right empty space -->
  <!-- 筆懸在右上留白區，向畫布指引，完全不遮擋 H 與 B！ -->
  <g transform="translate(800, 260) rotate(55)" filter="url(#penShadow2)">
    <rect x="-18" y="-340" width="36" height="300" rx="16" fill="url(#darkPen)" stroke="#0f172a" stroke-width="2" />
    <rect x="-18" y="-100" width="36" height="30" fill="#0284c7" />
    <polygon points="-16,-40 16,-40 0,0" fill="#cbd5e1" stroke="#0f172a" stroke-width="2" />
    <polygon points="-8,-12 8,-12 0,6" fill="#0f172a" />
  </g>
</svg>
"""

// =========================================================================
// Design 3: Emerald Dynamic Flourish (經典黑板綠狂放揮灑，H與B分開，筆在底部托底)
// =========================================================================
let svg3 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow3" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="penShadow3" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="12" dy="22" stdDeviation="16" flood-color="#0f172a" flood-opacity="0.25" />
    </filter>
    <linearGradient id="emeraldGrad3" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#10b981" />
      <stop offset="100%" stop-color="#047857" />
    </linearGradient>
    <linearGradient id="whitePen3" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ffffff" />
      <stop offset="100%" stop-color="#f1f5f9" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow3)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Emerald Expressive HB Lettering -->
  <g fill="none" stroke="url(#emeraldGrad3)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H (Independent) === -->
    <path d="M 265,305 C 250,445 235,565 215,685" stroke-width="78" />
    <path d="M 240,495 C 290,480 340,485 385,475" stroke-width="64" />
    <path d="M 385,290 C 375,435 365,555 355,685" stroke-width="78" />

    <!-- === LETTER B (Independent, Separated) === -->
    <path d="M 470,290 C 465,435 460,555 455,685" stroke-width="78" />
    <path d="M 465,300 C 635,270 695,340 675,445 C 655,500 580,510 465,510" stroke-width="72" />
    <path d="M 465,510 C 645,505 735,560 720,655 C 705,720 600,720 460,705" stroke-width="78" />

    <!-- Sweeping dynamic underline curve beneath both letters -->
    <path d="M 210,740 C 350,775 600,775 750,735" stroke-width="50" opacity="0.85" />
  </g>

  <!-- Apple Pencil Style Stylus positioned at the right end of the bottom underline -->
  <!-- 筆位於最右下角，托起整個底線，字體全貌乾淨俐落！ -->
  <g transform="translate(785, 730) rotate(-40)" filter="url(#penShadow3)">
    <rect x="-18" y="-340" width="36" height="300" rx="16" fill="url(#whitePen3)" stroke="#cbd5e1" stroke-width="2" />
    <polygon points="-16,-40 16,-40 0,0" fill="#f8fafc" stroke="#cbd5e1" stroke-width="2" />
    <polygon points="-8,-12 8,-12 0,6" fill="#047857" />
    <circle cx="0" cy="-310" r="8" fill="#10b981" />
  </g>
</svg>
"""

// =========================================================================
// Design 4: Sunset Coral Dynamic Graffiti (高張力赤橘塗鴉風，H與B徹底分開，筆在右上側)
// =========================================================================
let svg4 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow4" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <filter id="penShadow4" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="14" dy="22" stdDeviation="16" flood-color="#0f172a" flood-opacity="0.28" />
    </filter>
    <linearGradient id="coralGrad4" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ea580c" />
      <stop offset="100%" stop-color="#dc2626" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow4)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Bold Energetic Coral Brush Strokes: Independent H and B -->
  <g fill="none" stroke="url(#coralGrad4)" stroke-linecap="round" stroke-linejoin="round">
    <!-- === LETTER H === -->
    <path d="M 270,300 C 255,440 240,560 220,680" stroke-width="80" />
    <path d="M 245,490 C 295,475 345,480 390,470" stroke-width="66" />
    <path d="M 390,290 C 380,430 370,550 365,680" stroke-width="80" />

    <!-- === LETTER B (Clear 70px separation) === -->
    <path d="M 480,290 C 475,440 470,560 465,680" stroke-width="80" />
    <path d="M 475,300 C 640,270 705,340 685,450 C 665,505 590,515 475,515" stroke-width="74" />
    <path d="M 475,515 C 655,510 745,565 730,660 C 720,725 610,725 470,710" stroke-width="80" />

    <!-- Dynamic Speed Tail extending from top of B to the upper right -->
    <path d="M 685,340 C 730,290 770,250 810,230" stroke-width="48" stroke-dasharray="20 16" opacity="0.75" />
  </g>

  <!-- Modern Whiteboard Marker positioned at the top-right trailing out -->
  <!-- 筆在右上角邊緣，筆尖朝外，字體完全顯露、清晰無比！ -->
  <g transform="translate(830, 220) rotate(-65)" filter="url(#penShadow4)">
    <rect x="-18" y="-340" width="36" height="300" rx="16" fill="#f8fafc" stroke="#cbd5e1" stroke-width="2" />
    <rect x="-18" y="-100" width="36" height="28" fill="#ea580c" />
    <polygon points="-16,-40 16,-40 0,0" fill="#e2e8f0" stroke="#cbd5e1" stroke-width="2" />
    <polygon points="-8,-12 8,-12 0,6" fill="#dc2626" />
  </g>
</svg>
"""

let baseDir = "/Users/bear/Desktop/Code/HeiBan/macos/assets/wild_hb_icons"
let brainDir = "/Users/bear/.gemini/antigravity/brain/0aae9f09-77bc-4a49-9d66-dd3ce13eaf8b"

renderSvgToPng(svgString: svg1, outputPath: "\(baseDir)/wild_hb1_azure_brush.png")
renderSvgToPng(svgString: svg1, outputPath: "\(brainDir)/wild_hb1_azure_brush.png")

renderSvgToPng(svgString: svg2, outputPath: "\(baseDir)/wild_hb2_obsidian_calligraphy.png")
renderSvgToPng(svgString: svg2, outputPath: "\(brainDir)/wild_hb2_obsidian_calligraphy.png")

renderSvgToPng(svgString: svg3, outputPath: "\(baseDir)/wild_hb3_emerald_flourish.png")
renderSvgToPng(svgString: svg3, outputPath: "\(brainDir)/wild_hb3_emerald_flourish.png")

renderSvgToPng(svgString: svg4, outputPath: "\(baseDir)/wild_hb4_coral_graffiti.png")
renderSvgToPng(svgString: svg4, outputPath: "\(brainDir)/wild_hb4_coral_graffiti.png")

print("All 4 wild HB icons rendered successfully!")
