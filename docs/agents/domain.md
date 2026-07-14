# Domain Docs

This is a **single-context repository**. Engineering skills should use the root domain context and root architectural-decision directory when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repository root.
- **`docs/adr/`** for architectural decisions that affect the area about to be changed.

If either location does not exist, **proceed silently**. Do not flag its absence or suggest creating it upfront. The `domain-modeling` skill—reached through skills such as `grill-with-docs` and `improve-codebase-architecture`—creates these resources lazily when domain terms or architectural decisions are actually resolved.

## File structure

The single-context layout is:

```text
/
├── CONTEXT.md
├── docs/
│   └── adr/
└── project files and feature directories
```

`CONTEXT.md` holds the shared domain language for the game. `docs/adr/` holds repository-wide architectural decisions.

## Use the glossary's vocabulary

When output names a domain concept—in an issue title, refactor proposal, hypothesis, or test name—use the term defined in `CONTEXT.md`. Do not drift to synonyms that the glossary explicitly avoids.

If a needed concept is absent from the glossary, reconsider whether the term is being invented unnecessarily. If it represents a genuine gap, note it for `domain-modeling`.

## Flag ADR conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly instead of silently overriding the decision:

> _Contradicts ADR-0007 (example decision)—but worth reopening because…_
