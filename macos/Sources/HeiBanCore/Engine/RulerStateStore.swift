import Combine

/// Ruler movement invalidates the ruler overlay, rather than all board objects.
public final class RulerStateStore: ObservableObject {
    @Published public private(set) var state = RulerState()

    func update(_ next: RulerState) {
        if next != state { state = next }
    }
}
