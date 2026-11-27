#!/usr/bin/env python3
"""Narrow, dry-run-first integration for Pi TV planning snapshot. No network or git writes."""
import argparse
import subprocess
from pathlib import Path

BASE = '6f95b24533afa21e51fcd1e65b9cba750efb2f90'
PACK = Path(__file__).resolve().parent
EDITS = {
 'docs/architecture/BENCHMARKS.md': [
 ('Candidate p95 ≤100 ms for each measured response; applied denotes adapter boundary, not playback.', 'Candidate p95 ≤100 ms for eligible discrete input accepted/applied RTT separately; applied denotes adapter boundary, not playback. State-query, lifecycle and pairing latency are distinct classes: measure distributions and establish thresholds after baseline, not a universal 100 ms completion target. Record timeout/failure counts and at least 100 samples for frequent input where practicable.'),
 ('Measure 30 app switches, resource cleanup, browser recovery and HDMI reconnect.', 'Propose cold boot ≤45 s from power-on to actionable launcher or enrollment screen and return Home ≤5 s from command to actionable launcher. Measure 30 app switches, PSS/renderer/process cleanup and bounded resource growth (no orphaned process or uncontrolled trend), browser recovery and HDMI reconnect. Require no unexpected project process restart during stable playback. Record exact endpoints, sample count and exceptions.'),
 ('## Abort and recovery', 'Optional candidates: 1080p60 stretch, not MVP floor; ZRAM comparison on an isolated approved environment only (no shared-host swap changes); iOS 18 candidate minimum pending actual OS/SDK and physical-device validation. Report unsupported or deferred options explicitly. See [test strategy](../engineering/TEST_STRATEGY.md).\n\n## Abort and recovery')],
 'docs/design/SCREEN_INVENTORY.md': [
 ('First boot/local provisioning; unprovisioned or local recovery entry','First boot/provisioning; durably never-owned or authorized completed identity reset only'),
 ('QR enrollment window; approved local initiation','QR enrollment window; reviewed never-owned bootstrap or authenticated owner initiation'),
 ('Confirm enrollment; authenticated peer pending local decision','Confirm enrollment; candidate authenticated peer pending phone confirmation'),
 ('Manage enrolled devices; authorized local entry','Manage enrolled devices; authorized owner workflow'),
 ('Browser failure and local recovery; runtime failure or local entry','Browser failure and recovery; runtime failure or authorized phone recovery entry'),
 ('approved local recovery → TV-01','replacement recovery → IOS-10/IOS-04 using independent proof; TV-01 only after authorized completed reset')],
 'docs/design/FOCUS_GRAPH.md': [
 ('otherwise first approved local recovery action','otherwise first authorized recovery action; display-only guidance if no authenticated input exists')],
 'docs/design/DESIGN_SYSTEM.md': [
 ('The earlier handoff seed remains unchanged evidence.', 'The earlier handoff seed remains unchanged evidence. [Active v2 wireframes](wireframes/v2/README.md) are the sole active visual reference; the original handoff and batch A are historical, immutable and not implementation authorities.')],
 'PRD.md': [
 ('Ethernet remains an alternative. Never log or leak credentials.', 'Ethernet is the reference fallback; Wi-Fi-only plug-and-play claims require validated authenticated BLE setup. If deferred, explicitly disclose Ethernet or preconfigured networking as a prerequisite for online playback. Never log or leak credentials.')],
 'TRADEMARK_POLICY.md': [
 ('The owner must review mark ownership, permitted uses and a final policy in Session 1C.4B.', 'The initial Session 1C.4B review is recorded; mark ownership, permitted uses and final clearance remain open release gates. See [release gates](docs/engineering/RELEASE_GATES.md).')],
 'docs/architecture/TRACEABILITY.md': [
 ('Handoff design-system detail is deferred to Session 1C.2; its accessibility and localization outcomes remain R-19.', 'Design-system planning is integrated; [active v2 wireframes](../design/wireframes/v2/README.md) supersede handoff visuals, and accessibility/localization outcomes remain R-19. Physical validation remains pending.')],
 'docs/planning/session-1c4-review-backlog.md': [
 ('These findings follow the', 'Disposition at Session 1D (planning only): INT-01/02 are explicit F-23/F-24 security tasks; INT-03 documentation transitions corrected, physical validation F-33 pending; INT-04 Ethernet reference fallback with Wi-Fi-only claim gated by F-35; INT-05 active v2 authority clarified. See [backlog](IMPLEMENTATION_BACKLOG.md).\n\nThese findings follow the')],
 'docs/README.md': [
 ('- **Historical evidence:**', '- **Active visual reference:** [v2 wireframes](design/wireframes/v2/README.md); handoffs are historical.\n- **Final planning:** [roadmap](planning/ROADMAP.md), [implementation backlog](planning/IMPLEMENTATION_BACKLOG.md), [test strategy](engineering/TEST_STRATEGY.md), [benchmarks](architecture/BENCHMARKS.md), [release gates](engineering/RELEASE_GATES.md), [Session 2 runbook](planning/SESSION_2_RUNBOOK.md), [1D checkpoint](planning/session-1d-completion.md).\n- **Historical evidence:**')],
 'AGENTS.md': [
 ('Use canonical design tokens and component contracts; follow [quality gates](docs/design/QUALITY_GATES.md).','Use canonical design tokens and component contracts; follow [quality gates](docs/design/QUALITY_GATES.md) and [active v2 wireframes](docs/design/wireframes/v2/README.md). Do not regenerate or edit historical handoffs.')]
}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--apply', action='store_true')
    args = p.parse_args()
    root = args.repo.resolve()
    def git(*cmd):
        return subprocess.check_output(['git', '-C', str(root), *cmd], text=True).strip()
    if Path(git('rev-parse', '--show-toplevel')).resolve() != root:
        p.error('--repo must be the repository root')
    if git('rev-parse', 'HEAD') != BASE:
        p.error('HEAD differs from reviewed baseline; manual reconciliation required')
    writes = {}
    for path, replacements in EDITS.items():
        dest = root / path
        original = dest.read_text(encoding='utf-8')
        updated = original
        for old, new in replacements:
            if updated.count(old) != 1:
                p.error(f'{path}: expected exactly one matching passage; manual reconciliation required')
            updated = updated.replace(old, new, 1)
        if git('status', '--porcelain', '--', path):
            p.error(f'{path}: existing changes; preserve and reconcile manually')
        writes[dest] = updated
    for src in sorted((PACK / 'overlay').rglob('*.md')):
        dest = root / src.relative_to(PACK / 'overlay')
        if dest.exists():
            p.error(f'{dest}: already exists; no overwrite')
        writes[dest] = src.read_text(encoding='utf-8')
    for dest in writes:
        if not dest.resolve().is_relative_to(root):
            p.error(f'path escapes repository: {dest}')
        print(('UPDATE' if dest.exists() else 'CREATE'), dest.relative_to(root))
    if not args.apply:
        print(f'DRY RUN: {len(writes)} planned changes; no files written')
        return
    for dest, content in writes.items():
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding='utf-8')
    print(f'APPLIED {len(writes)} changes. Review and validate actual diff before approval.')

if __name__ == '__main__':
    main()
