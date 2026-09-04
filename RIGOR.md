# Who made this, and how carefully

*A [Rigor, Vouch, Stages](https://rigor.diaconou.com/) disclosure stamp. The format and vocabulary are specified at [rigor.diaconou.com/spec](https://rigor.diaconou.com/spec/), version 1.0.*

<!-- rigor:summary -->
**The idea was mine. Before LLMs, the plan was mine; the implementation was
written by me; it was reviewed for quality and for security, and tested, all by
me. Since LLMs, the plan and the implementation have been reworked by me with an
AI, and it has been reviewed for quality and for security, and tested, all by me
with an AI. The project is complete; it will not gain new features. I stand
behind this code as soundly engineered and hold architectural responsibility for
it. This assessment is as of 2026-09-04. I recommend this for use; I put my name
behind it. Statement made by: Stephen Ierodiaconou.**
<!-- /rigor:summary -->

## Notes

A typed operation has existed in my client work since 2018, in several forms.
The current form was hand-crafted and extracted into this gem in 2023, before
LLMs: the design, the implementation, the reviews, and the test suite were
mine.

Since LLMs, an AI has taken a progressively larger part in development and
refactoring, under my direction; today the work is human and AI together, and
still human-led. I have read that work and can account for it, and I reviewed
and tested it with an AI.

The gem is complete. What it will still receive is fixes and updates for new
Ruby and Rails releases: `activity: active`, `scope: complete`. I use it myself
and I recommend it.

## Stamp

```yaml
spec: "1.0"
signed: "Stephen Ierodiaconou"
rigor: owned
vouch: yes
checks:
  comprehended: [human, human-with-ai]
  quality_reviewed: [human, human-with-ai]
  security_reviewed: [human, human-with-ai]
  tested: [human, human-with-ai]
  owned: human
stages:
  idea: {by: human}
  plan: {by: [human, human-with-ai]}
  implementation: {by: [human, human-with-ai]}
  maintenance: {by: human-with-ai, activity: active, scope: complete}
assessed: 2026-09-04
```

<!--
checks: surface any subset; a done value names who did it.
  comprehended / quality_reviewed / security_reviewed / tested / owned:
    yes | human | ai | human-with-ai | no | not-applicable,
    or a pair [before LLMs, since LLMs] of actors.
  engineered and owned must surface the checks they imply; comprehended
  cannot be satisfied by an AI alone.
Run `rigor-md fmt RIGOR.md` after editing the stamp to refresh the summary.
-->