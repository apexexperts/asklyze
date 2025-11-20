create or replace PACKAGE myquery_dashboard_ai_pkg AS

  -- Default model
  c_default_model CONSTANT VARCHAR2(100) := 'gpt-4o-mini';

  ---------------------------------------------------------------------------
  -- Main dashboard planner (schema-aware)
  ---------------------------------------------------------------------------
  PROCEDURE plan_layout_and_blocks(
    p_question    IN  VARCHAR2,
    p_plan_json   OUT CLOB,
    p_schema      IN  VARCHAR2,
    p_model       IN  VARCHAR2 DEFAULT NULL,
    p_max_widgets IN  PLS_INTEGER DEFAULT 6
  );

  ---------------------------------------------------------------------------
  -- KPI blocks JSON: { "kpis": [ ... ] }
  ---------------------------------------------------------------------------
  PROCEDURE generate_kpi_blocks(
    p_question IN  VARCHAR2,
    p_kpis     OUT CLOB,
    p_schema   IN  VARCHAR2
  );

  ---------------------------------------------------------------------------
  -- Dashboard overview text
  ---------------------------------------------------------------------------
  PROCEDURE generate_overview_text(
    p_question IN  VARCHAR2,
    p_overview OUT CLOB,
    p_schema   IN  VARCHAR2
  );

  ---------------------------------------------------------------------------
  -- Executive summary based on widgets JSON + schema
  ---------------------------------------------------------------------------
  PROCEDURE generate_overall_summary(
    p_question IN  VARCHAR2,
    p_widgets  IN  CLOB,
    p_summary  OUT CLOB,
    p_schema   IN  VARCHAR2
  );

  ---------------------------------------------------------------------------
  -- Single chart + insights (schema-aware)
  ---------------------------------------------------------------------------
  PROCEDURE generate_chart_with_insights(
    p_question   IN  VARCHAR2,
    p_chart_data OUT CLOB,
    p_insights   OUT CLOB,
    p_schema     IN  VARCHAR2
  );

  ---------------------------------------------------------------------------
  -- Compatibility wrapper: build chart JSON for dashboard
  -- Returns: { "chart": { ... } , "insights": [ ... ] }
  ---------------------------------------------------------------------------
  PROCEDURE build_chart_data_for_dashboard(
    p_question IN  VARCHAR2,
    p_schema   IN  VARCHAR2,
    p_result   OUT CLOB
  );

  ---------------------------------------------------------------------------
  -- Persist chart widgets JSON so dashboards can be reloaded without AI
  ---------------------------------------------------------------------------
  PROCEDURE persist_chart_widgets(
    p_dash_id    IN NUMBER,
    p_chart_json IN CLOB
  );

END myquery_dashboard_ai_pkg;
/





create or replace PACKAGE BODY myquery_dashboard_ai_pkg AS

  ---------------------------------------------------------------------------
  -- Helpers
  ---------------------------------------------------------------------------

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
  END json_escape;

  PROCEDURE set_json_headers IS
  BEGIN
    apex_web_service.g_request_headers.delete;
    apex_web_service.g_request_headers(1).name  := 'Content-Type';
    apex_web_service.g_request_headers(1).value := 'application/json';
  END set_json_headers;

  FUNCTION is_numeric_type(p_code IN NUMBER) RETURN BOOLEAN IS
  BEGIN
    RETURN p_code IN (2, 100, 101);
  END is_numeric_type;

  FUNCTION is_date_type(p_code IN NUMBER) RETURN BOOLEAN IS
  BEGIN
    RETURN p_code IN (12, 178, 179, 180, 181, 231);
  END is_date_type;

  FUNCTION is_valid_json(p_text IN CLOB) RETURN BOOLEAN IS
    l_dummy NUMBER;
  BEGIN
    IF p_text IS NULL THEN
      RETURN FALSE;
    END IF;

    BEGIN
      SELECT CASE WHEN JSON_EXISTS(p_text, '$') THEN 1 ELSE 0 END
        INTO l_dummy
        FROM dual;
      RETURN (l_dummy = 1);
    EXCEPTION
      WHEN OTHERS THEN
        RETURN FALSE;
    END;
  END is_valid_json;

  FUNCTION normalize_json_block(p_text IN CLOB) RETURN CLOB IS
    l_clean     CLOB := p_text;
    l_candidate CLOB;
  BEGIN
    IF l_clean IS NULL THEN
      RETURN NULL;
    END IF;

    l_clean := REGEXP_REPLACE(l_clean, '^\s+', '', 1, 0, 'n');
    l_clean := REGEXP_REPLACE(l_clean, '\s+$', '', 1, 0, 'n');

    IF REGEXP_LIKE(l_clean, '^```', 'n') THEN
      l_clean := REGEXP_REPLACE(l_clean, '^```[a-zA-Z0-9_-]*', '', 1, 1, 'n');
      l_clean := REGEXP_REPLACE(l_clean, '```$', '', 1, 1, 'n');
      l_clean := REGEXP_REPLACE(l_clean, '^\s+', '', 1, 0, 'n');
      l_clean := REGEXP_REPLACE(l_clean, '\s+$', '', 1, 0, 'n');
    END IF;

    IF is_valid_json(l_clean) THEN
      RETURN l_clean;
    END IF;

    l_candidate := REGEXP_SUBSTR(l_clean, '\{.*\}', 1, 1, NULL, 'n');

    IF l_candidate IS NOT NULL AND is_valid_json(l_candidate) THEN
      RETURN l_candidate;
    END IF;

    RETURN l_clean;
  END normalize_json_block;

  FUNCTION build_fallback_plan(p_question IN VARCHAR2) RETURN CLOB IS
    l_focus   VARCHAR2(4000) := NVL(TRIM(p_question), 'the business question');
    l_title   VARCHAR2(200) := NVL(SUBSTR(TRIM(p_question), 1, 200), 'AI Dashboard');
    l_result  CLOB;
  BEGIN
    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.write('title', l_title);
      apex_json.open_object('layout');
        apex_json.write('columns', 12);
      apex_json.close_object;
      apex_json.open_array('blocks');

        apex_json.open_object;
          apex_json.write('type', 'KPI');
          apex_json.write('chartType', 'KPI');
          apex_json.write('title', 'Key Metrics Snapshot');
          apex_json.write('priority', 1);
          apex_json.write('notes', 'Highlight the most important KPIs related to ' || l_focus || '.');
        apex_json.close_object;

        apex_json.open_object;
          apex_json.write('type', 'CHART');
          apex_json.write('chartType', 'BAR');
          apex_json.write('title', 'Trend Overview');
          apex_json.write('priority', 2);
          apex_json.write('notes', 'Visualize how the primary measure for ' || l_focus || ' changes over time or across categories.');
        apex_json.close_object;

        apex_json.open_object;
          apex_json.write('type', 'TEXT');
          apex_json.write('chartType', 'TEXT');
          apex_json.write('title', 'Insights & Narrative');
          apex_json.write('priority', 3);
          apex_json.write('notes', 'Summarize AI-generated insights that explain what the metrics reveal about ' || l_focus || '.');
        apex_json.close_object;

      apex_json.close_array;
    apex_json.close_object;

    l_result := apex_json.get_clob_output;
    apex_json.free_output;

    RETURN l_result;
  END build_fallback_plan;

  FUNCTION validate_chart_sql(
    p_sql        IN  CLOB,
    p_error      OUT VARCHAR2,
    p_preview    OUT CLOB,
    p_chart_type IN  VARCHAR2 DEFAULT NULL
  ) RETURN BOOLEAN IS
    TYPE t_varchar IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
    TYPE t_number  IS TABLE OF NUMBER       INDEX BY PLS_INTEGER;

    l_cur           INTEGER := NULL;
    l_sql_wrap      CLOB;
    l_sql_clean     CLOB;
    l_cols          INTEGER;
    l_desc          DBMS_SQL.DESC_TAB2;
    l_label_char    VARCHAR2(4000);
    l_label_num     NUMBER;
    l_label_date    DATE;
    l_lat_value     NUMBER;
    l_lon_value     NUMBER;
    l_metric_value  NUMBER;
    l_idx           PLS_INTEGER := 0;
    l_exec          INTEGER;
    l_labels        t_varchar;
    l_values        t_number;
    l_latitudes     t_number;
    l_longitudes    t_number;
    l_label_type    NUMBER;
    l_type_upper    VARCHAR2(30) := UPPER(NVL(p_chart_type, ''));
    c_preview_limit CONSTANT PLS_INTEGER := 60;
  BEGIN
    p_error   := NULL;
    p_preview := NULL;

    IF p_sql IS NULL THEN
      p_error := 'SQL is NULL';
      RETURN FALSE;
    END IF;

    IF NOT REGEXP_LIKE(TRIM(LOWER(p_sql)), '^select\s') THEN
      p_error := 'Only SELECT statements are allowed';
      RETURN FALSE;
    END IF;

    IF INSTR(p_sql, ';') > 0 THEN
      p_error := 'Semicolons are not allowed';
      RETURN FALSE;
    END IF;

    l_sql_clean := TRIM(p_sql);

    IF REGEXP_LIKE(l_sql_clean, '^\s*with\b', 'i') THEN
      l_sql_wrap :=
        'WITH mq_src AS (' || l_sql_clean || ') ' ||
        'SELECT * FROM mq_src WHERE ROWNUM <= ' || c_preview_limit;
    ELSE
      l_sql_wrap :=
        'SELECT * FROM (' || l_sql_clean || ') WHERE ROWNUM <= ' || c_preview_limit;
    END IF;

    l_cur := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(l_cur, l_sql_wrap, DBMS_SQL.NATIVE);
    DBMS_SQL.DESCRIBE_COLUMNS2(l_cur, l_cols, l_desc);

    IF l_type_upper = 'MAP' THEN
      IF l_cols < 4 THEN
        p_error := 'Map queries must return location, latitude, longitude, and value columns';
        DBMS_SQL.CLOSE_CURSOR(l_cur);
        RETURN FALSE;
      END IF;

      IF NOT is_numeric_type(l_desc(2).col_type) THEN
        p_error := 'Latitude column must be numeric';
        DBMS_SQL.CLOSE_CURSOR(l_cur);
        RETURN FALSE;
      END IF;

      IF NOT is_numeric_type(l_desc(3).col_type) THEN
        p_error := 'Longitude column must be numeric';
        DBMS_SQL.CLOSE_CURSOR(l_cur);
        RETURN FALSE;
      END IF;

      IF NOT is_numeric_type(l_desc(4).col_type) THEN
        p_error := 'Map value column must be numeric';
        DBMS_SQL.CLOSE_CURSOR(l_cur);
        RETURN FALSE;
      END IF;
    ELSE
      IF l_cols < 2 THEN
        p_error := 'Chart query must return at least two columns';
        DBMS_SQL.CLOSE_CURSOR(l_cur);
        RETURN FALSE;
      END IF;

      IF NOT is_numeric_type(l_desc(2).col_type) THEN
        p_error := 'Second column must be numeric';
        DBMS_SQL.CLOSE_CURSOR(l_cur);
        RETURN FALSE;
      END IF;
    END IF;

    l_label_type := l_desc(1).col_type;

    IF is_numeric_type(l_label_type) THEN
      DBMS_SQL.DEFINE_COLUMN(l_cur, 1, l_label_num);
    ELSIF is_date_type(l_label_type) THEN
      DBMS_SQL.DEFINE_COLUMN(l_cur, 1, l_label_date);
    ELSE
      DBMS_SQL.DEFINE_COLUMN(l_cur, 1, l_label_char, 4000);
    END IF;

    IF l_type_upper = 'MAP' THEN
      DBMS_SQL.DEFINE_COLUMN(l_cur, 2, l_lat_value);
      DBMS_SQL.DEFINE_COLUMN(l_cur, 3, l_lon_value);
      DBMS_SQL.DEFINE_COLUMN(l_cur, 4, l_metric_value);
    ELSE
      DBMS_SQL.DEFINE_COLUMN(l_cur, 2, l_metric_value);
    END IF;

    l_exec := DBMS_SQL.EXECUTE(l_cur);

    LOOP
      EXIT WHEN DBMS_SQL.FETCH_ROWS(l_cur) = 0 OR l_idx >= c_preview_limit;
      l_idx := l_idx + 1;

      IF is_numeric_type(l_label_type) THEN
        DBMS_SQL.COLUMN_VALUE(l_cur, 1, l_label_num);
        l_labels(l_idx) := TO_CHAR(l_label_num);
      ELSIF is_date_type(l_label_type) THEN
        DBMS_SQL.COLUMN_VALUE(l_cur, 1, l_label_date);
        IF l_label_date IS NULL THEN
          l_labels(l_idx) := NULL;
        ELSE
          l_labels(l_idx) := TO_CHAR(l_label_date, 'YYYY-MM-DD"T"HH24:MI:SS');
        END IF;
      ELSE
        DBMS_SQL.COLUMN_VALUE(l_cur, 1, l_label_char);
        l_labels(l_idx) := l_label_char;
      END IF;

      IF l_type_upper = 'MAP' THEN
        DBMS_SQL.COLUMN_VALUE(l_cur, 2, l_lat_value);
        DBMS_SQL.COLUMN_VALUE(l_cur, 3, l_lon_value);
        DBMS_SQL.COLUMN_VALUE(l_cur, 4, l_metric_value);
        l_latitudes(l_idx)  := l_lat_value;
        l_longitudes(l_idx) := l_lon_value;
        l_values(l_idx)     := l_metric_value;
      ELSE
        DBMS_SQL.COLUMN_VALUE(l_cur, 2, l_metric_value);
        l_values(l_idx) := l_metric_value;
      END IF;
    END LOOP;

    DBMS_SQL.CLOSE_CURSOR(l_cur);

    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.open_array('labels');
      FOR i IN 1 .. l_idx LOOP
        apex_json.write(l_labels(i));
      END LOOP;
      apex_json.close_array;

      apex_json.open_array('data');
      FOR i IN 1 .. l_idx LOOP
        apex_json.write(l_values(i));
      END LOOP;
      apex_json.close_array;

      IF l_type_upper = 'MAP' THEN
        apex_json.open_array('latitudes');
        FOR i IN 1 .. l_idx LOOP
          apex_json.write(l_latitudes(i));
        END LOOP;
        apex_json.close_array;

        apex_json.open_array('longitudes');
        FOR i IN 1 .. l_idx LOOP
          apex_json.write(l_longitudes(i));
        END LOOP;
        apex_json.close_array;
      END IF;
    apex_json.close_object;

    p_preview := apex_json.get_clob_output;
    apex_json.free_output;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      p_error := SQLERRM;
      IF l_cur IS NOT NULL AND DBMS_SQL.IS_OPEN(l_cur) THEN
        DBMS_SQL.CLOSE_CURSOR(l_cur);
      END IF;
      BEGIN
        apex_json.free_output;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      p_preview := NULL;
      RETURN FALSE;
  END validate_chart_sql;

  -- Extract text from OpenAI Responses API JSON
FUNCTION get_response_text (
  p_response IN CLOB
) RETURN CLOB IS
  l_text      CLOB;
  l_text_vc   VARCHAR2(32767);
BEGIN
  ------------------------------------------------------------------
  -- 1) New OpenAI /v1/responses shape:
  --    response.output[*].content[*].text
  ------------------------------------------------------------------
  BEGIN
    SELECT t.text
      INTO l_text_vc
      FROM JSON_TABLE(
             p_response,
             '$.output[*].content[*]'
             COLUMNS (
               ord  FOR ORDINALITY,
               text VARCHAR2(32767) PATH '$.text'
             )
           ) t
      WHERE t.text IS NOT NULL
      ORDER BY t.ord
      FETCH FIRST 1 ROW ONLY;

    l_text := TO_CLOB(l_text_vc);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      -- ignore and try legacy shapes
      NULL;
  END;

  ------------------------------------------------------------------
  -- 2) Legacy chat.completions shape:
  --    choices[0].message.content
  ------------------------------------------------------------------
  IF l_text IS NULL THEN
    BEGIN
      SELECT JSON_VALUE(
               p_response,
               '$.choices[0].message.content'
             )
        INTO l_text_vc
        FROM dual;

      l_text := TO_CLOB(l_text_vc);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END IF;

  ------------------------------------------------------------------
  -- 3) Fallback: simple "output_text" top-level field (if present)
  ------------------------------------------------------------------
  IF l_text IS NULL THEN
    BEGIN
      SELECT JSON_VALUE(
               p_response,
               '$.output_text'
             )
        INTO l_text_vc
        FROM dual;

      l_text := TO_CLOB(l_text_vc);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END IF;

  RETURN l_text;
END get_response_text;


  FUNCTION build_schema_summary(
    p_owner     IN VARCHAR2,
    p_max_chars IN PLS_INTEGER DEFAULT 20000
  ) RETURN CLOB IS
    l_owner  VARCHAR2(128) := UPPER(p_owner);
    l_schema CLOB;

    PROCEDURE append_line(p_txt IN VARCHAR2) IS
    BEGIN
      IF l_schema IS NULL THEN
        DBMS_LOB.createtemporary(l_schema, TRUE);
      END IF;
      DBMS_LOB.writeappend(
        l_schema,
        LENGTH(p_txt || CHR(10)),
        p_txt || CHR(10)
      );
    END;
  BEGIN
    -- Tables
    FOR r IN (
      SELECT t.table_name,
             LISTAGG(
               c.column_name || ' ' ||
               CASE
                 WHEN c.data_type IN ('VARCHAR2','NVARCHAR2','CHAR','NCHAR')
                   THEN c.data_type || '(' || c.char_length || ')'
                 WHEN c.data_type = 'NUMBER'
                   THEN CASE
                          WHEN c.data_precision IS NOT NULL
                            THEN 'NUMBER(' || c.data_precision ||
                                 NVL2(c.data_scale, ','||c.data_scale, '') || ')'
                          ELSE 'NUMBER'
                        END
                 ELSE c.data_type
               END
               || CASE WHEN c.nullable = 'N' THEN ' NN' ELSE '' END,
               ', '
             ) WITHIN GROUP (ORDER BY c.column_id) AS cols
      FROM   all_tables t
      JOIN   all_tab_columns c
        ON   c.owner = t.owner
       AND   c.table_name = t.table_name
      WHERE  t.owner = l_owner
      GROUP  BY t.table_name
      ORDER  BY t.table_name
      FETCH FIRST 40 ROWS ONLY
    ) LOOP
      IF l_schema IS NULL OR DBMS_LOB.getlength(l_schema) < p_max_chars THEN
        append_line('TABLE '||l_owner||'.'||r.table_name||': '||r.cols);
      END IF;
    END LOOP;

    -- Views
    FOR r IN (
      SELECT v.view_name AS table_name,
             LISTAGG(c.column_name || ' ' || c.data_type, ', ')
               WITHIN GROUP (ORDER BY c.column_id) AS cols
      FROM   all_views v
      JOIN   all_tab_columns c
        ON   c.owner = v.owner
       AND   c.table_name = v.view_name
      WHERE  v.owner = l_owner
      GROUP  BY v.view_name
      ORDER  BY v.view_name
      FETCH FIRST 40 ROWS ONLY
    ) LOOP
      IF l_schema IS NULL OR DBMS_LOB.getlength(l_schema) < p_max_chars THEN
        append_line('VIEW '||l_owner||'.'||r.table_name||': '||r.cols);
      END IF;
    END LOOP;

    IF l_schema IS NULL THEN
      DBMS_LOB.createtemporary(l_schema, TRUE);
      append_line('No tables/views found for owner '||l_owner);
    END IF;

    RETURN DBMS_LOB.SUBSTR(l_schema, p_max_chars);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN TO_CLOB('Error reading schema '||l_owner||': '||SQLERRM);
  END build_schema_summary;

  ---------------------------------------------------------------------------
  -- Plan layout and blocks (schema-aware)
  ---------------------------------------------------------------------------
  PROCEDURE plan_layout_and_blocks(
    p_question    IN  VARCHAR2,
    p_plan_json   OUT CLOB,
    p_schema      IN  VARCHAR2,
    p_model       IN  VARCHAR2,
    p_max_widgets IN  PLS_INTEGER DEFAULT 6
  ) IS
    l_owner   VARCHAR2(128) := UPPER(NVL(p_schema, USER));
    l_schema  CLOB;
    l_prompt  CLOB;
    l_body    CLOB;
    l_resp    CLOB;
    l_txt     CLOB;
    l_ok      NUMBER;
    l_model   VARCHAR2(100);
  BEGIN
    l_schema := build_schema_summary(l_owner, 12000);

    l_prompt :=
      'You are designing a BI dashboard layout for an Oracle schema.'||CHR(10)||
      'Schema owner: '||l_owner||CHR(10)||
      'Schema summary:'||CHR(10)||l_schema||CHR(10)||CHR(10)||
      'Business question: '||NVL(p_question,'')||CHR(10)||CHR(10)||
      'Return JSON ONLY in this structure (no explanation, no code fences):'||CHR(10)||
      '{'||CHR(10)||
      '  "title": "human-readable dashboard title",'||CHR(10)||
      '  "layout": { "columns": 12 },'||CHR(10)||
      '  "blocks": ['||CHR(10)||
      '    {'||CHR(10)||
      '      "type": "KPI" | "CHART" | "TEXT",'||CHR(10)||
      '      "title": "block title",'||CHR(10)||
      '      "chartType": "KPI" | "TABLE" | "BAR" | "LINE" | "AREA" | "PIE",'||CHR(10)||
      '      "priority": 1,'||CHR(10)||
      '      "notes": "short description of what this block should show"'||CHR(10)||
      '    }'||CHR(10)||
      '  ]'||CHR(10)||
      '}'||CHR(10)||
      'Rules:'||CHR(10)||
      '- Use ONLY tables/columns that exist in the schema summary.'||CHR(10)||
      '- Focus on a maximum of '||p_max_widgets||' blocks, ordered by priority.'||CHR(10)||
      '- Do NOT include any actual SQL, only conceptual notes.';

    set_json_headers;

    l_model := NVL(p_model, c_default_model);

    l_body := '{"model":"'
           || REPLACE(l_model, '"','\"')
           || '","input":"'
           || json_escape(l_prompt)
           || '"}';

    l_resp := apex_web_service.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    IF apex_web_service.g_status_code <> 200 THEN
      p_plan_json := build_fallback_plan(p_question);
      RETURN;
    END IF;

    l_txt := get_response_text(l_resp);

    IF l_txt IS NULL THEN
      p_plan_json := build_fallback_plan(p_question);
      RETURN;
    END IF;

    l_txt := normalize_json_block(l_txt);

    SELECT CASE WHEN JSON_EXISTS(l_txt,'$.blocks[0]') THEN 1 ELSE 0 END
      INTO l_ok
      FROM dual;

    IF l_ok = 1 THEN
      p_plan_json := l_txt;
    ELSE
      p_plan_json := build_fallback_plan(p_question);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_plan_json := build_fallback_plan(p_question);
  END plan_layout_and_blocks;

  ---------------------------------------------------------------------------
  -- Generate KPI blocks (schema-aware, returns JSON { "kpis": [...] })
  ---------------------------------------------------------------------------
PROCEDURE generate_kpi_blocks(
  p_question IN  VARCHAR2,
  p_kpis     OUT CLOB,
  p_schema   IN  VARCHAR2
) IS
  l_owner   VARCHAR2(128) := UPPER(NVL(p_schema, USER));
  l_schema  CLOB;
  l_prompt  CLOB;
  l_body    CLOB;
  l_resp    CLOB;
  l_txt     CLOB;
  l_try     PLS_INTEGER := 0;
  l_ok      NUMBER := 0;
  c_max_attempts CONSTANT PLS_INTEGER := 3;
BEGIN
  -- Build schema summary for the given owner (no hard-coded tables)
  l_schema := build_schema_summary(l_owner, 12000);

  -- LLM prompt without any fixed KPI names or fake SQL
  l_prompt :=
    'You are an Oracle BI engineer.' || CHR(10) ||
    'Goal: design KPI metrics for an analytic dashboard that answer the business question, using ONLY the schema summary.' || CHR(10) ||
    'Schema owner: ' || l_owner || CHR(10) ||
    'Schema summary:' || CHR(10) || l_schema || CHR(10) || CHR(10) ||
    'Business question: ' || NVL(p_question, '') || CHR(10) || CHR(10) ||
          'Return JSON ONLY in this exact structure (no extra keys, no comments):'||CHR(10)||
      '{"kpis":['||CHR(10)||
      '  {'||CHR(10)||
      '    "title": "Total Expenses Amount",'||CHR(10)||
      '    "sql": "SELECT SUM('||l_owner||'.TABLE.COLUMN) AS VALUE FROM '||l_owner||'.TABLE",'||CHR(10)||
      '    "unit": "currency" or "tasks" or "%",'||CHR(10)||
      '    "icon": "fa-shopping-cart",'||CHR(10)||
      '    "color": "#2563eb"'||CHR(10)||
      '  }'||CHR(10)||
      ']}'||CHR(10)||
      'Rules:'||CHR(10)||
      '- "icon" must be a single Oracle APEX Font / Font Awesome CSS class, like "fa-shopping-cart", "fa-chart-line", "fa-receipt", "fa-users", "fa-database".'||CHR(10)||
      '- Choose an appropriate icon for each KPI (do NOT always use the same one).'||CHR(10)||
    '- Use ONLY tables and views that appear in the schema summary, and always prefix them with ' || l_owner || '.' || CHR(10) ||
    '- Every KPI "sql" must be a valid Oracle SELECT that returns exactly one numeric column aliased as VALUE.' || CHR(10) ||
    '- Use aggregations like SUM, COUNT, AVG, MIN, MAX as appropriate.' || CHR(10) ||
    '- Do NOT invent fake table names, column names, or constant values; only use what is visible in the schema summary.' || CHR(10) ||
    '- Do NOT hard-code specific IDs, names, or filters unless they are clearly implied by the business question (for example a specific company, user, status, or date range).' || CHR(10) ||
    '- Avoid adding WHERE filters that are not mentioned or strongly implied by the question. Prefer generic KPIs that work for the whole dataset.' || CHR(10) ||
    '- 3 to 6 KPIs that are directly relevant to the business question. Each KPI must have a different purpose (do not duplicate the same logic with different titles).';

  set_json_headers;

  l_body := '{"model":"'
         || REPLACE(c_default_model, '"', '\"')
         || '","input":"'
         || json_escape(l_prompt)
         || '"}';

  WHILE l_try < c_max_attempts LOOP
    l_try := l_try + 1;

    l_resp := apex_web_service.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    IF apex_web_service.g_status_code <> 200 THEN
      CONTINUE;
    END IF;

    l_txt := get_response_text(l_resp);
    l_txt := normalize_json_block(l_txt);

    IF l_txt IS NULL THEN
      CONTINUE;
    END IF;

    BEGIN
      SELECT CASE WHEN JSON_EXISTS(l_txt, '$.kpis[0]') THEN 1 ELSE 0 END
        INTO l_ok
        FROM dual;
    EXCEPTION
      WHEN OTHERS THEN
        l_ok := 0;
    END;

    IF l_ok = 1 THEN
      p_kpis := l_txt;
      RETURN;
    END IF;
  END LOOP;

  p_kpis := '{"kpis":[]}';
EXCEPTION
  WHEN OTHERS THEN
    p_kpis := '{"kpis":[]}';
END generate_kpi_blocks;


  ---------------------------------------------------------------------------
  -- Generate overview text (schema-aware, no generic buzzwords)
  ---------------------------------------------------------------------------
  PROCEDURE generate_overview_text(
    p_question IN  VARCHAR2,
    p_overview OUT CLOB,
    p_schema   IN  VARCHAR2
  ) IS
    l_owner   VARCHAR2(128) := UPPER(NVL(p_schema, USER));
    l_schema  CLOB;
    l_prompt  CLOB;
    l_body    CLOB;
    l_resp    CLOB;
    l_txt     CLOB;
  BEGIN
    l_schema := build_schema_summary(l_owner, 12000);

    l_prompt :=
      'You are an analytics consultant. Write a concise overview (3–5 sentences)'||CHR(10)||
      'for a BI dashboard built on the following Oracle schema and question.'||CHR(10)||
      'Schema owner: '||l_owner||CHR(10)||
      'Schema summary:'||CHR(10)||l_schema||CHR(10)||CHR(10)||
      'Business question: '||NVL(p_question,'')||CHR(10)||CHR(10)||
      'Rules:'||CHR(10)||
      '- The overview MUST be specific to the actual tables/columns shown in the schema summary.'||CHR(10)||
      '- Do NOT mention "sales" or "customers" unless such tables/columns exist in the schema.'||CHR(10)||
      '- Do NOT ask the user to provide schema details (you already have them).'||CHR(10)||
      '- Do NOT describe AI or the model. Just describe what the dashboard helps analyze.';

    set_json_headers;

    l_body := '{"model":"'
           || REPLACE(c_default_model,'"','\"')
           || '","input":"'
           || json_escape(l_prompt)
           || '"}';

    l_resp := apex_web_service.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    IF apex_web_service.g_status_code = 200 THEN
      l_txt := get_response_text(l_resp);
    END IF;

    IF l_txt IS NULL THEN
      p_overview := 'Overview is not available for this dashboard.';
    ELSE
      p_overview := l_txt;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_overview := 'Overview generation failed: '||SQLERRM;
  END generate_overview_text;

  ---------------------------------------------------------------------------
  -- Generate overall summary based on widgets + schema
  ---------------------------------------------------------------------------
  PROCEDURE generate_overall_summary(
    p_question IN  VARCHAR2,
    p_widgets  IN  CLOB,
    p_summary  OUT CLOB,
    p_schema   IN  VARCHAR2
  ) IS
    l_owner   VARCHAR2(128) := UPPER(NVL(p_schema, USER));
    l_schema  CLOB;
    l_prompt  CLOB;
    l_body    CLOB;
    l_resp    CLOB;
    l_txt     CLOB;
  BEGIN
    l_schema := build_schema_summary(l_owner, 12000);

    l_prompt :=
      'You are a senior BI analyst.'||CHR(10)||
      'Write an executive-style summary for a dashboard, based ONLY on:'||CHR(10)||
      '- The Oracle schema summary'||CHR(10)||
      '- The business question'||CHR(10)||
      '- The list of widgets (title, chart_type, sql)'||CHR(10)||CHR(10)||
      'Schema owner: '||l_owner||CHR(10)||
      'Schema summary:'||CHR(10)||l_schema||CHR(10)||CHR(10)||
      'Business question: '||NVL(p_question,'')||CHR(10)||CHR(10)||
      'Widgets JSON (truncated if very long):'||CHR(10)||
      DBMS_LOB.SUBSTR(p_widgets, 8000)||CHR(10)||CHR(10)||
      'Rules:'||CHR(10)||
      '- Output 4–6 bullet points.'||CHR(10)||
      '- Each bullet is 1–2 sentences and describes a business insight or trend.'||CHR(10)||
      '- Do NOT ask the user to provide the schema again.'||CHR(10)||
      '- Do NOT mention the AI or this prompt. Just the final summary.'||CHR(10)||
      '- Write in the same language as the business question if possible.';

    set_json_headers;

    l_body := '{"model":"'
           || REPLACE(c_default_model,'"','\"')
           || '","input":"'
           || json_escape(l_prompt)
           || '"}';

    l_resp := apex_web_service.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    IF apex_web_service.g_status_code = 200 THEN
      l_txt := get_response_text(l_resp);
    END IF;

    IF l_txt IS NULL THEN
      p_summary := 'Summary is not available for this dashboard.';
    ELSE
      p_summary := l_txt;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_summary := 'Summary generation failed: '||SQLERRM;
  END generate_overall_summary;

  ---------------------------------------------------------------------------
  -- Generate a single chart config + insights (schema-aware)
  ---------------------------------------------------------------------------
  PROCEDURE generate_chart_with_insights(
    p_question   IN  VARCHAR2,
    p_chart_data OUT CLOB,
    p_insights   OUT CLOB,
    p_schema     IN  VARCHAR2
  ) IS
    l_owner   VARCHAR2(128) := UPPER(NVL(p_schema, USER));
    l_schema  CLOB;
    l_prompt  CLOB;
    l_body    CLOB;
    l_resp    CLOB;
    l_txt     CLOB;
    l_prompt_attempt CLOB;
    l_chart_sql CLOB;
    l_valid   BOOLEAN := FALSE;
    l_error   VARCHAR2(4000);
    l_try     PLS_INTEGER := 0;
    l_preview CLOB;
    l_chart_type VARCHAR2(50);
    c_max_attempts CONSTANT PLS_INTEGER := 2;
  BEGIN
    l_schema := build_schema_summary(l_owner, 12000);

    l_prompt :=
      'You are designing a single chart for an Oracle BI dashboard.'||CHR(10)||
      'Schema owner: '||l_owner||CHR(10)||
      'Schema summary:'||CHR(10)||l_schema||CHR(10)||CHR(10)||
      'Business question: '||NVL(p_question,'')||CHR(10)||CHR(10)||
      'Return JSON ONLY in this exact structure:'||CHR(10)||
      '{'||CHR(10)||
      '  "chart": {'||CHR(10)||
      '    "title": "Chart title",'||CHR(10)||
      '    "subtitle": "Short description",'||CHR(10)||
      '    "chartType": "BAR" | "LINE" | "AREA" | "PIE" | "TABLE" | "MAP",'||CHR(10)||
      '    "sql": "SELECT ... FROM '||l_owner||'.TABLE ...",'||CHR(10)||
      '    "color": "#2563eb"'||CHR(10)||
      '  },'||CHR(10)||
      '  "insights": ['||CHR(10)||
      '    "short insight 1",'||CHR(10)||
      '    "short insight 2"'||CHR(10)||
      '  ]'||CHR(10)||
      '}'||CHR(10)||
      'Rules:'||CHR(10)||
      '- Use ONLY tables/views that exist in the schema summary, always prefixed with '||l_owner||'.'||CHR(10)||
      '- The SQL must be valid Oracle and return at least one numeric column and one label/dimension column.'||CHR(10)||
      '- For MAP charts, return LOCATION_NAME (text), LATITUDE (NUMBER), LONGITUDE (NUMBER), VALUE (NUMBER) columns with those exact aliases.'||CHR(10)||
      '- The chart should directly answer or illuminate the business question.'||CHR(10)||
      '- Do NOT include example values or fake constants.';

    WHILE l_try < c_max_attempts AND NOT l_valid LOOP
      l_try := l_try + 1;
      l_prompt_attempt := l_prompt;

      IF l_error IS NOT NULL THEN
        l_prompt_attempt := l_prompt_attempt || CHR(10) ||
          'Previous SQL attempt failed with this Oracle error: ' || l_error || '.' || CHR(10) ||
          'Please fix the SQL and return the JSON in the exact structure again without explanation.';
      END IF;

      set_json_headers;

      l_body := '{"model":"'
             || REPLACE(c_default_model,'"','\"')
             || '","input":"'
             || json_escape(l_prompt_attempt)
             || '"}';

      l_resp := apex_web_service.make_rest_request(
                  p_url                  => 'https://api.openai.com/v1/responses',
                  p_http_method          => 'POST',
                  p_body                 => l_body,
                  p_credential_static_id => 'credentials_for_ai_services'
                );

      IF apex_web_service.g_status_code <> 200 THEN
        l_error := 'HTTP '||apex_web_service.g_status_code;
        EXIT;
      END IF;

      l_txt := get_response_text(l_resp);
      l_txt := normalize_json_block(l_txt);

      IF l_txt IS NULL THEN
        l_error := 'Model returned no JSON payload';
        CONTINUE;
      END IF;

      BEGIN
        SELECT JSON_QUERY(
                 l_txt,
                 '$.chart'
                 RETURNING CLOB NULL ON ERROR NULL ON EMPTY
               )
          INTO p_chart_data
          FROM dual;

        SELECT JSON_QUERY(
                 l_txt,
                 '$.insights'
                 RETURNING CLOB NULL ON ERROR NULL ON EMPTY
               )
          INTO p_insights
          FROM dual;
      EXCEPTION
        WHEN OTHERS THEN
          p_chart_data := NULL;
          p_insights   := '[]';
      END;

      IF p_chart_data IS NULL THEN
        l_error := 'Response did not include chart JSON';
        CONTINUE;
      END IF;

      BEGIN
        SELECT JSON_VALUE(
                 p_chart_data,
                 '$.chartType'
                 RETURNING VARCHAR2(50) NULL ON ERROR NULL ON EMPTY
               )
          INTO l_chart_type
          FROM dual;
      EXCEPTION
        WHEN OTHERS THEN
          l_chart_type := NULL;
      END;

      l_chart_type := UPPER(NVL(l_chart_type, ''));

      BEGIN
        SELECT JSON_VALUE(
                 p_chart_data,
                 '$.sql'
                 RETURNING CLOB NULL ON ERROR NULL ON EMPTY
               )
          INTO l_chart_sql
          FROM dual;
      EXCEPTION
        WHEN OTHERS THEN
          l_chart_sql := NULL;
      END;

      IF l_chart_sql IS NULL THEN
        l_error := 'Chart JSON missing sql';
        CONTINUE;
      END IF;

      IF validate_chart_sql(l_chart_sql, l_error, l_preview, l_chart_type) THEN
        IF l_preview IS NOT NULL THEN
          BEGIN
            SELECT JSON_MERGEPATCH(
                     p_chart_data,
                     l_preview
                   )
              INTO p_chart_data
              FROM dual;
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        END IF;
        l_valid := TRUE;
      END IF;
    END LOOP;

    IF NOT l_valid THEN
      p_chart_data := NULL;
      p_insights   := '[]';
      RETURN;
    END IF;

    IF p_insights IS NULL THEN
      p_insights := '[]';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_chart_data := NULL;
      p_insights   := '[]';
  END generate_chart_with_insights;

  ---------------------------------------------------------------------------
  -- Wrapper: build_chart_data_for_dashboard
  ---------------------------------------------------------------------------
  PROCEDURE build_chart_data_for_dashboard(
    p_question IN  VARCHAR2,
    p_schema   IN  VARCHAR2,
    p_result   OUT CLOB
  ) IS
    l_chart CLOB;
    l_ins   CLOB;
  BEGIN
    generate_chart_with_insights(
      p_question   => p_question,
      p_chart_data => l_chart,
      p_insights   => l_ins,
      p_schema     => p_schema
    );

    IF l_chart IS NULL THEN
      p_result := '{"chart":null,"insights":' || NVL(l_ins, '[]') || '}';
    ELSE
      p_result := '{"chart":' || l_chart || ',"insights":' || NVL(l_ins, '[]') || '}';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_result := '{"chart":null,"insights":[]}';
  END build_chart_data_for_dashboard;

  ---------------------------------------------------------------------------
  PROCEDURE persist_chart_widgets(
    p_dash_id    IN NUMBER,
    p_chart_json IN CLOB
  ) IS
    v_next_y NUMBER := 0;
    FUNCTION has_chart_payload RETURN BOOLEAN IS
    BEGIN
      RETURN p_chart_json IS NOT NULL
         AND JSON_EXISTS(p_chart_json, '$.charts[0]');
    EXCEPTION
      WHEN OTHERS THEN
        RETURN FALSE;
    END;
  BEGIN
    IF p_dash_id IS NULL OR NOT has_chart_payload THEN
      RETURN;
    END IF;

    SELECT NVL(MAX(grid_y + grid_h), 0)
      INTO v_next_y
      FROM widgets
     WHERE dashboard_id = p_dash_id
       AND NVL(UPPER(chart_type), 'X') NOT IN (
             'CHART','BAR','LINE','AREA','PIE','DONUT','DOUGHNUT','MAP','TABLE','RADIALBAR','RADIAL_BAR','SCATTER'
           );

    DELETE FROM widgets
     WHERE dashboard_id = p_dash_id
       AND NVL(UPPER(chart_type), 'X') IN (
             'CHART','BAR','LINE','AREA','PIE','DONUT','DOUGHNUT','MAP','TABLE','RADIALBAR','RADIAL_BAR','SCATTER'
           );

    FOR r IN (
      SELECT jt.rn,
             jt.title,
             jt.chart_type,
             jt.sql_text,
             jt.payload
        FROM JSON_TABLE(
               p_chart_json,
               '$.charts[*]'
               COLUMNS (
                 rn         FOR ORDINALITY,
                 title      VARCHAR2(200)  PATH '$.title',
                 chart_type VARCHAR2(50)   PATH '$.chartType',
                 sql_text   CLOB           PATH '$.sql',
                 payload    CLOB           FORMAT JSON PATH '$'
               )
             ) jt
    ) LOOP
      INSERT INTO widgets (
        dashboard_id,
        title,
        chart_type,
        data_mapping,
        visual_options,
        sql_query,
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
        p_dash_id,
        NVL(r.title, 'Chart ' || r.rn),
        UPPER(NVL(r.chart_type, 'CHART')),
        NULL,
        r.payload,
        r.sql_text,
        0,
        v_next_y,
        12,
        6,
        'MANUAL',
        0,
        0,
        SYSTIMESTAMP,
        SYSTIMESTAMP
      );
      v_next_y := v_next_y + 7;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      apex_debug.message('persist_chart_widgets failed: %s', SQLERRM);
  END persist_chart_widgets;

END myquery_dashboard_ai_pkg;
/
