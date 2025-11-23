-- ============================================================================
-- APPLY PERFORMANCE THEME - Oracle APEX Dashboard AI
-- ============================================================================
-- This procedure configures an existing dashboard to use the Performance
-- Overview dark theme layout and styling.
--
-- Usage:
--   BEGIN
--     APPLY_PERFORMANCE_THEME(p_dashboard_id => 123);
--   END;
-- ============================================================================

CREATE OR REPLACE PROCEDURE APPLY_PERFORMANCE_THEME (
    p_dashboard_id  IN NUMBER
) AS
    l_visual_options CLOB;
    l_count NUMBER := 0;
BEGIN
    -- Validate dashboard exists
    SELECT COUNT(*)
    INTO l_count
    FROM DASHBOARDS
    WHERE ID = p_dashboard_id;

    IF l_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Dashboard ID ' || p_dashboard_id || ' not found');
    END IF;

    -- Update dashboard with performance theme metadata
    UPDATE DASHBOARDS
    SET
        VISUAL_THEME = 'PERFORMANCE_DARK',
        COLOR_SCHEME = JSON_OBJECT(
            'background' VALUE '#0a0a0a',
            'cardBg' VALUE '#1a1a1a',
            'cardBorder' VALUE '#2a2a2a',
            'textPrimary' VALUE '#ffffff',
            'textSecondary' VALUE '#a0a0a0',
            'textMuted' VALUE '#666666',
            'accentPurple' VALUE '#a78bfa',
            'accentCyan' VALUE '#22d3ee',
            'accentGreen' VALUE '#10b981',
            'palette' VALUE JSON_ARRAY(
                '#a78bfa', '#22d3ee', '#10b981', '#f59e0b',
                '#ef4444', '#8b5cf6', '#06b6d4', '#14b8a6'
            )
        ),
        UPDATED_AT = SYSTIMESTAMP
    WHERE ID = p_dashboard_id;

    -- Update widgets to use dark theme colors
    FOR widget_rec IN (
        SELECT ID, CHART_TYPE, VISUAL_OPTIONS
        FROM WIDGETS
        WHERE DASHBOARD_ID = p_dashboard_id
    ) LOOP
        l_visual_options := widget_rec.VISUAL_OPTIONS;

        -- Parse and update visual options
        IF l_visual_options IS NOT NULL THEN
            BEGIN
                -- Update colors in visual options JSON
                l_visual_options := JSON_TRANSFORM(
                    l_visual_options,
                    SET '$.theme' = 'dark',
                    SET '$.backgroundColor' = '#1a1a1a',
                    SET '$.textColor' = '#ffffff'
                );
            EXCEPTION
                WHEN OTHERS THEN
                    -- If JSON manipulation fails, create new options
                    l_visual_options := JSON_OBJECT(
                        'theme' VALUE 'dark',
                        'backgroundColor' VALUE '#1a1a1a',
                        'textColor' VALUE '#ffffff',
                        'borderColor' VALUE '#2a2a2a'
                    );
            END;
        ELSE
            -- Create new visual options if none exist
            l_visual_options := JSON_OBJECT(
                'theme' VALUE 'dark',
                'backgroundColor' VALUE '#1a1a1a',
                'textColor' VALUE '#ffffff',
                'borderColor' VALUE '#2a2a2a'
            );
        END IF;

        UPDATE WIDGETS
        SET VISUAL_OPTIONS = l_visual_options
        WHERE ID = widget_rec.ID;
    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Performance theme applied to dashboard ' || p_dashboard_id);
    DBMS_OUTPUT.PUT_LINE('Widgets updated: ' || SQL%ROWCOUNT);

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END APPLY_PERFORMANCE_THEME;
/

-- ============================================================================
-- Function to check if dashboard uses performance theme
-- ============================================================================
CREATE OR REPLACE FUNCTION IS_PERFORMANCE_THEME (
    p_dashboard_id IN NUMBER
) RETURN VARCHAR2 AS
    l_theme VARCHAR2(100);
BEGIN
    SELECT NVL(VISUAL_THEME, 'DEFAULT')
    INTO l_theme
    FROM DASHBOARDS
    WHERE ID = p_dashboard_id;

    RETURN CASE WHEN l_theme = 'PERFORMANCE_DARK' THEN 'TRUE' ELSE 'FALSE' END;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'FALSE';
END IS_PERFORMANCE_THEME;
/

-- ============================================================================
-- Alter DASHBOARDS table to add theme columns (if not exists)
-- ============================================================================
DECLARE
    l_count NUMBER;
BEGIN
    -- Check if VISUAL_THEME column exists
    SELECT COUNT(*)
    INTO l_count
    FROM USER_TAB_COLUMNS
    WHERE TABLE_NAME = 'DASHBOARDS'
    AND COLUMN_NAME = 'VISUAL_THEME';

    IF l_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE DASHBOARDS ADD (
            VISUAL_THEME VARCHAR2(50) DEFAULT ''DEFAULT'',
            COLOR_SCHEME CLOB CONSTRAINT ensure_color_scheme_json CHECK (COLOR_SCHEME IS JSON)
        )';
        DBMS_OUTPUT.PUT_LINE('Added VISUAL_THEME and COLOR_SCHEME columns to DASHBOARDS');
    END IF;
END;
/

-- ============================================================================
-- Sample: Apply performance theme to all dashboards (optional)
-- ============================================================================
-- Uncomment to apply to all existing dashboards:
/*
BEGIN
    FOR dash_rec IN (SELECT ID FROM DASHBOARDS) LOOP
        APPLY_PERFORMANCE_THEME(p_dashboard_id => dash_rec.ID);
    END LOOP;
END;
/
*/

-- ============================================================================
-- Grant execute permissions (adjust as needed for your schema)
-- ============================================================================
-- GRANT EXECUTE ON APPLY_PERFORMANCE_THEME TO WKSP_AI;
-- GRANT EXECUTE ON IS_PERFORMANCE_THEME TO WKSP_AI;
