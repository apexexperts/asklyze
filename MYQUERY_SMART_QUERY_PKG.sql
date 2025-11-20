create or replace PACKAGE myquery_smart_query_pkg AS
  -- Generate a human-friendly query title
  FUNCTION mk_query_name(p_question IN VARCHAR2, p_sql IN CLOB) RETURN VARCHAR2;

  -- Log executed SQL into SMART_QUERY
  PROCEDURE log_query(
    p_question   IN VARCHAR2,
    p_sql        IN VARCHAR2,
    p_created_by IN VARCHAR2 DEFAULT NULL
  );

  -- OpenAI call with live schema summary (tables/views/columns) 
  PROCEDURE call_openai_generate_sql_schema(
    p_owner       IN  VARCHAR2,                              -- schema owner, e.g. 'MYQUERY'
    p_question    IN  VARCHAR2,                              -- natural question
    p_sql_out     OUT VARCHAR2,                              -- final SELECT (no ;)
    p_model       IN  VARCHAR2 DEFAULT 'gpt-5-2025-08-07', -- model
    p_max_chars   IN  PLS_INTEGER DEFAULT 20000              -- cap schema summary
  );

  PROCEDURE call_openai_generate_sql_schema(
    p_owner       IN  VARCHAR2,
    p_question    IN  VARCHAR2,
    p_sql_out     OUT VARCHAR2,
    p_reason_out  OUT CLOB,
    p_model       IN  VARCHAR2 DEFAULT 'gpt-5-2025-08-07',
    p_max_chars   IN  PLS_INTEGER DEFAULT 20000
  );

  PROCEDURE call_openai_plan_schema(
    p_owner       IN  VARCHAR2,
    p_question    IN  VARCHAR2,
    p_plan_json   OUT CLOB,
    p_model       IN  VARCHAR2 DEFAULT 'gpt-5-2025-08-07',
    p_max_chars   IN  PLS_INTEGER DEFAULT 12000
  );

  procedure load_chat_proc(
    p_chat_id in number,
    p_sql     out clob,
    p_summary out clob
  );

    procedure gen_sql_and_log_json_proc(
    p_owner     in varchar2,
    p_question  in varchar2,
    p_user_id   in varchar2,
    p_sql_out   out varchar2,
    p_summary   out clob,
    p_chat_id   out number
  );

    procedure explain_sql_llm_json_proc(
    p_chat_id     in number,
    p_explanation out clob,
    p_ok          out varchar2,
    p_error       out varchar2
  );

  procedure get_side_menu_proc(
    p_user in varchar2,
    p_chat_id in number,
    p_json out clob
  );

  procedure send_report_email_proc(
    p_to     in varchar2,
    p_subj   in varchar2,
    p_html   in clob,
    p_status out varchar2,
    p_mailid out number,
    p_error  out varchar2
  );

END myquery_smart_query_pkg;
/





create or replace PACKAGE BODY myquery_smart_query_pkg AS

  ------------------------------------------------------------------------------
  -- Title generator
  ------------------------------------------------------------------------------
  FUNCTION mk_query_name(p_question IN VARCHAR2, p_sql IN CLOB) RETURN VARCHAR2 IS
    q      VARCHAR2(4000);
    s      VARCHAR2(4000);
    tbls   VARCHAR2(4000);
    tbl1   VARCHAR2(4000);
    title  VARCHAR2(4000);
  BEGIN
    q := TRIM(p_question);
    IF q IS NOT NULL THEN
      q := REGEXP_REPLACE(q, '[[:space:]]+', ' ');
      q := REGEXP_REPLACE(q, '[\?\.\s]+$','');
      title := SUBSTR(INITCAP(q), 1, 200);
      RETURN title;
    END IF;

    s := DBMS_LOB.SUBSTR(p_sql, 4000, 1);
    tbls := REGEXP_SUBSTR(
              s,
              'from\s+(.+?)(where|group\s+by|order\s+by|union|$)',
              1, 1, 'in', 1
            );
    tbl1 := REGEXP_SUBSTR(NVL(tbls, s), '([A-Z0-9_]+\.)?[A-Z0-9_]+', 1, 1, 'i');

    IF tbl1 IS NULL THEN
      RETURN 'SQL Query';
    END IF;

    title := 'Query on ' || tbl1;

    IF REGEXP_LIKE(s, '\b(sum|avg|count|min|max)\s*\(', 'i')
       OR REGEXP_LIKE(s, '\bgroup\s+by\b', 'i') THEN
      title := title || ' (Aggregated)';
    END IF;

    RETURN SUBSTR(title, 1, 200);
  END mk_query_name;

  ------------------------------------------------------------------------------
  -- Logger
  ------------------------------------------------------------------------------
  PROCEDURE log_query(
    p_question   IN VARCHAR2,
    p_sql        IN VARCHAR2,
    p_created_by IN VARCHAR2 DEFAULT NULL
  ) IS
    l_name VARCHAR2(4000);
    l_src  CLOB;
    l_user VARCHAR2(50);
  BEGIN
    l_name := mk_query_name(p_question, TO_CLOB(p_sql));
    l_src  := TO_CLOB(p_sql);
    l_user := NVL(p_created_by, NVL(V('APP_USER'), USER));

    INSERT INTO SMART_QUERY (QUERY_NAME, QUERY_SOURCE, CREATED_BY, CREATED_DATE)
    VALUES (SUBSTR(l_name, 1, 4000), l_src, SUBSTR(l_user, 1, 50), SYSDATE);
  END log_query;


  ------------------------------------------------------------------------------
  -- OpenAI call with schema summary (your requested version)
  ------------------------------------------------------------------------------
  PROCEDURE call_openai_generate_sql_schema (
    p_owner       IN  VARCHAR2,
    p_question    IN  VARCHAR2,
    p_sql_out     OUT VARCHAR2,
    p_model       IN  VARCHAR2 DEFAULT 'gpt-5-2025-08-07',
    p_max_chars   IN  PLS_INTEGER DEFAULT 20000
  ) AS
    l_owner        VARCHAR2(128) := UPPER(p_owner);
    l_schema       CLOB;
    l_schema_trim  VARCHAR2(32767);
    l_prompt       CLOB;
    l_prompt_esc   CLOB;
    l_body         CLOB;
    l_resp         CLOB;
    v_sql          VARCHAR2(4000);

    PROCEDURE append_line(p_txt IN VARCHAR2) IS
    BEGIN
      IF l_schema IS NULL THEN DBMS_LOB.createtemporary(l_schema, TRUE); END IF;
      DBMS_LOB.writeappend(l_schema, LENGTH(p_txt||CHR(10)), p_txt||CHR(10));
    END;

    FUNCTION json_escape(p IN CLOB) RETURN CLOB IS
      l CLOB;
    BEGIN
      l := p;
      l := REPLACE(l, '\', '\\');  -- backslash
      l := REPLACE(l, '"', '\"');  -- quotes
      l := REPLACE(l, CHR(13), '\r');
      l := REPLACE(l, CHR(10), '\n');
      l := REPLACE(l, CHR(9),  '\t');
      RETURN l;
    END;
  BEGIN
    -- 1) Tables
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
               || CASE WHEN c.nullable = 'N' THEN ' NN' ELSE '' END
               , ', '
             ) WITHIN GROUP (ORDER BY c.column_id) AS cols
      FROM   all_tables t
      JOIN   all_tab_columns c
             ON c.owner = t.owner AND c.table_name = t.table_name
      WHERE  t.owner = l_owner
      GROUP  BY t.table_name
      ORDER  BY t.table_name
    ) LOOP
      IF l_schema IS NULL OR DBMS_LOB.getlength(l_schema) < p_max_chars THEN
        append_line('TABLE '||l_owner||'.'||r.table_name||': '||r.cols);
      END IF;
    END LOOP;

    -- 2) Views
    FOR r IN (
      SELECT v.view_name AS table_name,
             LISTAGG(c.column_name || ' ' || c.data_type, ', ')
               WITHIN GROUP (ORDER BY c.column_id) AS cols
      FROM   all_views v
      JOIN   all_tab_columns c
             ON c.owner = v.owner AND c.table_name = v.view_name
      WHERE  v.owner = l_owner
      GROUP  BY v.view_name
      ORDER  BY v.view_name
    ) LOOP
      IF l_schema IS NULL OR DBMS_LOB.getlength(l_schema) < p_max_chars THEN
        append_line('VIEW '||l_owner||'.'||r.table_name||': '||r.cols);
      END IF;
    END LOOP;

    IF l_schema IS NULL THEN
      DBMS_LOB.createtemporary(l_schema, TRUE);
      append_line('No tables/views found for owner '||l_owner);
    END IF;

    -- 3) Prompt
    l_schema_trim := DBMS_LOB.SUBSTR(l_schema, p_max_chars);
    l_prompt := 'You are an Oracle SQL generator. Use ONLY schema '||l_owner||'. '
             || 'Always prefix tables/views with '||l_owner||'. '
             || 'Return exactly ONE Oracle SELECT (no DML/DDL, no explanations, no code fences, no semicolon). '
             || 'Use ANSI joins and correct date functions.'||CHR(10)||CHR(10)
             || 'SCHEMA SUMMARY:'||CHR(10)||l_schema_trim||CHR(10)||CHR(10)
             || 'QUESTION: '||p_question;

    l_prompt_esc := json_escape(l_prompt);

    -- 4) JSON body
    l_body := '{"model":"'
           || REPLACE(p_model, '"','\"')
           || '","input":"'
           || l_prompt_esc
           || '"}';

    -- 5) Call OpenAI (Authorization via credentials_for_ai_services)
    l_resp := APEX_WEB_SERVICE.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    IF APEX_WEB_SERVICE.g_status_code <> 200 THEN
      p_sql_out := 'HTTP '||APEX_WEB_SERVICE.g_status_code||': '||SUBSTR(l_resp,1,4000);
      RETURN;
    END IF;

    -- 6) Extract SQL from output[type='message']
    BEGIN
      SELECT t.txt
        INTO v_sql
        FROM JSON_TABLE(
               l_resp,
               '$.output[*]'
               COLUMNS (
                 typ  VARCHAR2(20)     PATH '$.type',
                 txt  VARCHAR2(4000)   PATH '$.content[0].text'
               )
             ) t
       WHERE t.typ = 'message'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_sql := NULL;
    END;

    -- Fallbacks
    IF v_sql IS NULL THEN
      SELECT JSON_VALUE(
               l_resp,
               '$.output_text[0]'
               RETURNING VARCHAR2(4000)
               NULL ON ERROR NULL ON EMPTY
             )
        INTO v_sql
        FROM dual;
    END IF;

    IF v_sql IS NULL THEN
      SELECT JSON_VALUE(
               l_resp,
               '$.choices[0].message.content'
               RETURNING VARCHAR2(4000)
               NULL ON ERROR NULL ON EMPTY
             )
        INTO v_sql
        FROM dual;
    END IF;

    IF v_sql IS NULL THEN
      p_sql_out := SUBSTR(l_resp,1,4000);
      RETURN;
    END IF;

    -- 7) Cleanup
    v_sql := REGEXP_REPLACE(v_sql, '^\s*```sql\s*', '');
    v_sql := REGEXP_REPLACE(v_sql, '^\s*```\s*', '');
    v_sql := REGEXP_REPLACE(v_sql, '\s*```\s*$', '');
    v_sql := REGEXP_REPLACE(v_sql, ';\s*$', '');

    p_sql_out := v_sql;
  END call_openai_generate_sql_schema;


    ------------------------------------------------------------------------------
  -- OpenAI call with schema summary + REASONING (Overload)
  ------------------------------------------------------------------------------

  PROCEDURE call_openai_generate_sql_schema (
    p_owner       IN  VARCHAR2,
    p_question    IN  VARCHAR2,
    p_sql_out     OUT VARCHAR2,
    p_reason_out  OUT CLOB,
    p_model       IN  VARCHAR2 DEFAULT 'gpt-5-2025-08-07',
    p_max_chars   IN  PLS_INTEGER DEFAULT 20000
  ) AS
    l_owner        VARCHAR2(128) := UPPER(p_owner);
    l_schema       CLOB;
    l_schema_trim  VARCHAR2(32767);
    l_prompt       CLOB;
    l_prompt_esc   CLOB;
    l_body         CLOB;
    l_resp         CLOB;
    v_sql          VARCHAR2(4000);

    PROCEDURE append_line(p_txt IN VARCHAR2) IS
    BEGIN
      IF l_schema IS NULL THEN DBMS_LOB.createtemporary(l_schema, TRUE); END IF;
      DBMS_LOB.writeappend(l_schema, LENGTH(p_txt||CHR(10)), p_txt||CHR(10));
    END;

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
  BEGIN
    -- 1) Tables
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
               || CASE WHEN c.nullable = 'N' THEN ' NN' ELSE '' END
               , ', '
             ) WITHIN GROUP (ORDER BY c.column_id) AS cols
      FROM   all_tables t
      JOIN   all_tab_columns c
             ON c.owner = t.owner AND c.table_name = t.table_name
      WHERE  t.owner = l_owner
      GROUP  BY t.table_name
      ORDER  BY t.table_name
    ) LOOP
      IF l_schema IS NULL OR DBMS_LOB.getlength(l_schema) < p_max_chars THEN
        append_line('TABLE '||l_owner||'.'||r.table_name||': '||r.cols);
      END IF;
    END LOOP;

    -- 2) Views
    FOR r IN (
      SELECT v.view_name AS table_name,
             LISTAGG(c.column_name || ' ' || c.data_type, ', ')
               WITHIN GROUP (ORDER BY c.column_id) AS cols
      FROM   all_views v
      JOIN   all_tab_columns c
             ON c.owner = v.owner AND c.table_name = v.view_name
      WHERE  v.owner = l_owner
      GROUP  BY v.view_name
      ORDER  BY v.view_name
    ) LOOP
      IF l_schema IS NULL OR DBMS_LOB.getlength(l_schema) < p_max_chars THEN
        append_line('VIEW '||l_owner||'.'||r.table_name||': '||r.cols);
      END IF;
    END LOOP;

    IF l_schema IS NULL THEN
      DBMS_LOB.createtemporary(l_schema, TRUE);
      append_line('No tables/views found for owner '||l_owner);
    END IF;

    -- 3) Prompt
    l_schema_trim := DBMS_LOB.SUBSTR(l_schema, p_max_chars);
    l_prompt := 'You are an Oracle SQL generator. Use ONLY schema '||l_owner||'. '
             || 'Always prefix tables/views with '||l_owner||'. '
             || 'Return exactly ONE Oracle SELECT (no DML/DDL, no explanations, no code fences, no semicolon). '
             || 'Use ANSI joins and correct date functions.'||CHR(10)||CHR(10)
             || 'SCHEMA SUMMARY:'||CHR(10)||l_schema_trim||CHR(10)||CHR(10)
             || 'QUESTION: '||p_question;

    l_prompt_esc := json_escape(l_prompt);


    l_body := '{"model":"'
           || REPLACE(p_model, '"','\"')
           || '","reasoning":{"effort":"medium"}'
           || ',"temperature":0.2'
           || ',"input":"'
           || l_prompt_esc
           || '"}';

    -- 5) Call OpenAI
    l_resp := APEX_WEB_SERVICE.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    IF APEX_WEB_SERVICE.g_status_code <> 200 THEN
      p_sql_out    := 'HTTP '||APEX_WEB_SERVICE.g_status_code||': '||SUBSTR(l_resp,1,4000);
      p_reason_out := NULL;
      RETURN;
    END IF;

    -- 6) Extract SQL (message)
    BEGIN
      SELECT t.txt
        INTO v_sql
        FROM JSON_TABLE(
               l_resp,
               '$.output[*]'
               COLUMNS (
                 typ  VARCHAR2(20) PATH '$.type',
                 txt  VARCHAR2(4000) PATH '$.content[0].text'
               )
             ) t
       WHERE t.typ = 'message'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_sql := NULL;
    END;

    -- Fallbacks
    IF v_sql IS NULL THEN
      SELECT JSON_VALUE(l_resp,'$.output_text[0]' RETURNING VARCHAR2(4000) NULL ON ERROR NULL ON EMPTY)
        INTO v_sql FROM dual;
    END IF;
    IF v_sql IS NULL THEN
      SELECT JSON_VALUE(l_resp,'$.choices[0].message.content' RETURNING VARCHAR2(4000) NULL ON ERROR NULL ON EMPTY)
        INTO v_sql FROM dual;
    END IF;


    BEGIN
      SELECT t.txt
        INTO p_reason_out
        FROM JSON_TABLE(
               l_resp,
               '$.output[*]'
               COLUMNS (
                 typ  VARCHAR2(20) PATH '$.type',
                 txt  CLOB         PATH '$.content[0].text'
               )
             ) t
       WHERE t.typ = 'reasoning'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_reason_out := NULL;
    END;
    IF p_reason_out IS NULL THEN
      SELECT JSON_VALUE(l_resp,'$.reasoning.content[0].text' RETURNING CLOB NULL ON ERROR NULL ON EMPTY)
        INTO p_reason_out FROM dual;
    END IF;

    -- 8) Cleanup & return
    IF v_sql IS NULL THEN
      p_sql_out := SUBSTR(l_resp,1,4000);
      RETURN;
    END IF;
    v_sql := REGEXP_REPLACE(v_sql, '^\s*```sql\s*', '');
    v_sql := REGEXP_REPLACE(v_sql, '^\s*```\s*', '');
    v_sql := REGEXP_REPLACE(v_sql, '\s*```\s*$', '');
    v_sql := REGEXP_REPLACE(v_sql, ';\s*$', '');

    p_sql_out := v_sql;
  END call_openai_generate_sql_schema;







  PROCEDURE call_openai_plan_schema(
    p_owner       IN  VARCHAR2,
    p_question    IN  VARCHAR2,
    p_plan_json   OUT CLOB,
    p_model       IN  VARCHAR2 DEFAULT 'gpt-5-2025-08-07',
    p_max_chars   IN  PLS_INTEGER DEFAULT 12000
  ) IS
    l_owner  VARCHAR2(128) := UPPER(p_owner);
    l_schema CLOB;
    l_prompt CLOB;
    l_body   CLOB;
    l_resp   CLOB;
    v_txt    CLOB;

    PROCEDURE append_line(p_txt IN VARCHAR2) IS
    BEGIN
      IF l_schema IS NULL THEN DBMS_LOB.createtemporary(l_schema, TRUE); END IF;
      DBMS_LOB.writeappend(l_schema, LENGTH(p_txt||CHR(10)), p_txt||CHR(10));
    END;
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
  BEGIN

    FOR r IN (
      SELECT t.table_name,
             LISTAGG(c.column_name||' '||c.data_type, ', ')
               WITHIN GROUP (ORDER BY c.column_id) AS cols
      FROM   all_tables t
      JOIN   all_tab_columns c ON c.owner=t.owner AND c.table_name=t.table_name
      WHERE  t.owner = l_owner
      GROUP  BY t.table_name
      ORDER  BY t.table_name
      FETCH FIRST 40 ROWS ONLY
    ) LOOP
      IF l_schema IS NULL OR DBMS_LOB.getlength(l_schema) < p_max_chars THEN
        append_line('TABLE '||l_owner||'.'||r.table_name||': '||r.cols);
      END IF;
    END LOOP;

    IF l_schema IS NULL THEN
      DBMS_LOB.createtemporary(l_schema, TRUE);
      append_line('No tables/views found for owner '||l_owner);
    END IF;

    -- Prompt يفرض JSON بسيط
    l_prompt := 'You plan SQL generation for Oracle.'||CHR(10)||
                'Provide a brief plan as JSON only (no extra text): '||
                '{"steps":[short strings],"tables":[OWNER.TABLE], "columns":[OWNER.TABLE.COLUMN], "notes":[strings]}.'||CHR(10)||
                'SCHEMA SUMMARY:'||CHR(10)||DBMS_LOB.SUBSTR(l_schema, p_max_chars)||CHR(10)||
                'QUESTION: '||p_question;

    -- enforce JSON via response_format
    l_body := '{"model":"'
           || REPLACE(p_model,'"','\"')
           || '","response_format":{"type":"json_object"}'
           || ',"temperature":0'
           || ',"input":"'
           || json_escape(l_prompt)
           || '"}';

    l_resp := APEX_WEB_SERVICE.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    IF APEX_WEB_SERVICE.g_status_code <> 200 THEN
      p_plan_json := '{"steps":["HTTP '||APEX_WEB_SERVICE.g_status_code||'"],"tables":[],"columns":[],"notes":[]}';
      RETURN;
    END IF;

  
    SELECT JSON_VALUE(l_resp,'$.output[0].content[0].text' RETURNING CLOB NULL ON ERROR NULL ON EMPTY)
      INTO v_txt FROM dual;

    IF v_txt IS NULL THEN
      SELECT JSON_VALUE(l_resp,'$.output_text[0]' RETURNING CLOB NULL ON ERROR NULL ON EMPTY)
        INTO v_txt FROM dual;
    END IF;

    IF v_txt IS NULL THEN
      v_txt := '{"steps":["No plan"],"tables":[],"columns":[],"notes":[]}';
    END IF;

   
    DECLARE l_ok NUMBER;
    BEGIN
      SELECT CASE WHEN JSON_EXISTS(v_txt,'$') THEN 1 ELSE 0 END INTO l_ok FROM dual;
      IF l_ok = 1 THEN
        p_plan_json := v_txt;
      ELSE
        apex_json.initialize_clob_output;
        apex_json.open_object;
          apex_json.open_array('steps');   apex_json.write(NVL(v_txt,'No plan')); apex_json.close_array;
          apex_json.open_array('tables');  apex_json.close_array;
          apex_json.open_array('columns'); apex_json.close_array;
          apex_json.open_array('notes');   apex_json.close_array;
        apex_json.close_object;
        p_plan_json := apex_json.get_clob_output;
        apex_json.free_output;
      END IF;
    END;
  END call_openai_plan_schema;


  ------------------------------------------------------------------------------ 
  -- Load chat by ID
  ------------------------------------------------------------------------------ 

------------------------------------------------------------------------------
-- Load chat by ID (returns SQL + Summary)
------------------------------------------------------------------------------
procedure load_chat_proc(
    p_chat_id in number,
    p_sql     out clob,
    p_summary out clob
) is
begin
    if p_chat_id is not null then
        begin
            select query_source, chat_summary
              into p_sql, p_summary
              from smart_query
             where id = p_chat_id;
        exception
            when no_data_found then
                p_sql := null;
                p_summary := null;
        end;
    else
        p_sql := null;
        p_summary := null;
    end if;
end load_chat_proc;



 ------------------------------------------------------------------------------ 
  -- Generate SQL via OpenAI, log into SMART_QUERY, and return summary as JSON
  ------------------------------------------------------------------------------ 
  procedure gen_sql_and_log_json_proc(
    p_owner     in varchar2,
    p_question  in varchar2,
    p_user_id   in varchar2,
    p_sql_out   out varchar2,
    p_summary   out clob,
    p_chat_id   out number
  ) is
    l_name    varchar2(4000);
    l_prompt  clob;
    l_body    clob;
    l_resp    clob;
    v_text    clob;

    function json_escape(p in clob) return clob is
      l clob;
    begin
      l := p;
      l := replace(l, '\', '\\');
      l := replace(l, '"', '\"');
      l := replace(l, chr(13), '\r');
      l := replace(l, chr(10), '\n');
      l := replace(l, chr(9),  '\t');
      return l;
    end;
  begin
    -- 1) Generate SQL
    myquery_smart_query_pkg.call_openai_generate_sql_schema(
      p_owner    => p_owner,
      p_question => p_question,
      p_sql_out  => p_sql_out
    );

    -- 2) Generate title
    l_name := myquery_smart_query_pkg.mk_query_name(p_question, to_clob(p_sql_out));

    -- 3) Build prompt for explanation
    l_prompt :=
      'Explain the following Oracle SQL query for a business user.'||chr(10)||
      'Reply **in the same language as this question** (auto-detect): '||nvl(p_question,'(none)')||chr(10)||chr(10)||
      'Return **GitHub-Flavored Markdown** only (no outer code fences). Use clear sections:'||chr(10)||
      '- # Summary'||chr(10)||
      '- ## Sources (tables/views)'||chr(10)||
      '- ## Filters & Joins'||chr(10)||
      '- ## Aggregations / Window functions (if any)'||chr(10)||
      '- ## Ordering / Limits (if any)'||chr(10)||
      '- ## How to modify (1–3 quick ideas)'||chr(10)||
      'Use `inline code` for identifiers; don’t repeat the full SQL.'||chr(10)||chr(10)||
      'SQL:'||chr(10)||p_sql_out;

    l_body := '{"model":"gpt-4o-mini",'
           ||  '"temperature":0.2,'
           ||  '"max_output_tokens":400,'
           ||  '"input":"'|| json_escape(l_prompt) ||'"}';

    l_resp := apex_web_service.make_rest_request(
                p_url                  => 'https://api.openai.com/v1/responses',
                p_http_method          => 'POST',
                p_body                 => l_body,
                p_credential_static_id => 'credentials_for_ai_services'
              );

    if apex_web_service.g_status_code = 200 then
      begin
        select t.txt into v_text
          from json_table(
                 l_resp, '$.output[*]'
                 columns (typ varchar2(30) path '$.type',
                          txt clob        path '$.content[0].text')
               ) t
         where t.typ = 'message' and rownum = 1;
      exception
        when no_data_found then 
          select json_value(l_resp,'$.output_text[0]' returning clob null on error null on empty)
            into v_text from dual;
      end;

      if v_text is null then
        select json_value(l_resp,'$.choices[0].message.content' returning clob null on error null on empty)
          into v_text from dual;
      end if;
    end if;

    if v_text is null then
      p_summary := '**User:** '||nvl(p_question, '(no question)')||chr(10)||chr(10)||
                   '_Could not generate explanation._';
    else
      p_summary := v_text;
    end if;

    -- 4) Insert into SMART_QUERY
    insert into smart_query (query_name, query_source, chat_summary, created_by, created_date)
    values (substr(l_name,1,4000), to_clob(p_sql_out), p_summary, substr(nvl(p_user_id,user),1,50), sysdate)
    returning id into p_chat_id;

  exception
    when others then
      p_sql_out := null;
      p_summary := sqlerrm;
      p_chat_id := null;
  end gen_sql_and_log_json_proc;

  ------------------------------------------------------------------------------ 
  -- Return stored LLM explanation for a given chat_id
  ------------------------------------------------------------------------------ 
  procedure explain_sql_llm_json_proc(
    p_chat_id     in number,
    p_explanation out clob,
    p_ok          out varchar2,
    p_error       out varchar2
  ) is
  begin
    select chat_summary
      into p_explanation
      from smart_query
     where id = p_chat_id;

    p_ok := 'true';
    p_error := null;

  exception
    when no_data_found then
      p_ok := 'false';
      p_error := 'No chat found with ID: '||p_chat_id;
      p_explanation := null;
    when others then
      p_ok := 'false';
      p_error := substr(sqlerrm,1,2000);
      p_explanation := null;
  end explain_sql_llm_json_proc;

  ------------------------------------------------------------------------------ 
  -- Build side menu JSON (static items + chat history grouped by date)
  ------------------------------------------------------------------------------ 
procedure get_side_menu_proc(
    p_user    in varchar2,
    p_chat_id in number,
    p_json    out clob
) is
  l_page_id number := to_number(nvl(v('APP_PAGE_ID'),0));
begin
  if l_page_id = 3 then
    -- Dashboard Builder (Page 3): only dashboards + "New Dashboard" + "Query Builder"
    select json_arrayagg(
             json_object(
                 'id'         value id,
                 'title'      value label,
                 'target'     value target,
                 'icon'       value icon_css,
                 'parent_id'  value parent_id,
                 'is_current' value is_current,
                 'is_header'  value is_header
             )
             order by sort_key, sort_date desc, label
           )
      into p_json
      from (
        -- New Dashboard
        select 1000 as id,
               'New Dashboard' as label,
               'f?p='||v('APP_ID')||':3:'||v('APP_SESSION')||'::NO::P3_DASH_ID:' as target,
               'fa fa-dashboard' as icon_css,
               null as parent_id,
               'NO' as is_current,
               'NO' as is_header,
               1 as sort_key,
               null as sort_date
          from dual
        union all
        -- Query Builder link
        select 1002,
               'Report Builder' as label,
               'f?p='||v('APP_ID')||':1:'||v('APP_SESSION') as target,
               'fa fa-terminal' as icon_css,
               null,
               'NO',
               'NO',
               2,
               null
          from dual
      union all
        -- Ask your files link
        select 1003,
               'Ask your files' as label,
               'f?p='||v('APP_ID')||':2:'||v('APP_SESSION') as target,
               'fa fa-files' as icon_css,
               null,
               'NO',
               'NO',
               2,
               null
          from dual
        union all
        -- Dashboard History header + groups
        select 3000, 'Dashboard History', null, null, null, 'NO', 'YES', 10, null from dual
        union all
        select 3100, 'Today',           null, null, 3000, 'NO', 'YES', 11, null from dual
        union all
        select 3200, 'Last 30 days',    null, null, 3000, 'NO', 'YES', 12, null from dual
        union all
        -- Dashboard items
        select d.id                                                   as id,
               substr(nvl(d.name,'(untitled dashboard)'),1,60)        as label,
               'f?p='||v('APP_ID')||':3:'||v('APP_SESSION')||'::NO::P3_DASH_ID:'||d.id as target,
               'fa fa-dashboard'                                      as icon_css,
               case
                 when trunc(d.created_at) = trunc(sysdate) then 3100
                 when d.created_at >= trunc(sysdate) - 30 then 3200
                 else 3200
               end                                                    as parent_id,
               case when to_char(p_chat_id) = to_char(d.id)
                    then 'YES' else 'NO' end                          as is_current,
               'NO'                                                   as is_header,
               100000                                                 as sort_key,
               d.created_at                                           as sort_date
          from dashboards d
      );
  else
    -- Query Builder (Page 1 and others): only chats + "New Chat" + "Dashboard Builder"
    select json_arrayagg(
             json_object(
                 'id'         value id,
                 'title'      value label,
                 'target'     value target,
                 'icon'       value icon_css,
                 'parent_id'  value parent_id,
                 'is_current' value is_current,
                 'is_header'  value is_header
             )
             order by sort_key, sort_date desc, label
           )
      into p_json
      from (
        -- New Chat
        select 1000              as id,
               'New Chat'        as label,
               '#new'            as target,
               'fa fa-plus'      as icon_css,
               null              as parent_id,
               'NO'              as is_current,
               'NO'              as is_header,
               1                 as sort_key,
               null              as sort_date
          from dual
        union all
        -- Dashboard Builder link
        select 1001,
               'Dashboard Builder',
               'f?p='||v('APP_ID')||':3:'||v('APP_SESSION'),
               'fa fa-dashboard',
               null,
               'NO',
               'NO',
               2,
               null
          from dual
       union all
        -- Ask your files link
        select 1003,
               'Ask your files',
               'f?p='||v('APP_ID')||':2:'||v('APP_SESSION'),
               'fa fa-files',
               null,
               'NO',
               'NO',
               2,
               null
          from dual
        union all
        -- Chat History header + groups
        select 2000, 'Chat History',  null, null, null, 'NO', 'YES', 10, null from dual
        union all
        select 2100, 'Today',         null, null, 2000, 'NO', 'YES', 11, null from dual
        union all
        select 2200, 'Last 30 days',  null, null, 2000, 'NO', 'YES', 12, null from dual
        union all
        -- Chat items
        select q.id                                        as id,
               substr(nvl(q.query_name,'(untitled)'),1,60) as label,
               '#chat-'||to_char(q.id)                     as target,
               'fa-regular fa-message'                     as icon_css,
               case
                 when q.created_date >= trunc(sysdate) then 2100
                 when q.created_date >= trunc(sysdate) - 30 then 2200
                 else 2200
               end                                         as parent_id,
               case when to_char(p_chat_id) = to_char(q.id)
                    then 'YES' else 'NO' end               as is_current,
               'NO'                                        as is_header,
               100000                                      as sort_key,
               q.created_date                              as sort_date
          from smart_query q
         where q.created_by = nvl(p_user, user)
      );
  end if;
exception
  when others then
    p_json := '[]';
end get_side_menu_proc;



  ------------------------------------------------------------------------------ 
  -- Send SQL report via APEX_MAIL
  ------------------------------------------------------------------------------ 
  procedure send_report_email_proc(
    p_to     in varchar2,
    p_subj   in varchar2,
    p_html   in clob,
    p_status out varchar2,
    p_mailid out number,
    p_error  out varchar2
  ) is
  begin
    if p_to is null then
      p_status := 'error';
      p_error  := 'Missing recipient';
      p_mailid := null;
      return;
    end if;

    p_mailid := apex_mail.send(
                  p_to        => p_to,
                  p_from      => 'sender@example.com',
                  p_subj      => nvl(p_subj, 'SQL Report'),
                  p_body      => null,
                  p_body_html => p_html
                );

    apex_mail.push_queue;

    p_status := 'ok';
    p_error  := null;

  exception
    when others then
      p_status := 'error';
      p_mailid := null;
      p_error  := substr(sqlerrm,1,2000);
  end send_report_email_proc;


END myquery_smart_query_pkg;
/
