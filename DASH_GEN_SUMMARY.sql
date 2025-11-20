--Ajax callback process called DASH_GEN_SUMMARY
DECLARE
  v_dash_id      NUMBER := TO_NUMBER(:P3_DASH_ID);
  v_widgets_json CLOB;
  v_summary      CLOB;
  v_sum_wid      NUMBER;
  v_ymax         NUMBER := 0;
  l_out          CLOB;

  -- JSON escape helper
  FUNCTION json_escape(p IN CLOB) RETURN CLOB IS
    l CLOB;
  BEGIN
    l := p;
    l := REPLACE(l, '\', '\\');
    l := REPLACE(l, '"', '\"');
    l := REPLACE(l, CHR(13), '\r');
    l := REPLACE(l, CHR(10), '\n');
    l := REPLACE(l, CHR(9),  '\t');
    RETURN l;
  END;

  -- HTTP headers helper
  PROCEDURE set_json_headers IS
  BEGIN
    apex_web_service.g_request_headers.delete;
    apex_web_service.g_request_headers(1).name  := 'Content-Type';
    apex_web_service.g_request_headers(1).value := 'application/json';
  END;

  -- out helper
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
  END out_json;

BEGIN
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

  -- build widgets snapshot (title/chart_type/sql)
  apex_json.initialize_clob_output;
  apex_json.open_array;
  FOR r IN (
    SELECT title, chart_type, sql_query
      FROM widgets
     WHERE dashboard_id = v_dash_id
       AND NVL(UPPER(chart_type),'TABLE') <> 'TEXT'
     ORDER BY id
  ) LOOP
    apex_json.open_object;
      apex_json.write('title',      r.title);
      apex_json.write('chart_type', r.chart_type);
      apex_json.write('sql',        DBMS_LOB.SUBSTR(r.sql_query, 32000));
    apex_json.close_object;
  END LOOP;
  apex_json.close_array;
  v_widgets_json := apex_json.get_clob_output;
  apex_json.free_output;

  -- ensure there is at least one widget
  IF v_widgets_json IS NULL OR v_widgets_json = '[]' THEN
    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.write('ok', false);
      apex_json.write('error', 'No data widgets found');
    apex_json.close_object;
    l_out := apex_json.get_clob_output;
    apex_json.free_output;
    out_json(l_out);
    RETURN;
  END IF;

  -------------------------------------------------------------------
  -- Call OpenAI /v1/responses to generate an overall summary
  -------------------------------------------------------------------
  DECLARE
    l_prompt CLOB;
    l_body   CLOB;
    l_resp   CLOB;
  BEGIN
    l_prompt :=
      'You are a BI copilot that summarizes dashboards for business users.'||CHR(10)||
      'Reply in the same language as this question (auto-detect): '||
        NVL(:P3_QUESTION, '(none)')||CHR(10)||
      'Use GitHub-Flavored Markdown only (no outer code fences).'||CHR(10)||
      'Use clear sections like:'||CHR(10)||
      '- # Summary'||CHR(10)||
      '- ## Key trends'||CHR(10)||
      '- ## Risks and anomalies'||CHR(10)||
      '- ## Recommended next questions'||CHR(10)||
      'Base your summary on the widgets and their SQL, assuming they already run correctly.'||CHR(10)||
      'Dashboard question: '||NVL(:P3_QUESTION, '(no question)')||CHR(10)||
      'Database schema owner (for context only): '||NVL(:P0_DATABASE_SCHEMA, '(not specified)')||CHR(10)||
      'Widgets JSON (truncated):'||CHR(10)||
      DBMS_LOB.SUBSTR(v_widgets_json, 12000);

    l_body := '{"model":"gpt-4o-mini"'
           || ',"temperature":0.2'
           || ',"max_output_tokens":600'
           || ',"input":"' || json_escape(l_prompt) || '"}';

    set_json_headers;

    l_resp := APEX_WEB_SERVICE.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    IF APEX_WEB_SERVICE.g_status_code = 200 THEN
      BEGIN
        SELECT JSON_VALUE(
                 l_resp,
                 '$.output[0].content[0].text'
                 RETURNING CLOB NULL ON ERROR NULL ON EMPTY
               )
          INTO v_summary
          FROM dual;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_summary := NULL;
      END;

      IF v_summary IS NULL THEN
        SELECT JSON_VALUE(
                 l_resp,
                 '$.output_text[0]'
                 RETURNING CLOB NULL ON ERROR NULL ON EMPTY
               )
          INTO v_summary
          FROM dual;
      END IF;
    ELSE
      v_summary :=
        TO_CLOB('Summary unavailable. HTTP '||
                APEX_WEB_SERVICE.g_status_code||': '||
                SUBSTR(l_resp,1,1000));
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      v_summary := TO_CLOB('Summary unavailable. Error: '||SQLERRM);
  END;

  IF v_summary IS NULL THEN
    v_summary := TO_CLOB('Summary unavailable.');
  END IF;

  -- update dashboard description
  UPDATE dashboards
     SET description = DBMS_LOB.SUBSTR(v_summary, 4000),
         updated_at  = SYSTIMESTAMP
   WHERE id = v_dash_id;

  -- find existing Summary widget (if any)
  BEGIN
    SELECT id
      INTO v_sum_wid
      FROM widgets
     WHERE dashboard_id = v_dash_id
       AND NVL(UPPER(chart_type),'TEXT') = 'TEXT'
       AND UPPER(title) = 'SUMMARY'
       AND ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_sum_wid := NULL;
  END;

  IF v_sum_wid IS NULL THEN
    -- place below the lowest widget
    SELECT NVL(MAX(grid_y + grid_h), 0)
      INTO v_ymax
      FROM widgets
     WHERE dashboard_id = v_dash_id;

    INSERT INTO widgets(
      dashboard_id, title, sql_query, chart_type, data_mapping, visual_options,
      grid_x, grid_y, grid_w, grid_h,
      refresh_mode, refresh_interval_sec, cache_ttl_sec,
      created_at, updated_at
    ) VALUES (
      v_dash_id,
      'Summary',
      TO_CLOB(
        'SELECT ''' ||
        REPLACE(NVL(v_summary,'Summary unavailable.'), '''', '''''') ||
        ''' AS summary_text FROM dual'
      ),
      'TEXT',
      NULL,
      NULL,
      0, v_ymax, 12, 4,
      'MANUAL', 0, 0,
      SYSTIMESTAMP, SYSTIMESTAMP
    ) RETURNING id INTO v_sum_wid;
  ELSE
    UPDATE widgets
       SET visual_options =
             TO_CLOB(
               '{"text":"'||
               REPLACE(DBMS_LOB.SUBSTR(v_summary, 24000), '"','\"')||
               '"}'
             ),
           updated_at     = SYSTIMESTAMP
     WHERE id = v_sum_wid;
  END IF;

  -- response
  apex_json.initialize_clob_output;
  apex_json.open_object;
    apex_json.write('ok', true);
    apex_json.write('dashboardId', v_dash_id);
    apex_json.write('summaryWidgetId', v_sum_wid);
    apex_json.write('summaryLen', DBMS_LOB.getlength(v_summary));
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
