-- Ajax callback process called GET_DASH_META
DECLARE
    l_dash_id        NUMBER := :P3_DASH_ID;

    l_title          VARCHAR2(4000);
    l_subtitle       VARCHAR2(4000);
    l_overview       CLOB;

    l_kpis_json      CLOB := '{"kpis": []}';
    l_insights_json  CLOB := '[]';
    l_chart_json     CLOB;           -- will hold {"charts":[ ... ]}
    l_chart_insights CLOB := '[]';
    l_question       VARCHAR2(4000);
    l_out            CLOB;
    l_need_kpi_refresh BOOLEAN := FALSE;

    PROCEDURE out_json(p CLOB) IS
      pos PLS_INTEGER := 1;
      len PLS_INTEGER := DBMS_LOB.getlength(p);
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
            l_overview := l_subtitle;
    END;

    ------------------------------------------------------------------
    -- KPIs: full VISUAL_OPTIONS JSON from KPI widget
    ------------------------------------------------------------------
    BEGIN
        SELECT w.VISUAL_OPTIONS
          INTO l_kpis_json
          FROM WKSP_AI.WIDGETS w
         WHERE w.DASHBOARD_ID = l_dash_id
           AND UPPER(w.CHART_TYPE) = 'KPI'
           FETCH FIRST 1 ROW ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_kpis_json := '{"kpis": []}';
            l_need_kpi_refresh := TRUE;
    END;

    IF l_kpis_json IS NULL
       OR DBMS_LOB.getlength(l_kpis_json) = 0
       OR NOT JSON_EXISTS(l_kpis_json, '$.kpis[0]') THEN
        l_need_kpi_refresh := TRUE;
        BEGIN
            MYQUERY_DASHBOARD_AI_PKG.generate_kpi_blocks(
                p_question => l_question,
                p_kpis     => l_kpis_json,
                p_schema   => NVL(:P0_DATABASE_SCHEMA, USER)
            );
        EXCEPTION
            WHEN OTHERS THEN
                l_kpis_json := NULL;
        END;
        IF l_kpis_json IS NULL
           OR DBMS_LOB.getlength(l_kpis_json) = 0
           OR NOT JSON_EXISTS(l_kpis_json, '$.kpis[0]') THEN
            l_kpis_json := '{"kpis": []}';
            l_need_kpi_refresh := FALSE;
        END IF;
    END IF;

    IF l_need_kpi_refresh THEN
        DECLARE
            v_first      BOOLEAN := TRUE;
            v_final      CLOB := '{"kpis":[';
            v_value      NUMBER;
            v_value_str  VARCHAR2(100);
        BEGIN
            FOR r IN (
                SELECT jt.title,
                       jt.sql_text,
                       jt.unit,
                       jt.icon,
                       jt.color
                  FROM JSON_TABLE(
                         l_kpis_json,
                         '$.kpis[*]'
                         COLUMNS (
                           title    VARCHAR2(200)  PATH '$.title',
                           sql_text VARCHAR2(4000) PATH '$.sql',
                           unit     VARCHAR2(50)   PATH '$.unit',
                           icon     VARCHAR2(50)   PATH '$.icon',
                           color    VARCHAR2(50)   PATH '$.color'
                         )
                       ) jt
            ) LOOP
                IF r.sql_text IS NOT NULL AND LENGTH(TRIM(r.sql_text)) > 0 THEN
                    BEGIN
                        EXECUTE IMMEDIATE r.sql_text INTO v_value;
                        v_value_str := TO_CHAR(v_value, 'FM999G999G999G990D00');
                    EXCEPTION
                        WHEN OTHERS THEN
                            apex_debug.message('GET_DASH_META KPI SQL failed: %s', SQLERRM);
                            v_value_str := 'N/A';
                    END;
                ELSE
                    v_value_str := 'N/A';
                END IF;

                IF NOT v_first THEN
                    v_final := v_final || ',';
                END IF;
                v_first := FALSE;

                v_final := v_final ||
                  '{"title":"' || REPLACE(NVL(r.title,''), '"','\"') || '",'||
                  '"value":"' || REPLACE(NVL(v_value_str,'N/A'),'"','\"') || '",'||
                  '"unit":"'  || REPLACE(NVL(r.unit,''),'"','\"') || '",'||
                  '"icon":"'  || REPLACE(NVL(r.icon,''),'"','\"') || '",'||
                  '"color":"' || REPLACE(NVL(r.color,''),'"','\"') || '"}';
            END LOOP;

            IF v_first THEN
                l_kpis_json := '{"kpis": []}';
            ELSE
                l_kpis_json := v_final || ']}';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                apex_debug.message('GET_DASH_META KPI fallback failed: %s', SQLERRM);
                l_kpis_json := '{"kpis": []}';
        END;
    END IF;

    ------------------------------------------------------------------
    -- Insights: "insights" array from Key Insights widget
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
    -- Charts: load persisted widgets if available, otherwise generate
    ------------------------------------------------------------------
    BEGIN
        SELECT JSON_ARRAYAGG(
                 w.visual_options FORMAT JSON
                 ORDER BY w.grid_y, w.id
               )
          INTO l_chart_json
          FROM WKSP_AI.WIDGETS w
         WHERE w.DASHBOARD_ID = l_dash_id
           AND w.VISUAL_OPTIONS IS NOT NULL
           AND NVL(UPPER(w.CHART_TYPE), 'X') IN (
                 'CHART','BAR','LINE','AREA','PIE','DONUT','DOUGHNUT','MAP','TABLE','RADIALBAR','RADIAL_BAR','SCATTER'
               );

        IF l_chart_json IS NOT NULL THEN
            l_chart_json := '{"charts":' || l_chart_json || '}';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            l_chart_json := NULL;
            apex_debug.message('GET_DASH_META chart load failed: %s', SQLERRM);
    END;

    IF l_chart_json IS NULL THEN
        DECLARE
            l_schema        VARCHAR2(128) := NVL(:P0_DATABASE_SCHEMA, USER);
            l_base_prompt   CLOB;
            l_chart_prompt  CLOB;
            l_chart_piece   CLOB;
            l_dummy_ins     CLOB;
            l_has_geo       BOOLEAN       := FALSE;
            l_geo_table     VARCHAR2(128);
            l_geo_lat_col   VARCHAR2(128);
            l_geo_lon_col   VARCHAR2(128);
            c_total_charts  CONSTANT PLS_INTEGER := 6;
            TYPE t_type_set IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(50);
            l_used_types    t_type_set;
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
              RETURN UPPER(NVL(l_type, ''));
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

            l_base_prompt :=
                   l_question
                || ' | IMPORTANT: Use only real data from schema '
                || l_schema
                || '. Generate valid SELECT SQL queries against these tables. '
                || 'Do not invent or hardcode any sample values or dummy series.';

            BEGIN
                SELECT lat.table_name,
                       lat.column_name AS lat_col,
                       lon.column_name AS lon_col
                  INTO l_geo_table,
                       l_geo_lat_col,
                       l_geo_lon_col
                  FROM all_tab_columns lat
                  JOIN all_tab_columns lon
                    ON     lat.owner = lon.owner
                       AND lat.table_name = lon.table_name
                 WHERE lat.owner = UPPER(l_schema)
                   AND lon.owner = UPPER(l_schema)
                   AND REGEXP_LIKE(lat.column_name, '(^|_)LAT(ITUDE)?(_|$)')
                   AND REGEXP_LIKE(lon.column_name, '(^|_)LON(GITUDE)?(_|$)')
                   AND ROWNUM = 1;
                l_has_geo := TRUE;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    l_has_geo := FALSE;
            END;

            FOR i IN 1 .. c_total_charts LOOP
                l_chart_piece := NULL;
                l_dummy_ins   := NULL;

                CASE i
                    WHEN 1 THEN
                        l_chart_prompt :=
                            l_base_prompt
                            || ' Focus this chart on a time-based trend (for example monthly or daily performance) '
                            || 'and prefer a LINE chart if a date or period column is available.';
                    WHEN 2 THEN
                        l_chart_prompt :=
                            l_base_prompt
                            || ' Focus this chart on ranking or comparison across a key dimension '
                            || '(such as product, category, or region) and prefer a BAR chart.';
                    WHEN 3 THEN
                        l_chart_prompt :=
                            l_base_prompt
                            || ' Focus this chart on cumulative or running totals over time and prefer an AREA chart.';
                    WHEN 4 THEN
                        l_chart_prompt :=
                            l_base_prompt
                            || ' Focus this chart on percentage contribution / share by category '
                            || 'and prefer a DONUT chart (or PIE chart if needed).';
                    WHEN 5 THEN
                        l_chart_prompt :=
                            l_base_prompt
                            || ' Surface any outliers or anomalies by comparing actuals vs averages. '
                            || 'Return a TABLE chart that lists the top records contributing to the question.';
                    WHEN 6 THEN
                        IF l_has_geo THEN
                            l_chart_prompt :=
                                l_base_prompt
                                || ' Highlight the geographic distribution of the metric using a MAP chart. '
                                || 'Use table '||l_geo_table||' and the actual latitude column '
                                || l_geo_table||'.'||l_geo_lat_col||' plus longitude column '
                                || l_geo_table||'.'||l_geo_lon_col||'. '
                                || 'SQL must return LOCATION_NAME, LATITUDE, LONGITUDE, VALUE columns (in that order) with real aggregates.';
                        ELSE
                            l_chart_prompt :=
                                l_base_prompt
                                || ' Provide another complementary perspective such as comparing two related measures across a key dimension and prefer a BAR chart.';
                        END IF;
                END CASE;

                BEGIN
                    MYQUERY_DASHBOARD_AI_PKG.generate_chart_with_insights(
                        p_question   => l_chart_prompt,
                        p_chart_data => l_chart_piece,
                        p_insights   => l_dummy_ins,
                        p_schema     => l_schema
                    );
                EXCEPTION
                    WHEN OTHERS THEN
                        l_chart_piece := NULL;
                END;

                IF l_chart_piece IS NULL
                   OR DBMS_LOB.getlength(l_chart_piece) = 0
                THEN
                    CONTINUE;
                END IF;

                DECLARE
                  l_type VARCHAR2(50) := chart_type_from_json(l_chart_piece);
                BEGIN
                  IF l_type IS NULL OR l_used_types.EXISTS(l_type) THEN
                    CONTINUE;
                  END IF;
                  l_used_types(l_type) := 1;
                  append_chart(l_chart_piece);
                END;
            END LOOP;

            IF l_chart_json IS NULL THEN
                l_chart_json := '[]';
            ELSE
                l_chart_json := l_chart_json || ']}';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                l_chart_json := '[]';
                apex_debug.message('GET_DASH_META chart generation failed: %s', SQLERRM);
        END;

        BEGIN
          MYQUERY_DASHBOARD_AI_PKG.persist_chart_widgets(l_dash_id, l_chart_json);
        EXCEPTION
          WHEN OTHERS THEN
            apex_debug.message('GET_DASH_META persist failed: %s', SQLERRM);
        END;
    END IF;

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

    -- kpis, chartData, insights are JSON strings (JS does JSON.parse)
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
        apex_debug.message('GET_DASH_META failed: %s', SQLERRM);
        apex_json.initialize_clob_output;
        apex_json.open_object;
        apex_json.write('ok', FALSE);
        apex_json.write('error', SQLERRM);
        apex_json.close_object;
        l_out := apex_json.get_clob_output;
        apex_json.free_output;
        out_json(l_out);
END;
