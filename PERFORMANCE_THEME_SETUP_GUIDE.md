# Performance Overview Dashboard Theme - Setup Guide

This guide explains how to integrate the Performance Overview dark theme into your Oracle APEX AI Dashboard Builder.

## 📋 Overview

The Performance Overview theme provides:
- **Dark theme styling** with modern color palette
- **Enhanced KPI cards** with hover effects and animations
- **Horizontal bar charts** for top N comparisons
- **Donut charts** for distribution analysis
- **Revenue trend comparisons** with multi-series support
- **Responsive grid layouts** that adapt to screen size
- **Dynamic AI-driven generation** based on user questions

## 📁 Files Created

1. **performance-dashboard.css** - Dark theme styles
2. **performance-theme-renderer.js** - JavaScript extensions for rendering
3. **performance-dashboard-template.html** - Reference HTML template
4. **APPLY_PERFORMANCE_THEME.sql** - Database procedures for theme application

## 🚀 Installation Steps

### Step 1: Upload CSS File to Oracle APEX

1. Navigate to **Shared Components** → **Static Application Files**
2. Click **Create File**
3. Upload `performance-dashboard.css`
4. Note the reference path (e.g., `#APP_FILES#performance-dashboard.css`)

### Step 2: Upload JavaScript File

1. In **Shared Components** → **Static Application Files**
2. Upload `performance-theme-renderer.js`
3. Note the reference path (e.g., `#APP_FILES#performance-theme-renderer.js`)

### Step 3: Configure Page to Use Performance Theme

#### Option A: Global Application Configuration (Recommended)

1. Go to **Shared Components** → **User Interface Attributes**
2. Under **JavaScript** → **File URLs**, add:
   ```
   #APP_FILES#performance-theme-renderer.js
   ```
3. Under **CSS** → **File URLs**, add:
   ```
   #APP_FILES#performance-dashboard.css
   ```
4. Under **JavaScript** → **Execute when Page Loads**, add:
   ```javascript
   // Enable Performance Theme globally
   window.AUTO_ENABLE_PERFORMANCE_THEME = true;
   ```

#### Option B: Per-Page Configuration

For specific dashboard pages:

1. Go to your dashboard page (e.g., Page 3)
2. In **Page Properties** → **CSS** → **File URLs**, add:
   ```
   #APP_FILES#performance-dashboard.css
   ```
3. In **JavaScript** → **File URLs**, add:
   ```
   #APP_FILES#performance-theme-renderer.js
   ```
4. In **JavaScript** → **Execute when Page Loads**, add:
   ```javascript
   // Enable Performance Theme for this page
   apex.jQuery(function() {
       window.enablePerformanceTheme();
   });
   ```

### Step 4: Execute SQL Scripts

Connect to your Oracle database and run:

```sql
-- Connect as your APEX workspace schema
-- e.g., ALTER SESSION SET CURRENT_SCHEMA = WKSP_AI;

@APPLY_PERFORMANCE_THEME.sql
```

This will:
- Add `VISUAL_THEME` and `COLOR_SCHEME` columns to DASHBOARDS table
- Create `APPLY_PERFORMANCE_THEME` procedure
- Create `IS_PERFORMANCE_THEME` function

### Step 5: Modify Page Body HTML (Optional)

If you want the dark theme to apply to the entire page:

1. Go to your dashboard page
2. In **Page Properties** → **CSS** → **Inline**, add:
   ```css
   body {
       background-color: #0a0a0a !important;
   }

   .t-Body-content,
   .t-Region,
   .t-Region-body {
       background-color: transparent !important;
   }
   ```

## 🎨 Usage Examples

### Example 1: Enable Theme for Specific Dashboard

```sql
BEGIN
    -- Apply performance theme to dashboard ID 123
    APPLY_PERFORMANCE_THEME(p_dashboard_id => 123);
END;
/
```

### Example 2: Enable Theme Programmatically via JavaScript

```javascript
// In your page JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Enable the performance theme
    window.enablePerformanceTheme();

    // Generate dashboard with theme
    if (typeof window.runDashboardBuilder === 'function') {
        window.runDashboardBuilder();
    }
});
```

### Example 3: Toggle Theme On/Off

```javascript
// Enable dark theme
window.enablePerformanceTheme();

// Disable dark theme (revert to default)
window.disablePerformanceTheme();
```

### Example 4: Check if Dashboard Uses Performance Theme

```sql
-- Check if dashboard uses performance theme
SELECT IS_PERFORMANCE_THEME(123) FROM DUAL;
-- Returns: 'TRUE' or 'FALSE'
```

## 🔧 Customization

### Modify Color Palette

Edit `performance-theme-renderer.js` and update the `PERF_THEME` object:

```javascript
const PERF_THEME = {
    colors: {
        background: '#0a0a0a',      // Main background
        cardBg: '#1a1a1a',          // Card background
        cardBorder: '#2a2a2a',      // Card borders
        textPrimary: '#ffffff',     // Primary text
        textSecondary: '#a0a0a0',   // Secondary text
        accentPurple: '#a78bfa',    // Accent color 1
        accentCyan: '#22d3ee',      // Accent color 2
        // ... modify as needed
    },
    palette: [
        '#a78bfa',  // Purple - Change these colors
        '#22d3ee',  // Cyan
        '#10b981',  // Green
        // ... add more colors
    ]
};
```

### Customize Chart Appearance

The theme automatically applies dark styling to all ApexCharts. To customize:

```javascript
// In performance-theme-renderer.js, modify getDarkThemeChartOptions()
function getDarkThemeChartOptions(type, labels, series, config) {
    const baseOptions = {
        chart: {
            // Your custom chart options
            fontFamily: 'Inter, sans-serif',  // Custom font
            // ...
        },
        // ...
    };
    return baseOptions;
}
```

### Modify Grid Layout

Update the grid template in the CSS file:

```css
/* In performance-dashboard.css */
.perf-grid-top {
  display: grid;
  /* Change column layout */
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
}
```

## 🎯 AI Generation Configuration

To have the AI automatically use this theme for generated dashboards:

### Update DASH_CREATE_BLOCKS Process

Add theme parameter when creating dashboards:

```sql
-- In DASH_CREATE_BLOCKS.sql or similar
INSERT INTO DASHBOARDS (
    NAME,
    DESCRIPTION,
    OWNER_USER_ID,
    VISUAL_THEME,  -- Add this
    CREATED_AT
) VALUES (
    l_title,
    l_description,
    l_user_id,
    'PERFORMANCE_DARK',  -- Use performance theme
    SYSTIMESTAMP
);
```

### Modify AI Prompts for Chart Generation

In `DASH_GEN_CHART.sql` or your chart generation logic, add instructions to the AI:

```sql
l_prompt := 'Generate a modern dashboard with the following requirements:
- Use dark theme with purple and cyan accent colors
- Create horizontal bar charts for top N comparisons
- Use donut charts for percentage distributions
- Include KPI cards with large values and supporting metrics
- Arrange in responsive grid layout
- Chart types available: bar, line, area, pie, donut, horizontal_bar

User question: ' || p_question || '
Schema: ' || l_schema;
```

## 📊 Supported Chart Types

The performance theme supports:

| Chart Type | Use Case | Example |
|------------|----------|---------|
| **KPI Card** | Single metric display | Total Cost: $52,925 |
| **Horizontal Bar** | Top N comparisons | Top 5 Customers |
| **Donut Chart** | Distribution % | Defect rates by inspection |
| **Bar Chart** | Category comparison | Revenue by month |
| **Line Chart** | Trends over time | Sales trend |
| **Area Chart** | Cumulative trends | Revenue growth |
| **Table** | Detailed data | Transaction list |
| **Map** | Geographic data | Revenue by location |

## 🐛 Troubleshooting

### Theme Not Applying

**Issue**: Dashboard still shows default theme

**Solutions**:
1. Clear browser cache and reload
2. Verify CSS and JS files are uploaded correctly
3. Check browser console for JavaScript errors
4. Ensure `window.enablePerformanceTheme()` is called

### Charts Not Rendering in Dark Theme

**Issue**: Charts appear with default colors

**Solutions**:
1. Verify ApexCharts library is loaded before `performance-theme-renderer.js`
2. Check that `USE_PERFORMANCE_THEME` is set to true
3. Inspect chart options in browser developer tools

### Layout Breaking on Mobile

**Issue**: Grid layout not responsive

**Solutions**:
1. Verify CSS media queries are loaded
2. Check viewport meta tag in page template
3. Test with different screen sizes in browser dev tools

## 📱 Responsive Breakpoints

The theme includes responsive breakpoints:

- **Desktop** (1400px+): Full grid layout with all columns
- **Laptop** (1024px-1400px): 2-column grid for main sections
- **Tablet** (768px-1024px): Single column for most sections
- **Mobile** (< 768px): Full single column layout

## 🔒 Security Considerations

1. **CSS Injection**: The CSS file is static and uploaded to APEX - no user input
2. **XSS Prevention**: All dynamic content uses `escapeHTML()` function
3. **SQL Injection**: All database procedures use bind variables
4. **Access Control**: Theme application respects APEX authentication

## 📈 Performance Optimization

1. **Lazy Loading**: Charts render progressively
2. **Debouncing**: Hover effects use CSS transitions (hardware accelerated)
3. **Minimal Reflows**: Grid layouts use CSS Grid (efficient)
4. **Cached Styles**: CSS loaded once and cached by browser

## 🔄 Version History

- **v1.0** - Initial release with dark theme support
- **v1.1** - Added horizontal bar charts and donut charts
- **v1.2** - Responsive grid layouts
- **v1.3** - AI prompt integration for automatic theme generation

## 📞 Support

For issues or questions:
1. Check browser console for errors
2. Review APEX page error logs
3. Verify SQL scripts executed successfully
4. Test with a simple static example first

## 🎉 Next Steps

After setup:

1. **Test with sample data**: Create a test dashboard to verify theme works
2. **Customize colors**: Adjust palette to match your brand
3. **Train AI**: Update prompts to generate themed dashboards automatically
4. **Create templates**: Save successful layouts as templates
5. **Monitor performance**: Check dashboard load times and optimize

---

**Ready to generate stunning dashboards!** 🚀

Try asking the AI:
- "Show me performance metrics for sales data"
- "Create a dashboard comparing product categories"
- "Analyze customer revenue trends year over year"

The AI will automatically generate dashboards with the Performance Overview theme!
