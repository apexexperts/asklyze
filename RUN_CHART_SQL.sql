-- Ajax callback process called RUN_CHART_SQL
DECLARE
  l_sql      CLOB := apex_application.g_x01;
  l_owner    VARCHAR2(128) := NVL(:P0_DATABASE_SCHEMA, USER);
  l_safe_sql CLOB;
  l_label    VARCHAR2(4000);
  l_value    NUMBER;
  l_cur      SYS_REFCURSOR;

  TYPE t_varchar IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
  TYPE t_number  IS TABLE OF NUMBER       INDEX BY PLS_INTEGER;

  l_labels t_varchar;
  l_values t_number;
  l_idx    PLS_INTEGER := 0;
  c_max_rows CONSTANT PLS_INTEGER := 120;
BEGIN
  -- Basic validation: non-empty SELECT only
  IF l_sql IS NULL THEN
    apex_json.open_object;
    apex_json.write('ok', FALSE);
    apex_json.write('error', 'No SQL provided');
    apex_json.close_object;
    RETURN;
  END IF;

  IF NOT REGEXP_LIKE(TRIM(LOWER(l_sql)), '^select ') THEN
    apex_json.open_object;
    apex_json.write('ok', FALSE);
    apex_json.write('error', 'Only SELECT statements are allowed');
    apex_json.close_object;
    RETURN;
  END IF;

  -- Optional: prevent semicolons for safety
  IF INSTR(l_sql, ';') > 0 THEN
    apex_json.open_object;
    apex_json.write('ok', FALSE);
    apex_json.write('error', 'Semicolons are not allowed in chart SQL');
    apex_json.close_object;
    RETURN;
  END IF;

  -- Run SQL: must return exactly 2 columns (label, value)
  l_safe_sql := l_sql;

  OPEN l_cur FOR l_safe_sql;

  LOOP
    FETCH l_cur INTO l_label, l_value;
    EXIT WHEN l_cur%NOTFOUND OR l_idx >= c_max_rows;

    l_idx := l_idx + 1;
    l_labels(l_idx) := l_label;
    l_values(l_idx) := l_value;
  END LOOP;
  CLOSE l_cur;

  apex_json.open_object;
  apex_json.write('ok', TRUE);

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

  apex_json.close_object;
EXCEPTION
  WHEN OTHERS THEN
    apex_json.open_object;
    apex_json.write('ok', FALSE);
    apex_json.write('error', SQLERRM);
    apex_json.close_object;
END;
