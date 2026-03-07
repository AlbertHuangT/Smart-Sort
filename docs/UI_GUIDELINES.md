# UI Guidelines

This document defines the app's current UI system. It is aligned with:

- [TrashTheme.swift](/Users/alberthuang/Documents/Smart%20Sort/Smart%20Sort/Theme/TrashTheme.swift)
- [TrashCorePrimitives.swift](/Users/alberthuang/Documents/Smart%20Sort/Smart%20Sort/Theme/TrashCorePrimitives.swift)
- [TrashFormControls.swift](/Users/alberthuang/Documents/Smart%20Sort/Smart%20Sort/Theme/TrashFormControls.swift)
- [TrashSegmentedControl.swift](/Users/alberthuang/Documents/Smart%20Sort/Smart%20Sort/Theme/TrashSegmentedControl.swift)

Use this file as the implementation-facing source for visual consistency.

## Principles

- Prefer shared theme tokens over page-local magic numbers.
- Prefer shared primitives over ad-hoc `RoundedRectangle`, `Button`, and form styling.
- Follow Apple HIG-sized touch targets and control density.
- Reuse semantic colors. Do not hardcode raw `.red`, `.green`, `.secondary`, or `.gray` for app states unless the platform behavior itself requires it.

## Sizing

These values come from `ThemeComponentMetrics`.

- Minimum tappable target: `44pt`
- Icon button size: `44pt`
- Primary button height: `50pt`
- Text input height: `50pt`
- Standard row height: `56pt`
- Segmented control height: `44pt`
- Interactive pill height: `44pt`
- Card padding: `16pt`
- Sheet/dialog padding: `24pt`
- Default horizontal content inset: `16pt`

Rules:

- Any tappable control must respect the `44pt` minimum target.
- Do not create custom small icon buttons below `44pt`.
- Do not introduce one-off button heights like `52`, `54`, or `60` unless there is a strong layout reason.
- Use responsive height only when the layout truly depends on screen size, such as large image/card regions.

## Corner Radius

These values come from `ThemeCornerRadius`.

- `small`: `10`
- `medium`: `16`
- `large`: `24`
- `pill`: `22`

Rules:

- Use `small` for compact chips, icon surfaces, and small badges.
- Use `medium` for standard cards, rows, and inline surfaces.
- Use `large` for hero cards, sheets, quiz/image cards, and major panels.
- Use `pill` only for capsule-like interactive pills.
- Do not add page-local values like `12`, `14`, `15`, `18`, `20`, `28`, `30`, or `36` unless the shared token set is first expanded intentionally.

## Spacing

These values come from `ThemeSpacing`.

- `xs`: `4`
- `sm`: `8`
- `md`: `16`
- `lg`: `20`
- `xl`: `28`
- `xxl`: `40`

Rules:

- Use `md` as the default screen inset and standard card spacing.
- Use `lg` for section separation and medium-emphasis groups.
- Use `xl` and `xxl` for hero spacing and empty states.
- Keep layouts on this scale instead of mixing arbitrary values like `10`, `12`, `14`, `18`, `24`, `32`.

## Typography

These values come from `ThemeTypography`.

- `title`: `34pt bold rounded`
- `headline`: `24pt semibold rounded`
- `subheadline`: `17pt semibold rounded`
- `body`: `17pt regular rounded`
- `caption`: `13pt medium rounded`
- `button`: `17pt semibold rounded`
- `heroIcon`: `48pt semibold rounded`

Rules:

- Use theme typography instead of ad-hoc `.system(size:)` for common text roles.
- Default body copy should usually be `theme.typography.body`.
- Section labels and small metadata should usually use `theme.typography.caption`.
- Only use custom system sizes for deliberate hero moments, countdowns, or illustrations.

## Color System

Use these sources:

- Base palette: `theme.palette`
- Accent colors: `theme.accents`
- Semantic states:
  - `theme.semanticSuccess`
  - `theme.semanticWarning`
  - `theme.semanticDanger`
  - `theme.semanticInfo`
  - `theme.semanticHighlight`
- Category colors:
  - `theme.categoryRecyclable`
  - `theme.categoryCompostable`
  - `theme.categoryHazardous`
  - `theme.categoryLandfill`
- Medal colors:
  - `theme.medalGold`
  - `theme.medalSilver`
  - `theme.medalBronze`

Rules:

- Text should default to `theme.palette.textPrimary` or `theme.palette.textSecondary`.
- Interactive accent foreground should use `theme.onAccentForeground`.
- Danger/success/warning UI must use semantic colors, not raw platform colors.
- Do not use `.secondary` or `.primary` for app-owned styling when a theme token exists.

## Shared Primitives

Prefer these primitives before writing custom UI:

- Cards: `TrashCard` or `.surfaceCard(...)`
- Primary actions: `TrashButton`
- Tap rows/surfaces: `TrashTapArea`
- Inputs:
  - `TrashFormTextField`
  - `TrashFormSecureField`
  - `TrashFormTextEditor`
  - `TrashFormPicker`
  - `TrashOptionalFormPicker`
  - `TrashFormToggle`
  - `TrashFormStepper`
  - `TrashFormDatePicker`
- Small controls:
  - `TrashIconButton`
  - `TrashPill`
  - `TrashTextButton`
  - `TrashSectionTitle`
  - `TrashSearchField`
  - `TrashSegmentedControl`
- Sheets:
  - `TrashNoticeSheet`
  - `TrashConfirmSheet`
  - `TrashTextInputSheet`

Rules:

- If a shared primitive can express the UI, use it.
- Expand the primitive or theme token only when repeated page-specific styling starts appearing in multiple places.
- Do not fork a second visual system inside one feature if a shared primitive already exists.

## Feature-Specific Guidance

### Arena

- Reuse `SharedQuizCard`, `ArenaStatusBar`, and `GenericSessionSummaryView` whenever possible.
- Arena image/quiz cards should use the shared large-radius image-card treatment.
- Mode wrappers may differ in logic, not in core control sizing.

### Community

- Event, community, and location rows should use shared row/card metrics.
- Detail sheets should use `contentInset`, `cardPadding`, and theme semantic colors instead of local one-off geometry.

### Verify

- Verify’s hero camera surface can use larger visual geometry, but supporting controls still follow the shared hit target, button, and card rules.
- Error/result/feedback cards should use theme cards, semantic colors, and shared spacing.

### Account/Profile/Auth

- Avoid raw system button styles for app-owned calls to action when `TrashButton` is appropriate.
- Status banners, toasts, and inline feedback should use semantic colors and theme typography.
- Badge/achievement chips must still respect `44pt` targets if interactive.

## Anti-Patterns

Avoid introducing:

- Raw `RoundedRectangle(cornerRadius: 12/14/15/18/20/28...)` when a shared radius token already fits
- Raw `padding(10/12/14/18/24/32...)` when an existing spacing token fits
- Raw `.foregroundColor(.red/.green/.gray/.secondary/.primary)` for app states
- Tiny interactive chips or buttons below `44pt`
- Parallel component systems inside one feature

## When To Expand The System

Add or change theme tokens only when:

- the same exception appears in multiple places
- a new component shape/size is clearly intentional and reusable
- the existing token set forces awkward or repetitive overrides

When expanding the system:

1. Add the token to `TrashTheme`
2. Update shared primitives if needed
3. Migrate feature code to the new token
4. Avoid leaving page-local fallback numbers behind
