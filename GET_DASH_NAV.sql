DECLARE
  l_json CLOB;
BEGIN

  myquery_navigation_pkg.get_nav_json(
    p_app_id    => :APP_ID,
    p_session   => :APP_SESSION,
    p_user      => :APP_USER,
    p_page_id   => 3,
    p_active_id => :P3_DASH_ID,
    p_schema    => :P0_DATABASE_SCHEMA,
    p_json      => l_json
  );


  IF l_json IS NULL OR DBMS_LOB.GETLENGTH(l_json) = 0 THEN
     l_json := '[]';
  END IF;


  owa_util.mime_header('application/json', FALSE);
  htp.p('Cache-Control: no-cache');
  owa_util.http_header_close;
  

  DECLARE
    l_offset INT := 1;
    l_chunk  VARCHAR2(32000);
    l_len    INT := DBMS_LOB.GETLENGTH(l_json);
  BEGIN
    WHILE l_offset <= l_len LOOP
       l_chunk := DBMS_LOB.SUBSTR(l_json, 8000, l_offset);
       htp.prn(l_chunk);
       l_offset := l_offset + 8000;
    END LOOP;
  END;

EXCEPTION WHEN OTHERS THEN

  owa_util.mime_header('application/json', FALSE);
  owa_util.http_header_close;
  htp.prn('[]');
END;
