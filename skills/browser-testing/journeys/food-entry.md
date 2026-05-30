# Food Entry Journey

Add, edit, and delete food entries.

---

## Prerequisites

- Authenticated (complete `auth.md` login flow first)
- On dashboard (`/app`)
- Mobile viewport set (`390 x 844`)

---

## Happy Path: Add Food Entry

### Via FAB (Primary Flow)

The FAB (floating action button) creates a draft entry, then navigates to the form.

1. **Click FAB to expand**

   ```bash
   agent-browser --session food click @[fab-ref]
   agent-browser --session food snapshot -i
   ```

2. **Click "Log food entry"**

   ```bash
   agent-browser --session food click @[log-food-ref]
   agent-browser --session food wait --load networkidle
   ```

   **Checkpoint:** Navigated to `/app/foods/[draftId]` (a UUID, not "new")

### Via Direct URL (Also Works)

```bash
agent-browser --session food open "[BASE_URL]/app/foods/new"
agent-browser --session food set viewport 390 844
agent-browser --session food wait --load networkidle
```

### 3. Verify form loaded

```bash
agent-browser --session food snapshot -i
```

**Checkpoint:** Form contains (in order):

- DateTimePicker at top
- 4-slot ImageGallery (tap empty slot to capture/upload)
- VoiceRecorder
- Ingredient input with placeholder `"Type ingredient and press Enter"`
- Editable meal title in header (tap to rename)

### 4. Add ingredients

```bash
# Type ingredient in input
agent-browser --session food fill @[ingredient-input] "Spinach"
agent-browser --session food keyboard Enter
agent-browser --session food fill @[ingredient-input] "Eggs"
agent-browser --session food keyboard Enter
```

### 5. Verify ingredients added

```bash
agent-browser --session food snapshot -i
```

**Checkpoint:** Ingredient chips/tags visible for "Spinach" and "Eggs"

### 6. Save entry

```bash
# Button label is "Save entry" in add mode
agent-browser --session food click @[save-button]
agent-browser --session food wait --url "/app"
```

### 7. Verify entry appears in list

```bash
# Switch to entries tab
agent-browser --session food click @[entries-tab]
agent-browser --session food wait --load networkidle
agent-browser --session food snapshot -i
```

**Checkpoint:** New food entry visible in Entries tab for today.

---

## Happy Path: Edit Food Entry

### Steps

1. **Navigate to entries tab**

   ```bash
   agent-browser --session food click @[entries-tab]
   agent-browser --session food wait --load networkidle
   ```

2. **Click on existing food entry**

   ```bash
   agent-browser --session food snapshot -i
   # Find food entry card and click
   agent-browser --session food click @[food-entry-card]
   agent-browser --session food wait --load networkidle
   ```

3. **Modify entry**

   ```bash
   # Add another ingredient
   agent-browser --session food fill @[ingredient-input] "Tomatoes"
   agent-browser --session food keyboard Enter
   ```

4. **Save changes**

   ```bash
   # Button label is "Update entry" in edit mode
   agent-browser --session food click @[update-button]
   agent-browser --session food wait --url "/app"
   ```

---

## Happy Path: Delete Food Entry

### Steps

1. **Navigate to food entry edit page** (click entry from Entries tab)

2. **Click delete button**

   ```bash
   # Button label is "Delete entry" (destructive variant, edit mode only)
   agent-browser --session food click @[delete-button]
   ```

3. **Verify redirected to dashboard**

   ```bash
   agent-browser --session food wait --url "/app"
   ```

4. **Verify entry no longer in list**

---

## Form Elements Reference

| Element          | Type        | Details                                          |
| ---------------- | ----------- | ------------------------------------------------ |
| DateTimePicker   | Component   | Always visible at top                            |
| ImageGallery     | Component   | 4 slots, tap empty slot to capture/upload        |
| VoiceRecorder    | Component   | Audio transcription input                        |
| Analyze button   | Button      | `"Analyze"` (first time) or `"Re-analyze"`       |
| Ingredient input | Text input  | Placeholder: `"Type ingredient and press Enter"` |
| Copy ingredients | Icon button | BookCopy icon, copies from previous entry        |
| Notes            | Collapsible | `"Add notes (optional)"`, textarea inside        |

## Footer Buttons (UniversalNavbar)

| Button               | Mode             | Variant     |
| -------------------- | ---------------- | ----------- |
| `"Save entry"`       | Add              | success     |
| `"Update entry"`     | Edit             | success     |
| `"Delete entry"`     | Edit             | destructive |
| `"Upload image"`     | Edit             | default     |
| `"Take photo"`       | Edit             | default     |
| `"Dismiss keyboard"` | Keyboard visible | default     |

---

## Edge Cases

### Empty Submission

1. Navigate to add food
2. Click save without adding ingredients

**Expected:** Validation error shown, form not submitted

### Duplicate Ingredients

1. Add "Spinach" twice

**Expected:** Either prevents duplicate or shows both, no crash

### Special Characters in Ingredients

1. Add ingredient with special chars: "Cafe au lait"

**Expected:** Saved and displayed correctly

---

## Mobile Considerations

- Ingredient input accessible on mobile keyboard
- Chip/tag deletion works with touch
- Date picker usable on small screens
- Footer buttons accessible above keyboard (keyboard offset applied)
- Image gallery touch targets adequate (4-slot grid)

---

## Validation Report

```markdown
FOOD_ENTRY_VALIDATION:
add_flow:
form_loads: PASS | FAIL
ingredients_addable: PASS | FAIL
save_works: PASS | FAIL
entry_appears: PASS | FAIL
edit_flow:
entry_clickable: PASS | FAIL
changes_saveable: PASS | FAIL
delete_flow:
delete_button_works: PASS | FAIL
entry_removed: PASS | FAIL
status: PASS | FAIL
```
