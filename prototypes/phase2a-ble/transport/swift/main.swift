import Foundation
func hex(_ s: String) -> [UInt8] { stride(from: 0, to: s.count, by: 2).map { i in let a = s.index(s.startIndex, offsetBy: i); return UInt8(s[a..<s.index(a, offsetBy: 2)], radix: 16)! } }
func errorName(_ e: Error) -> String { String(describing: e) }
let path = CommandLine.arguments[1]
let lines = try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n").filter { !$0.hasPrefix("#") }
let receiver = FragmentReceiver()
for line in lines {
    let p = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    switch p[0] {
    case "encode":
        let sender = FragmentSender(next: UInt32(p[5])!)
        do { let actual = try sender.fragment(Array(repeating: UInt8(p[4])!, count: Int(p[3])!), capacity: Int(p[2])!); precondition(actual == p[6].split(separator: "/").map { hex(String($0)) }, p[1]) }
        catch { precondition(errorName(error) == p[6], "\(p[1]): \(error)") }
    case "receive":
        do { let actual = try receiver.receive(p[2], hex(p[5]), capacity: Int(p[3])!, now: UInt64(p[4])!); if let actual { precondition(p[6].hasPrefix("done:") && actual == hex(String(p[6].dropFirst(5))), p[1]) } else { precondition(p[6] == "pending", p[1]) } }
        catch { precondition(errorName(error) == p[6], "\(p[1]): \(error)") }
    case "expire":
        do { try receiver.expire(p[2], now: UInt64(p[3])!); precondition(p[4] == "ok", p[1]) } catch { precondition(errorName(error) == p[4], p[1]) }
    case "reset": receiver.reset(p[2])
    case "resetall": receiver.resetAll()
    default: fatalError("unknown fixture")
    }
}
let sender = FragmentSender(next: UInt32.max)
_ = try sender.fragment([1], capacity: 14)
do { _ = try sender.fragment([1], capacity: 14); fatalError("counter wrapped") } catch { precondition(errorName(error) == "exhausted") }
do { _ = try sender.fragment([1], capacity: 14); fatalError("sender not terminal") } catch { precondition(errorName(error) == "state") }
print("\(lines.count) shared fixture operations; counter exhaustion passed")
