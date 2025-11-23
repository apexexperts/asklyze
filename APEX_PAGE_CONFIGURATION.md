# Oracle APEX Page Configuration - Performance Dashboard Theme

## Quick Integration Checklist

### 1. Page CSS Files (Page Properties → CSS → File URLs)
```
#APP_FILES#performance-dashboard.css
```

### 2. Page JavaScript Files (Page Properties → JavaScript → File URLs)
```
#APP_FILES#dashboard.js
#APP_FILES#performance-theme-renderer.js
```

### 3. Page Inline CSS (Page Properties → CSS → Inline)
```css
/* Dark theme global styling */
body {
    background-color: #0a0a0a !important;
    color: #ffffff;
}

.t-Body-content,
.t-Region,
.t-Region-body {
    background-color: transparent !important;
    border: none !important;
}

.t-Region-header {
    background-color: #1a1a1a !important;
    border-color: #2a2a2a !important;
    color: #ffffff !important;
}

/* Hide default APEX elements if needed */
.t-BreadcrumbRegion {
    display: none;
}
```

### 4. Page JavaScript Initialization (Execute when Page Loads)
```javascript
// Enable Performance Theme
apex.jQuery(function($) {
    // Activate the performance theme
    window.AUTO_ENABLE_PERFORMANCE_THEME = true;
    window.enablePerformanceTheme();

    // Ensure question input button is styled correctly
    if (typeof ensureQuestionActionButton === 'function') {
        ensureQuestionActionButton();
    }

    // Load existing dashboard if DASH_ID exists
    const dashId = apex.item('P3_DASH_ID').getValue();
    if (dashId) {
        sectionReady.overview = true;
        sectionReady.kpis = true;
        sectionReady.charts = true;
        renderHeaderAndOverview();
    }
});
```

### 5. Page Items Required

Create these page items if they don't exist:

| Item Name | Type | Default Value |
|-----------|------|---------------|
| `P3_QUESTION` | Textarea | (empty) |
| `P3_DASH_ID` | Hidden | (empty) |
| `P3_PLAN_JSON` | Hidden | (empty) |
| `P0_DATABASE_SCHEMA` | Application Item | Your schema name |

### 6. Static Region for Dashboard (Create a Region)

**Region Configuration:**
- **Title**: Dashboard Container
- **Type**: Static Content
- **Template**: Blank with Attributes
- **Static ID**: `mq_dash`

**Region Inline CSS:**
```css
#mq_dash {
    background-color: transparent;
    border: none;
    padding: 0;
}
```

### 7. Question Input Region (Create a Region)

**Region Configuration:**
- **Title**: Ask Question
- **Type**: Form
- **Template**: Blank with Attributes

**Items in Region:**
- `P3_QUESTION` (Textarea)
  - Display As: Textarea
  - Rows: 3
  - Label: (hidden via JavaScript)
  - Placeholder: "Ask your question about the data..."

### 8. AJAX Processes (Create Ajax Callback)

Create these processes with **Process Point** = "Ajax Callback":

| Process Name | PL/SQL Code |
|--------------|-------------|
| `DASH_PLAN` | See DASH_PLAN.sql |
| `DASH_CREATE_BLOCKS` | See DASH_CREATE_BLOCKS.sql |
| `DASH_GEN_OVERVIEW` | See DASH_GEN_OVERVIEW.sql |
| `DASH_GEN_KPIS` | See DASH_GEN_KPIS.sql |
| `DASH_GEN_CHART` | See DASH_GEN_CHART.sql |
| `DASH_FINALIZE` | See DASH_FINALIZE.sql |
| `GET_DASH_META` | See GET_DASH_META.sql |
| `RUN_CHART_SQL` | See RUN_CHART_SQL.sql |

### 9. External JavaScript Libraries (Page Properties → JavaScript → File URLs)

Add these BEFORE your custom JavaScript:

```
https://cdn.jsdelivr.net/npm/apexcharts@latest/dist/apexcharts.min.js
https://unpkg.com/leaflet@1.9.4/dist/leaflet.js
```

### 10. External CSS Libraries (Page Properties → CSS → File URLs)

```
https://unpkg.com/leaflet@1.9.4/dist/leaflet.css
```

## Complete Page JavaScript Template

```javascript
// ============================================================================
// ORACLE APEX - PERFORMANCE DASHBOARD PAGE
// Page: 3 - Dashboard Builder
// ============================================================================

(function() {
    'use strict';

    // Configuration
    const ITEM_Q = "P3_QUESTION";
    const ITEM_PLAN_JSON = "P3_PLAN_JSON";
    const ITEM_DASH_ID = "P3_DASH_ID";
    const REGION_STATIC_ID = "mq_dash";

    // Initialize page
    apex.jQuery(function($) {
        console.log('Initializing Performance Dashboard...');

        // 1. Enable Performance Theme
        window.AUTO_ENABLE_PERFORMANCE_THEME = true;
        if (typeof window.enablePerformanceTheme === 'function') {
            window.enablePerformanceTheme();
        }

        // 2. Setup question input button
        if (typeof ensureQuestionActionButton === 'function') {
            ensureQuestionActionButton();
        }

        // 3. Load existing dashboard if ID present
        const dashId = apex.item(ITEM_DASH_ID).getValue();
        if (dashId) {
            loadExistingDashboard();
        } else {
            showPlaceholder();
        }

        // 4. Setup event listeners
        setupEventListeners();
    });

    function loadExistingDashboard() {
        if (typeof window.sectionReady !== 'undefined') {
            window.sectionReady.overview = true;
            window.sectionReady.kpis = true;
            window.sectionReady.charts = true;
        }

        if (typeof renderHeaderAndOverview === 'function') {
            renderHeaderAndOverview();
        }
    }

    function showPlaceholder() {
        const region = document.getElementById(REGION_STATIC_ID);
        if (!region) return;

        const placeholder = document.createElement('div');
        placeholder.id = 'mqPlaceholder';
        placeholder.style.cssText = `
            margin: 130px auto 12px;
            padding-right: 140px;
            text-align: center;
            color: #a0a0a0;
            font: 15px/1.6 system-ui;
            max-width: 640px;
        `;
        placeholder.innerHTML = `
            <p style="margin: 0 0 8px; font-size: 18px; font-weight: 600;">
                Ready to create your AI-powered dashboard
            </p>
            <p style="margin: 0; font-size: 15px;">
                Enter your question and click "Generate Dashboard" to begin
            </p>
        `;

        if (region.parentElement) {
            region.parentElement.insertBefore(placeholder, region);
        }
    }

    function setupEventListeners() {
        // Add any custom event listeners here
        document.addEventListener('dashboardGenerated', function(e) {
            console.log('Dashboard generated:', e.detail);
            // Apply theme to newly generated dashboard
            if (typeof window.enablePerformanceTheme === 'function') {
                window.enablePerformanceTheme();
            }
        });
    }

    // Expose functions
    window.refreshPerformanceDashboard = function() {
        if (typeof renderHeaderAndOverview === 'function') {
            renderHeaderAndOverview();
        }
    };

})();
```

## Testing Your Implementation

### Test 1: Theme Loads Correctly
1. Navigate to your dashboard page
2. Open browser developer tools (F12)
3. Check Console for: "Performance Theme Renderer loaded"
4. Verify background is dark (#0a0a0a)

### Test 2: Generate a Dashboard
1. Enter a question like: "Show me sales performance by product category"
2. Click the send button
3. Watch the progress indicator
4. Verify dashboard renders with dark theme

### Test 3: Chart Rendering
1. Inspect any chart element
2. Verify ApexCharts options include `theme: { mode: 'dark' }`
3. Check colors match PERF_THEME palette

## Common APEX Application Settings

### Application Definition
- **User Interface**: Universal Theme
- **Theme Style**: Vita
- **Global Page**: 0

### Application Items (Shared Components → Application Items)
```
P0_DATABASE_SCHEMA - Computation: Your schema name
```

### Application Process (Optional - On New Instance)
```sql
BEGIN
    -- Initialize schema for new sessions
    :P0_DATABASE_SCHEMA := 'YOUR_SCHEMA_NAME';
END;
```

## Debugging Tips

### Enable Console Logging
Add to page JavaScript:
```javascript
window.DEBUG_DASHBOARD = true;
```

### Check Theme Status
In browser console:
```javascript
// Check if theme is enabled
console.log('Theme enabled:', window.USE_PERFORMANCE_THEME);

// Check theme config
console.log('Theme config:', window.PERF_THEME);

// Check chart instances
console.log('Charts:', window.mqChartInstances);
```

### Verify AJAX Processes
```javascript
// Test DASH_PLAN process
apex.server.process('DASH_PLAN', {
    pageItems: 'P3_QUESTION,P0_DATABASE_SCHEMA'
}, {
    dataType: 'json',
    success: function(data) {
        console.log('DASH_PLAN response:', data);
    }
});
```

## Mobile Considerations

For mobile devices, add to page inline CSS:
```css
@media (max-width: 768px) {
    .performance-dashboard {
        padding: 12px !important;
    }

    .perf-grid-top {
        grid-template-columns: 1fr !important;
    }

    .perf-kpi-value {
        font-size: 28px !important;
    }
}
```

## Export/Import

To export page configuration:
1. Go to **Application Builder** → **Export**
2. Select your page
3. Export with Supporting Objects
4. Share the export file

## Security

### Recommended Settings
- Enable **Session State Protection** for all items
- Set **Authorization Scheme** for page access
- Use **HTTPS** only
- Enable **Content Security Policy**

---

**You're all set!** 🎉

Your Oracle APEX page is now configured to generate AI-powered dashboards with the Performance Overview dark theme.
