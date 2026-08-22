---
name: arena
description: Run competing candidates for the same non-trivial artifact, judge them against one rubric, then synthesize and verify the strongest result. Use when the user says "arena" or explicitly wants multiple independent attempts or model approaches.
---

# Arena

Produce independent candidates, pick the best base, graft only compatible strengths from the others, and verify the synthesis.

Arena invocation authorizes candidate generation within the user's original task. It does not authorize commits, branches, deployments, paid or live calls, or a broader implementation scope.

## 1. Frame the contract

Before launching candidates, record:

- the exact artifact each candidate must produce;
- shared grounding files and facts;
- scope and protected dirty paths;
- 3-6 concrete grading criteria;
- the required output format and verification signal.

Use the task tracker or plan tool when one is available. Keep one item for framing, candidates, judging, synthesis, and verification.

## 2. Choose independent lanes

Use 2-3 candidates by default, capped by available concurrency. Give each a clean, bounded task packet and its own output location under a temporary directory. For code changes, candidates should produce patches or edit isolated copies; only the parent applies the chosen synthesis to the user's worktree.

Use different available model families when the user requests a model bake-off or the current harness exposes that choice cheaply. Otherwise inherit the current model and preserve independence through clean contexts. Use only model names exposed by the current environment.

When fewer than two independent lanes are available, say that a faithful arena cannot run. Offer sequential variants rather than presenting them as independent candidates.

## 3. Generate candidates

Send every lane the same contract and rubric. Require:

- the artifact or patch;
- a short rationale;
- alternatives considered and rejected;
- verification performed and any unresolved uncertainty.

Candidate lanes may write only inside their assigned temporary location. A dropout reduces the field; record it and continue when at least two candidates remain.

## 4. Cross-judge

After candidate writes finish, run one independent read-only judging lane when capacity allows. Label candidates neutrally. The judge receives the rubric and candidate paths, scores each criterion, names a recommended base, and explains the tradeoffs.

In parallel with that judge, the parent reads every candidate end to end and scores the same rubric. If no judging lane is available, the parent judges and records that limitation.

## 5. Pick and graft

Choose the base that satisfies the contract with the smallest coherent surface and is easiest to maintain. Resolve disagreement with the judge by revisiting the relevant rubric criteria, not by averaging scores.

Inspect each losing candidate once more. Graft only ideas that improve a criterion without breaking the base's mental model. Reimplement grafts deliberately; mechanical pasting usually creates two designs in one artifact.

If candidates converge, keep the consensus and note it. If they diverge because the contract was underspecified, tighten the contract and rerun instead of blending incompatible answers.

## 6. Apply and verify

For repository changes, the parent alone applies the selected patch and grafts to the user's worktree, preserving unrelated changes. Run the contract's focused verification and a proportional regression check. Keep paid, live, deployment, and hardware gates closed until separately authorized.

Return one synthesized artifact plus a concise synthesis record covering the base, grafts, rejections, dropouts, judge disagreement, and verification. Save that record in the repository only when the user asks or the repo has an established location for it.
