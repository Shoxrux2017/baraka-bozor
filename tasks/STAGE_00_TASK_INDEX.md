# Stage 0 Task Index — Product & Engineering Foundation

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 0 — Product & Engineering Foundation` |
| Stage status | `Blocked` |
| Verification model | `Workflow v3 controls prepared for Stage 1+` |
| Product/technical contracts | `PASS — LOCKED FOR MVP IMPLEMENTATION` |
| Repository foundation | `Prepared locally` |
| GitHub baseline | `Blocked — repository not yet created/delivered` |
| Stage closed | `No` |

Stage 0 cannot close until this exact baseline is present on real `origin/main`, local `main` is synchronized/clean, and Stage 1 decomposition is approved.

## 2. Stage Goal

Create and lock the complete MVP product/technical specification, establish repository/engineering workflow, deliver the initial baseline to GitHub, and prepare Stage 1 decomposition.

## 3. Completed/Prepared Work

| Order | ID | Outcome | Current evidence | Delivery state |
|---:|---|---|---|---|
| 1 | `S00-DOC-001` | Business Overview | `docs/01-business-overview.md` locked | Pending GitHub baseline |
| 2 | `S00-DOC-002` | User Roles | `docs/02-user-roles.md` locked | Pending GitHub baseline |
| 3 | `S00-DOC-003` | Features | `docs/03-features.md` locked | Pending GitHub baseline |
| 4 | `S00-DOC-004` | User Flows | `docs/04-user-flows.md` locked | Pending GitHub baseline |
| 5 | `S00-DOC-005` | Business Rules | `docs/05-business-rules.md` locked | Pending GitHub baseline |
| 6 | `S00-DOC-006` | Roadmap | `docs/06-roadmap.md` locked | Pending GitHub baseline |
| 7 | `S00-DOC-007` | Architecture | `docs/07-architecture.md` locked | Pending GitHub baseline |
| 8 | `S00-DOC-008` | Database | `docs/08-database.md` locked | Pending GitHub baseline |
| 9 | `S00-DOC-009` | API Contracts | `docs/09-api-contracts.md` locked | Pending GitHub baseline |
| 10 | `S00-DOC-010` | Contract Alignment | `docs/CONTRACT_ALIGNMENT_REPORT.md` | Pending GitHub baseline |
| 11 | `S00-INT-003` | Cross-document consistency audit | `docs/FINAL_AUDIT_REPORT.md`: PASS | Pending GitHub baseline |
| 12 | `S00-INT-001` | Repository foundation | README/.gitignore/AGENTS/tasks scaffold prepared | Pending GitHub baseline |
| 13 | `S00-INT-002` | Engineering workflow/templates | `tasks/README.md`, templates | Pending GitHub baseline |
| 14 | `S00-INT-004` | Initial GitHub baseline delivery | Not executable yet | `Blocked` |

The documentation/workflow files are prepared, but no item is marked task-level `Accepted` until the baseline is actually present on `origin/main` and repository state satisfies the workflow acceptance rule.

## 4. Blocker

No `Shoxrux2017/baraka-bozor` repository currently exists on GitHub. The connected GitHub integration also returned write-access failures on write probes to an existing repository. The assistant cannot create a GitHub repository through the available connector actions.

Required Project Owner action:

1. create an empty GitHub repository (recommended name `baraka-bozor`) under the intended account;
2. grant the ChatGPT GitHub connection access if future connector writes/reviews are desired;
3. push this prepared local `main` baseline;
4. provide/confirm the repository URL.

Then Stage 0 Closure Review can be re-run against actual `origin/main`.

## 5. Stage 0 Closure Conditions

- [x] Locked `docs/01–09` exist locally.
- [x] Contract alignment report exists.
- [x] Final cross-document audit PASS exists.
- [x] Root/backend/frontend `AGENTS.md` prepared.
- [x] `tasks/README.md` and templates prepared.
- [x] Stage 1 decomposition draft prepared.
- [ ] Real GitHub repository exists.
- [ ] Accepted baseline is on `origin/main`.
- [ ] Local `main == origin/main`.
- [ ] Ahead/behind `0/0`.
- [ ] Worktree clean after delivery.
- [ ] Stage 1 decomposition approved against real repository baseline.
- [ ] Stage 0 Closure Review verdict = `STAGE CLOSED`.
