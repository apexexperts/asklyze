/**
 * Performance Theme Renderer - Dark Theme Extension for Oracle APEX Dashboard
 *
 * This module extends the existing dashboard.js to support rendering
 * AI-generated dashboards in the Performance Overview dark theme style.
 *
 * Features:
 * - Dark theme styling for all chart types
 * - Enhanced KPI card layouts
 * - Horizontal bar charts
 * - Custom color palettes
 * - Responsive grid layouts
 */

(function(apex, $) {
    'use strict';

    // Performance Theme Configuration
    const PERF_THEME = {
        colors: {
            background: '#0a0a0a',
            cardBg: '#1a1a1a',
            cardBorder: '#2a2a2a',
            textPrimary: '#ffffff',
            textSecondary: '#a0a0a0',
            textMuted: '#666666',
            accentPurple: '#a78bfa',
            accentCyan: '#22d3ee',
            accentGreen: '#10b981',
            hoverBg: '#252525'
        },
        palette: [
            '#a78bfa', // Purple
            '#22d3ee', // Cyan
            '#10b981', // Green
            '#f59e0b', // Amber
            '#ef4444', // Red
            '#8b5cf6', // Violet
            '#06b6d4', // Cyan-600
            '#14b8a6', // Teal
            '#f97316', // Orange
            '#ec4899'  // Pink
        ]
    };

    /**
     * Apply dark theme styling to dashboard container
     */
    function applyPerformanceTheme() {
        const dashboardContainer = document.getElementById('mq_dash') ||
                                   document.querySelector('.mq-card') ||
                                   document.body;

        if (dashboardContainer) {
            dashboardContainer.style.backgroundColor = PERF_THEME.colors.background;
            dashboardContainer.style.color = PERF_THEME.colors.textPrimary;
            dashboardContainer.style.padding = '24px';
            dashboardContainer.style.minHeight = '100vh';
        }

        // Apply to parent if exists
        const parent = dashboardContainer.parentElement;
        if (parent && parent.classList.contains('t-Region-body')) {
            parent.style.backgroundColor = PERF_THEME.colors.background;
        }
    }

    /**
     * Enhanced KPI card renderer with dark theme
     */
    function renderKPICardDark(kpi, container) {
        const card = document.createElement('div');
        card.className = 'perf-kpi-card';
        card.style.cssText = `
            background-color: ${PERF_THEME.colors.cardBg};
            border: 1px solid ${PERF_THEME.colors.cardBorder};
            border-radius: 12px;
            padding: 20px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        `;

        const color = kpi.color || PERF_THEME.palette[0];

        card.innerHTML = `
            <div class="perf-kpi-label" style="
                font-size: 14px;
                color: ${PERF_THEME.colors.textSecondary};
                font-weight: 500;
                margin-bottom: 8px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            ">${escapeHTML(kpi.title || '')}</div>
            <div class="perf-kpi-value" style="
                font-size: 36px;
                font-weight: 700;
                color: ${color};
                margin-bottom: 8px;
                line-height: 1;
            ">${escapeHTML(formatKpiValue(kpi))}</div>
            ${kpi.subtitle ? `
                <div class="perf-kpi-meta" style="
                    font-size: 12px;
                    color: ${PERF_THEME.colors.textMuted};
                    margin-top: 4px;
                ">${escapeHTML(kpi.subtitle)}</div>
            ` : ''}
        `;

        // Hover effects
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-2px)';
            this.style.boxShadow = '0 8px 25px rgba(0,0,0,0.3)';
            this.style.borderColor = color;
        });

        card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0)';
            this.style.boxShadow = 'none';
            this.style.borderColor = PERF_THEME.colors.cardBorder;
        });

        container.appendChild(card);
    }

    /**
     * Render horizontal bar chart (for supplier defects, customer top 5, etc.)
     */
    function renderHorizontalBarChart(container, data, config) {
        const chartCard = document.createElement('div');
        chartCard.className = 'perf-chart-card';
        chartCard.style.cssText = `
            background-color: ${PERF_THEME.colors.cardBg};
            border: 1px solid ${PERF_THEME.colors.cardBorder};
            border-radius: 12px;
            padding: 20px;
        `;

        // Header
        const header = document.createElement('div');
        header.style.marginBottom = '16px';
        header.innerHTML = `
            <div style="
                font-size: 16px;
                font-weight: 600;
                color: ${PERF_THEME.colors.textPrimary};
                margin-bottom: 4px;
            ">${escapeHTML(config.title || 'Chart')}</div>
            ${config.subtitle ? `
                <div style="
                    font-size: 12px;
                    color: ${PERF_THEME.colors.textSecondary};
                ">${escapeHTML(config.subtitle)}</div>
            ` : ''}
        `;
        chartCard.appendChild(header);

        // Create horizontal bars
        const barsContainer = document.createElement('div');
        barsContainer.style.cssText = 'display: flex; flex-direction: column; gap: 12px; padding: 12px 0;';

        const maxValue = Math.max(...data.map(d => d.value || 0));

        data.forEach((item, idx) => {
            const barItem = document.createElement('div');
            barItem.style.cssText = 'display: flex; align-items: center; gap: 12px;';

            const label = document.createElement('div');
            label.style.cssText = `
                min-width: 150px;
                font-size: 13px;
                color: ${PERF_THEME.colors.textSecondary};
                text-align: right;
            `;
            label.textContent = item.label || '';

            const barContainer = document.createElement('div');
            barContainer.style.cssText = 'flex: 1; position: relative;';

            const barBg = document.createElement('div');
            barBg.style.cssText = `
                background-color: rgba(167, 139, 250, 0.1);
                border-radius: 4px;
                height: 28px;
                position: relative;
                overflow: hidden;
            `;

            const barFill = document.createElement('div');
            const percent = (item.value / maxValue) * 100;
            barFill.style.cssText = `
                background: linear-gradient(90deg, ${PERF_THEME.palette[idx % PERF_THEME.palette.length]}, ${PERF_THEME.palette[(idx + 1) % PERF_THEME.palette.length]});
                height: 100%;
                width: 0%;
                border-radius: 4px;
                transition: width 0.8s ease;
            `;

            const barValue = document.createElement('div');
            barValue.style.cssText = `
                position: absolute;
                right: 8px;
                top: 50%;
                transform: translateY(-50%);
                font-size: 12px;
                font-weight: 600;
                color: ${PERF_THEME.colors.textPrimary};
                z-index: 1;
            `;
            barValue.textContent = item.value;

            barBg.appendChild(barFill);
            barBg.appendChild(barValue);
            barContainer.appendChild(barBg);

            barItem.appendChild(label);
            barItem.appendChild(barContainer);
            barsContainer.appendChild(barItem);

            // Animate bar fill
            setTimeout(() => {
                barFill.style.width = percent + '%';
            }, 100 + (idx * 100));
        });

        chartCard.appendChild(barsContainer);
        container.appendChild(chartCard);
    }

    /**
     * Enhanced ApexCharts options with dark theme
     */
    function getDarkThemeChartOptions(type, labels, series, config) {
        const baseOptions = {
            chart: {
                type: type,
                height: 320,
                background: 'transparent',
                toolbar: { show: false },
                foreColor: PERF_THEME.colors.textSecondary
            },
            theme: {
                mode: 'dark'
            },
            colors: PERF_THEME.palette,
            grid: {
                borderColor: PERF_THEME.colors.cardBorder,
                strokeDashArray: 4,
                xaxis: {
                    lines: { show: false }
                }
            },
            xaxis: {
                categories: labels,
                labels: {
                    style: {
                        colors: PERF_THEME.colors.textSecondary,
                        fontSize: '11px'
                    }
                },
                axisBorder: {
                    show: true,
                    color: PERF_THEME.colors.cardBorder
                },
                axisTicks: {
                    show: true,
                    color: PERF_THEME.colors.cardBorder
                }
            },
            yaxis: {
                labels: {
                    style: {
                        colors: PERF_THEME.colors.textSecondary,
                        fontSize: '11px'
                    }
                }
            },
            tooltip: {
                theme: 'dark',
                style: {
                    fontSize: '12px'
                }
            },
            legend: {
                labels: {
                    colors: PERF_THEME.colors.textSecondary
                },
                fontSize: '12px'
            },
            dataLabels: {
                style: {
                    colors: ['#fff']
                }
            }
        };

        // Type-specific options
        if (type === 'bar') {
            baseOptions.plotOptions = {
                bar: {
                    borderRadius: 4,
                    columnWidth: '60%',
                    horizontal: config.horizontal || false
                }
            };
        } else if (type === 'donut' || type === 'pie') {
            baseOptions.labels = labels;
            baseOptions.plotOptions = {
                pie: {
                    donut: {
                        size: type === 'donut' ? '65%' : undefined,
                        labels: {
                            show: false
                        }
                    }
                }
            };
            baseOptions.stroke = {
                show: false
            };
        } else if (type === 'line' || type === 'area') {
            baseOptions.stroke = {
                curve: 'smooth',
                width: 2
            };
            if (type === 'area') {
                baseOptions.fill = {
                    type: 'gradient',
                    gradient: {
                        shadeIntensity: 1,
                        opacityFrom: 0.4,
                        opacityTo: 0.1
                    }
                };
            }
        }

        baseOptions.series = series;
        return baseOptions;
    }

    /**
     * Override renderChartSection to apply dark theme
     */
    const originalRenderChartSection = window.renderChartSection;
    window.renderChartSection = function(meta, useDarkTheme) {
        // Apply dark theme if enabled
        if (useDarkTheme === true || window.USE_PERFORMANCE_THEME === true) {
            applyPerformanceTheme();
            renderChartSectionDark(meta);
        } else {
            // Use original renderer
            if (typeof originalRenderChartSection === 'function') {
                originalRenderChartSection(meta);
            }
        }
    };

    /**
     * Dark theme chart section renderer
     */
    function renderChartSectionDark(meta) {
        const container = document.getElementById("mq_chart") ||
                         document.querySelector("#mq_dash .mq-chart-section") ||
                         document.getElementById("mq_dash");

        if (!container) {
            console.warn("Chart container not found");
            return;
        }

        container.innerHTML = '';
        container.style.backgroundColor = 'transparent';

        const chartDataRaw = meta.chartData || meta.chart_data || meta.charts || null;
        if (!chartDataRaw) {
            container.innerHTML = '<div style="color: ' + PERF_THEME.colors.textSecondary + '; padding: 20px;">No chart data available</div>';
            return;
        }

        let chartConfig;
        try {
            chartConfig = typeof chartDataRaw === 'string' ? JSON.parse(chartDataRaw) : chartDataRaw;
        } catch (e) {
            console.error("Invalid chartData JSON", e);
            return;
        }

        const chartsArray = Array.isArray(chartConfig) ? chartConfig :
                           (Array.isArray(chartConfig.charts) ? chartConfig.charts : []);

        if (!chartsArray.length) {
            return;
        }

        // Create grid container
        const grid = document.createElement('div');
        grid.style.cssText = `
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 16px;
            margin-top: 8px;
        `;
        container.appendChild(grid);

        // Render each chart
        chartsArray.forEach((chart, idx) => {
            const chartType = (chart.chartType || chart.type || 'bar').toLowerCase();

            // Create chart card
            const chartCard = document.createElement('div');
            chartCard.style.cssText = `
                background-color: ${PERF_THEME.colors.cardBg};
                border: 1px solid ${PERF_THEME.colors.cardBorder};
                border-radius: 12px;
                padding: 20px;
                transition: all 0.3s ease;
            `;

            chartCard.addEventListener('mouseenter', function() {
                this.style.boxShadow = '0 8px 25px rgba(0,0,0,0.3)';
            });

            chartCard.addEventListener('mouseleave', function() {
                this.style.boxShadow = 'none';
            });

            // Chart header
            const header = document.createElement('div');
            header.style.marginBottom = '16px';
            header.innerHTML = `
                <div style="
                    font-size: 16px;
                    font-weight: 600;
                    color: ${PERF_THEME.colors.textPrimary};
                    margin-bottom: 4px;
                ">${escapeHTML(chart.title || 'Chart ' + (idx + 1))}</div>
                ${chart.subtitle ? `
                    <div style="
                        font-size: 12px;
                        color: ${PERF_THEME.colors.textSecondary};
                    ">${escapeHTML(chart.subtitle)}</div>
                ` : ''}
            `;
            chartCard.appendChild(header);

            // Chart container
            const chartDiv = document.createElement('div');
            chartDiv.id = 'perf_chart_' + (idx + 1);
            chartDiv.style.height = '320px';
            chartCard.appendChild(chartDiv);

            grid.appendChild(chartCard);

            // Render chart based on type
            if (typeof ApexCharts !== 'undefined') {
                const labels = chart.labels || [];
                const series = chart.series || chart.data || [];
                const options = getDarkThemeChartOptions(chartType, labels, series, chart);

                const apexChart = new ApexCharts(chartDiv, options);
                apexChart.render();

                if (typeof mqChartInstances !== 'undefined') {
                    mqChartInstances.push(apexChart);
                }
            }
        });
    }

    /**
     * Enhanced KPI renderer with dark theme
     */
    window.renderKPISection = function(kpisData) {
        const container = document.getElementById('mqKpiSection');
        if (!container || !kpisData || !kpisData.length) {
            return;
        }

        container.innerHTML = '';
        container.style.cssText = `
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-bottom: 16px;
        `;

        kpisData.forEach(kpi => {
            renderKPICardDark(kpi, container);
        });
    };

    /**
     * Enable/Disable Performance Theme
     */
    window.enablePerformanceTheme = function() {
        window.USE_PERFORMANCE_THEME = true;
        applyPerformanceTheme();

        // Re-render if dashboard already exists
        const dashId = apex.item('P3_DASH_ID') ? apex.item('P3_DASH_ID').getValue() : null;
        if (dashId && typeof renderHeaderAndOverview === 'function') {
            renderHeaderAndOverview();
        }
    };

    window.disablePerformanceTheme = function() {
        window.USE_PERFORMANCE_THEME = false;
    };

    // Utility functions
    function escapeHTML(txt) {
        return txt == null ? '' : String(txt)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
    }

    function formatKpiValue(kpi) {
        const raw = kpi.value != null ? String(kpi.value) : '';
        const unit = (kpi.unit || '').toLowerCase();
        if (!unit) return raw;
        if (unit === 'currency') return raw;
        if (unit === '%') return raw + '%';
        return raw + ' ' + kpi.unit;
    }

    // Auto-enable if configured
    if (window.AUTO_ENABLE_PERFORMANCE_THEME === true) {
        window.enablePerformanceTheme();
    }

    // Expose theme config
    window.PERF_THEME = PERF_THEME;

    console.log('Performance Theme Renderer loaded');

})(apex, apex.jQuery);
