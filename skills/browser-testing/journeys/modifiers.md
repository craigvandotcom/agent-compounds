# Modifier Journey

Sourcing and processing modifier display, selection, and persistence across food entry lifecycle.

---

## Prerequisites

- Authenticated (complete `auth.md` login flow first)
- On dashboard (`/app`)
- Mobile viewport set (`390 x 844`)
- At least one food entry with resolved ingredients exists

---

## Happy Path 1: Modifier Icons Display on Resolved Ingredients

### Steps

1. **Navigate to entries tab**

   ```bash
   agent-browser --session mod click @[entries-tab]
   agent-browser --session mod wait --load networkidle
   ```

2. **Click on a food entry with resolved ingredients**

   ```bash
   agent-browser --session mod click @[food-entry-card]
   agent-browser --session mod wait --load networkidle
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:** Each resolved ingredient row shows:

- Ingredient base name (no modifier prefix in text)
- Sourcing icon in first position (e.g., Factory for conventional, Leaf for organic)
- Processing icon or empty in second position
- Icons are NOT clickable in view mode (no ghost icons visible)

---

## Happy Path 2: Default 'Conventional' Sourcing on New Ingredients

### Steps

1. **Create a new food entry via FAB**

   ```bash
   agent-browser --session mod click @[fab-ref]
   agent-browser --session mod click @[log-food-ref]
   agent-browser --session mod wait --load networkidle
   ```

2. **Add a plain ingredient (no modifier prefix)**

   ```bash
   agent-browser --session mod fill @[ingredient-input] "Chicken breast"
   agent-browser --session mod keyboard Enter
   ```

3. **Wait for resolution (shimmer resolves to zone color)**

   ```bash
   agent-browser --session mod wait --timeout 15000
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:**

- Ingredient shows "Chicken breast" as name (no "conventional" prefix)
- Factory icon (conventional sourcing) visible in first icon slot
- Ghost CookingPot icon in second slot (no processing modifier)
- Zone bar shows green/yellow/red (not shimmer)

---

## Happy Path 3: Change Sourcing Modifier via Icon Tap (Edit Mode)

### Steps

1. **Open food entry for editing** (click existing entry from Entries tab)

   ```bash
   agent-browser --session mod click @[food-entry-card]
   agent-browser --session mod wait --load networkidle
   ```

2. **Tap the sourcing icon on an ingredient**

   ```bash
   agent-browser --session mod click @[sourcing-icon]
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:** ModifierSwapDrawer opens with:

- Title: "Change Sourcing"
- List of sourcing modifiers (conventional, organic, grass-fed, pasture-raised, wild-caught, farmed)
- Current modifier highlighted with `bg-accent` background
- Zone dots next to modifiers that have existing canonical variants
- "new" badge next to modifiers without existing variants

3. **Select a different sourcing modifier**

   ```bash
   agent-browser --session mod click @[organic-option]
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:**

- Drawer closes
- Ingredient name remains the base name (e.g., "Chicken breast", not "Organic chicken breast")
- Sourcing icon changes from Factory to Leaf (organic)
- If variant doesn't exist: zone bar shows shimmer while resolving

4. **Save the entry**

   ```bash
   agent-browser --session mod click @[update-button]
   agent-browser --session mod wait --url "/app"
   ```

5. **Re-open the entry and verify modifier persisted**

   ```bash
   agent-browser --session mod click @[entries-tab]
   agent-browser --session mod click @[food-entry-card]
   agent-browser --session mod wait --load networkidle
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:** Sourcing icon still shows Leaf (organic), not Factory (conventional)

---

## Happy Path 4: Change Processing Modifier via Icon Tap

### Steps

1. **Open food entry for editing**

2. **Tap the ghost processing icon (CookingPot) on an ingredient**

   ```bash
   agent-browser --session mod click @[ghost-processing-icon]
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:** ModifierSwapDrawer opens with:

- Title: "Change Processing"
- List: fermented, sprouted, raw, smoked, washed

3. **Select "fermented"**

   ```bash
   agent-browser --session mod click @[fermented-option]
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:**

- Processing icon changes from ghost CookingPot to Beaker (fermented)
- Sourcing icon remains in first position (no swap)
- Processing icon in second position

---

## Happy Path 5: Text-Based Modifier Application

### Steps

1. **Open food entry for editing**

2. **Edit ingredient name to include modifier prefix**

   ```bash
   # Long-press or double-tap to enter edit mode on ingredient
   agent-browser --session mod click @[ingredient-edit-button]
   agent-browser --session mod clear @[ingredient-name-input]
   agent-browser --session mod fill @[ingredient-name-input] "organic chicken breast"
   agent-browser --session mod keyboard Enter
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:**

- Ingredient displays "Chicken breast" (base name, capitalized)
- Sourcing icon: Leaf (organic)
- Zone resets to shimmer (unzoned) while re-resolving with new modifier

---

## Happy Path 6: Image Analysis Ingredient Resolution

### Steps

1. **Create food entry with camera/image**

   ```bash
   agent-browser --session mod click @[fab-ref]
   agent-browser --session mod click @[log-food-ref]
   agent-browser --session mod wait --load networkidle
   ```

2. **Upload a food image and trigger analysis**

3. **Wait for AI analysis to complete and ingredients to populate**

   ```bash
   agent-browser --session mod wait --timeout 30000
   agent-browser --session mod snapshot -i
   ```

**Checkpoint:**

- All resolved ingredients show Factory icon (conventional default)
- No ghost sourcing icons on resolved ingredients
- Base names display without modifier prefixes

---

## Edge Cases

### Icon Position Stability

1. Add ingredient with only processing modifier (e.g., "fermented cabbage")

**Expected:**

- Sourcing slot (first): ghost Vegan icon (in edit mode) or empty (in view mode)
- Processing slot (second): active Beaker icon
- Icons never swap positions regardless of which modifiers are set

### View Mode Non-Interactive

1. View a food entry from the entries list (not editing)

**Expected:**

- Active modifier icons display as static (not clickable)
- No ghost icons shown (only in edit mode)
- Tapping icons does NOT open the modifier drawer

### Modifier Persistence After Resolution

1. Add new ingredient "Eggs"
2. Wait for resolution (zone appears)
3. Change sourcing to "pasture-raised" via icon
4. Save entry
5. Close and reopen entry

**Expected:** Sourcing icon shows Sun (pasture-raised), not Factory (conventional)

### Bulk Sourcing Apply (Compound Ingredients)

1. Create/edit food entry with compound ingredient (e.g., "Hummus")
2. Tap the compound's sourcing icon

**Expected:** Drawer opens in 'bulk' mode — "Apply sourcing modifier to all ingredients"

### No Modifier on Unresolved Ingredient

1. Add ingredient that hasn't resolved yet (showing shimmer)

**Expected:** Ghost icons visible in edit mode, not clickable until resolved

---

## Mobile Considerations

- Modifier drawer respects keyboard offset (Vaul handles this)
- Icon touch targets are min 44px (p-1 on 16px icon = 32px, may need verification)
- Drawer scrollable list uses `data-vaul-no-drag` to prevent accidental dismiss
- Icon labels include modifier name for screen readers

---

## Validation Report

```markdown
MODIFIER_VALIDATION:
display:
sourcing_icon_shows: PASS | FAIL
processing_icon_shows: PASS | FAIL
no_prefix_in_name: PASS | FAIL
conventional_default: PASS | FAIL
icon_position_stable: PASS | FAIL
view_mode:
icons_non_interactive: PASS | FAIL
no_ghost_icons: PASS | FAIL
edit_mode:
drawer_opens_sourcing: PASS | FAIL
drawer_opens_processing: PASS | FAIL
modifier_selection_updates_icon: PASS | FAIL
modifier_persists_after_save: PASS | FAIL
text_edit:
modifier_extracted_from_name: PASS | FAIL
base_name_displayed_correctly: PASS | FAIL
image_analysis:
conventional_default_applied: PASS | FAIL
edge_cases:
icon_position_no_swap: PASS | FAIL
bulk_apply_compound: PASS | FAIL
status: PASS | FAIL
```
