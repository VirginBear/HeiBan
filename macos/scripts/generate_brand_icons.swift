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

// -------------------------------------------------------------------------
// Brand 1: Architectural "H" Monogram on Pure Whiteboard (極致純白板 + 深墨黑字標 "H")
// -------------------------------------------------------------------------
let svg1 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow1" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.18" />
    </filter>
    <linearGradient id="bgWhite1" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" />
      <stop offset="100%" stop-color="#f8fafc" />
    </linearGradient>
  </defs>

  <!-- Pure Whiteboard Squircle Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bgWhite1)" filter="url(#shadow1)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Bold Monogram "H" & Vector Bridge (Deep Obsidian #0f172a) -->
  <g transform="translate(512, 512)" fill="#0f172a">
    <!-- Left Vertical Marker Pillar -->
    <rect x="-220" y="-220" width="88" height="440" rx="44" />

    <!-- Right Vertical Marker Pillar -->
    <rect x="132" y="-220" width="88" height="440" rx="44" />

    <!-- Dynamic S-Curve Vector Bridge Connecting Them -->
    <path d="M -176,-30 C -60,-30 -60,30 50,30 C 120,30 150,30 176,30 L 176,-30 C 60,-30 60,30 -50,30 C -120,30 -150,30 -176,30 Z" />

    <!-- Vector Anchor Control Diamond in Center -->
    <rect x="-24" y="-24" width="48" height="48" rx="8" transform="rotate(45)" fill="#0284c7" />
  </g>
</svg>
"""

// -------------------------------------------------------------------------
// Brand 2: Electric Azure Whiteboard Ribbon (極簡藍白流線浪潮 - 如 Edge / Discord / Raycast)
// -------------------------------------------------------------------------
let svg2 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow2" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <linearGradient id="azureGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2563eb" />
      <stop offset="100%" stop-color="#1d4ed8" />
    </linearGradient>
  </defs>

  <!-- Pure Whiteboard Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow2)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Single Iconic Continuous Marker Ribbon (Bold, Unmistakable on Dock) -->
  <g transform="translate(512, 512)">
    <!-- Sweeping Whiteboard Stroke forming an Infinite Loop & Stylus -->
    <path d="M -220,120 C -220,-140 -20,-200 60,-100 C 140,0 240,60 240,-40 C 240,-140 140,-180 80,-180" 
          fill="none" stroke="url(#azureGrad)" stroke-width="84" stroke-linecap="round" />

    <path d="M -220,120 C -220,200 -80,200 40,120 C 160,40 240,140 180,200 C 120,260 -60,260 -180,180" 
          fill="none" stroke="url(#azureGrad)" stroke-width="84" stroke-linecap="round" />

    <!-- Whiteboard Marker Precision Chisel Tip at Start -->
    <circle cx="-220" cy="120" r="42" fill="#1e40af" />
    <circle cx="-220" cy="120" r="18" fill="#ffffff" />
  </g>
</svg>
"""

// -------------------------------------------------------------------------
// Brand 3: Chalkboard Emerald on Crisp Porcelain (純白底 + 經典黑板墨綠徽標 - Google / Slack 幾何風)
// -------------------------------------------------------------------------
let svg3 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow3" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <linearGradient id="emeraldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#10b981" />
      <stop offset="100%" stop-color="#047857" />
    </linearGradient>
  </defs>

  <!-- Pure Whiteboard Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow3)" stroke="#e2e8f0" stroke-width="3" />

  <!-- Geometric Drafting Triangle & Infinite Canvas (Single Signature Color) -->
  <g transform="translate(512, 512)">
    <!-- Outer Drafting Frame -->
    <path d="M -180,-180 L 180,-180 C 220,-180 220,-140 180,-100 L -100,180 C -140,220 -180,220 -180,180 Z" 
          fill="none" stroke="url(#emeraldGrad)" stroke-width="64" stroke-linejoin="round" stroke-linecap="round" />

    <!-- Center Perfect Geometric Circle -->
    <circle cx="20" cy="20" r="110" fill="none" stroke="url(#emeraldGrad)" stroke-width="64" />

    <!-- White Core Vector Dot -->
    <circle cx="20" cy="20" r="28" fill="#047857" />
  </g>
</svg>
"""

// -------------------------------------------------------------------------
// Brand 4: The Minimalist Marker Slash & Infinite Arc (極簡白板筆劃與向量弧 - Linear / Notion / Figma 風)
// -------------------------------------------------------------------------
let svg4 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow4" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#0f172a" flood-opacity="0.16" />
    </filter>
    <linearGradient id="indigoGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#4f46e5" />
      <stop offset="100%" stop-color="#312e81" />
    </linearGradient>
  </defs>

  <!-- Pure Whiteboard Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#ffffff" filter="url(#shadow4)" stroke="#e2e8f0" stroke-width="3" />

  <g transform="translate(512, 512)">
    <!-- Bold 45-degree Whiteboard Marker Slash -->
    <rect x="-240" y="-48" width="480" height="96" rx="48" transform="rotate(-45)" fill="url(#indigoGrad)" />

    <!-- Two Sweeping Arc Halves of Infinite Whiteboard -->
    <path d="M -160,160 A 180 180 0 0 1 -160,-160" fill="none" stroke="url(#indigoGrad)" stroke-width="64" stroke-linecap="round" />
    <path d="M 160,-160 A 180 180 0 0 1 160,160" fill="none" stroke="url(#indigoGrad)" stroke-width="64" stroke-linecap="round" />

    <!-- Center Precision Chalk Pivot (White cutout) -->
    <circle cx="0" cy="0" r="26" fill="#ffffff" />
  </g>
</svg>
"""

let baseDir = "/Users/bear/Desktop/Code/HeiBan/macos/assets/brand_icons"
let brainDir = "/Users/bear/.gemini/antigravity/brain/0aae9f09-77bc-4a49-9d66-dd3ce13eaf8b"

renderSvgToPng(svgString: svg1, outputPath: "\(baseDir)/brand1_monogram_h.png")
renderSvgToPng(svgString: svg1, outputPath: "\(brainDir)/brand1_monogram_h.png")

renderSvgToPng(svgString: svg2, outputPath: "\(baseDir)/brand2_electric_azure_wave.png")
renderSvgToPng(svgString: svg2, outputPath: "\(brainDir)/brand2_electric_azure_wave.png")

renderSvgToPng(svgString: svg3, outputPath: "\(baseDir)/brand3_emerald_vector.png")
renderSvgToPng(svgString: svg3, outputPath: "\(brainDir)/brand3_emerald_vector.png")

renderSvgToPng(svgString: svg4, outputPath: "\(baseDir)/brand4_indigo_marker_slash.png")
renderSvgToPng(svgString: svg4, outputPath: "\(brainDir)/brand4_indigo_marker_slash.png")

print("All 4 white-canvas brand icons rendered successfully!")
