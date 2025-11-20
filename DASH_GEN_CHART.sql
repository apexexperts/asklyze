-- Ajax callback process called DASH_GEN_CHART
DECLARE
    l_dash_id        NUMBER := :P3_DASH_ID;

    l_title          VARCHAR2(4000);
    l_subtitle       VARCHAR2(4000);
    l_overview       CLOB;

    l_kpis_json      CLOB := '{"kpis": []}';
    l_insights_json  CLOB := '[]';
    l_chart_json     CLOB;           -- IMPORTANT: start as NULL
    l_chart_insights CLOB := '[]';
    l_ai_chart_data  CLOB;
    l_question       VARCHAR2(4000);
    l_out            CLOB;

    PROCEDURE out_json(p CLOB) IS
      pos  PLS_INTEGER := 1;
      len  PLS_INTEGER := DBMS_LOB.getlength(p);
    BEGIN
      owa_util.mime_header('application/json', FALSE);
      owa_util.http_header_close;
      WHILE pos <= len LOOP
        htp.prn(DBMS_LOB.SUBSTR(p, 32767, pos));
        pos := pos + 32767;
      END LOOP;
    END;
BEGIN
    IF l_dash_id IS NULL THEN
      apex_json.initialize_clob_output;
      apex_json.open_object;
        apex_json.write('ok', FALSE);
        apex_json.write('error', 'P3_DASH_ID is NULL');
      apex_json.close_object;
      l_out := apex_json.get_clob_output;
      apex_json.free_output;
      out_json(l_out);
      RETURN;
    END IF;

    -- Dashboard main info
    SELECT d.NAME,
           d.DESCRIPTION
      INTO l_title,
           l_subtitle
      FROM WKSP_AI.DASHBOARDS d
     WHERE d.ID = l_dash_id;

    l_question := NVL(:P3_QUESTION, l_title);

    -- Overview text (TEXT widget "Overview")
    BEGIN
        SELECT json_value(w.VISUAL_OPTIONS, '$.text' RETURNING CLOB)
          INTO l_overview
          FROM WKSP_AI.WIDGETS w
         WHERE w.DASHBOARD_ID = l_dash_id
           AND w.CHART_TYPE   = 'TEXT'
           AND w.TITLE        = 'Overview'
           FETCH FIRST 1 ROW ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- fallback: use dashboard description
            l_overview := l_subtitle;
    END;

    ------------------------------------------------------------------
    -- KPIs: take full VISUAL_OPTIONS JSON from KPI widget
    ------------------------------------------------------------------
    BEGIN
        SELECT w.VISUAL_OPTIONS
          INTO l_kpis_json
          FROM WKSP_AI.WIDGETS w
         WHERE w.DASHBOARD_ID = l_dash_id
           AND w.CHART_TYPE   = 'KPI'
           FETCH FIRST 1 ROW ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_kpis_json := '{"kpis": []}';
    END;

    ------------------------------------------------------------------
    -- Insights: take only the "insights" array from Key Insights widget
    ------------------------------------------------------------------
    BEGIN
        SELECT json_query(
                   w.VISUAL_OPTIONS,
                   '$.insights'
                   RETURNING CLOB PRETTY
               )
          INTO l_insights_json
          FROM WKSP_AI.WIDGETS w
         WHERE w.DASHBOARD_ID = l_dash_id
           AND w.CHART_TYPE   = 'TEXT'
           AND w.TITLE        = 'Key Insights'
           FETCH FIRST 1 ROW ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_insights_json := '[]';
    END;

    ------------------------------------------------------------------
    -- Charts: build up to 4 dynamic charts (existing widgets + AI)
    ------------------------------------------------------------------
    DECLARE
        l_schema VARCHAR2(128) := NVL(:P0_DATABASE_SCHEMA, USER);
        l_cnt    PLS_INTEGER := 0;
        l_needed PLS_INTEGER;
        TYPE t_type_set IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(50);
        l_used_types t_type_set;
        FUNCTION chart_type_from_json(p_json CLOB) RETURN VARCHAR2 IS
          l_type VARCHAR2(50);
        BEGIN
          SELECT JSON_VALUE(
                   p_json,
                   '$.chartType'
                   RETURNING VARCHAR2(50) NULL ON ERROR NULL ON EMPTY
                 )
            INTO l_type
            FROM dual;
          RETURN UPPER(NVL(l_type,''));
        EXCEPTION
          WHEN OTHERS THEN
            RETURN '';
        END chart_type_from_json;
        PROCEDURE append_chart(p_piece CLOB) IS
        BEGIN
          IF l_chart_json IS NULL THEN
            l_chart_json := '{"charts":[' || p_piece;
          ELSE
            l_chart_json := l_chart_json || ',' || p_piece;
          END IF;
        END;
    BEGIN
        l_chart_json := NULL;

        -- 1) Reuse existing CHART widgets (max 4)
        FOR c IN (
            SELECT w.VISUAL_OPTIONS
              FROM WKSP_AI.WIDGETS w
             WHERE w.DASHBOARD_ID = l_dash_id
               AND UPPER(w.CHART_TYPE) IN ('CHART','BAR','LINE','AREA','PIE','DONUT')
             ORDER BY w.ID
             FETCH FIRST 4 ROWS ONLY
        ) LOOP
            DECLARE
              l_type VARCHAR2(50) := chart_type_from_json(c.VISUAL_OPTIONS);
            BEGIN
              IF l_type IS NULL OR l_used_types.EXISTS(l_type) THEN
                CONTINUE;
              END IF;
              l_used_types(l_type) := 1;
              append_chart(c.VISUAL_OPTIONS);
              l_cnt := l_cnt + 1;
            END;
        END LOOP;

        -- 2) Generate extra charts from AI until we have up to 4 unique types
        l_needed := GREATEST(0, 4 - NVL(l_cnt, 0));
        FOR i IN 1 .. (l_needed * 2 + 4) LOOP
            EXIT WHEN l_cnt >= 4;
            l_ai_chart_data  := NULL;
            l_chart_insights := '[]';

            BEGIN
                MYQUERY_DASHBOARD_AI_PKG.generate_chart_with_insights(
                    p_question   => l_question,
                    p_chart_data => l_ai_chart_data,   -- single chart JSON object
                    p_insights   => l_chart_insights,  -- optional insights
                    p_schema     => l_schema
                );
            EXCEPTION
                WHEN OTHERS THEN
                    l_ai_chart_data := NULL;
            END;

            -- Only append if AI returned valid JSON
            IF l_ai_chart_data IS NOT NULL
               AND LENGTH(TRIM(l_ai_chart_data)) > 0
            THEN
                DECLARE
                  l_type VARCHAR2(50) := chart_type_from_json(l_ai_chart_data);
                BEGIN
                  IF l_type IS NULL OR l_used_types.EXISTS(l_type) THEN
                    CONTINUE;
                  END IF;
                  l_used_types(l_type) := 1;
                  append_chart(l_ai_chart_data);
                  l_cnt := l_cnt + 1;
                END;
            END IF;
        END LOOP;

        -- 3) Finalize JSON wrapper or fall back to []
        IF l_chart_json IS NOT NULL THEN
            l_chart_json := l_chart_json || ']}';
        ELSE
            l_chart_json := '[]';
        END IF;
    END;

    ------------------------------------------------------------------
    -- Build JSON response
    ------------------------------------------------------------------
    IF l_chart_json IS NULL THEN
      l_chart_json := TO_CLOB('[]');
    END IF;

    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.write('ok',        TRUE);
      apex_json.write('title',     l_title);
      apex_json.write('subtitle',  l_subtitle);
      apex_json.write('overview',  l_overview);
      apex_json.write('kpis',          l_kpis_json);
      apex_json.write('chartData',     l_chart_json);
      apex_json.write('chartInsights', l_chart_insights);
      apex_json.write('insights',      l_insights_json);
    apex_json.close_object;
    l_out := apex_json.get_clob_output;
    apex_json.free_output;
    out_json(l_out);
EXCEPTION
  WHEN OTHERS THEN
    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.write('ok', FALSE);
      apex_json.write('error', SQLERRM);
    apex_json.close_object;
    l_out := apex_json.get_clob_output;
    apex_json.free_output;
    out_json(l_out);
END;
