# Advanced Blockchain Security - Style Guide

## 🎨 Brand Identity

### Company Information
- **Company Name**: Advanced Blockchain Security
- **Tagline**: "Next-Generation Web3 Scanner Platform"
- **Logo**: 🛡️ (shield emoji) + Company name
- **Industry**: Web3 Security, Smart Contract Analysis
- **Target Audience**: Developers, Security Auditors, DeFi Protocols, Blockchain Companies

## 🎯 Color Palette

### Primary Colors (Baby Blue Palette)
```css
--primary-light: #B8E2F2    /* Lightest blue - Primary text, titles */
--primary-medium: #9DD9F3   /* Light blue - Secondary text, subtitles */
--primary-accent: #89CFF0   /* Medium blue - Logo, CTAs, active states */
--primary-dark: #77C3EC     /* Deeper blue - Gradients, progress bars */
```

### Background Colors
```css
--bg-primary: linear-gradient(135deg, #1a3a52 0%, #2d5a7b 100%)
--bg-sidebar: linear-gradient(180deg, #3d6d8f 0%, #2d5270 100%)
--bg-card: linear-gradient(135deg, rgba(184, 226, 242, 0.2) 0%, rgba(157, 217, 243, 0.1) 100%)
--bg-glass: rgba(137, 207, 240, 0.1)
```

### Semantic Colors
```css
--success: #22c55e     /* Green for success states */
--warning: #eab308     /* Yellow for warnings */
--error: #ef4444       /* Red for errors */
--info: #f97316        /* Orange for info */
```

### Border Colors
```css
--border-primary: #89CFF0
--border-secondary: rgba(137, 207, 240, 0.3)
--border-glass: rgba(255, 255, 255, 0.1)
```

## 📝 Typography

### Font Family
```css
font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
```

### Font Sizes & Weights
```css
/* Headings */
--h1-size: 3.5rem;        /* Hero titles */
--h2-size: 2.5rem;        /* Section titles */
--h3-size: 1.3rem;        /* Card titles */
--tagline-size: 1.5rem;   /* Hero tagline */

/* Body Text */
--body-large: 1.2rem;     /* Hero descriptions */
--body-medium: 1rem;      /* Form inputs, regular text */
--body-small: 0.9rem;     /* Secondary text */
--body-tiny: 0.8rem;      /* Labels, indicators */

/* Font Weights */
--weight-light: 400;
--weight-medium: 500;
--weight-semibold: 600;
--weight-bold: 700;
--weight-extrabold: 800;
```

### Text Colors by Context
```css
/* Primary text colors */
--text-primary: #B8E2F2      /* Main headings, important text */
--text-secondary: #9DD9F3    /* Body text, descriptions */
--text-accent: #89CFF0       /* Links, active states */
--text-muted: rgba(157, 217, 243, 0.7)  /* Placeholder text */
```

## 🎭 Design System Components

### Buttons

#### Primary Button (CTA)
```css
.btn-primary {
    background: linear-gradient(135deg, #89CFF0, #77C3EC);
    color: #1a3a52;
    padding: 1rem 2rem;
    border: none;
    border-radius: 12px;
    font-size: 1.1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
}

.btn-primary:hover {
    transform: translateY(-3px);
    box-shadow: 0 10px 30px rgba(137, 207, 240, 0.4);
}
```

#### Secondary Button
```css
.btn-secondary {
    background: transparent;
    color: #89CFF0;
    padding: 1rem 2rem;
    border: 2px solid #89CFF0;
    border-radius: 12px;
    font-size: 1.1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
}

.btn-secondary:hover {
    background: rgba(137, 207, 240, 0.1);
    transform: translateY(-3px);
}
```

### Cards

#### Standard Card
```css
.card {
    background: linear-gradient(135deg, rgba(184, 226, 242, 0.2) 0%, rgba(157, 217, 243, 0.1) 100%);
    border: 1px solid #89CFF0;
    border-radius: 16px;
    padding: 2rem;
    backdrop-filter: blur(10px);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.card:hover {
    transform: translateY(-5px);
    box-shadow: 0 15px 40px rgba(137, 207, 240, 0.2);
}
```

#### Glass Card (Glassmorphism)
```css
.glass-card {
    background: rgba(137, 207, 240, 0.1);
    backdrop-filter: blur(20px);
    border: 1px solid #89CFF0;
    border-radius: 20px;
}
```

### Form Elements

#### Input Fields
```css
.form-input {
    width: 100%;
    padding: 1rem;
    background: rgba(137, 207, 240, 0.1);
    border: 1px solid #89CFF0;
    border-radius: 8px;
    color: #B8E2F2;
    font-size: 1rem;
    transition: border-color 0.3s ease, box-shadow 0.3s ease;
}

.form-input:focus {
    outline: none;
    border-color: #77C3EC;
    box-shadow: 0 0 0 3px rgba(137, 207, 240, 0.2);
}

.form-input::placeholder {
    color: #9DD9F3;
}
```

#### Labels
```css
.form-label {
    display: block;
    color: #B8E2F2;
    margin-bottom: 0.5rem;
    font-weight: 600;
}
```

### Navigation

#### Header/Navbar
```css
.header {
    position: fixed;
    top: 0;
    background: rgba(137, 207, 240, 0.1);
    backdrop-filter: blur(20px);
    border-bottom: 1px solid #89CFF0;
}

.nav-link {
    color: #9DD9F3;
    text-decoration: none;
    transition: color 0.3s ease;
}

.nav-link:hover {
    color: #89CFF0;
}
```

## 🎬 Animations & Effects

### Standard Animations
```css
/* Hover lift effect */
.hover-lift {
    transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.hover-lift:hover {
    transform: translateY(-3px);
}

/* Floating animation */
@keyframes float {
    0%, 100% { transform: translateY(0px); }
    50% { transform: translateY(-20px); }
}

.float-animation {
    animation: float 6s ease-in-out infinite;
}

/* Pulse animation */
@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}

.pulse-animation {
    animation: pulse 2s infinite;
}
```

### Transition Standards
```css
--transition-fast: 0.2s ease;
--transition-medium: 0.3s ease;
--transition-slow: 0.5s ease;
```

## 📱 Responsive Breakpoints

```css
/* Mobile First Approach */
--breakpoint-sm: 576px;   /* Small devices */
--breakpoint-md: 768px;   /* Medium devices */
--breakpoint-lg: 992px;   /* Large devices */
--breakpoint-xl: 1200px;  /* Extra large devices */
```

### Common Responsive Patterns
```css
/* Grid layouts */
.responsive-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 2rem;
}

/* Mobile adjustments */
@media (max-width: 768px) {
    .hero-title { font-size: 2.5rem; }
    .card { padding: 1.5rem; }
    .form-row { grid-template-columns: 1fr; }
}
```

## 📊 Dashboard-Specific Components

### Status Indicators
```css
.status-healthy {
    background: rgba(34, 197, 94, 0.2);
    color: #22c55e;
    border: 1px solid rgba(34, 197, 94, 0.3);
}
```

### Progress Bars
```css
.loading-progress {
    background: linear-gradient(90deg, #89CFF0, #77C3EC);
    height: 3px;
    border-radius: 2px;
    transition: width 0.3s ease;
}
```

### Result/Alert Items
```css
.result-item.critical { border-left-color: #ef4444; }
.result-item.high { border-left-color: #f97316; }
.result-item.medium { border-left-color: #eab308; }
.result-item.low { border-left-color: #22c55e; }
```

## 🛠️ Technical Implementation

### External Libraries Used
- **Chart.js 3.9.1**: For data visualizations and charts
  ```html
  <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.9.1/chart.min.js"></script>
  ```

### CSS Features Utilized
- CSS Grid for layouts
- Flexbox for component alignment
- CSS Custom Properties (variables)
- Backdrop-filter for glassmorphism
- CSS Animations and Transitions
- Media queries for responsive design

### Browser Support
- Modern browsers supporting CSS Grid, Flexbox, and backdrop-filter
- Graceful degradation for older browsers

## 🔧 Development Guidelines

### Code Organization
1. **CSS Structure**:
   - Reset/Base styles first
   - CSS variables at the top
   - Components organized by section
   - Media queries at the bottom

2. **Class Naming Convention**:
   - Use descriptive, semantic class names
   - Follow BEM methodology where appropriate
   - Use utility classes for common patterns

3. **Performance Considerations**:
   - Minimize use of backdrop-filter (can be performance intensive)
   - Use transform for animations (GPU accelerated)
   - Optimize images and assets

### Accessibility Guidelines
- Ensure proper color contrast ratios
- Include focus states for interactive elements
- Use semantic HTML structure
- Provide alt text for images
- Test with screen readers

## 🎯 Usage Examples

### Page Header Template
```html
<header class="header">
    <nav class="nav">
        <div class="logo">
            🛡️ Advanced Blockchain Security
        </div>
        <ul class="nav-links">
            <li><a href="#" class="nav-link">Features</a></li>
            <li><a href="#" class="nav-link">Pricing</a></li>
        </ul>
        <a href="#" class="cta-button">Get Started</a>
    </nav>
</header>
```

### Standard Form Template
```html
<form class="glass-card">
    <div class="form-group">
        <label class="form-label">Email Address *</label>
        <input type="email" class="form-input" required>
    </div>
    <button type="submit" class="btn-primary">Submit</button>
</form>
```

### Feature Card Template
```html
<div class="card">
    <div class="feature-icon">🛡️</div>
    <h3>Feature Title</h3>
    <p>Feature description text goes here...</p>
</div>
```

## 📋 Content Guidelines

### Voice & Tone
- **Professional yet approachable**
- **Security-focused language**
- **Clear, concise messaging**
- **Technical accuracy without jargon**

### Common Terminology
- Web3 Scanner Platform
- Smart Contract Security
- Blockchain Security Analysis
- Vulnerability Detection
- Security Auditing
- Real-time Monitoring

This style guide ensures consistency across all pages and components of the Advanced Blockchain Security platform.