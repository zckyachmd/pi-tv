import Foundation

let peer = "ABCDEF00-0000-0000-0000-000000000001"
let payload = (0..<4096).map { UInt8(truncatingIfNeeded: $0) }
let central = RecordTransport(), peripheral = RecordTransport()
var requests = Requests()
let request = EchoRequest(id: 1, generation: 1, payload: Data(payload), sent: 0, deadline: 30)
assert(requests.admit(request, ready: true))
try central.sender.start(payload, capacity: 20)
var count = 0, received: [UInt8]?
while let frame = central.sender.frame() {
    received = try peripheral.receive(peer, frame, capacity: 512, now: UInt64(count))
    try central.sender.advance()
    count += 1
}
assert(count > 16 && received == payload)
_ = requests.update { $0.ack(error: false) }
try peripheral.sender.start(received!, capacity: 20)
var echo: [UInt8]?
var first = true
while let frame = peripheral.sender.frame() {
    if first {
        // updateValue(false) does not advance the cursor.
        try peripheral.sender.notificationResult(false)
        assert(peripheral.sender.frame() == frame)
        first = false
    }
    echo = try central.receive(peer, frame, capacity: 512, now: UInt64(count))
    try peripheral.sender.notificationResult(true)
    count += 1
}
assert(echo == payload)
assert(requests.update { _ = $0.echo(Data(echo!), at: 1) } == .success)

let interrupted = RecordTransport()
try interrupted.sender.start(payload, capacity: 20)
let frame = interrupted.sender.frame()!
assert(interrupted.sender.frame() == frame)
let missing = RecordTransport()
let incomplete = try missing.receive(peer, frame, capacity: 512, now: 0)
assert(incomplete == nil)
do { try missing.expire(peer, now: 3000); fatalError("missing fragment accepted") }
catch { assert(error as? FragmentError == .expired) }
do { _ = try missing.receive(peer, frame, capacity: 512, now: 3001); fatalError("failed context reused") }
catch { assert(error as? FragmentError == .state) }
let invalid = RecordTransport()
do { _ = try invalid.receive(peer, [0], capacity: 512, now: 0); fatalError("invalid frame accepted") }
catch { assert(error as? FragmentError == .invalid) }
let fresh = RecordTransport()
try fresh.sender.start([1], capacity: 20)
let freshRecord = try fresh.receive(peer, fresh.sender.frame()!, capacity: 512, now: 0)
assert(freshRecord == [1])
assert(requests.admit(EchoRequest(id: 2, generation: 1, payload: Data([1]), sent: 0, deadline: 1), ready: true))
assert(requests.update { $0.expire(1) } == .acknowledgementTimeout)
requests.clear()
assert(requests.admit(EchoRequest(id: 2, generation: 2, payload: Data([1]), sent: 1, deadline: 4), ready: true))
var queue = PeerQueue(limit: 16)
let id = UUID(uuidString: peer)!
assert(queue.subscribe(id))
let write = PeerQueue.Write(peer: id, valid: true, data: Data([1]))
assert(queue.admit(Array(repeating: write, count: 16)) == .success)
assert(queue.admit([write]) == .full && queue.pending.count == 16)
queue.delivered()
assert(queue.admit([write]) == .success && queue.pending.count == 16)
queue.unsubscribe(id)
assert(queue.pending.isEmpty)
print("Integrated record and flow-control regressions passed; \(count / 2) fragments per direction")
