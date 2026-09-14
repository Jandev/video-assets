# Contributing

Thanks for helping improve these video assets and demos.

## Before opening a change

- Keep each demo self-contained in its numbered directory.
- Update the demo's README when behavior, prerequisites, deployment steps, or
  costs change.
- Add new demos to the table in the root [README](README.md).
- Use fictional names and example domains. Never commit credentials,
  subscription-specific values, deployment output, or personal contact details.
- Keep cloud resources inexpensive, disabled by default where practical, and
  accompanied by cleanup instructions.

## Verify your change

Run the verification script from every demo you changed. For example:

```bash
cd 26-action-groups-that-reach-someone
./scripts/verify.sh
```

If a change affects deployment behavior, also run the demo's what-if command in
a non-production subscription before opening a pull request.

## Pull requests

Explain what changed, why it changed, and how you verified it. Keep unrelated
changes in separate pull requests. Screenshots or command output are helpful
when the change affects a video's visible result.

By contributing, you agree that your contribution is licensed under the
repository's [CC BY 4.0 license](LICENSE).
