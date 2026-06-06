# VPS/VM Options for Agent Flywheel

## What Specs Matter?

### RAM is the primary bottleneck

- Each AI coding agent consumes ~2GB RAM
- 10 agents = 20GB minimum + OS + MCP servers + buffers
- **Jeffrey recommends: 64GB RAM**

### CPU is secondary

- Agents are primarily API clients (inference is cloud-side)
- Local work: git, npm/bun, test suites, linting (I/O-bound)
- 8-16 vCPUs is sufficient for 10-16 agents
- Shared cores are acceptable

### Disk I/O matters for worktrees

- NVMe SSDs handle parallel access well (40x throughput at 64 threads)
- Each worktree duplicates codebase + node_modules
- 2GB repo × 10 worktrees = 20-30GB consumed
- **Minimum 240GB, ideal 480GB NVMe**

### Network: Location doesn't matter much

- Anthropic/OpenAI/Google have global CDN
- Choose VPS location for SSH latency (YOUR location), not API latency

## Recommended Specs by Tier

| Tier     | RAM   | vCPUs | Storage     | Agents | Cost        |
| -------- | ----- | ----- | ----------- | ------ | ----------- |
| Budget   | 32GB  | 4-8   | 120GB NVMe  | 5-8    | $20-30/mo   |
| Standard | 64GB  | 8-16  | 240GB NVMe  | 10-15  | $40-100/mo  |
| Power    | 128GB | 16-32 | 480GB+ NVMe | 20+    | $150-250/mo |

## Provider Comparison (64GB RAM tier, Feb 2026)

### Best Value

| Provider          | Specs                     | Price/mo | Notes                            |
| ----------------- | ------------------------- | -------- | -------------------------------- |
| **Hetzner CCX43** | 16 vCPU, 64GB, 360GB NVMe | ~$102    | Developer favorite, EU           |
| **Contabo VDS**   | 64GB, 480GB NVMe          | ~$56-70  | Cheapest, mixed reviews          |
| **OVH Dedicated** | 64GB, NVMe                | ~$50-80  | Good EU performance              |
| **Advinservers**  | 12 vCPU, 64GB, 240GB NVMe | ~$23/mo  | Quarterly billing, extreme value |

### Premium (North America)

| Provider          | Specs          | Price/mo  | Notes                 |
| ----------------- | -------------- | --------- | --------------------- |
| **DigitalOcean**  | 32 vCPU, 64GB  | ~$240     | Excellent ecosystem   |
| **Vultr**         | 64GB High Perf | ~$160-200 | Good global locations |
| **Linode/Akamai** | 64GB Dedicated | ~$240-280 | Reliable performance  |

### NOT Suitable

- **AWS Lightsail** - Maxes at 8GB RAM
- **Lambda/RunPod/Vast.ai** - GPU-focused, CPU VPS not competitive
- **Spot/Preemptible instances** - Agent sessions span hours/days, sudden termination = lost work

### New Post-OpenClaw Providers

- **Hostinger AI VPS** - One-click OpenClaw deployment (~$40-50/mo)
- **BoostedHost** - Pre-configured agent VPS (~$50-60/mo)
- **xCloud** - Fully managed with Telegram/WhatsApp integration
- **IONOS AI VPS** - Budget AI agent hosting

## What Jeffrey Uses

Based on evidence:

- **Provider:** Likely Hetzner or OVH
- **Specs:** 64GB RAM, 16 vCPUs, 480GB NVMe
- **Cost:** $40-100/month
- **Key quote:** "Cloud giants charge by the hour and make billing unpredictable. A dedicated VPS is simpler and cheaper."

## Cost Context

```
VPS (64GB):     $40-100/mo
Claude Max:     $200/mo
ChatGPT Pro:    $200/mo
─────────────────────────
Total:          $440-500/mo
```

A junior developer costs $5,000+/month. The VPS cost is noise compared to the AI subscriptions.

## Recommendation

**Start with Hetzner CCX43 (~$102/mo)**

- Best balance of price, performance, and developer community
- Jeffrey's likely provider
- Run the single-command installer and go

If budget-constrained, try **Contabo** at ~$56/mo - good enough to test the workflow, upgrade later if needed.

## Key Considerations

- **Don't use spot instances** - agent sessions need stability
- **Use tmux + Mosh** for SSH stability (survives disconnects)
- **Use pnpm** for worktrees (symlinks, saves disk space)
- **Start at 32GB** if unsure, scale to 64GB when hitting limits
- **Reserve 1-year** for 10-20% discount once you've validated the workflow
