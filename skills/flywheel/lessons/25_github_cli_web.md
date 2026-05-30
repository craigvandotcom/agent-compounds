# GitHub CLI

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Manage GitHub issues, PRs, releases, and actions from the command line.

          **GitHub CLI (gh)** lets you interact with GitHub
          directly from your terminal. No more switching between your editor and
          browser for common tasks.

> ---

            AI agents use gh extensively for
            GitHub operations. Understanding these commands helps you review
            what agents propose.

          First, authenticate with your GitHub account:

```

> ****
            The interactive login will guide you through browser-based OAuth.
            Choose HTTPS for the git protocol unless you have SSH keys set up.

```

          Create and manage pull requests without leaving your terminal:

```

> ****
            Agents often create PRs using heredocs for the body. This format
            is common: --body "$(cat <<'EOF' ... EOF)"

```

          Monitor and interact with your CI/CD workflows:

```

          For advanced use cases, access the GitHub API directly:

```

> ---

            Agents use gh api for operations not
            covered by the standard commands. Review these carefully as they
            have full API access.

```

// =============================================================================
// BEST PRACTICE
// =============================================================================
function BestPractice({
  title,
  description,
}: {
  title: string;
  description: string;
}) {

{title}

{description}


```
