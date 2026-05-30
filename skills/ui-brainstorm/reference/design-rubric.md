# Design Rubric Reference

Detailed criteria for evaluating UI/UX improvement ideas.

---

## Rubric Overview

| Criterion       | Weight | Score Range | Focus                                  |
| --------------- | ------ | ----------- | -------------------------------------- |
| Visual Appeal   | 20%    | 1-5         | Professional aesthetics and engagement |
| Usability       | 30%    | 1-5         | Intuition, accessibility, efficiency   |
| Brand Alignment | 15%    | 1-5         | Consistency with brand identity        |
| Innovation      | 20%    | 1-5         | Differentiation and uniqueness         |
| Feasibility     | 15%    | 1-5         | Implementation complexity and risk     |

**Total possible:** 25 points (5 criteria × 5 max score)

---

## 1. Visual Appeal (20%)

**Question:** Does it look professional and engaging?

### Scoring Guide

**5/5 - Exceptional**

- Visually striking, memorable
- Professional polish
- Strong visual hierarchy
- Excellent use of whitespace
- Color contrast enhances readability
- Typography is polished and purposeful

**4/5 - Strong**

- Professional and appealing
- Good visual hierarchy
- Appropriate color usage
- Minor refinements possible
- Generally engaging

**3/5 - Adequate**

- Functional but unremarkable
- Standard design patterns
- No major visual issues
- Room for improvement in polish
- Neutral aesthetic

**2/5 - Weak**

- Lacks polish
- Poor visual hierarchy
- Color choices conflict
- Typography issues
- Appears amateurish

**1/5 - Poor**

- Visually unappealing
- Confusing layout
- Clashing colors
- Unprofessional appearance
- Actively detracts from experience

### Evaluation Questions

- Does it grab attention positively?
- Is the visual hierarchy clear at a glance?
- Do colors enhance or detract from usability?
- Is typography readable and appropriate?
- Does it look current (not dated)?
- Would users perceive this as professional?

---

## 2. Usability (30%)

**Question:** Is it intuitive and accessible?

**Highest weight because user impact matters most.**

### Scoring Guide

**5/5 - Exceptional**

- Immediately intuitive
- Reduces cognitive load significantly
- Accessible to all users (WCAG AAA)
- Minimizes clicks/taps to goal
- Clear affordances
- Excellent error prevention
- Mobile-optimized

**4/5 - Strong**

- Intuitive to most users
- Good accessibility (WCAG AA)
- Efficient task completion
- Clear call-to-action
- Minor learning curve acceptable
- Responsive design

**3/5 - Adequate**

- Usable with minimal guidance
- Basic accessibility compliance
- No major blockers
- Standard interaction patterns
- Some friction acceptable

**2/5 - Weak**

- Requires explanation or help
- Accessibility gaps
- Inefficient workflows
- Unclear next steps
- Frustration likely

**1/5 - Poor**

- Confusing or broken
- Major accessibility failures
- Blocks task completion
- High error rates
- User frustration guaranteed

### Evaluation Questions

- Can first-time users accomplish the task without help?
- How many clicks/taps to complete primary action?
- Is it accessible to screen readers?
- Does it work on mobile (touch targets ≥44px)?
- Are error states handled gracefully?
- Do interaction patterns match user expectations?
- Can users undo mistakes easily?

### Accessibility Checklist

- [ ] Color contrast ratio ≥4.5:1 (text)
- [ ] Touch targets ≥44×44px (mobile)
- [ ] Keyboard navigable
- [ ] Screen reader friendly
- [ ] Form labels and error messages clear
- [ ] No motion-required interactions
- [ ] Respects reduced motion preferences

---

## 3. Brand Alignment (15%)

**Question:** Does it match brand identity?

### Scoring Guide

**5/5 - Exceptional**

- Perfectly embodies brand values
- Uses brand design tokens correctly
- Reinforces brand positioning
- Consistent with existing assets
- Strengthens brand recognition

**4/5 - Strong**

- Generally aligned with brand
- Uses brand colors/typography
- Minor deviations acceptable
- Maintains brand feel
- Recognizable as brand

**3/5 - Adequate**

- Neutral brand impact
- Doesn't violate brand guidelines
- Could be more distinctive
- Generic but acceptable
- Missed opportunity for reinforcement

**2/5 - Weak**

- Deviates from brand guidelines
- Feels off-brand
- Inconsistent with existing assets
- Weakens brand identity
- Confuses brand perception

**1/5 - Poor**

- Contradicts brand values
- Violates brand guidelines
- Unrecognizable as brand
- Damages brand perception
- Complete misalignment

### Evaluation Questions

- Does it use brand color palette?
- Is typography consistent with brand?
- Does visual style match brand personality?
- Would users recognize this as your brand?
- Does it reinforce or weaken brand positioning?
- Is tone/voice aligned with brand guidelines?

### Brand Reference

**Load brand skill for specifics:**
`.claude/skills/brand/SKILL.md`

**Key brand attributes to check:**

- Color palette
- Typography system
- Visual style (photography, illustrations, icons)
- Tone of voice
- Brand values and positioning
- Target audience expectations

---

## 4. Innovation (20%)

**Question:** Does it differentiate from competitors?

### Scoring Guide

**5/5 - Exceptional**

- Breakthrough approach
- First-mover advantage
- Creates new interaction pattern
- Memorable and unique
- Competitive differentiation
- Users will notice and remember

**4/5 - Strong**

- Fresh take on standard pattern
- Differentiates from competitors
- Thoughtful innovation
- Balances novelty with familiarity
- Competitive edge

**3/5 - Adequate**

- Standard best practice
- Follows proven patterns
- Safe and reliable
- No differentiation but no risk
- Industry standard

**2/5 - Weak**

- Generic implementation
- Copies competitor exactly
- No unique value
- Forgettable
- Commodity approach

**1/5 - Poor**

- Outdated pattern
- Behind competitors
- Regressive change
- Misses industry evolution
- Actively backward

### Evaluation Questions

- Have competitors done this already?
- Is this pattern tired or fresh?
- Will users notice the difference?
- Does it create competitive advantage?
- Is novelty balanced with usability?
- Does innovation serve user needs or just novelty?

### Innovation vs. Usability Tradeoff

**Watch for:** High innovation often trades with usability

- Novel patterns require user learning
- First-mover advantage requires education
- Differentiation must still be intuitive

**Best case:** Innovation that _improves_ usability (rare but valuable)

---

## 5. Feasibility (15%)

**Question:** Can it be implemented reasonably?

### Scoring Guide

**5/5 - Exceptional**

- 1-2 day implementation
- Uses existing components/patterns
- No technical risk
- No dependencies
- Easily testable
- Low cost

**4/5 - Strong**

- 3-5 day implementation
- Minimal new components
- Low technical risk
- Few dependencies
- Standard testing approach
- Moderate cost

**3/5 - Adequate**

- 1-2 week implementation
- Some custom development
- Moderate technical risk
- Manageable dependencies
- Requires thorough testing
- Reasonable cost

**2/5 - Weak**

- 2-4 week implementation
- Significant custom work
- High technical risk
- Complex dependencies
- Extensive testing needed
- High cost

**1/5 - Poor**

- > 1 month implementation
- Complete rebuild required
- Extreme technical risk
- Breaking dependencies
- Unknown unknowns
- Prohibitive cost

### Evaluation Questions

- What's realistic timeline?
- Do we have existing components?
- What technical risks exist?
- What dependencies are introduced?
- How much testing is required?
- What's the cost/benefit ratio?
- Can we prototype quickly to validate?

### Feasibility Factors

**Time:**

- Development hours
- Design iteration time
- Testing requirements
- QA cycles
- Deployment complexity

**Risk:**

- Technical unknowns
- Browser compatibility
- Performance impact
- Security considerations
- Data migration needs

**Resources:**

- Team capacity
- Design resources
- External dependencies
- Third-party tools/APIs
- Budget constraints

---

## Rubric Weight Adjustments

**Default weights work for most cases, but adjust for:**

### High-Growth Products (prioritize innovation)

- Visual Appeal: 15%
- Usability: 30%
- Brand Alignment: 10%
- **Innovation: 30%** (increased)
- Feasibility: 15%

### Enterprise Products (prioritize usability + feasibility)

- Visual Appeal: 15%
- **Usability: 35%** (increased)
- Brand Alignment: 10%
- Innovation: 15%
- **Feasibility: 25%** (increased)

### Brand Relaunch (prioritize brand alignment)

- Visual Appeal: 25%
- Usability: 25%
- **Brand Alignment: 30%** (increased)
- Innovation: 10%
- Feasibility: 10%

### Competitive Pressure (prioritize innovation + visual)

- **Visual Appeal: 25%** (increased)
- Usability: 25%
- Brand Alignment: 10%
- **Innovation: 30%** (increased)
- Feasibility: 10%

### MVP/Prototype (prioritize feasibility)

- Visual Appeal: 10%
- **Usability: 35%** (increased)
- Brand Alignment: 10%
- Innovation: 10%
- **Feasibility: 35%** (increased)

---

## Scoring Calibration Examples

### Example 1: "Add Dark Mode Toggle"

**Visual Appeal: 4/5**

- Dark mode is polished when done right
- Enhances visual appeal for some users
- Not groundbreaking but professional

**Usability: 5/5**

- Reduces eye strain in low light
- Accessible feature
- Standard toggle pattern (intuitive)
- Improves task efficiency for power users

**Brand Alignment: 3/5**

- Neutral brand impact
- Expected feature (doesn't differentiate)
- Doesn't strengthen or weaken brand

**Innovation: 2/5**

- Industry standard (not innovative)
- Expected by users
- No competitive differentiation

**Feasibility: 5/5**

- 1-2 day implementation with CSS variables
- Standard pattern
- Low risk
- Easy to test

**Total: 19/25** (76%)

---

### Example 2: "Redesign Navigation with Floating Action Button"

**Visual Appeal: 5/5**

- Modern, eye-catching
- Strong visual hierarchy
- Professional polish

**Usability: 3/5**

- Unfamiliar pattern for web
- Mobile-first (good for mobile, odd on desktop)
- Requires user education
- Efficient once learned

**Brand Alignment: 4/5**

- Modern feel aligns with brand
- Uses brand colors effectively
- Slight deviation from current style

**Innovation: 5/5**

- Rare pattern on web
- Differentiates from competitors
- Memorable interaction

**Feasibility: 3/5**

- 1-2 week implementation
- Custom component needed
- Cross-browser testing required
- Animation complexity

**Total: 20/25** (80%)

**Note:** Higher score than dark mode despite lower usability - innovation + visual appeal compensate. **High variance expected** in ranking phase (usability-focused models will rank lower).

---

## Using This Rubric

**During Phase 1 (Generation):**

- Models use rubric to self-assess ideas
- Forces structured thinking
- Provides justification baseline

**During Phase 2 (Ranking):**

- Models weight criteria per their priorities
- Reveals which criteria matter most per model
- Enables variance analysis

**During Phase 4 (Synthesis):**

- Meta-model uses rubric to explain consensus
- Identifies which criteria drove agreement
- Surfaces tradeoffs across dimensions

---

**Version:** 1.0
**Last Updated:** 2026-01-31
