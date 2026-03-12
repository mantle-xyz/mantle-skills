# Security Policy

## Reporting

Do not report sensitive issues in a public issue if they involve:

- secrets or credentials
- wallet safety
- deployment or signing flows
- exploitable address or verification mistakes
- any issue that could enable unsafe transaction execution

If GitHub private vulnerability reporting is enabled for this repository, use it first.
If it is not available, email the maintainer privately at `demiwhisker@gmail.com`.

## What to Include

Please include:

- affected files
- exact behavior observed
- reproduction steps
- impact assessment
- whether the issue affects skill outputs, eval correctness, or both

## Repository-Specific Notes

- This repository should not contain private keys, seed phrases, or API keys.
- Skills in this repository are designed around read-only analysis and external execution handoff; claims of direct execution should be treated as a correctness issue.
- Address safety, chain/environment mismatches, and stale or unverified contract references should be treated as security-relevant defects.
