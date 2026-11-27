import Foundation

enum FragmentError: Error, Equatable { case state, config, invalid, sequence, expired, resource, exhausted }
let fragmentHeader = 13, maxMessage = 4096, peerBudget = 8192, globalBudget = 16384

final class FragmentSender {
    private var next: UInt32
    private var failed = false
    init(next: UInt32 = 1) { self.next = next }
    func fragment(_ data: [UInt8], capacity: Int) throws -> [[UInt8]] {
        guard !failed else { throw FragmentError.state }
        do { return try encode(data, capacity: capacity) } catch { failed = true; throw error }
    }
    private func encode(_ data: [UInt8], capacity: Int) throws -> [[UInt8]] {
        guard capacity > fragmentHeader else { throw FragmentError.config }
        guard !data.isEmpty && data.count <= maxMessage else { throw FragmentError.invalid }
        guard next != 0 else { throw FragmentError.exhausted }
        let size = capacity - fragmentHeader, count = 1 + (data.count - 1) / size
        guard count <= Int(UInt16.max) else { throw FragmentError.invalid }
        let id = next; next = next == UInt32.max ? 0 : next + 1
        return (0..<count).map { index in
            let start = index * size, end = start + min(size, data.count - start)
            return [1] + bytes(id, 4) + bytes(UInt32(index), 2) + bytes(UInt32(count), 2) + bytes(UInt32(data.count), 4) + data[start..<end]
        }
    }
}
private func bytes(_ value: UInt32, _ count: Int) -> [UInt8] { (0..<count).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) } }
private func number(_ data: ArraySlice<UInt8>) -> UInt32 { data.reduce(0) { ($0 << 8) | UInt32($1) } }
private struct Pending { let count: Int, length: Int, start: UInt64; var next = 0; var data: [UInt8] = [] }
private struct Peer { var failed = false; var pending: [UInt32: Pending] = [:]; var lastID: UInt32 = 0 }
final class FragmentReceiver {
    private var peers: [String: Peer] = [:]
    private var reserved = 0
    private var failed = false
    func resetAll() { peers.removeAll(); reserved = 0; failed = false }
    func reset(_ peer: String) { if let p = peers.removeValue(forKey: peer) { reserved -= p.pending.values.reduce(0) { $0 + $1.length } } }
    func expire(_ peer: String, now: UInt64) throws {
        if failed { throw FragmentError.state }
        guard let p = peers[peer] else { return }
        if p.failed { throw FragmentError.state }
        if p.pending.values.contains(where: { now < $0.start || now - $0.start >= 3000 }) {
            reset(peer); peers[peer] = Peer(failed: true); throw FragmentError.expired
        }
    }
    func receive(_ peer: String, _ f: [UInt8], capacity: Int, now: UInt64) throws -> [UInt8]? {
        if failed || peers[peer]?.failed == true { throw FragmentError.state }
        if peer.isEmpty || peer.utf8.count > 64 || (peers[peer] == nil && peers.count >= 32) { failed = true; throw FragmentError.resource }
        do { return try accept(peer, f, capacity: capacity, now: now) }
        catch { reset(peer); peers[peer] = Peer(failed: true); throw error }
    }
    private func accept(_ peer: String, _ f: [UInt8], capacity: Int, now: UInt64) throws -> [UInt8]? {
        try expire(peer, now: now)
        guard capacity > fragmentHeader else { throw FragmentError.config }
        guard f.count >= fragmentHeader, f.count <= capacity, f[0] == 1 else { throw FragmentError.invalid }
        let id = number(f[1..<5]), index = Int(number(f[5..<7])), count = Int(number(f[7..<9])), length = Int(number(f[9..<13]))
        let payload = f[fragmentHeader...]
        guard id != 0, length > 0, length <= maxMessage, count > 0, index < count, count <= length, !payload.isEmpty, payload.count <= length else { throw FragmentError.invalid }
        let initialAfter = length - payload.count, initialLeft = count - index - 1
        if index == 0 { guard (initialLeft == 0 && initialAfter == 0) || (initialLeft > 0 && initialAfter >= initialLeft && initialAfter <= initialLeft * min(capacity - fragmentHeader, maxMessage)) else { throw FragmentError.invalid } }
        var p = peers[peer] ?? Peer()
        if p.pending[id] == nil {
            guard index == 0, id > p.lastID else { throw FragmentError.sequence }
            guard p.pending.count < 2, p.pending.values.reduce(0, { $0 + $1.length }) + length <= peerBudget, reserved + length <= globalBudget else { throw FragmentError.resource }
            p.lastID = id; reserved += length
            p.pending[id] = Pending(count: count, length: length, start: now)
            peers[peer] = p
        }
        var x = p.pending[id]!
        guard x.next == index, x.count == count, x.length == length else { throw FragmentError.sequence }
        let remaining = length - x.data.count
        guard payload.count <= remaining else { throw FragmentError.invalid }
        let after = remaining - payload.count, left = count - index - 1
        guard (left == 0 && after == 0) || (left > 0 && after >= left && after <= left * min(capacity - fragmentHeader, maxMessage)) else { throw FragmentError.invalid }
        x.data.append(contentsOf: payload); x.next += 1
        if x.next == count { p.pending.removeValue(forKey: id); reserved -= length; peers[peer] = p; return x.data }
        p.pending[id] = x; peers[peer] = p; return nil
    }
}
