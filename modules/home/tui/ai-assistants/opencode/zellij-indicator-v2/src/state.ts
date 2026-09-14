import type { Phase } from "./config"

export type FamilyMemberSnapshot = {
  running: boolean
  pending: boolean
  permissions: number
  forms: number
}

export type SessionState = {
  phase: Phase
  seen: boolean
  runStartedAt?: number
}

export function derivePhase(members: FamilyMemberSnapshot[]): Phase {
  if (members.some((member) => member.permissions > 0 || member.forms > 0)) return "permission"
  if (members.some((member) => member.running || member.pending)) return "running"
  return "done"
}

export function shouldCheckFocus(previous: SessionState | undefined, phase: Phase): boolean {
  return Boolean(previous && phase === "done" && (previous.phase !== "done" || !previous.seen))
}

export function transitionSession(previous: SessionState | undefined, phase: Phase, focused: boolean, now: number): SessionState {
  if (!previous) {
    return {
      phase,
      seen: true,
      runStartedAt: phase === "running" ? now : undefined,
    }
  }

  if (phase === "running") {
    return {
      phase,
      seen: true,
      runStartedAt: previous.phase === "running" ? (previous.runStartedAt ?? now) : now,
    }
  }

  if (phase === "permission") return { phase, seen: false }
  return { phase, seen: previous.phase === "done" ? previous.seen || focused : focused }
}
