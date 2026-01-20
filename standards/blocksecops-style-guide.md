# BlockSecOps Style Guide

**Version:** 1.0
**Last Updated:** January 19, 2026

---

## Overview

This style guide defines the visual language for BlockSecOps applications, featuring a dark cyberpunk aesthetic with electric cyan, purple accents, glassmorphism effects, and neon glows.

---

## Color Palette

### Primary Colors

| Name | Hex | Usage |
|------|-----|-------|
| Electric Cyan | `#00D4FF` | Primary actions, links, active states |
| Purple | `#8B5CF6` | Accent, secondary actions, gradients |

### Electric Cyan Scale

```
50:  #E6F9FF  - Lightest backgrounds
100: #CCF3FF  - Hover states
200: #99E7FF  - Light accents
300: #66DBFF  - Medium accents
400: #33D0FF  - Soft highlights
500: #00D4FF  - Primary (main)
600: #00A8CC  - Pressed states
700: #007B99  - Dark accents
800: #005366  - Darker backgrounds
900: #002B33  - Darkest accents
```

### Purple Scale

```
50:  #F5F3FF  - Lightest backgrounds
100: #EDE9FE  - Hover states
200: #DDD6FE  - Light accents
300: #C4B5FD  - Medium accents
400: #A78BFA  - Soft highlights
500: #8B5CF6  - Main accent
600: #7C3AED  - Pressed states
700: #6D28D9  - Dark accents
800: #5B21B6  - Darker backgrounds
900: #4C1D95  - Darkest accents
```

### Dark Backgrounds

| Name | Hex | Usage |
|------|-----|-------|
| Dark 50 | `#4B5563` | Lightest dark |
| Dark 100 | `#374151` | Light dark |
| Dark 200 | `#2A2D50` | Medium dark |
| Dark 300 | `#1A1B3D` | Cards, panels |
| Dark 400 | `#0A0E27` | Main background |
| Dark 500 | `#050711` | Deepest dark |

### Semantic Colors

| Name | Hex | Usage |
|------|-----|-------|
| Success | `#00FF88` | Success states, confirmations |
| Warning | `#FF8A00` | Warnings, cautions |
| Error | `#FF3366` | Errors, critical alerts |

### Text Colors

| Class | Value | Usage |
|-------|-------|-------|
| `text-white` | `#FFFFFF` | Primary text |
| `text-white/80` | `rgba(255,255,255,0.8)` | Secondary text |
| `text-white/60` | `rgba(255,255,255,0.6)` | Muted text |
| `text-white/40` | `rgba(255,255,255,0.4)` | Disabled text |
| `text-electric-500` | `#00D4FF` | Links, accents |

---

## Typography

### Font Families

| Name | Font | Usage |
|------|------|-------|
| `font-sans` | Inter | Body text, UI elements |
| `font-display` | Space Grotesk | Headings, hero text |
| `font-mono` | JetBrains Mono | Code, technical content |

### Font Sizes

| Class | Size | Line Height | Usage |
|-------|------|-------------|-------|
| `text-hero` | 4.5rem | 1.1 | Hero headlines |
| `text-5xl` | 3.5rem | 1.2 | Page titles |
| `text-4xl` | 2.25rem | 1.2 | Section headers |
| `text-3xl` | 1.875rem | 1.3 | Card titles |
| `text-2xl` | 1.5rem | 1.4 | Subheadings |
| `text-xl` | 1.25rem | 1.5 | Large body |
| `text-lg` | 1.125rem | 1.5 | Emphasized body |
| `text-base` | 1rem | 1.5 | Body text |
| `text-sm` | 0.875rem | 1.5 | Secondary text |
| `text-xs` | 0.75rem | 1.5 | Labels, badges |

### Gradient Text

```css
.gradient-text {
  background: linear-gradient(to right, #00D4FF, #8B5CF6);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}
```

---

## Components

### Glassmorphism Cards

```css
.glass {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
}
```

**Usage in Tailwind:**
```html
<div class="glass rounded-xl p-6">
  <!-- Card content -->
</div>
```

### Standard Cards

```html
<div class="bg-dark-300/80 backdrop-blur-[10px] border border-white/10 rounded-xl p-6">
  <!-- Card content -->
</div>
```

### Buttons

#### Primary Button
```html
<button class="bg-electric-500 text-dark-400 px-6 py-3 rounded-lg font-medium
               hover:shadow-neon transition-all duration-200">
  Primary Action
</button>
```

#### Secondary Button
```html
<button class="border border-electric-500 text-electric-500 px-6 py-3 rounded-lg
               font-medium hover:bg-electric-500/10 transition-all duration-200">
  Secondary Action
</button>
```

#### Ghost Button
```html
<button class="text-white/70 px-6 py-3 rounded-lg hover:bg-white/5
               transition-all duration-200">
  Ghost Action
</button>
```

#### Danger Button
```html
<button class="bg-error text-white px-6 py-3 rounded-lg font-medium
               hover:bg-error/80 transition-all duration-200">
  Delete
</button>
```

### Badges

#### Severity Badges

```html
<!-- Critical -->
<span class="bg-error/20 text-error border border-error/30 px-2 py-1 rounded text-xs">
  Critical
</span>

<!-- High -->
<span class="bg-warning/20 text-warning border border-warning/30 px-2 py-1 rounded text-xs">
  High
</span>

<!-- Medium -->
<span class="bg-yellow-400/20 text-yellow-400 border border-yellow-400/30 px-2 py-1 rounded text-xs">
  Medium
</span>

<!-- Low -->
<span class="bg-electric-500/20 text-electric-400 border border-electric-500/30 px-2 py-1 rounded text-xs">
  Low
</span>

<!-- Info -->
<span class="bg-purple-500/20 text-purple-400 border border-purple-500/30 px-2 py-1 rounded text-xs">
  Info
</span>
```

### Form Inputs

```html
<input
  type="text"
  class="bg-dark-300 border border-white/10 text-white placeholder-white/40
         rounded-lg px-4 py-3 focus:border-electric-500 focus:ring-2
         focus:ring-electric-500/20 transition-all duration-200"
  placeholder="Enter text..."
/>
```

### Tables

```html
<table class="w-full">
  <thead class="bg-dark-400/50">
    <tr class="border-b border-white/10">
      <th class="text-left text-white/60 text-sm font-medium px-4 py-3">Header</th>
    </tr>
  </thead>
  <tbody class="divide-y divide-white/5">
    <tr class="hover:bg-white/5 transition-colors">
      <td class="text-white px-4 py-3">Content</td>
    </tr>
  </tbody>
</table>
```

### Modals

```html
<!-- Overlay -->
<div class="fixed inset-0 bg-dark-500/80 backdrop-blur-sm z-50">
  <!-- Modal -->
  <div class="glass rounded-2xl max-w-lg mx-auto mt-20 p-6">
    <h2 class="text-xl font-display text-white mb-4">Modal Title</h2>
    <!-- Content -->
  </div>
</div>
```

---

## Visual Effects

### Neon Glow - Cyan

```css
.neon-glow {
  box-shadow:
    0 0 20px rgba(0, 212, 255, 0.5),
    0 0 40px rgba(0, 212, 255, 0.3),
    0 0 60px rgba(0, 212, 255, 0.1);
}
```

### Neon Glow - Purple

```css
.neon-glow-purple {
  box-shadow:
    0 0 20px rgba(139, 92, 246, 0.5),
    0 0 40px rgba(139, 92, 246, 0.3),
    0 0 60px rgba(139, 92, 246, 0.1);
}
```

### Grid Pattern Background

```css
.grid-pattern {
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.03) 1px, transparent 1px);
  background-size: 40px 40px;
}
```

### Background Gradients

```css
/* Primary gradient */
background: linear-gradient(135deg, #0A0E27 0%, #1A1B3D 100%);

/* Purple gradient */
background: linear-gradient(135deg, #1A1B3D 0%, #2D1B4E 100%);

/* Mesh gradient (for hero sections) */
background:
  radial-gradient(at 40% 20%, #8B5CF6 0px, transparent 50%),
  radial-gradient(at 80% 0%, #00D4FF 0px, transparent 50%),
  radial-gradient(at 0% 50%, #6366F1 0px, transparent 50%);
```

---

## Spacing

Use Tailwind's standard spacing scale:

| Class | Size |
|-------|------|
| `p-1` / `m-1` | 0.25rem (4px) |
| `p-2` / `m-2` | 0.5rem (8px) |
| `p-3` / `m-3` | 0.75rem (12px) |
| `p-4` / `m-4` | 1rem (16px) |
| `p-6` / `m-6` | 1.5rem (24px) |
| `p-8` / `m-8` | 2rem (32px) |
| `p-12` / `m-12` | 3rem (48px) |

### Container Padding

- Mobile: `px-4`
- Desktop: `px-6` or `px-8`
- Max width: `max-w-7xl mx-auto`

---

## Border Radius

| Class | Size | Usage |
|-------|------|-------|
| `rounded` | 0.25rem | Small elements |
| `rounded-md` | 0.375rem | Buttons, inputs |
| `rounded-lg` | 0.5rem | Cards, modals |
| `rounded-xl` | 0.75rem | Large cards |
| `rounded-2xl` | 1rem | Hero sections |
| `rounded-full` | 50% | Avatars, badges |

---

## Shadows

| Class | Usage |
|-------|-------|
| `shadow-neon` | Primary CTA buttons (hover) |
| `shadow-neon-purple` | Secondary elements |
| `shadow-glow` | Hero elements |

---

## Transitions

Standard transition for all interactive elements:

```html
<element class="transition-all duration-200">
```

For color-only transitions:
```html
<element class="transition-colors duration-200">
```

---

## Scrollbar Styling

```css
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: #1A1B3D;
}

::-webkit-scrollbar-thumb {
  background: rgba(0, 212, 255, 0.5);
  border-radius: 9999px;
}

::-webkit-scrollbar-thumb:hover {
  background: #00D4FF;
}
```

---

## Focus States

All interactive elements should have visible focus states:

```html
<element class="focus:outline-none focus:ring-2 focus:ring-electric-500 focus:ring-offset-2 focus:ring-offset-dark-400">
```

---

## Animations

### Gradient Animation
```css
@keyframes gradient {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}
```

### Float Animation
```css
@keyframes float {
  0%, 100% { transform: translateY(0px); }
  50% { transform: translateY(-20px); }
}
```

### Glow Pulse
```css
@keyframes glow-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.6; }
}
```

---

## Dark Mode Only

This design system is dark-mode only. There is no light mode variant. All colors and effects are optimized for dark backgrounds.

---

## Implementation Notes

1. **CSS Variables**: Use CSS custom properties for easy theming
2. **Tailwind Config**: Extend default theme, don't override
3. **Component Classes**: Use `@apply` sparingly, prefer utility classes
4. **Accessibility**: Ensure color contrast ratios meet WCAG AA standards
5. **Performance**: Use `backdrop-blur` sparingly as it impacts performance

---

## File References

- Tailwind Config: `blocksecops-dashboard/tailwind.config.js`
- Global CSS: `blocksecops-dashboard/src/index.css`
- Source Reference: `blocksecops_com/tailwind.config.ts`
