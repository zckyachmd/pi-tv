import Foundation

struct PeerQueue {
    struct Write { let peer: UUID; let valid: Bool; let data: Data? }
    enum Decision { case empty, success, peer, invalid, full }
    private(set) var peer: UUID?
    private(set) var pending: [Data] = []
    let limit: Int

    mutating func subscribe(_ id: UUID) -> Bool {
        guard peer == nil || peer == id else { return false }
        peer = id
        return true
    }
    mutating func unsubscribe(_ id: UUID) {
        guard peer == id else { return }
        reset()
    }
    mutating func reset() { peer = nil; pending.removeAll() }
    mutating func admit(_ writes: [Write]) -> Decision {
        guard !writes.isEmpty else { return .empty }
        guard let peer, writes.allSatisfy({ $0.peer == peer }) else { return .peer }
        guard writes.allSatisfy({ $0.valid && $0.data != nil }) else { return .invalid }
        guard writes.count <= limit - pending.count else { return .full }
        pending.append(contentsOf: writes.compactMap(\.data))
        return .success
    }
    mutating func delivered() { if !pending.isEmpty { pending.removeFirst() } }
}
