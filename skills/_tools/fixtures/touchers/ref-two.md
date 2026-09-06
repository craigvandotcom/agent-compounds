# ref-two — a second fixture REFERRER

Reads skills/_tools/fixtures/touchers/tchr-target.md too (two referrers, so a count of 1
cannot pass by accident), and also skills/_tools/fixtures/touchers/ref-one.md — which makes
ref-one.md itself referenced, so a phantom obligation on it would be a REFUSAL if the
extraction ever read touchers lines again.
