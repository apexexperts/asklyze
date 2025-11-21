create or replace PACKAGE myquery_navigation_pkg AS


    PROCEDURE get_nav_json (
        p_app_id      IN NUMBER,
        p_session     IN NUMBER,
        p_user        IN VARCHAR2,
        p_page_id     IN NUMBER,
        p_active_id   IN VARCHAR2 DEFAULT NULL, 
        p_schema      IN VARCHAR2 DEFAULT NULL, 
        p_json        OUT CLOB
    );

END myquery_navigation_pkg;
/






create or replace PACKAGE BODY myquery_navigation_pkg AS

    PROCEDURE get_nav_json (
        p_app_id      IN NUMBER,
        p_session     IN NUMBER,
        p_user        IN VARCHAR2,
        p_page_id     IN NUMBER,
        p_active_id   IN VARCHAR2 DEFAULT NULL,
        p_schema      IN VARCHAR2 DEFAULT NULL,
        p_json        OUT CLOB
    ) IS
    BEGIN
        -- ==========================================================
        -- منطق صفحة 3: DASHBOARD BUILDER
        -- ==========================================================
        IF p_page_id = 3 THEN
            SELECT COALESCE(
                     json_arrayagg(
                         json_object(
                             'id'         VALUE id,
                             'title'      VALUE label,
                             'target'     VALUE target,
                             'icon'       VALUE icon_css,
                             'parent_id'  VALUE parent_id,
                             'is_current' VALUE is_current,
                             'is_header'  VALUE is_header
                         )
                         ORDER BY sort_key, sort_date DESC, label
                         RETURNING CLOB
                     ),
                     TO_CLOB('[]')
                   )
              INTO p_json
              FROM (
                -- 1. الروابط الثابتة
                SELECT 1000 AS id, 'New Dashboard' AS label, '#new' AS target, 'fa fa-plus-square-o' AS icon_css, NULL AS parent_id, 'NO' AS is_current, 'NO' AS is_header, 1 AS sort_key, NULL AS sort_date FROM DUAL
                UNION ALL
                SELECT 1002, 'Report Builder', 'f?p='||p_app_id||':1:'||p_session, 'fa fa-table', NULL, 'NO', 'NO', 2, NULL FROM DUAL
                UNION ALL
                SELECT 1003, 'Ask your files', 'f?p='||p_app_id||':2:'||p_session, 'fa fa-file-text-o', NULL, 'NO', 'NO', 3, NULL FROM DUAL
                UNION ALL
                
                -- 2. العناوين
                SELECT 3000, 'Dashboard History', NULL, NULL, NULL, 'NO', 'YES', 10, NULL FROM DUAL
                UNION ALL
                SELECT 3100, 'Today', NULL, NULL, 3000, 'NO', 'YES', 11, NULL FROM DUAL
                UNION ALL
                SELECT 3200, 'Last 30 days', NULL, NULL, 3000, 'NO', 'YES', 12, NULL FROM DUAL
                UNION ALL
                
                -- 3. سجل الداشبورد (الفلترة الحاسمة هنا)
                SELECT d.id AS id,
                       SUBSTR(NVL(d.name,'(untitled)'),1,60) AS label,
                       '#dash-'||d.id AS target,
                       'fa fa-tachometer' AS icon_css,
                       CASE WHEN TRUNC(d.created_at) = TRUNC(SYSDATE) THEN 3100 ELSE 3200 END AS parent_id,
                       CASE WHEN TO_CHAR(p_active_id) = TO_CHAR(d.id) THEN 'YES' ELSE 'NO' END AS is_current,
                       'NO' AS is_header, 100000 AS sort_key, d.created_at AS sort_date
                  FROM dashboards d
                 -- هنا الفلترة بناءً على تأكيدك أن OWNER_USER_ID هو السكيما
                 WHERE (p_schema IS NULL OR UPPER(d.OWNER_USER_ID) = UPPER(p_schema))
              );

        -- ==========================================================
        -- منطق صفحة 1: REPORT BUILDER
        -- ==========================================================
        ELSE 
            SELECT COALESCE(
                     json_arrayagg(
                         json_object(
                             'id'         VALUE id,
                             'title'      VALUE label,
                             'target'     VALUE target,
                             'icon'       VALUE icon_css,
                             'parent_id'  VALUE parent_id,
                             'is_current' VALUE is_current,
                             'is_header'  VALUE is_header
                         )
                         ORDER BY sort_key, sort_date DESC, label
                         RETURNING CLOB
                     ),
                     TO_CLOB('[]')
                   )
              INTO p_json
              FROM (
                SELECT 1000 AS id, 'New Chat' AS label, '#new' AS target, 'fa fa-comment-o' AS icon_css, NULL AS parent_id, 'NO' AS is_current, 'NO' AS is_header, 1 AS sort_key, NULL AS sort_date FROM DUAL
                UNION ALL SELECT 1001, 'Dashboard Builder', 'f?p='||p_app_id||':3:'||p_session, 'fa fa-tachometer', NULL, 'NO', 'NO', 2, NULL FROM DUAL
                UNION ALL SELECT 1003, 'Ask your files', 'f?p='||p_app_id||':2:'||p_session, 'fa fa-file-text-o', NULL, 'NO', 'NO', 3, NULL FROM DUAL
                UNION ALL SELECT 2000, 'Chat History', NULL, NULL, NULL, 'NO', 'YES', 10, NULL FROM DUAL
                UNION ALL SELECT 2100, 'Today', NULL, NULL, 2000, 'NO', 'YES', 11, NULL FROM DUAL
                UNION ALL SELECT 2200, 'Last 30 days', NULL, NULL, 2000, 'NO', 'YES', 12, NULL FROM DUAL
                UNION ALL
                SELECT q.id, SUBSTR(NVL(q.query_name,'(untitled)'),1,60), '#chat-'||q.id, 'fa fa-comments-o', CASE WHEN q.created_date >= TRUNC(SYSDATE) THEN 2100 ELSE 2200 END, CASE WHEN TO_CHAR(p_active_id) = TO_CHAR(q.id) THEN 'YES' ELSE 'NO' END, 'NO', 100000, q.created_date
                  FROM smart_query q 
                 WHERE q.created_by = NVL(p_user, USER)
              );
        END IF;

    EXCEPTION WHEN OTHERS THEN p_json := TO_CLOB('[]');
    END get_nav_json;

END myquery_navigation_pkg;
/
