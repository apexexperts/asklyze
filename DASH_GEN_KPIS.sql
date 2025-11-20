-- Ajax callback process called DASH_GEN_KPIS
DECLARE
  v_dash_id     NUMBER := TO_NUMBER(:P3_DASH_ID);
  v_question    VARCHAR2(4000) := :P3_QUESTION;
  v_kpis_json   CLOB;
  v_kpi_id      NUMBER;
  v_kpi_count   PLS_INTEGER := 0;
  l_has_kpis    NUMBER := 0;
  l_out         CLOB;

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
  ------------------------------------------------------------------
  -- 0) Basic guard
  ------------------------------------------------------------------
  IF v_dash_id IS NULL THEN
    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.write('ok', false);
      apex_json.write('error', 'P3_DASH_ID is NULL');
    apex_json.close_object;
    l_out := apex_json.get_clob_output;
    apex_json.free_output;
    out_json(l_out);
    RETURN;
  END IF;

  ------------------------------------------------------------------
  -- 1) Generate KPI definitions via AI (SQL + meta)
  ------------------------------------------------------------------
  MYQUERY_DASHBOARD_AI_PKG.generate_kpi_blocks(
    p_question => v_question,
    p_kpis     => v_kpis_json,
    p_schema   => NVL(:P0_DATABASE_SCHEMA, USER)
  );

  DBMS_OUTPUT.PUT_LINE('KPI JSON from package (raw): ' || DBMS_LOB.SUBSTR(v_kpis_json, 2000));

  -- لو مفيش JSON أو مش فيه كيز kpis نرجّع قائمة فاضية
  IF v_kpis_json IS NOT NULL THEN
    BEGIN
      SELECT CASE
               WHEN JSON_EXISTS(v_kpis_json, '$.kpis') THEN 1
               ELSE 0
             END
        INTO l_has_kpis
        FROM dual;
    EXCEPTION
      WHEN OTHERS THEN
        l_has_kpis := 0;
    END;
  ELSE
    l_has_kpis := 0;
  END IF;

  IF v_kpis_json IS NULL
     OR DBMS_LOB.getlength(v_kpis_json) = 0
     OR l_has_kpis = 0 THEN
    v_kpis_json := '{"kpis":[]}';
    DBMS_OUTPUT.PUT_LINE('AI returned no KPI definitions or invalid JSON – using empty list.');
  END IF;

  ------------------------------------------------------------------
  -- 2) Execute each KPI SQL and build final values JSON
  ------------------------------------------------------------------
  DECLARE
    v_final_kpis CLOB := '{"kpis":[';
    v_first      BOOLEAN := TRUE;
  BEGIN
    BEGIN
      apex_json.parse(v_kpis_json);
      v_kpi_count := apex_json.get_count(p_path => 'kpis');
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error parsing KPI JSON: ' || SQLERRM);
        v_kpi_count := 0;
    END;

    DBMS_OUTPUT.PUT_LINE('Number of KPI definitions: ' || v_kpi_count);

    IF v_kpi_count = 0 THEN
      v_kpis_json := '{"kpis":[]}';
    ELSE
      FOR i IN 1 .. v_kpi_count LOOP
        DECLARE
          v_title      VARCHAR2(200)  := apex_json.get_varchar2(p_path => 'kpis[%d].title', p0 => i);
          v_sql_query  VARCHAR2(4000) := apex_json.get_varchar2(p_path => 'kpis[%d].sql',   p0 => i);
          v_unit       VARCHAR2(50)   := apex_json.get_varchar2(p_path => 'kpis[%d].unit',  p0 => i);
          v_icon       VARCHAR2(50)   := apex_json.get_varchar2(p_path => 'kpis[%d].icon',  p0 => i);
          v_color      VARCHAR2(50)   := apex_json.get_varchar2(p_path => 'kpis[%d].color', p0 => i);
          v_real_value NUMBER;
          v_value_str  VARCHAR2(100);
        BEGIN
          DBMS_OUTPUT.PUT_LINE('KPI ' || i || ': ' || v_title);
          DBMS_OUTPUT.PUT_LINE('SQL: ' || SUBSTR(v_sql_query, 1, 500));

          IF v_sql_query IS NOT NULL AND LENGTH(TRIM(v_sql_query)) > 10 THEN
            BEGIN
              EXECUTE IMMEDIATE v_sql_query INTO v_real_value;
              v_value_str := TO_CHAR(v_real_value, 'FM999G999G999G990D00');
              DBMS_OUTPUT.PUT_LINE('KPI ' || i || ' value: ' || v_value_str);
            EXCEPTION
              WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('KPI SQL failed for "' || v_title || '": ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('SQL was: ' || v_sql_query);
                v_value_str := 'N/A';
            END;
          ELSE
            v_value_str := 'N/A';
          END IF;

          IF NOT v_first THEN
            v_final_kpis := v_final_kpis || ',';
          END IF;
          v_first := FALSE;

          v_final_kpis := v_final_kpis ||
            '{"title":"' || REPLACE(NVL(v_title,''), '"', '\"') || '",' ||
            '"value":"' || REPLACE(NVL(v_value_str,'N/A'), '"', '\"') || '",' ||
            '"unit":"'  || REPLACE(NVL(v_unit,''),'"','\"') || '",' ||
            '"icon":"'  || REPLACE(NVL(v_icon,''),'"','\"') || '",' ||
            '"color":"' || REPLACE(NVL(v_color,''),'"','\"') || '"}';
        END;
      END LOOP;

      v_final_kpis := v_final_kpis || ']}';
      v_kpis_json  := v_final_kpis;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Final KPI JSON: ' || DBMS_LOB.SUBSTR(v_kpis_json, 2000));
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('KPI execution block error: ' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE('Original KPI JSON was: ' || DBMS_LOB.SUBSTR(v_kpis_json, 2000));
  END;

  ------------------------------------------------------------------
  -- 3) Create or update KPI widget
  ------------------------------------------------------------------
  BEGIN
    BEGIN
      SELECT id
        INTO v_kpi_id
        FROM widgets
       WHERE dashboard_id = v_dash_id
         AND UPPER(NVL(chart_type,'KPI')) = 'KPI'
         AND UPPER(title) = 'KPIS'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_kpi_id := NULL;
    END;

    IF v_kpi_id IS NULL THEN
      INSERT INTO widgets(
        dashboard_id, title, sql_query, chart_type, data_mapping, visual_options,
        grid_x, grid_y, grid_w, grid_h,
        refresh_mode, refresh_interval_sec, cache_ttl_sec,
        created_at, updated_at
      ) VALUES (
        v_dash_id,
        'KPIs',
        TO_CLOB('SELECT 1 AS dummy FROM dual'),
        'KPI',
        NULL,
        v_kpis_json,
        0, 0, 12, 2,
        'MANUAL', 0, 0,
        SYSTIMESTAMP, SYSTIMESTAMP
      ) RETURNING id INTO v_kpi_id;
    ELSE
      UPDATE widgets
         SET visual_options = v_kpis_json,
             updated_at     = SYSTIMESTAMP
       WHERE id = v_kpi_id;
    END IF;
  END;

  ------------------------------------------------------------------
  -- 4) Response
  ------------------------------------------------------------------
  apex_json.initialize_clob_output;
  apex_json.open_object;
    apex_json.write('ok', true);
    apex_json.write('dashboardId', v_dash_id);
    apex_json.write('kpiWidgetId', v_kpi_id);
    apex_json.write('kpisGenerated', v_kpi_count);
  apex_json.close_object;
  l_out := apex_json.get_clob_output;
  apex_json.free_output;
  out_json(l_out);

EXCEPTION
  WHEN OTHERS THEN
    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.write('ok', false);
      apex_json.write('error', SQLERRM);
    apex_json.close_object;
    l_out := apex_json.get_clob_output;
    apex_json.free_output;
    out_json(l_out);
END;
