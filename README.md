# CFB Model — Public Picks Ledger

This repository is the **forward record** of a college-football prediction model:
what it said *before* each week was played, together with the market number it
was priced against at that moment.

It contains no model code. It exists so the track record can be checked by
someone who does not trust the person publishing it.

## What is recorded

Each week gets a folder under `cards/`, written **before** that week's first
kickoff:

| file | contents |
|---|---|
| `run_info.csv` | generation timestamp, season, week, which ratings were used, HFA, game count, how many games qualified as plays |
| `sides_card.csv` | every game: predicted margin, the **opening** spread and total captured at that moment, the edge, and whether it qualified as a play |

`chain.csv` also records `model_commit` -- the exact revision of the model code
that produced each card. It is inside the hash, so a published week cannot later
be re-attributed to a different model version.

The line stored is the one available **when the pick was made**, not the closing
line. Grading uses that stored number.

## Why the hash chain

Publishing predictions proves nothing if they can be edited afterwards.
`chain.csv` links every week to the one before it, so changing any past card
invalidates every row that follows.

```
content_sha256(week):
    for each file in cards/<week_id>/, sorted by filename (ordinal):
        line = "<filename>:<sha256 of the file's raw bytes, lowercase hex>"
    joined = the lines joined with LF, no trailing newline
    content_sha256 = sha256(UTF-8 bytes of joined)

row_hash = sha256(UTF-8 of "<seq>|<week_id>|<generated_utc>|<model_commit>|<content_sha256>|<prev_hash>")
prev_hash of the first row = "GENESIS"
```

That is the whole algorithm — about ten lines in any language. `verify_chain.ps1`
is one implementation; reimplementing it yourself is the point.

`.gitattributes` sets `* -text` so git never rewrites line endings. Without it the
bytes would differ after cloning on another OS and every hash would fail.

## Posting the digest

The newest `row_hash` is posted publicly each week. Every row folds in the one
before it, so the latest hash commits to the whole history behind it -- only that
one needs posting.

```
powershell -ExecutionPolicy Bypass -File latest_hash.ps1
```

## Independent timestamp proof

`chain.csv.ots` is an [OpenTimestamps](https://opentimestamps.org) proof: it
anchors the hash of `chain.csv` into the Bitcoin blockchain. Unlike a hash posted
to a channel someone controls, this needs no witnesses and no trust in the
publisher -- the block itself carries the time.

To check it, open [opentimestamps.org](https://opentimestamps.org), switch to
**Verify**, and supply both `chain.csv` and `chain.csv.ots`. It reports the
Bitcoin block that fixes the file, and therefore the latest moment the whole
chain up to that point could have existed.

Only the hash of the file is ever sent -- the card contents are not uploaded.

## Results

`results.csv` grades every published pick against the line recorded **when the
pick was posted**, never a line looked up afterwards. Losses are listed exactly
as prominently as wins.

| column | meaning |
|---|---|
| `basis` | `validated` = met the model's proven wk5+ thresholds. `posted` = shown on the site in weeks 1-4, outside that window |
| `line` | the number the pick was made against, from the card |
| `result` | `W` / `L` / `P` (push) |

The two bases are graded separately and never pooled into a single headline
number. An early-season play was never claimed as validated, and the record
keeps that distinction permanently.

`results.csv` is not itself hash-chained, and does not need to be: every grade is
derived from a chained card plus a publicly known final score, so anyone can
recompute the whole file and check it. The chain protects the inputs; the grades
follow from them.

## Verifying

```
powershell -ExecutionPolicy Bypass -File verify_chain.ps1
```

It recomputes every row from the card files on disk and compares against
`chain.csv`. Any edited, added, or removed card shows up as a broken row, and
every row after it breaks too.

**What this does and does not prove.** It proves the cards have not been altered
*since they were committed*, and git's own commit timestamps show when each
arrived. It does not by itself prevent the entire history being rewritten and
force-pushed. To close that gap the latest `row_hash` is periodically posted
somewhere outside this repository; pin a hash you have seen and re-check it later.

## Revisions

A week is never silently overwritten. If a card is regenerated, the new version
is stored alongside the original as `<week_id>_revN` and appended as its own
chain row. A revision is visible, by design — an append-only log that quietly
replaced its own entries would be worth nothing.

## Reading the record

`side_play` / `tot_play` mark games that met the model's validated betting
thresholds. Rows without a play are still published: the full slate is recorded
every week so the plays cannot be selected after the fact.
