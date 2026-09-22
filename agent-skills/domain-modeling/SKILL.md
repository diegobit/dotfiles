---
name: domain-modeling
description: Sharpen project terminology and record domain definitions or architectural decisions. Use when resolving ambiguous domain concepts or creating or editing a glossary, CONTEXT.md, or ADR.
---

# Domain modeling

Build a shared vocabulary and record decisions whose reasoning matters later. Reading an existing glossary for context alone does not require this workflow.

## Find the existing model

Follow repository instructions and documentation indexes to locate the authoritative glossary and ADRs. A glossary may be `wiki/glossary.md`, `CONTEXT.md`, or another established file; reuse it rather than introducing a second one. Follow `CONTEXT-MAP.md` if the repo uses it to separate domains.

Match existing formats and locations. When documentation edits are requested and no convention exists, use `CONTEXT.md` for domain vocabulary and `docs/adr/` for decisions. Create each only when there is something agreed to record. The fallback formats are [glossary](CONTEXT-FORMAT.md) and [ADR](ADR-FORMAT.md).

## Resolve the model

Surface terms with conflicting meanings and propose precise alternatives. Use concrete scenarios to test concept boundaries. Cross-check claims about current behavior against code; distinguish what exists from the intended design.

When documentation edits are part of the request, record settled definitions and qualifying decisions as they emerge. For discussion or review alone, propose changes in the response. Preserve existing authorization rather than requesting it again.

Keep glossary entries focused on domain meanings and relationships. Put implementation plans and decision history in their appropriate documents. Preserve other content in a mixed-purpose existing document rather than imposing the fallback glossary format on it.

## Record consequential decisions

An ADR is useful when the choice has meaningful reversal cost, would surprise a future reader without context, and involved a real trade-off. Record the decision and why it was made; include alternatives or consequences when they explain it. Routine or easily reversible choices rarely need their own ADR.
