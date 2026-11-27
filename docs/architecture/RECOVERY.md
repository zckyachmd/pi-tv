# First boot, enrollment and local recovery

Status: proposed, not approved or tested. Authority: owner after security review. A phone that has not completed enrollment is never a trusted local confirmer. A displayed QR proves neither physical presence nor authorization by itself.

| Candidate | Benefits and limitations | Gate |
|---|---|---|
| USB keyboard at the Pi | Candidate baseline for initial provisioning and all-devices-lost recovery; requires physical access and available input/seat. | Verify trusted input routing, accessibility, physical access assumptions and user guidance. |
| Explicitly authorized first-boot enrollment window | Avoids keyboard on initial boot but proximity and QR visibility alone do not establish authorization; reset, replay, attacker-first and window abuse require a reviewed ceremony. | Owner and independent security approval of a concrete physical-presence model before selection. |
| Physical controls | Local button may establish presence; Pi enclosure and hardware availability vary, accidental activation and tampering need review. | Hardware design, abuse and accessibility tests. |
| HDMI-CEC | Potential television remote path; device support and origin/authenticity vary. | Deferred; interoperability and trust evaluation, never assumed available. |

## Flows

1. **Initial enrollment:** trusted local operator opens a time-limited enrollment window using the approved local mechanism (USB keyboard candidate). TV displays identity and one-use QR; phone verifies the device identity via the reviewed secure channel. TV shows a human-verifiable peer description; the operator confirms using the same trusted local path. Persist peer and consume secret atomically. Timeout, cancellation or uncertain commit invalidates the QR. No unauthenticated phone action supplies confirmation.
2. **Replacement phone:** an existing authorized controller may request enrollment only if policy allows, but approval must use an approved trusted local path; otherwise use local recovery. Verify identity and revoke the lost phone separately.
3. **Lost or revoked controller:** an authorized operator sees paired devices and revokes the selected identity; persist before success, terminate its session and deny reconnect. A revoked phone must enroll again under a fresh ceremony. A temporary radio outage must not revoke credentials.
4. **All devices revoked:** trusted local operator enters recovery via approved local input, opens a new enrollment window and confirms it. Do not silently reset device identity or erase provider profiles.
5. **Factory reset:** require deliberate local confirmation and clearly identify scope. Revoke all controller credentials and rotate device identity; erase settings and provider profiles only when explicitly included and confirmed. Interrupted reset fails closed and has a documented recovery path. Ordinary upgrade, reconnect and controller revocation are not factory reset.

Keyboard-free normal operation begins after successful provisioning and includes navigation, pairing management and recovery available to an authorized controller. Local access remains the fallback when no controller works. Test power loss at each persistence boundary, stale QR, wrong device, stolen phone, all-revoked state and reset interruption. Exact local authorization, identity rotation, credential migration and reset implementation remain security and owner gates.
