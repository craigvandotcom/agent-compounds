# Proposed structure — presentation shape

Present this tree (or the plan's equivalent) for approval:

```
Epic: User Authentication
├── BR-1: Create user schema (P0, labels: auth,backend)
├── BR-2: Implement JWT middleware (P0, depends: BR-1, labels: auth,backend)
├── BR-3: Add login endpoint (P0, depends: BR-2, labels: auth,api)
├── BR-4: Add registration endpoint (P1, depends: BR-2, labels: auth,api)
└── BR-5: Add password reset (P2, depends: BR-3, labels: auth,api)

Epic: Dashboard
├── BR-6: Create layout component (P0, labels: dashboard,frontend)
├── BR-7: Add navigation (P0, depends: BR-6, labels: dashboard,frontend)
...
```
