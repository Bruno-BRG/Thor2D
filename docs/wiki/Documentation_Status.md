# Documentation Status

`Api_Reference.md` is a generated **signature index** and `Complete_API.md` is
the exhaustive one-entry-per-procedure reference. They prove that every public
procedure is discoverable, not that its behavior is explained. Run this audit
from the framework root:

```sh
python3 scripts/audit_wiki.py
```

The audit excludes the generated index and counts a procedure only when its
name appears in the relevant curated module or guide page. A complete page
should explain inputs, return errors, headless behavior, LOVE differences and
include at least one working example.

Short pages and currently incomplete areas are tracked openly rather than
claiming full documentation:

- ECS storage and component examples.
- Project/editor API details beyond manifest validation.
- Input edge cases and platform-specific capability behavior.
- The large graphics, audio and physics APIs need procedure-level examples,
  not only feature summaries.
