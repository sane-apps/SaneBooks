# Contributing to ZecBooks

The product is **ZecBooks**. Source currently lives at [`sane-apps/SaneBooks`](https://github.com/sane-apps/SaneBooks) (historical repo/module path).

## License

ZecBooks is **open source under the [MIT License](LICENSE)**.

## Reporting bugs

1. Prefer **Settings → About → Report Public Issue** in the Mac app (diagnostics are prepared locally; nothing is sent until you submit on GitHub).
2. Or open a GitHub issue with the `bug_report` template.
3. **Never** post viewing keys, seeds, recovery words, memos, txids, `.sanebooks` packs, passphrases, wallet databases, or screenshots that show those. Email `hi@saneapps.com` for sensitive reports.

## Pull requests

- Keep changes small and focused.
- Match existing Swift style in this repo; when touching shared Zcash parsing paths, prefer the patterns in the [librustzcash style guides](https://github.com/zcash/librustzcash/blob/main/CONTRIBUTING.md#styleguides).
- Do not weaken view-only guarantees (no seed/spend acceptance, no propose/send APIs).
- Do not put UVKs or raw viewing keys into proof packs.
- Run `./scripts/SaneMaster.rb verify --timeout 1800` on the Mini before claiming green.

## Security

See `SECURITY.md`. Report security issues privately to `hi@saneapps.com` when disclosure could put funds or keys at risk.
