import Foundation
var clock: TimeInterval = 0
func ready(_ l: inout Lifecycle) {
    assert(l.move(.idle)); assert(l.move(.scanning)); assert(l.move(.connecting)); assert(l.move(.services)); assert(l.move(.characteristics)); assert(l.move(.subscribing)); assert(l.move(.ready))
}
func request(_ id: UInt64 = 1) -> EchoRequest { EchoRequest(id: id, generation: 1, payload: Data([UInt8(id)]), sent: 0, deadline: 3) }
var l = Lifecycle(now: { clock }); ready(&l)
var a = request(); a.ack(error: false); _ = a.echo(Data([1]), at: 1); assert(a.outcome == .success && a.echoAt == 1)
var b = request(); _ = b.echo(Data([1]), at: 1); b.ack(error: false); assert(b.outcome == .success)
var c = request(); c.expire(3); assert(c.outcome == .acknowledgementTimeout); c.ack(error: false); assert(c.outcome == .acknowledgementTimeout)
l.invalidate(); assert(!l.canSend && l.state == .disconnecting)
clock = 10; l.expireDisconnect(); assert(l.state == .failed && !l.canSend); assert(!l.move(.scanning))
assert(l.move(.disconnected)); assert(l.move(.scanning)); assert(l.move(.connecting)); assert(l.move(.services)); assert(l.move(.characteristics)); assert(l.move(.subscribing)); assert(l.move(.ready)); assert(l.canSend && l.generation == 2)
var reconnected = EchoRequest(id: 2, generation: l.generation, payload: Data([2]), sent: 10, deadline: 13)
reconnected.ack(error: false); _ = reconnected.echo(Data([2]), at: 11); assert(reconnected.outcome == .success)
var d = request(2); d.ack(error: false); d.expire(3); assert(d.outcome == .echoTimeout); assert(d.echo(Data([2]), at: 4) == "late response")
var e = request(); assert(e.echo(Data([2]), at: 1) == "payload mismatch"); assert(e.outcome == .mismatch); e.ack(error: false); assert(e.outcome == .mismatch)
var f = request(); _ = f.echo(Data([1]), at: 1); assert(f.echo(Data([1]), at: 2) == "duplicate notification"); f.cancel(); assert(f.outcome == .cancelled)
l.invalidate(); assert(!l.canSend); assert(l.move(.disconnected)); assert(!l.canSend)
print("Lifecycle and echo regression assertions passed")
