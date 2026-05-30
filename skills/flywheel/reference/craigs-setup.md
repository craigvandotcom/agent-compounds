# Craig's Actual Setup (3-Agent Scale)

## Agents

- **Agent 1:** Claude Code (Max plan) -- $200/month
- **Agent 2:** Codex CLI (OpenAI $20/mo tier) -- $20/month
- **Agent 3:** Gemini CLI (free tier) -- $0/month

## Infrastructure

**VPS:** Hetzner CX32 (16GB RAM, 4 vCPU) -- ~$10-15/month

**Total Cost:** ~$225-235/month

## Why 16GB RAM is Enough

- Each agent process: ~2GB RAM peak
- 3 agents = ~6GB used
- OS + services: ~4GB
- Headroom: ~6GB for file buffers

## Scaling Path

| Agents | RAM  | VPS  | Cost      |
| ------ | ---- | ---- | --------- |
| 3-5    | 16GB | CX32 | ~EUR13/mo |
| 6-10   | 32GB | CX42 | ~EUR24/mo |
| 10+    | 64GB | CX52 | ~EUR48/mo |

## Notes

- No ChatGPT Pro needed initially (can add later for planning)
- 16GB RAM is generous for 3 agents (~2GB per agent = 6GB + 4GB OS overhead)
- Tokens are the bottleneck, not CPU/RAM
- This scale validates the workflow before expanding

## Tool Priority (For 3-Agent Scale)

| Priority | Tool                 | Why                                                                     |
| -------- | -------------------- | ----------------------------------------------------------------------- |
| 1        | **DCG**              | Safety net -- agents run in vibe mode, one bad `rm -rf` ends everything |
| 2        | **CAAM**             | Credential backup immediately after auth                                |
| 3        | **acfs doctor**      | Verify install works before proceeding                                  |
| 4        | **SRPS**             | Keeps VM responsive when agents spawn builds/tests                      |
| 5        | **Pre-commit guard** | Prevents file conflict damage between agents                            |
| 6        | **APR**              | Automates plan refinement (15-20 AI rounds). Biggest ROI at small scale |
| 7        | **PT**               | Zombie process cleanup (`pt --top`)                                     |
| 8        | **NTM + BV + BR**    | Core flywheel tools                                                     |
| 9        | **JFP**              | Browse/install prompts from Jeffrey's library                           |
| 10       | **S2P**              | Context assembly for web LLM sessions                                   |

**Skip for now:** SLB (overkill at 3 agents), WA (needs WezTerm), Brenner Bot, XF, RCH, GIIL
