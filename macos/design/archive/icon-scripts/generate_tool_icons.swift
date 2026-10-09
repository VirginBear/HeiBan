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
// Design 1: Drafting Triangle & Vector Curve (極簡角規與向量筆劃)
// -------------------------------------------------------------------------
let svg1 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#000" flood-opacity="0.45" />
    </filter>
    <linearGradient id="bgGrad1" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1b2f27" />
      <stop offset="100%" stop-color="#101c17" />
    </linearGradient>
    <pattern id="dotGrid1" x="0" y="0" width="48" height="48" patternUnits="userSpaceOnUse">
      <circle cx="24" cy="24" r="1.8" fill="#ffffff" opacity="0.08" />
    </pattern>
    <linearGradient id="rulerGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2a4539" stop-opacity="0.9" />
      <stop offset="100%" stop-color="#182a22" stop-opacity="0.95" />
    </linearGradient>
  </defs>

  <!-- macOS App Squircle Base -->
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bgGrad1)" filter="url(#shadow)" stroke="#345244" stroke-width="4" stroke-opacity="0.5" />
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#dotGrid1)" />

  <!-- Center Graphic: Drafting Triangle Ruler & Vector Path -->
  <g transform="translate(512, 512)">
    <!-- 45-degree Technical Drafting Triangle -->
    <path d="M -220,180 L 220,180 L -220,-260 Z" fill="url(#rulerGrad)" stroke="#86efac" stroke-width="6" stroke-linejoin="round" />
    <!-- Inner Cutout of Triangle -->
    <path d="M -160,130 L 110,130 L -160,-140 Z" fill="#14211c" stroke="#4ade80" stroke-width="3" stroke-opacity="0.6" stroke-linejoin="round" />

    <!-- Ruler Tick Marks along bottom -->
    <g stroke="#86efac" stroke-width="3" stroke-linecap="round" opacity="0.75">
      <line x1="-200" y1="180" x2="-200" y2="160" />
      <line x1="-160" y1="180" x2="-160" y2="168" />
      <line x1="-120" y1="180" x2="-120" y2="160" />
      <line x1="-80" y1="180" x2="-80" y2="168" />
      <line x1="-40" y1="180" x2="-40" y2="160" />
      <line x1="0" y1="180" x2="0" y2="168" />
      <line x1="40" y1="180" x2="40" y2="160" />
      <line x1="80" y1="180" x2="80" y2="168" />
      <line x1="120" y1="180" x2="120" y2="160" />
      <line x1="160" y1="180" x2="160" y2="168" />
      <line x1="200" y1="180" x2="200" y2="160" />
    </g>

    <!-- Flowing Vector Spline in Crisp White & Mint Green -->
    <path d="M -260,60 C -120,-80 -20,240 180,-120 S 260,-220 280,-240" fill="none" stroke="#ffffff" stroke-width="16" stroke-linecap="round" />
    <path d="M -260,60 C -120,-80 -20,240 180,-120 S 260,-220 280,-240" fill="none" stroke="#86efac" stroke-width="6" stroke-dasharray="14 12" stroke-linecap="round" opacity="0.9" />

    <!-- Vector Anchor Control Handles -->
    <circle cx="180" cy="-120" r="14" fill="#86efac" stroke="#101c17" stroke-width="4" />
    <circle cx="-120" cy="-80" r="10" fill="#ffffff" stroke="#101c17" stroke-width="3" />
    <circle cx="-260" cy="60" r="10" fill="#ffffff" stroke="#101c17" stroke-width="3" />
  </g>
</svg>
"""

// -------------------------------------------------------------------------
// Design 2: Infinite Blackboard Coordinate (無限畫布幾何座標 - Raycast/Linear 工具風)
// -------------------------------------------------------------------------
let svg2 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow2" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#000" flood-opacity="0.5" />
    </filter>
    <linearGradient id="bgGrad2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1e242b" />
      <stop offset="100%" stop-color="#12161b" />
    </linearGradient>
    <pattern id="coordGrid" x="0" y="0" width="64" height="64" patternUnits="userSpaceOnUse">
      <path d="M 64 0 L 0 0 0 64" fill="none" stroke="#ffffff" stroke-width="1" stroke-opacity="0.05" />
    </pattern>
    <linearGradient id="strokeGrad2" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38bdf8" />
      <stop offset="100%" stop-color="#86efac" />
    </linearGradient>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bgGrad2)" filter="url(#shadow2)" stroke="#334155" stroke-width="3" stroke-opacity="0.6" />
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#coordGrid)" />

  <g transform="translate(512, 512)">
    <!-- Mathematical Coordinate Axis Crosshair -->
    <line x1="-280" y1="0" x2="280" y2="0" stroke="#475569" stroke-width="2" stroke-dasharray="8 6" opacity="0.6" />
    <line x1="0" y1="-280" x2="0" y2="280" stroke="#475569" stroke-width="2" stroke-dasharray="8 6" opacity="0.6" />

    <!-- Pure Geometric Infinity Monogram Loop (Whiteboard symbol) -->
    <!-- Left Circle Loop -->
    <path d="M 0,0 C -120,-160 -260,-160 -260,0 C -260,160 -120,160 0,0 C 120,-160 260,-160 260,0 C 260,160 120,160 0,0 Z"
          fill="none" stroke="url(#strokeGrad2)" stroke-width="34" stroke-linejoin="round" stroke-linecap="round" />

    <!-- Pure Inner Chalk Core Line -->
    <path d="M 0,0 C -120,-160 -260,-160 -260,0 C -260,160 -120,160 0,0 C 120,-160 260,-160 260,0 C 260,160 120,160 0,0 Z"
          fill="none" stroke="#ffffff" stroke-width="12" stroke-linejoin="round" stroke-linecap="round" opacity="0.85" />

    <!-- Ruler Precision Tick Marks on the right axis -->
    <g stroke="#ffffff" stroke-width="3" stroke-linecap="round" opacity="0.8">
      <line x1="120" y1="-14" x2="120" y2="14" />
      <line x1="160" y1="-22" x2="160" y2="22" />
      <line x1="200" y1="-14" x2="200" y2="14" />
      <line x1="240" y1="-22" x2="240" y2="22" />
    </g>

    <!-- Center Coordinate Pivot Point -->
    <circle cx="0" cy="0" r="14" fill="#ffffff" stroke="#12161b" stroke-width="4" />
  </g>
</svg>
"""

// -------------------------------------------------------------------------
// Design 3: GoodNotes Geometric Snap (手繪轉幾何重構 - GoodNotes/Excalidraw 工具風)
// -------------------------------------------------------------------------
let svg3 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow3" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#000" flood-opacity="0.45" />
    </filter>
    <linearGradient id="bgGrad3" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#182c23" />
      <stop offset="100%" stop-color="#0f1a15" />
    </linearGradient>
    <pattern id="dotGrid3" x="0" y="0" width="56" height="56" patternUnits="userSpaceOnUse">
      <circle cx="28" cy="28" r="2" fill="#ffffff" opacity="0.07" />
    </pattern>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bgGrad3)" filter="url(#shadow3)" stroke="#2b4739" stroke-width="4" stroke-opacity="0.6" />
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#dotGrid3)" />

  <g transform="translate(512, 512)">
    <!-- Perfect Geometric Golden Ratio Circle -->
    <circle cx="80" cy="0" r="180" fill="none" stroke="#86efac" stroke-width="20" />
    <circle cx="80" cy="0" r="180" fill="none" stroke="#ffffff" stroke-width="6" opacity="0.9" />

    <!-- Inscribed Equilateral Square rotated 45 deg -->
    <rect x="-47" y="-127" width="254" height="254" rx="16" fill="none" stroke="#4ade80" stroke-width="8" stroke-dasharray="16 12" opacity="0.75" />

    <!-- Dynamic Transition from Freehand Wiggle into Geometric Tangent -->
    <path d="M -260,180 Q -240,-40 -160,80 T -80,120 L -80,-180" fill="none" stroke="#fef08a" stroke-width="16" stroke-linecap="round" stroke-linejoin="round" />

    <!-- Minimalist Stylus Drafting Nib (Engineering Pen) -->
    <g transform="translate(-80, -180) rotate(-45)">
      <!-- Pen Body -->
      <path d="M -16,-120 L 16,-120 L 12,0 L -12,0 Z" fill="#e2e8f0" stroke="#0f1a15" stroke-width="4" />
      <!-- Precision Tip -->
      <polygon points="-12,0 12,0 0,24" fill="#38bdf8" />
      <line x1="0" y1="-80" x2="0" y2="0" stroke="#94a3b8" stroke-width="3" />
    </g>

    <!-- Geometric Intersection Points -->
    <circle cx="80" cy="-180" r="10" fill="#ffffff" />
    <circle cx="260" cy="0" r="10" fill="#ffffff" />
    <circle cx="80" cy="180" r="10" fill="#ffffff" />
  </g>
</svg>
"""

// -------------------------------------------------------------------------
// Design 4: The Precision Blackboard & Ruler (精準黑板與透明直尺 - Apple HIG 專業工具風)
// -------------------------------------------------------------------------
let svg4 = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="shadow4" x="-10%" y="-10%" width="125%" height="130%">
      <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#000" flood-opacity="0.5" />
    </filter>
    <linearGradient id="bgGrad4" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#22262e" />
      <stop offset="100%" stop-color="#14171d" />
    </linearGradient>
    <linearGradient id="glassRuler" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.22" />
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0.06" />
    </linearGradient>
    <pattern id="fineGrid4" x="0" y="0" width="36" height="36" patternUnits="userSpaceOnUse">
      <path d="M 36 0 L 0 0 0 36" fill="none" stroke="#ffffff" stroke-width="1" stroke-opacity="0.06" />
    </pattern>
  </defs>

  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bgGrad4)" filter="url(#shadow4)" stroke="#3b4252" stroke-width="3" stroke-opacity="0.6" />
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#fineGrid4)" />

  <g transform="translate(512, 512)">
    <!-- Architectural Precision Arc in Chalk White -->
    <path d="M -220,180 A 240 240 0 0 1 180,-160" fill="none" stroke="#ffffff" stroke-width="22" stroke-linecap="round" />
    <path d="M -220,180 A 240 240 0 0 1 180,-160" fill="none" stroke="#38bdf8" stroke-width="6" stroke-linecap="round" opacity="0.8" />

    <!-- 45-degree Technical Precision Ruler with Frosted Glass Look -->
    <g transform="rotate(-35)">
      <!-- Ruler Base -->
      <rect x="-260" y="-45" width="520" height="90" rx="12" fill="url(#glassRuler)" stroke="#ffffff" stroke-width="3" stroke-opacity="0.5" />
      <!-- Beveled Edge Line -->
      <line x1="-250" y1="-30" x2="250" y2="-30" stroke="#ffffff" stroke-width="1.5" stroke-opacity="0.3" />

      <!-- Centimeter & Millimeter Engravings -->
      <g stroke="#ffffff" stroke-opacity="0.85">
        <line x1="-220" y1="-45" x2="-220" y2="-15" stroke-width="3" />
        <line x1="-180" y1="-45" x2="-180" y2="-25" stroke-width="2" />
        <line x1="-140" y1="-45" x2="-140" y2="-15" stroke-width="3" />
        <line x1="-100" y1="-45" x2="-100" y2="-25" stroke-width="2" />
        <line x1="-60" y1="-45" x2="-60" y2="-15" stroke-width="3" />
        <line x1="-20" y1="-45" x2="-20" y2="-25" stroke-width="2" />
        <line x1="20" y1="-45" x2="20" y2="-15" stroke-width="3" />
        <line x1="60" y1="-45" x2="60" y2="-25" stroke-width="2" />
        <line x1="100" y1="-45" x2="100" y2="-15" stroke-width="3" />
        <line x1="140" y1="-45" x2="140" y2="-25" stroke-width="2" />
        <line x1="180" y1="-45" x2="180" y2="-15" stroke-width="3" />
        <line x1="220" y1="-45" x2="220" y2="-25" stroke-width="2" />
      </g>
    </g>

    <!-- Precision Chalk Point Dot -->
    <circle cx="180" cy="-160" r="14" fill="#38bdf8" stroke="#ffffff" stroke-width="4" />
  </g>
</svg>
"""

let baseDir = "/Users/bear/Desktop/Code/HeiBan/macos/assets/tool_icons"
let brainDir = "/Users/bear/.gemini/antigravity/brain/0aae9f09-77bc-4a49-9d66-dd3ce13eaf8b"

renderSvgToPng(svgString: svg1, outputPath: "\(baseDir)/tool_icon1_triangle_vector.png")
renderSvgToPng(svgString: svg1, outputPath: "\(brainDir)/tool_icon1_triangle_vector.png")

renderSvgToPng(svgString: svg2, outputPath: "\(baseDir)/tool_icon2_infinity_matrix.png")
renderSvgToPng(svgString: svg2, outputPath: "\(brainDir)/tool_icon2_infinity_matrix.png")

renderSvgToPng(svgString: svg3, outputPath: "\(baseDir)/tool_icon3_geometry_snap.png")
renderSvgToPng(svgString: svg3, outputPath: "\(brainDir)/tool_icon3_geometry_snap.png")

renderSvgToPng(svgString: svg4, outputPath: "\(baseDir)/tool_icon4_slate_ruler.png")
renderSvgToPng(svgString: svg4, outputPath: "\(brainDir)/tool_icon4_slate_ruler.png")

print("All 4 professional tool icons rendered successfully!")
