use std::collections::HashMap;

pub const HEADER: usize = 13;
pub const MAX_MESSAGE: usize = 4096;
pub const PEER_BUDGET: usize = 8192;
pub const GLOBAL_BUDGET: usize = 16384;

#[derive(Debug, PartialEq, Eq)]
pub enum Error { State, Config, Invalid, Sequence, Expired, Resource, Exhausted }

pub struct Sender { next: u32, failed: bool }
impl Default for Sender { fn default() -> Self { Self { next: 1, failed: false } } }
impl Sender {
    pub fn with_next(next: u32) -> Self { Self { next, failed: false } }
    pub fn fragment(&mut self, data: &[u8], capacity: usize) -> Result<Vec<Vec<u8>>, Error> {
        if self.failed { return Err(Error::State); }
        let result = self.encode(data, capacity);
        if result.is_err() { self.failed = true; }
        result
    }
    fn encode(&mut self, data: &[u8], capacity: usize) -> Result<Vec<Vec<u8>>, Error> {
        if capacity <= HEADER { return Err(Error::Config); }
        if data.is_empty() || data.len() > MAX_MESSAGE { return Err(Error::Invalid); }
        if self.next == 0 { return Err(Error::Exhausted); }
        let payload = capacity - HEADER;
        let count = 1 + (data.len() - 1) / payload;
        if count > u16::MAX as usize { return Err(Error::Invalid); }
        let id = self.next;
        self.next = self.next.checked_add(1).unwrap_or(0);
        let mut result = Vec::with_capacity(count);
        for (index, chunk) in data.chunks(payload).enumerate() {
            let mut frame = Vec::with_capacity(HEADER + chunk.len());
            frame.push(1); frame.extend(id.to_be_bytes()); frame.extend((index as u16).to_be_bytes());
            frame.extend((count as u16).to_be_bytes()); frame.extend((data.len() as u32).to_be_bytes());
            frame.extend(chunk); result.push(frame);
        }
        Ok(result)
    }
}
struct Pending { count: usize, len: usize, next: usize, start: u64, data: Vec<u8> }
#[derive(Default)]
struct Peer { failed: bool, pending: HashMap<u32, Pending>, last_id: u32 }
#[derive(Default)]
pub struct Receiver { peers: HashMap<String, Peer>, reserved: usize, failed: bool }
impl Receiver {
    pub fn reset_all(&mut self) { *self = Self::default(); }
    pub fn reset(&mut self, peer: &str) { if let Some(p) = self.peers.remove(peer) { self.reserved -= p.pending.values().map(|x| x.len).sum::<usize>(); } }
    pub fn receive(&mut self, peer: &str, frame: &[u8], capacity: usize, now_ms: u64) -> Result<Option<Vec<u8>>, Error> {
        if self.failed || self.peers.get(peer).is_some_and(|p| p.failed) { return Err(Error::State); }
        if peer.is_empty() || peer.len() > 64 || (!self.peers.contains_key(peer) && self.peers.len() >= 32) { self.failed = true; return Err(Error::Resource); }
        let result = self.accept(peer, frame, capacity, now_ms);
        if result.is_err() { self.reset(peer); self.peers.entry(peer.to_string()).or_default().failed = true; }
        result
    }
    pub fn expire(&mut self, peer: &str, now_ms: u64) -> Result<(), Error> {
        if self.failed { return Err(Error::State); }
        let p = self.peers.get(peer);
        if p.is_some_and(|p| p.failed) { return Err(Error::State); }
        if p.is_some_and(|p| p.pending.values().any(|v| now_ms < v.start || now_ms - v.start >= 3000)) {
            self.reset(peer); self.peers.entry(peer.to_string()).or_default().failed = true; return Err(Error::Expired);
        }
        Ok(())
    }
    fn accept(&mut self, peer: &str, f: &[u8], capacity: usize, now: u64) -> Result<Option<Vec<u8>>, Error> {
        self.expire(peer, now)?;
        if capacity <= HEADER { return Err(Error::Config); }
        if f.len() < HEADER || f.len() > capacity || f[0] != 1 { return Err(Error::Invalid); }
        let id = u32::from_be_bytes(f[1..5].try_into().unwrap());
        let index = u16::from_be_bytes(f[5..7].try_into().unwrap()) as usize;
        let count = u16::from_be_bytes(f[7..9].try_into().unwrap()) as usize;
        let len = u32::from_be_bytes(f[9..13].try_into().unwrap()) as usize;
        let payload = &f[HEADER..];
        if id == 0 || len == 0 || len > MAX_MESSAGE || count == 0 || index >= count || count > len || payload.is_empty() || payload.len() > len { return Err(Error::Invalid); }
        let after_first = len - payload.len();
        let left = count - index - 1;
        if index == 0 && ((left == 0 && after_first != 0) || (left > 0 && (after_first < left || after_first > left.saturating_mul(capacity - HEADER)))) { return Err(Error::Invalid); }
        let p = self.peers.entry(peer.to_string()).or_default();
        if !p.pending.contains_key(&id) {
            if index != 0 || id <= p.last_id { return Err(Error::Sequence); }
            if p.pending.len() >= 2 || p.pending.values().map(|x| x.len).sum::<usize>() + len > PEER_BUDGET || self.reserved + len > GLOBAL_BUDGET { return Err(Error::Resource); }
            p.last_id = id; self.reserved += len;
            p.pending.insert(id, Pending { count, len, next: 0, start: now, data: Vec::with_capacity(len) });
        }
        let x = p.pending.get_mut(&id).unwrap();
        if x.next != index || x.count != count || x.len != len { return Err(Error::Sequence); }
        let remaining = len - x.data.len();
        let after = remaining.checked_sub(payload.len()).ok_or(Error::Invalid)?;
        let fragments_left = count - index - 1;
        if (fragments_left == 0 && after != 0) || (fragments_left > 0 && (after < fragments_left || after > fragments_left.saturating_mul(capacity - HEADER))) { return Err(Error::Invalid); }
        x.data.extend_from_slice(payload); x.next += 1;
        if x.next == count { let done = p.pending.remove(&id).unwrap(); self.reserved -= done.len; return Ok(Some(done.data)); }
        Ok(None)
    }
}

#[cfg(test)]
mod tests {
 use super::*;
 fn hex(s: &str) -> Vec<u8> { (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i+2],16).unwrap()).collect() }
 fn name(e: Error) -> &'static str { match e { Error::State=>"state", Error::Config=>"config", Error::Invalid=>"invalid", Error::Sequence=>"sequence", Error::Expired=>"expired", Error::Resource=>"resource", Error::Exhausted=>"exhausted" } }
 #[test] fn shared_corpus() {
  let mut receiver=Receiver::default(); let mut count=0;
  for line in include_str!("../../fixtures/cases.txt").lines().filter(|l| !l.starts_with('#') && !l.is_empty()) {
   let p: Vec<_>=line.split('|').collect(); count+=1;
   match p[0] {
    "encode" => { let mut s=Sender::with_next(p[5].parse().unwrap()); let result=s.fragment(&vec![p[4].parse().unwrap();p[3].parse().unwrap()],p[2].parse().unwrap()); match result { Ok(frames)=>assert_eq!(frames,p[6].split('/').map(hex).collect::<Vec<_>>(),"{}",p[1]), Err(e)=>assert_eq!(name(e),p[6],"{}",p[1]) } },
    "receive" => { let result=receiver.receive(p[2],&hex(p[5]),p[3].parse().unwrap(),p[4].parse().unwrap()); match result { Ok(None)=>assert_eq!(p[6],"pending","{}",p[1]), Ok(Some(data))=>assert_eq!(data,hex(p[6].strip_prefix("done:").unwrap()),"{}",p[1]), Err(e)=>assert_eq!(name(e),p[6],"{}",p[1]) } },
    "expire" => { let result=receiver.expire(p[2],p[3].parse().unwrap()); assert_eq!(result.err().map(name).unwrap_or("ok"),p[4],"{}",p[1]); },
    "reset" => receiver.reset(p[2]), _=>panic!("unknown fixture")
   }
  }
  println!("{count} shared fixture operations");
 }
 #[test] fn counter_does_not_wrap() { let mut s=Sender::with_next(u32::MAX); assert!(s.fragment(&[1],14).is_ok()); assert_eq!(s.fragment(&[1],14),Err(Error::Exhausted)); assert_eq!(s.fragment(&[1],14),Err(Error::State)); }
}
