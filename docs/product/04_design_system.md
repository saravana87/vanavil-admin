# VANAVIL Design System Direction

## Theme Intent

VANAVIL should feel bright, warm, and rewarding without becoming visually noisy.

Based on the provided references and palette sampling, the core direction is:

- warm light backgrounds
- clean surfaces for admin web
- more playful accents for child mobile
- rounded shapes and large touch targets
- colorful state badges with strong contrast

---

## Color System

### Base Neutrals

Use warm off-whites instead of pure cold gray backgrounds.

- `cream50`: `#FEFEFD`
- `cream100`: `#FEFBF4`
- `sand100`: `#FEF9F3`
- `sand200`: `#F4EBDD`
- `ink900`: `#2B2A28`
- `ink700`: `#4C4A46`

### Accent Palette

These accents keep the child experience lively and the admin view readable.

- `sun`: `#F5B938`
- `coral`: `#F46F5E`
- `leaf`: `#4FB36B`
- `sky`: `#4CA7E8`
- `berry`: `#D95AA5`
- `lavender`: `#8B7CF6`

### Semantic Usage

- assigned: `sky`
- submitted: `sun`
- approved/completed: `leaf`
- rejected: `coral`
- badges/rewards: `berry` or `lavender`

---

## Surface Rules

### Admin Web

- background: warm cream
- cards: near-white with subtle shadow
- tables: clean row dividers, not heavy borders
- accents: restrained, mostly in charts, chips, and CTAs

### Child Mobile

- background: layered warm gradients or soft color sections
- cards: large radius, colorful edge treatment or top stripe
- primary buttons: bold fills with high contrast labels
- use illustrations or badge icons sparingly but intentionally

---

## Typography

Use one readable rounded family for the child app and a more neutral UI family for admin if needed. If keeping a single font family across both apps, choose one that stays friendly without looking childish.

Suggested hierarchy:

- Display: 28 to 34, bold
- Screen title: 22 to 26, semibold
- Card title: 16 to 18, semibold
- Body: 14 to 16, regular
- Caption: 12 to 13, medium

Rules:

- avoid thin weights
- keep line height generous for child-facing content
- use short sentences in task cards and alerts

---

## Shape And Spacing

### Radius Tokens

- small: 12
- medium: 18
- large: 24
- pill: 999

### Spacing Tokens

- 4, 8, 12, 16, 20, 24, 32

Rules:

- child app buttons should not be smaller than 48 logical pixels in height
- cards should have comfortable internal padding, usually 16 to 20
- avoid dense admin forms; use 16 to 24 vertical rhythm

---

## Core Components

### Shared Components

- status chip
- primary button
- secondary button
- empty state card
- avatar tile
- points badge
- announcement card
- loading skeleton

### Admin-Specific Components

- summary stat card
- review queue row
- child management table
- task template form section
- media preview panel

### Child-Specific Components

- reward hero card
- task card with due date badge
- badge trophy chip
- profile selection tile
- upload proof action sheet

---

## Motion

Use motion lightly but meaningfully.

- child app: staggered card reveal on dashboard, success pulse on badge award, soft transitions between tabs
- admin web: quick fade or slide for panels, no excessive animation

Avoid decorative animation that delays routine admin actions.

---

## Visual Split Between Admin And Child

### Admin Web Feel

- structured
- calm
- metric-driven
- clear hierarchy

### Child Mobile Feel

- playful
- celebratory
- obvious actions
- emotionally positive

The two surfaces should feel related by palette and shapes, but not identical.
