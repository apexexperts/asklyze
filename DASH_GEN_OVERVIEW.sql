-- Ajax callback process called DASH_GEN_OVERVIEW
DECLARE
  v_dash_id     NUMBER := TO_NUMBER(:P3_DASH_ID);
  v_question    VARCHAR2(4000) := :P3_QUESTION;
  v_overview    CLOB;
  v_overview_id NUMBER;
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
  -- Basic guard
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
  -- 1) Generate overview text via AI (with schema context)
  ------------------------------------------------------------------
  MYQUERY_DASHBOARD_AI_PKG.generate_overview_text(
    p_question => v_question,
    p_overview => v_overview,
    p_schema   => NVL(:P0_DATABASE_SCHEMA, USER)
  );

  -- Fallback text لو الـ AI مرجعش حاجة
  IF v_overview IS NULL THEN
    v_overview := TO_CLOB(
      'Overview will be generated based on your dashboard data and schema. '||
      'Please make sure KPIs and charts are created, then regenerate the overview.'
    );
  END IF;

  ------------------------------------------------------------------
  -- 2) Create or update "Overview" widget (TEXT + visual_options.text)
  ------------------------------------------------------------------
  DECLARE
    v_ymin NUMBER := 0;
  BEGIN
    -- حاول تلاقي widget موجودة باسم Overview
    BEGIN
      SELECT id
        INTO v_overview_id
        FROM widgets
       WHERE dashboard_id = v_dash_id
         AND UPPER(NVL(chart_type,'TEXT')) = 'TEXT'
         AND UPPER(title) = 'OVERVIEW'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_overview_id := NULL;
    END;

    IF v_overview_id IS NULL THEN
      -- حطها فوق أول صف widgets (زي Key Insights)
      SELECT NVL(MIN(grid_y), 0)
        INTO v_ymin
        FROM widgets
       WHERE dashboard_id = v_dash_id;

      INSERT INTO widgets(
        dashboard_id,
        title,
        sql_query,
        chart_type,
        data_mapping,
        visual_options,
        grid_x,
        grid_y,
        grid_w,
        grid_h,
        refresh_mode,
        refresh_interval_sec,
        cache_ttl_sec,
        created_at,
        updated_at
      ) VALUES (
        v_dash_id,
        'Overview',
        TO_CLOB(
          'SELECT ''' ||
          REPLACE(DBMS_LOB.SUBSTR(NVL(v_overview,'No overview available.'), 24000), '''', '''''') ||
          ''' AS overview_text FROM dual'
        ),
        'TEXT',
        NULL,
        TO_CLOB(
          '{"text":"' ||
          REPLACE(DBMS_LOB.SUBSTR(NVL(v_overview,'No overview.'), 24000), '"','\"') ||
          '"}'
        ),
        0,
        LEAST(0, v_ymin - 1),
        12,
        4,
        'MANUAL',
        0,
        0,
        SYSTIMESTAMP,
        SYSTIMESTAMP
      )
      RETURNING id INTO v_overview_id;
    ELSE
      -- حدّث النص في visual_options فقط (العرض هيستخدم ده)
      UPDATE widgets
         SET visual_options = TO_CLOB(
               '{"text":"' ||
               REPLACE(DBMS_LOB.SUBSTR(NVL(v_overview,'No overview.'), 24000), '"','\"') ||
               '"}'
             ),
             updated_at = SYSTIMESTAMP
       WHERE id = v_overview_id;
    END IF;
  END;

  ------------------------------------------------------------------
  -- 3) JSON response
  ------------------------------------------------------------------
  apex_json.initialize_clob_output;
  apex_json.open_object;
    apex_json.write('ok', true);
    apex_json.write('dashboardId', v_dash_id);
    apex_json.write('overviewWidgetId', v_overview_id);
    apex_json.write('overviewLen', DBMS_LOB.getlength(v_overview));
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
