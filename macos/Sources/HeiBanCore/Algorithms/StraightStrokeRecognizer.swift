import Foundation

public enum StraightStrokeRecognizer {
    public static func isEligible(_ points: [Point], zoom: Double) -> Bool {
        guard points.count >= 5, zoom > 0, let a = points.first, let b = points.last else { return false }
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = hypot(dx, dy)
        guard length * zoom >= 24 else { return false }
        let tolerance = max(5 / zoom, length * 0.035)
        guard points.allSatisfy({ abs(($0.x - a.x) * dy - ($0.y - a.y) * dx) / length <= tolerance }) else {
            return false
        }
        let travel = zip(points, points.dropFirst()).reduce(0.0) {
            $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y)
        }
        return travel <= length * 1.2
    }
}
