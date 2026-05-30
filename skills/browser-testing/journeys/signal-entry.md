# Signal Entry Journey

Add, edit, and delete symptom/signal entries.

---

## Prerequisites

- Authenticated (complete `auth.md` login flow first)
- On dashboard (`/app`)
- Mobile viewport set (`390 x 844`)

---

## Happy Path: Add Signal Entry

### Steps

1. **Navigate to add signal**

   Via FAB:

   ```bash
   agent-browser --session signal click @[fab-ref]
   agent-browser --session signal click @[log-signal-ref]
   agent-browser --session signal wait --url "/app/symptoms/add"
   ```

   Or direct URL:

   ```bash
   agent-browser --session signal open "[BASE_URL]/app/symptoms/add"
   agent-browser --session signal set viewport 390 844
   agent-browser --session signal wait --load networkidle
   ```

2. **Verify form loaded**

   ```bash
   agent-browser --session signal snapshot -i
   ```

   **Checkpoint:** Page title is **"Add Signal"**. Form contains:
   - DateTimePicker at top
   - Search input (placeholder: `"Search symptoms..."`)
   - Recent symptoms chips (up to 3, if any exist)
   - 2-column category grid (8 categories)
   - Footer: `"Cancel"` and `"Save Symptoms"` buttons

3. **Select signal category**

   ```bash
   # Click on a category (e.g., Digestion)
   agent-browser --session signal click @[digestion-category]
   ```

   **Checkpoint:** Category expands with accordion showing individual symptoms

4. **Select specific signal**

   ```bash
   agent-browser --session signal snapshot -i
   # Click specific signal (e.g., Bloating)
   agent-browser --session signal click @[bloating-signal]
   ```

   **Checkpoint:** SignalConfirmationCard appears showing selected symptom with category icon

5. **Set severity**

   ```bash
   # Severity picker appears (1-5 scale, default 3 "Moderate")
   # Click desired severity level
   agent-browser --session signal click @[severity-button]
   ```

   **Severity levels:**

   | Level | Label    | Color       |
   | ----- | -------- | ----------- |
   | 1     | Mild     | Zone Green  |
   | 2     | Light    | Lime Green  |
   | 3     | Moderate | Zone Yellow |
   | 4     | Strong   | Orange      |
   | 5     | Severe   | Zone Red    |

6. **Save entry**

   ```bash
   # Button label is "Save Symptoms"
   agent-browser --session signal click @[save-button]
   agent-browser --session signal wait --url "/app"
   ```

7. **Verify entry appears in list**

   ```bash
   agent-browser --session signal click @[entries-tab]
   agent-browser --session signal wait --load networkidle
   agent-browser --session signal snapshot -i
   ```

   **Checkpoint:** New signal entry visible in Entries tab.

---

## Happy Path: Edit Signal Entry

### Steps

1. **Navigate to entries tab**
2. **Click on existing signal entry**
3. **Modify severity**
4. **Save changes**
5. **Verify changes persisted**

---

## Happy Path: Delete Signal Entry

### Steps

1. **Navigate to signal entry edit page**
2. **Find and click delete button**
3. **Confirm deletion**
4. **Verify entry removed from list**

---

## Signal Categories (8 total)

| Category    | Icon        | Symptom Count |
| ----------- | ----------- | ------------- |
| Digestion   | stomach     | 8             |
| Energy      | electricity | 5             |
| Mind        | neurology   | 9             |
| Recovery    | joints      | 7             |
| Skin        | body        | 4             |
| Headaches   | headache    | 2             |
| Respiratory | lungs       | 4             |
| Sleep       | sleepy      | 3             |

---

## Edge Cases

### No Symptom Selected

1. Try to click "Save Symptoms" without selecting a symptom

**Expected:** Save button is disabled (`disabled: !isFormValid`)

### Search for Symptom

1. Type in search input `"Bloating"`

**Expected:** Filtered results replace category grid

### Recent Symptoms Quick Select

1. If recent symptoms chips are shown, click one

**Expected:** Symptom selected immediately, confirmation card appears

---

## Mobile Considerations

- Category grid renders as 2-column layout
- Touch targets adequately sized (44px minimum)
- Severity picker supports keyboard navigation (arrow keys)
- Footer buttons accessible above keyboard
- Search input centered with placeholder overlay

---

## Validation Report

```markdown
SIGNAL_ENTRY_VALIDATION:
add_flow:
form_loads: PASS | FAIL
category_selectable: PASS | FAIL
signal_selectable: PASS | FAIL
severity_adjustable: PASS | FAIL
save_works: PASS | FAIL
entry_appears: PASS | FAIL
edit_flow:
entry_clickable: PASS | FAIL
changes_saveable: PASS | FAIL
delete_flow:
delete_works: PASS | FAIL
entry_removed: PASS | FAIL
status: PASS | FAIL
```
