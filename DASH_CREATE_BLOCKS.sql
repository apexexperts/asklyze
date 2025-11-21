-- Ajax callback process called DASH_CREATE_BLOCKS
-- This version ensures the question is captured from multiple sources
DECLARE
  v_plan        CLOB := :P3_PLAN_JSON;
  v_question    VARCHAR2(4000) := :P3_QUESTION;
  v_schema      VARCHAR2(128) := :P0_DATABASE_SCHEMA;
  v_dash_title  VARCHAR2(1000);
  v_dash_id     NUMBER;
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
  IF v_plan IS NULL THEN
    apex_json.initialize_clob_output;
    apex_json.open_object;
      apex_json.write('ok', false);
      apex_json.write('error', 'P3_PLAN_JSON is NULL');
    apex_json.close_object;
    l_out := apex_json.get_clob_output; 
    apex_json.free_output; 
    out_json(l_out);
    RETURN;
  END IF;

  -- Try multiple sources for the question
  -- 1. First try the bound variable
  IF v_question IS NULL OR TRIM(v_question) IS NULL THEN
    -- 2. Try to get from x01 parameter (passed from JavaScript)
    v_question := apex_application.g_x01;
  END IF;
  
  IF v_question IS NULL OR TRIM(v_question) IS NULL THEN
    -- 3. Try to get from session state
    v_question := apex_util.get_session_state('P3_QUESTION');
  END IF;
  
  IF v_question IS NULL OR TRIM(v_question) IS NULL THEN
    -- 4. Try to extract from the plan JSON
    BEGIN
      SELECT JSON_VALUE(v_plan, '$.title')
      INTO v_question
      FROM dual;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END IF;

  -- Use user's question as dashboard title, or fallback to 'AI Dashboard'
  v_dash_title := SUBSTR(NVL(TRIM(v_question), 'AI Dashboard'), 1, 1000);

  -- Create dashboard with NAME (question) and OWNER_USER_ID (schema)
  INSERT INTO DASHBOARDS (
    NAME,           -- User's question
    DESCRIPTION,    -- Full question
    OWNER_USER_ID,  -- Selected schema from P0_DATABASE_SCHEMA
    IS_PUBLIC, 
    CREATED_AT, 
    UPDATED_AT
  )
  VALUES (
    v_dash_title,   -- The question as title
    v_question,     -- Full question as description
    v_schema,       -- The database schema
    'N', 
    SYSTIMESTAMP, 
    SYSTIMESTAMP
  )
  RETURNING ID INTO v_dash_id;

  -- Set page item so all following processes see the ID
  APEX_UTIL.SET_SESSION_STATE('P3_DASH_ID', v_dash_id);

  -- Return success
  apex_json.initialize_clob_output;
  apex_json.open_object;
    apex_json.write('ok', true);
    apex_json.write('dashboardId', v_dash_id);
    apex_json.write('title', v_dash_title);
    apex_json.write('question', v_question);
    apex_json.write('schema', v_schema);
    apex_json.write('blocksCreated', 0);
    apex_json.write('message', 'Dashboard created. Question: ' || SUBSTR(v_dash_title, 1, 50) || '... Schema: ' || v_schema);
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
