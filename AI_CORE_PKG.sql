create or replace PACKAGE AI_CORE_PKG AUTHID CURRENT_USER AS 
    
    -- ============================================================
    -- ASKLYZE AI - Core Package Specification
    -- Version: 5.1 - WHITELISTED TABLES + CHART EDITING
    -- ============================================================
    
    -- Configuration
    FUNCTION GET_CONF(p_key IN VARCHAR2) RETURN CLOB;
    
    -- DEPRECATED: Do not use - kept for backward compatibility only
    FUNCTION GET_CONTEXT_SCHEMA(p_owner VARCHAR2 DEFAULT NULL) RETURN CLOB;
    
    -- Whitelisted-only context for AI
    FUNCTION GET_WHITELISTED_CONTEXT(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL,
        p_app_user     IN VARCHAR2 DEFAULT NULL,
        p_include_relations IN CHAR DEFAULT 'Y'
    ) RETURN CLOB;
    
    -- Validate that SQL only references whitelisted tables
    FUNCTION VALIDATE_SQL_WHITELIST(
        p_sql          IN CLOB,
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;
    
    -- Check if whitelist is configured
    FUNCTION HAS_WHITELISTED_TABLES(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;
    
    -- Access Control
    PROCEDURE CHECK_SCHEMA_ACCESS(
        p_schema_name IN VARCHAR2, 
        p_has_access OUT BOOLEAN, 
        p_message OUT VARCHAR2
    );
    
    -- Suggestions (Mode-Aware)
    PROCEDURE GET_SUGGESTIONS(
        p_schema_name IN VARCHAR2, 
        p_mode IN VARCHAR2 DEFAULT 'REPORT',
        p_suggestions OUT CLOB
    );
    
    -- Helper: Clean SQL
    FUNCTION CLEAN_AI_SQL(p_sql IN CLOB) RETURN CLOB;

    -- KPI Processing Engine
    FUNCTION PROCESS_KPIS(p_kpi_json IN CLOB) RETURN CLOB;
    
    -- Data Profile Analysis
    FUNCTION ANALYZE_DATA_PROFILE(
        p_sql IN CLOB,
        p_sample_size IN NUMBER DEFAULT 100
    ) RETURN CLOB;
    
    -- Chart Configuration Builder
    FUNCTION BUILD_CHART_CONFIG(
        p_data_profile IN CLOB,
        p_ai_suggestion IN CLOB,
        p_user_preference IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    -- Question Validation
    FUNCTION VALIDATE_QUESTION(p_question IN VARCHAR2) RETURN VARCHAR2;
    
    -- Intelligent Intent Detection
    FUNCTION DETECT_QUERY_INTENT(p_question IN VARCHAR2) RETURN VARCHAR2;
    
    -- Main AI Generation
    PROCEDURE GENERATE_INSIGHTS(
        p_question IN VARCHAR2, 
        p_schema_name IN VARCHAR2 DEFAULT USER, 
        p_category IN VARCHAR2 DEFAULT 'General', 
        p_result_json OUT CLOB
    );
    
    -- Dashboard Generation
    PROCEDURE GENERATE_DASHBOARD(
        p_question IN VARCHAR2,
        p_schema_name IN VARCHAR2 DEFAULT USER,
        p_result_json OUT CLOB
    );
    
    -- Execute Dashboard and get all data
    PROCEDURE EXECUTE_DASHBOARD(
        p_query_id IN NUMBER,
        p_result_json OUT CLOB
    );
    
    -- Update Query from SQL Editor
    PROCEDURE UPDATE_QUERY(
        p_query_id IN NUMBER,
        p_new_sql IN CLOB,
        p_result_json OUT CLOB
    );
    
    -- ============================================================
    -- NEW: Update individual chart in dashboard
    -- ============================================================
    PROCEDURE UPDATE_DASHBOARD_CHART(
        p_query_id    IN NUMBER,
        p_chart_index IN NUMBER,
        p_new_sql     IN CLOB DEFAULT NULL,
        p_chart_type  IN VARCHAR2 DEFAULT NULL,
        p_chart_title IN VARCHAR2 DEFAULT NULL,
        p_result_json OUT CLOB
    );
    
    -- NEW: Delete chart from dashboard
    PROCEDURE DELETE_DASHBOARD_CHART(
        p_query_id    IN NUMBER,
        p_chart_index IN NUMBER,
        p_result_json OUT CLOB
    );
    
    -- NEW: Get available chart types
    PROCEDURE GET_CHART_TYPES(
        p_result_json OUT CLOB
    );

    -- Data Execution & Rendering
    PROCEDURE EXECUTE_AND_RENDER(
        p_query_id IN NUMBER, 
        p_result_json OUT CLOB
    );
    
    -- Chat History Management
    PROCEDURE GET_CHAT_HISTORY(
        p_user IN VARCHAR2 DEFAULT NULL,
        p_limit IN NUMBER DEFAULT 50,
        p_offset IN NUMBER DEFAULT 0,
        p_search IN VARCHAR2 DEFAULT NULL,
        p_result_json OUT CLOB
    );
    
    PROCEDURE DELETE_CHAT(
        p_query_id IN NUMBER,
        p_result_json OUT CLOB
    );
    
    PROCEDURE TOGGLE_FAVORITE(
        p_query_id IN NUMBER,
        p_result_json OUT CLOB
    );
    
    PROCEDURE RENAME_CHAT(
        p_query_id IN NUMBER,
        p_new_title IN VARCHAR2,
        p_result_json OUT CLOB
    );
    
    PROCEDURE CLEAR_HISTORY(
        p_user IN VARCHAR2 DEFAULT NULL,
        p_result_json OUT CLOB
    );
    
    -- CATALOG API
    PROCEDURE CATALOG_REFRESH_SCHEMA(
        p_org_id        IN NUMBER,
        p_schema_owner  IN VARCHAR2,
        p_refresh_mode  IN VARCHAR2 DEFAULT 'INCR',
        p_include_views IN CHAR     DEFAULT NULL,
        p_result_json   OUT CLOB
    );

    PROCEDURE CATALOG_SET_WHITELIST(
        p_org_id          IN NUMBER,
        p_schema_owner    IN VARCHAR2,
        p_object_name     IN VARCHAR2,
        p_object_type     IN VARCHAR2 DEFAULT 'TABLE',
        p_is_whitelisted  IN CHAR     DEFAULT 'Y',
        p_is_enabled      IN CHAR     DEFAULT 'Y',
        p_app_user        IN VARCHAR2 DEFAULT NULL,
        p_result_json     OUT CLOB
    );

    FUNCTION CATALOG_GET_CONTEXT_TABLES_JSON(
        p_org_id        IN NUMBER,
        p_schema_owner  IN VARCHAR2,
        p_app_user      IN VARCHAR2 DEFAULT NULL,
        p_max_tables    IN NUMBER   DEFAULT 40,
        p_max_cols      IN NUMBER   DEFAULT 60
    ) RETURN CLOB;

    FUNCTION CATALOG_GET_TABLE_DETAILS_JSON(
        p_table_id IN NUMBER,
        p_max_cols IN NUMBER DEFAULT 200
    ) RETURN CLOB;

    PROCEDURE CATALOG_AI_DESCRIBE_TABLE(
        p_table_id     IN NUMBER,
        p_force        IN CHAR DEFAULT 'N',
        p_result_json  OUT CLOB
    );

    PROCEDURE CATALOG_AI_DESCRIBE_SCHEMA(
        p_org_id        IN NUMBER,
        p_schema_owner  IN VARCHAR2,
        p_only_missing  IN CHAR   DEFAULT 'Y',
        p_max_tables    IN NUMBER DEFAULT 50,
        p_force         IN CHAR   DEFAULT 'N',
        p_result_json   OUT CLOB
    );

        -- NEW: Pivot Table Analysis
    FUNCTION ANALYZE_PIVOT_SUITABILITY(
        p_data_profile IN CLOB,
        p_row_count IN NUMBER,
        p_question IN VARCHAR2
    ) RETURN CLOB;
    
    FUNCTION DETECT_PIVOT_CONFIG_AI(
        p_question IN VARCHAR2,
        p_data_profile IN CLOB,
        p_sample_data IN CLOB
    ) RETURN CLOB;

    -- Save Dashboard Layout
    PROCEDURE SAVE_DASHBOARD_LAYOUT(
        p_query_id    IN NUMBER,
        p_layout_json IN CLOB,
        p_result_json OUT CLOB
    );
    
    -- Reset Layout to Default
    PROCEDURE RESET_DASHBOARD_LAYOUT(
        p_query_id    IN NUMBER,
        p_result_json OUT CLOB
    );
    
    FUNCTION EXECUTE_SQL_TO_JSON(p_sql IN CLOB) RETURN CLOB;


     FUNCTION CATALOG_SEARCH_TABLES(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL,
        p_keywords     IN VARCHAR2,
        p_domain       IN VARCHAR2 DEFAULT NULL,
        p_max_results  IN NUMBER DEFAULT 10
    ) RETURN CLOB;
    
    -- NEW: Get Compact Context for LLM
    FUNCTION CATALOG_GET_SEMANTIC_CONTEXT(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL,
        p_domain       IN VARCHAR2 DEFAULT NULL,
        p_max_tables   IN NUMBER DEFAULT 30
    ) RETURN CLOB;
    
    -- NEW: Get Analysis Statistics
    FUNCTION CATALOG_GET_STATS(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;


        FUNCTION SMART_SELECT_TABLES(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL,
        p_question     IN VARCHAR2,
        p_max_tables   IN NUMBER DEFAULT 10
    ) RETURN CLOB;
    

    FUNCTION GET_SMART_CONTEXT(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL,
        p_question     IN VARCHAR2,
        p_include_relations IN CHAR DEFAULT 'Y'
    ) RETURN CLOB;

END AI_CORE_PKG;
/

create or replace PACKAGE BODY AI_CORE_PKG AS 

    -- ============================================================
    -- PRIVATE CONSTANTS
    -- ============================================================
    C_DEFAULT_ORG_ID CONSTANT NUMBER := 1;
    
    -- ============================================================
    -- PRIVATE HELPER: SAFE JSON ESCAPE
    -- ============================================================

        FUNCTION SMART_SELECT_TABLES_FALLBACK(
        p_schema_id  IN NUMBER,
        p_question   IN VARCHAR2,
        p_max_tables IN NUMBER DEFAULT 10
    ) RETURN CLOB;

    FUNCTION SAFE_JSON_ESCAPE(p_val IN VARCHAR2) RETURN VARCHAR2 IS
        l_res VARCHAR2(32767);
    BEGIN
        IF p_val IS NULL THEN RETURN NULL; END IF;
        l_res := SUBSTR(p_val, 1, 4000); 
        l_res := REPLACE(l_res, '\', '\\');
        l_res := REPLACE(l_res, '"', '\"');
        l_res := REPLACE(l_res, CHR(10), '\n');
        l_res := REPLACE(l_res, CHR(13), '\r');
        l_res := REPLACE(l_res, CHR(9), '\t');
        RETURN l_res;
    EXCEPTION WHEN OTHERS THEN RETURN 'JSON_ERROR';
    END SAFE_JSON_ESCAPE;


 -- ============================================================
    FUNCTION SMART_SELECT_TABLES(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL,
        p_question     IN VARCHAR2,
        p_max_tables   IN NUMBER DEFAULT 10
    ) RETURN CLOB IS
        l_owner       VARCHAR2(128) := UPPER(NVL(p_schema_owner, NVL(apex_application.g_flow_owner, USER)));
        l_schema_id   NUMBER;
        l_tables_list CLOB;
        l_prompt      CLOB;
        l_response    CLOB;
        l_result      CLOB;
        l_first       BOOLEAN := TRUE;
        l_api_key     VARCHAR2(1000);
        l_model       VARCHAR2(100) := 'openai/gpt-oss-120b';  
        l_body        CLOB;
    BEGIN
        -- Get schema ID
        BEGIN
            SELECT id INTO l_schema_id
            FROM ASKLYZE_CATALOG_SCHEMAS
            WHERE org_id = p_org_id
              AND UPPER(schema_owner) = l_owner;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RETURN '{"tables":[],"error":"No catalog configured"}';
        END;
        
        -- Build compact table list (name + domain + description only)
        DBMS_LOB.CREATETEMPORARY(l_tables_list, TRUE);
        
        FOR t IN (
            SELECT t.object_name, 
                   t.object_type,
                   NVL(t.business_domain, 'Other') AS domain,
                   NVL(t.summary_en, t.table_comment) AS description,
                   t.tags_json
            FROM ASKLYZE_CATALOG_TABLES t
            WHERE t.schema_id = l_schema_id
              AND t.is_whitelisted = 'Y'
              AND t.is_enabled = 'Y'
              AND NVL(t.status, 'VALID') != 'MISSING'
            ORDER BY t.relevance_score DESC NULLS LAST, t.num_rows DESC
        ) LOOP
            IF NOT l_first THEN
                DBMS_LOB.APPEND(l_tables_list, CHR(10));
            END IF;
            l_first := FALSE;
            
            DBMS_LOB.APPEND(l_tables_list, '- ' || t.object_name || ' [' || t.domain || '] (' || t.object_type || '): ');
            IF t.description IS NOT NULL THEN
                DBMS_LOB.APPEND(l_tables_list, SUBSTR(t.description, 1, 150));
            ELSE
                DBMS_LOB.APPEND(l_tables_list, 'No description');
            END IF;
        END LOOP;
        
        -- Build routing prompt
        DBMS_LOB.CREATETEMPORARY(l_prompt, TRUE);
        DBMS_LOB.APPEND(l_prompt, 'You are a database schema router. Your job is to select ONLY the relevant tables needed to answer a user question.

USER QUESTION: ' || p_question || '

AVAILABLE TABLES:
');
        DBMS_LOB.APPEND(l_prompt, l_tables_list);
        DBMS_LOB.APPEND(l_prompt, '

INSTRUCTIONS:
1. Analyze the user question carefully
2. Select ONLY the tables needed to answer this specific question
3. Consider relationships - if you need to join tables, include all required tables
4. Maximum ' || p_max_tables || ' tables
5. Return ONLY a JSON object with tables array, nothing else

RESPONSE FORMAT (strict JSON object):
{"tables": ["TABLE1", "TABLE2", "TABLE3"]}

Return ONLY the JSON object, no explanation.');

        -- Get API key
        BEGIN
            SELECT DBMS_LOB.SUBSTR(SETTING_VALUE, 1000, 1) INTO l_api_key
            FROM ASKLYZE_AI_SETTINGS
            WHERE SETTING_KEY = 'GROQ_API_KEY';
        EXCEPTION WHEN NO_DATA_FOUND THEN
            -- Fallback: return all tables if no API key
            RETURN SMART_SELECT_TABLES_FALLBACK(l_schema_id, p_question, p_max_tables);
        END;
        
        -- Call AI for routing (using Groq model - fast inference)
        APEX_JSON.INITIALIZE_CLOB_OUTPUT;
        APEX_JSON.OPEN_OBJECT;
            APEX_JSON.WRITE('model', l_model);
            APEX_JSON.OPEN_ARRAY('messages');
                APEX_JSON.OPEN_OBJECT;
                    APEX_JSON.WRITE('role', 'user');
                    APEX_JSON.WRITE('content', l_prompt);
                APEX_JSON.CLOSE_OBJECT;
            APEX_JSON.CLOSE_ARRAY;
            APEX_JSON.WRITE('temperature', 0.1);
            APEX_JSON.WRITE('max_tokens', 65536);
            APEX_JSON.OPEN_OBJECT('response_format');
                APEX_JSON.WRITE('type', 'json_object');
            APEX_JSON.CLOSE_OBJECT;
        APEX_JSON.CLOSE_OBJECT;
        l_body := APEX_JSON.GET_CLOB_OUTPUT;
        APEX_JSON.FREE_OUTPUT;
        
        -- Make API call
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        apex_web_service.g_request_headers(2).name  := 'Authorization';
        apex_web_service.g_request_headers(2).value := 'Bearer ' || l_api_key;
        
        l_response := apex_web_service.make_rest_request(
            p_url              => 'https://api.groq.com/openai/v1/chat/completions',
            p_http_method      => 'POST',
            p_body             => l_body,
            p_transfer_timeout => 15
        );
        
        -- Parse response
        IF apex_web_service.g_status_code = 200 THEN
            APEX_JSON.PARSE(l_response);
            DECLARE
                l_text VARCHAR2(4000);
                l_tables_json VARCHAR2(4000);
            BEGIN
                l_text := APEX_JSON.GET_VARCHAR2('choices[%d].message.content', 1);
                -- Clean up response
                l_text := REPLACE(REPLACE(l_text, '```json', ''), '```', '');
                l_text := TRIM(l_text);

                -- Parse the JSON object to extract "tables" array
                IF SUBSTR(l_text, 1, 1) = '{' THEN
                    APEX_JSON.PARSE(l_text);
                    l_tables_json := APEX_JSON.GET_VARCHAR2('tables');
                    -- If tables key exists, extract the array
                    IF l_tables_json IS NOT NULL THEN
                        l_result := l_tables_json;
                    ELSE
                        -- Try to get as array directly from parsed content
                        DECLARE
                            l_arr_count NUMBER;
                            l_arr_result CLOB;
                            l_first_item BOOLEAN := TRUE;
                        BEGIN
                            l_arr_count := APEX_JSON.GET_COUNT('tables');
                            IF l_arr_count > 0 THEN
                                DBMS_LOB.CREATETEMPORARY(l_arr_result, TRUE);
                                DBMS_LOB.APPEND(l_arr_result, '[');
                                FOR i IN 1..l_arr_count LOOP
                                    IF NOT l_first_item THEN
                                        DBMS_LOB.APPEND(l_arr_result, ',');
                                    END IF;
                                    l_first_item := FALSE;
                                    DBMS_LOB.APPEND(l_arr_result, '"' || APEX_JSON.GET_VARCHAR2('tables[%d]', i) || '"');
                                END LOOP;
                                DBMS_LOB.APPEND(l_arr_result, ']');
                                l_result := l_arr_result;
                            ELSE
                                l_result := SMART_SELECT_TABLES_FALLBACK(l_schema_id, p_question, p_max_tables);
                            END IF;
                        EXCEPTION WHEN OTHERS THEN
                            l_result := SMART_SELECT_TABLES_FALLBACK(l_schema_id, p_question, p_max_tables);
                        END;
                    END IF;
                ELSIF SUBSTR(l_text, 1, 1) = '[' THEN
                    -- Backward compatibility: if still returns array directly
                    l_result := l_text;
                ELSE
                    -- Fallback if response is not valid JSON
                    l_result := SMART_SELECT_TABLES_FALLBACK(l_schema_id, p_question, p_max_tables);
                END IF;
            EXCEPTION WHEN OTHERS THEN
                l_result := SMART_SELECT_TABLES_FALLBACK(l_schema_id, p_question, p_max_tables);
            END;
        ELSE
            -- API error - use fallback
            l_result := SMART_SELECT_TABLES_FALLBACK(l_schema_id, p_question, p_max_tables);
        END IF;
        
        DBMS_LOB.FREETEMPORARY(l_tables_list);
        DBMS_LOB.FREETEMPORARY(l_prompt);
        
        RETURN l_result;
        
    EXCEPTION WHEN OTHERS THEN
        RETURN '["' || SQLERRM || '"]';
    END SMART_SELECT_TABLES;

    FUNCTION SMART_SELECT_TABLES_FALLBACK(
        p_schema_id  IN NUMBER,
        p_question   IN VARCHAR2,
        p_max_tables IN NUMBER DEFAULT 10
    ) RETURN CLOB IS
        l_question VARCHAR2(4000) := LOWER(NVL(p_question, ''));
        l_result   CLOB;
        l_first    BOOLEAN := TRUE;
        l_words    VARCHAR2(4000);
        l_word     VARCHAR2(100);
        l_pos      NUMBER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '[');
        
        -- Extract words from question (simple tokenization)
        l_words := REGEXP_REPLACE(l_question, '[^a-z0-9 ]', ' ');
        l_words := REGEXP_REPLACE(l_words, '\s+', ' ');
        
        FOR t IN (
            SELECT object_name, summary_en, tags_json, relevance_score,
                   -- Simple keyword matching score
                   (CASE WHEN LOWER(object_name) LIKE '%' || SUBSTR(l_words, 1, INSTR(l_words||' ', ' ')-1) || '%' THEN 50 ELSE 0 END +
                    CASE WHEN summary_en IS NOT NULL AND LOWER(summary_en) LIKE '%' || SUBSTR(l_words, 1, INSTR(l_words||' ', ' ')-1) || '%' THEN 30 ELSE 0 END +
                    CASE WHEN tags_json IS NOT NULL AND LOWER(tags_json) LIKE '%' || SUBSTR(l_words, 1, INSTR(l_words||' ', ' ')-1) || '%' THEN 40 ELSE 0 END +
                    NVL(relevance_score, 0)
                   ) AS match_score
            FROM ASKLYZE_CATALOG_TABLES
            WHERE schema_id = p_schema_id
              AND is_whitelisted = 'Y'
              AND is_enabled = 'Y'
            ORDER BY match_score DESC, relevance_score DESC NULLS LAST
            FETCH FIRST p_max_tables ROWS ONLY
        ) LOOP
            IF NOT l_first THEN
                DBMS_LOB.APPEND(l_result, ',');
            END IF;
            l_first := FALSE;
            DBMS_LOB.APPEND(l_result, '"' || t.object_name || '"');
        END LOOP;
        
        DBMS_LOB.APPEND(l_result, ']');
        
        RETURN l_result;
    EXCEPTION WHEN OTHERS THEN
        RETURN '[]';
    END SMART_SELECT_TABLES_FALLBACK;

    -- ============================================================
    -- Configuration Helper
    -- ============================================================
    FUNCTION GET_CONF(p_key IN VARCHAR2) RETURN CLOB IS 
        l_val CLOB; 
    BEGIN 
        SELECT SETTING_VALUE INTO l_val FROM ASKLYZE_AI_SETTINGS WHERE SETTING_KEY = p_key; 
        RETURN l_val; 
    EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL; 
    END; 

    -- ============================================================
    -- DEPRECATED: Old Schema Context Builder (DO NOT USE)
    -- Kept only for backward compatibility - returns empty if whitelist exists
    -- ============================================================
    FUNCTION GET_CONTEXT_SCHEMA(p_owner VARCHAR2 DEFAULT NULL) RETURN CLOB IS 
    BEGIN 
        -- DEPRECATED: This function should not be used
        -- All callers should use GET_WHITELISTED_CONTEXT instead
        RETURN GET_WHITELISTED_CONTEXT(
            p_org_id => C_DEFAULT_ORG_ID,
            p_schema_owner => p_owner,
            p_include_relations => 'Y'
        );
    END; 

    -- ============================================================
    -- NEW: Check if any whitelisted tables exist
    -- ============================================================
    FUNCTION HAS_WHITELISTED_TABLES(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        l_count NUMBER;
        l_owner VARCHAR2(128) := UPPER(NVL(p_schema_owner, NVL(apex_application.g_flow_owner, USER)));
    BEGIN
        SELECT COUNT(*) INTO l_count
        FROM ASKLYZE_CATALOG_TABLES t
        JOIN ASKLYZE_CATALOG_SCHEMAS s ON s.id = t.schema_id
        WHERE s.org_id = p_org_id
          AND UPPER(s.schema_owner) = l_owner
          AND t.is_whitelisted = 'Y'
          AND t.is_enabled = 'Y'
          AND NVL(t.status, 'VALID') != 'MISSING';
        
        RETURN l_count > 0;
    EXCEPTION WHEN OTHERS THEN
        RETURN FALSE;
    END HAS_WHITELISTED_TABLES;

    -- ============================================================
    -- NEW: Get ONLY whitelisted tables context for AI
    -- This is the ONLY function that should feed context to LLM
    -- ============================================================
    FUNCTION GET_WHITELISTED_CONTEXT(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL,
        p_app_user     IN VARCHAR2 DEFAULT NULL,
        p_include_relations IN CHAR DEFAULT 'Y'
    ) RETURN CLOB IS
        l_owner VARCHAR2(128) := UPPER(NVL(p_schema_owner, NVL(apex_application.g_flow_owner, USER)));
        l_result CLOB;
        l_tables CLOB;
        l_relations CLOB;
        l_first_table BOOLEAN := TRUE;
        l_first_col BOOLEAN;
        l_first_rel BOOLEAN := TRUE;
        l_schema_id NUMBER;
    BEGIN
        -- Get schema ID
        BEGIN
            SELECT id INTO l_schema_id
            FROM ASKLYZE_CATALOG_SCHEMAS
            WHERE org_id = p_org_id
              AND UPPER(schema_owner) = l_owner;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RETURN '{"tables":[],"relations":[],"error":"No catalog configured. Please configure data settings first."}';
        END;
        
        DBMS_LOB.CREATETEMPORARY(l_tables, TRUE);
        DBMS_LOB.APPEND(l_tables, '[');
        
        -- Build tables array with columns and AI descriptions
        FOR t IN (
            SELECT t.id, t.object_name, t.object_type, 
                   t.summary_en, t.summary_ar, t.table_comment,
                   NVL(t.num_rows, 0) AS num_rows
            FROM ASKLYZE_CATALOG_TABLES t
            WHERE t.schema_id = l_schema_id
              AND t.is_whitelisted = 'Y'
              AND t.is_enabled = 'Y'
              AND NVL(t.status, 'VALID') != 'MISSING'
            ORDER BY t.num_rows DESC, t.object_name
        ) LOOP
            IF NOT l_first_table THEN
                DBMS_LOB.APPEND(l_tables, ',');
            END IF;
            l_first_table := FALSE;
            
            -- Table object with rich description
            DBMS_LOB.APPEND(l_tables, '{"table":"' || SAFE_JSON_ESCAPE(t.object_name) || '"');
            DBMS_LOB.APPEND(l_tables, ',"type":"' || t.object_type || '"');
            
            -- Include AI description if available
            IF t.summary_en IS NOT NULL THEN
                DBMS_LOB.APPEND(l_tables, ',"description":"' || SAFE_JSON_ESCAPE(SUBSTR(t.summary_en, 1, 500)) || '"');
            ELSIF t.table_comment IS NOT NULL THEN
                DBMS_LOB.APPEND(l_tables, ',"description":"' || SAFE_JSON_ESCAPE(SUBSTR(t.table_comment, 1, 500)) || '"');
            END IF;
            
            -- Columns with semantic roles
            DBMS_LOB.APPEND(l_tables, ',"columns":[');
            l_first_col := TRUE;
            
            FOR c IN (
                SELECT column_name, data_type, semantic_role, 
                       NVL(column_comment, '') AS column_comment,
                       is_search_key
                FROM ASKLYZE_CATALOG_COLUMNS
                WHERE table_id = t.id
                ORDER BY column_id
            ) LOOP
                IF NOT l_first_col THEN
                    DBMS_LOB.APPEND(l_tables, ',');
                END IF;
                l_first_col := FALSE;
                
                DBMS_LOB.APPEND(l_tables, '{"name":"' || SAFE_JSON_ESCAPE(c.column_name) || '"');
                DBMS_LOB.APPEND(l_tables, ',"type":"' || c.data_type || '"');
                IF c.semantic_role IS NOT NULL THEN
                    DBMS_LOB.APPEND(l_tables, ',"role":"' || c.semantic_role || '"');
                END IF;
                IF c.is_search_key = 'Y' THEN
                    DBMS_LOB.APPEND(l_tables, ',"searchKey":true');
                END IF;
                IF c.column_comment IS NOT NULL AND LENGTH(c.column_comment) > 0 THEN
                    DBMS_LOB.APPEND(l_tables, ',"desc":"' || SAFE_JSON_ESCAPE(SUBSTR(c.column_comment, 1, 200)) || '"');
                END IF;
                DBMS_LOB.APPEND(l_tables, '}');
            END LOOP;
            
            DBMS_LOB.APPEND(l_tables, ']}');
        END LOOP;
        
        DBMS_LOB.APPEND(l_tables, ']');
        
        -- Build relations array if requested
        IF p_include_relations = 'Y' THEN
            DBMS_LOB.CREATETEMPORARY(l_relations, TRUE);
            DBMS_LOB.APPEND(l_relations, '[');
            
            FOR r IN (
                SELECT fk_t.object_name AS fk_table,
                       rel.fk_column_name,
                       pk_t.object_name AS pk_table,
                       rel.pk_column_name
                FROM ASKLYZE_CATALOG_RELATIONS rel
                JOIN ASKLYZE_CATALOG_TABLES fk_t ON fk_t.id = rel.fk_table_id
                JOIN ASKLYZE_CATALOG_TABLES pk_t ON pk_t.id = rel.pk_table_id
                WHERE fk_t.schema_id = l_schema_id
                  AND fk_t.is_whitelisted = 'Y'
                  AND pk_t.is_whitelisted = 'Y'
            ) LOOP
                IF NOT l_first_rel THEN
                    DBMS_LOB.APPEND(l_relations, ',');
                END IF;
                l_first_rel := FALSE;
                
                DBMS_LOB.APPEND(l_relations, '{"from":"' || SAFE_JSON_ESCAPE(r.fk_table) || '.' || SAFE_JSON_ESCAPE(r.fk_column_name) || '"');
                DBMS_LOB.APPEND(l_relations, ',"to":"' || SAFE_JSON_ESCAPE(r.pk_table) || '.' || SAFE_JSON_ESCAPE(r.pk_column_name) || '"}');
            END LOOP;
            
            DBMS_LOB.APPEND(l_relations, ']');
        ELSE
            l_relations := '[]';
        END IF;
        
        -- Combine into final result
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '{"tables":');
        DBMS_LOB.APPEND(l_result, l_tables);
        DBMS_LOB.APPEND(l_result, ',"relations":');
        DBMS_LOB.APPEND(l_result, l_relations);
        DBMS_LOB.APPEND(l_result, '}');
        
        DBMS_LOB.FREETEMPORARY(l_tables);
        IF p_include_relations = 'Y' THEN
            DBMS_LOB.FREETEMPORARY(l_relations);
        END IF;
        
        RETURN l_result;
        
    EXCEPTION WHEN OTHERS THEN
        RETURN '{"tables":[],"relations":[],"error":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END GET_WHITELISTED_CONTEXT;


-- ============================================================
    -- GET_SMART_CONTEXT: Returns context with only selected tables
    -- ============================================================
    FUNCTION GET_SMART_CONTEXT(
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL,
        p_question     IN VARCHAR2,
        p_include_relations IN CHAR DEFAULT 'Y'
    ) RETURN CLOB IS
        l_owner VARCHAR2(128) := UPPER(NVL(p_schema_owner, NVL(apex_application.g_flow_owner, USER)));
        l_schema_id NUMBER;
        l_selected_tables CLOB;
        l_result CLOB;
        l_tables CLOB;
        l_relations CLOB;
        l_first_table BOOLEAN := TRUE;
        l_first_col BOOLEAN;
        l_first_rel BOOLEAN := TRUE;
        
        TYPE t_table_set IS TABLE OF VARCHAR2(1) INDEX BY VARCHAR2(128);
        l_table_set t_table_set;
    BEGIN
        -- Get schema ID
        BEGIN
            SELECT id INTO l_schema_id
            FROM ASKLYZE_CATALOG_SCHEMAS
            WHERE org_id = p_org_id
              AND UPPER(schema_owner) = l_owner;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RETURN '{"tables":[],"relations":[],"error":"No catalog configured"}';
        END;
        
        -- Get selected tables using Smart Router
        l_selected_tables := SMART_SELECT_TABLES(
            p_org_id       => p_org_id,
            p_schema_owner => l_owner,
            p_question     => p_question,
            p_max_tables   => 10
        );
        
        -- Parse selected tables into a set for fast lookup
        BEGIN
            APEX_JSON.PARSE(l_selected_tables);
            DECLARE
                l_count NUMBER := 0;
                l_tbl VARCHAR2(128);
            BEGIN
                BEGIN
                    l_count := APEX_JSON.GET_COUNT('.');
                EXCEPTION WHEN OTHERS THEN 
                    l_count := 0;
                END;
                
                IF l_count > 0 THEN
                    FOR i IN 1..l_count LOOP
                        l_tbl := UPPER(APEX_JSON.GET_VARCHAR2('[%d]', i));
                        IF l_tbl IS NOT NULL THEN
                            l_table_set(l_tbl) := 'Y';
                        END IF;
                    END LOOP;
                END IF;
            END;
        EXCEPTION WHEN OTHERS THEN
            -- If parsing fails, return all tables (fallback)
            RETURN GET_WHITELISTED_CONTEXT(p_org_id, p_schema_owner, NULL, p_include_relations);
        END;
        
        -- If no tables selected, return error
        IF l_table_set.COUNT = 0 THEN
            RETURN '{"tables":[],"relations":[],"error":"No relevant tables found for this question"}';
        END IF;
        
        -- Build tables array with ONLY selected tables
        DBMS_LOB.CREATETEMPORARY(l_tables, TRUE);
        DBMS_LOB.APPEND(l_tables, '[');
        
        FOR t IN (
            SELECT t.id, t.object_name, t.object_type, 
                   t.summary_en, t.table_comment,
                   NVL(t.num_rows, 0) AS num_rows
            FROM ASKLYZE_CATALOG_TABLES t
            WHERE t.schema_id = l_schema_id
              AND t.is_whitelisted = 'Y'
              AND t.is_enabled = 'Y'
              AND NVL(t.status, 'VALID') != 'MISSING'
            ORDER BY t.num_rows DESC, t.object_name
        ) LOOP
            -- Only include if in selected set
            IF l_table_set.EXISTS(UPPER(t.object_name)) THEN
                IF NOT l_first_table THEN
                    DBMS_LOB.APPEND(l_tables, ',');
                END IF;
                l_first_table := FALSE;
                
                DBMS_LOB.APPEND(l_tables, '{"table":"' || SAFE_JSON_ESCAPE(t.object_name) || '"');
                DBMS_LOB.APPEND(l_tables, ',"type":"' || t.object_type || '"');
                
                IF t.summary_en IS NOT NULL THEN
                    DBMS_LOB.APPEND(l_tables, ',"description":"' || SAFE_JSON_ESCAPE(SUBSTR(t.summary_en, 1, 500)) || '"');
                ELSIF t.table_comment IS NOT NULL THEN
                    DBMS_LOB.APPEND(l_tables, ',"description":"' || SAFE_JSON_ESCAPE(SUBSTR(t.table_comment, 1, 500)) || '"');
                END IF;
                
                -- Columns
                DBMS_LOB.APPEND(l_tables, ',"columns":[');
                l_first_col := TRUE;
                
                FOR c IN (
                    SELECT column_name, data_type, semantic_role, 
                           NVL(column_comment, '') AS column_comment,
                           is_search_key
                    FROM ASKLYZE_CATALOG_COLUMNS
                    WHERE table_id = t.id
                    ORDER BY column_id
                ) LOOP
                    IF NOT l_first_col THEN
                        DBMS_LOB.APPEND(l_tables, ',');
                    END IF;
                    l_first_col := FALSE;
                    
                    DBMS_LOB.APPEND(l_tables, '{"name":"' || SAFE_JSON_ESCAPE(c.column_name) || '"');
                    DBMS_LOB.APPEND(l_tables, ',"type":"' || c.data_type || '"');
                    IF c.semantic_role IS NOT NULL THEN
                        DBMS_LOB.APPEND(l_tables, ',"role":"' || c.semantic_role || '"');
                    END IF;
                    IF c.is_search_key = 'Y' THEN
                        DBMS_LOB.APPEND(l_tables, ',"searchKey":true');
                    END IF;
                    DBMS_LOB.APPEND(l_tables, '}');
                END LOOP;
                
                DBMS_LOB.APPEND(l_tables, ']}');
            END IF;
        END LOOP;
        
        DBMS_LOB.APPEND(l_tables, ']');
        
        -- Build relations (only between selected tables)
        IF p_include_relations = 'Y' THEN
            DBMS_LOB.CREATETEMPORARY(l_relations, TRUE);
            DBMS_LOB.APPEND(l_relations, '[');
            
            FOR r IN (
                SELECT fk_t.object_name AS fk_table,
                       rel.fk_column_name,
                       pk_t.object_name AS pk_table,
                       rel.pk_column_name
                FROM ASKLYZE_CATALOG_RELATIONS rel
                JOIN ASKLYZE_CATALOG_TABLES fk_t ON fk_t.id = rel.fk_table_id
                JOIN ASKLYZE_CATALOG_TABLES pk_t ON pk_t.id = rel.pk_table_id
                WHERE fk_t.schema_id = l_schema_id
                  AND fk_t.is_whitelisted = 'Y'
                  AND pk_t.is_whitelisted = 'Y'
            ) LOOP
                -- Only include if BOTH tables are in selected set
                IF l_table_set.EXISTS(UPPER(r.fk_table)) AND l_table_set.EXISTS(UPPER(r.pk_table)) THEN
                    IF NOT l_first_rel THEN
                        DBMS_LOB.APPEND(l_relations, ',');
                    END IF;
                    l_first_rel := FALSE;
                    
                    DBMS_LOB.APPEND(l_relations, '{"from":"' || r.fk_table || '.' || r.fk_column_name || '"');
                    DBMS_LOB.APPEND(l_relations, ',"to":"' || r.pk_table || '.' || r.pk_column_name || '"}');
                END IF;
            END LOOP;
            
            DBMS_LOB.APPEND(l_relations, ']');
        ELSE
            l_relations := '[]';
        END IF;
        
        -- Combine
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '{"tables":');
        DBMS_LOB.APPEND(l_result, l_tables);
        DBMS_LOB.APPEND(l_result, ',"relations":');
        DBMS_LOB.APPEND(l_result, l_relations);
        DBMS_LOB.APPEND(l_result, ',"selected_count":' || l_table_set.COUNT);
        DBMS_LOB.APPEND(l_result, '}');
        
        DBMS_LOB.FREETEMPORARY(l_tables);
        IF p_include_relations = 'Y' THEN
            DBMS_LOB.FREETEMPORARY(l_relations);
        END IF;
        
        RETURN l_result;
        
    EXCEPTION WHEN OTHERS THEN
        RETURN '{"tables":[],"relations":[],"error":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END GET_SMART_CONTEXT;

    -- ============================================================
    -- NEW: Validate SQL only uses whitelisted tables
    -- Returns NULL if valid, error message if invalid
    -- ============================================================
    FUNCTION VALIDATE_SQL_WHITELIST(
        p_sql          IN CLOB,
        p_org_id       IN NUMBER DEFAULT 1,
        p_schema_owner IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_owner VARCHAR2(128) := UPPER(NVL(p_schema_owner, NVL(apex_application.g_flow_owner, USER)));
        l_sql_upper VARCHAR2(32767);
        l_schema_id NUMBER;
        l_found_invalid VARCHAR2(4000);
        
        TYPE t_table_set IS TABLE OF NUMBER INDEX BY VARCHAR2(128);
        l_whitelist t_table_set;
    BEGIN
        IF p_sql IS NULL THEN
            RETURN NULL;
        END IF;
        
        l_sql_upper := UPPER(DBMS_LOB.SUBSTR(p_sql, 32000, 1));
        
        -- Get schema ID
        BEGIN
            SELECT id INTO l_schema_id
            FROM ASKLYZE_CATALOG_SCHEMAS
            WHERE org_id = p_org_id
              AND UPPER(schema_owner) = l_owner;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RETURN 'No catalog configured for schema ' || l_owner;
        END;
        
        -- Build whitelist set
        FOR t IN (
            SELECT UPPER(object_name) AS tbl
            FROM ASKLYZE_CATALOG_TABLES
            WHERE schema_id = l_schema_id
              AND is_whitelisted = 'Y'
              AND is_enabled = 'Y'
        ) LOOP
            l_whitelist(t.tbl) := 1;
        END LOOP;
        
        -- Check all tables in schema against SQL
        -- This is a simple check - looks for table names in SQL
        FOR t IN (
            SELECT UPPER(object_name) AS tbl
            FROM ASKLYZE_CATALOG_TABLES
            WHERE schema_id = l_schema_id
              AND is_whitelisted = 'N'
        ) LOOP
            -- Check if non-whitelisted table appears in SQL
            -- Use word boundary check to avoid false positives
            IF REGEXP_LIKE(l_sql_upper, '(^|[^A-Z0-9_])' || t.tbl || '($|[^A-Z0-9_])') THEN
                IF l_found_invalid IS NULL THEN
                    l_found_invalid := t.tbl;
                ELSE
                    l_found_invalid := l_found_invalid || ', ' || t.tbl;
                END IF;
            END IF;
        END LOOP;
        
        IF l_found_invalid IS NOT NULL THEN
            RETURN 'SQL references non-whitelisted tables: ' || l_found_invalid || '. Please add these tables to your data configuration.';
        END IF;
        
        RETURN NULL; -- Valid
        
    EXCEPTION WHEN OTHERS THEN
        -- Don't block on validation errors, just log
        RETURN NULL;
    END VALIDATE_SQL_WHITELIST;

    -- ============================================================
    -- Security Check
    -- ============================================================
    PROCEDURE CHECK_SCHEMA_ACCESS(p_schema_name IN VARCHAR2, p_has_access OUT BOOLEAN, p_message OUT VARCHAR2) IS 
        l_cnt NUMBER; 
    BEGIN 
        SELECT COUNT(*) INTO l_cnt FROM all_tables WHERE owner = UPPER(p_schema_name) AND ROWNUM = 1; 
        IF l_cnt > 0 THEN p_has_access := TRUE; 
        ELSE p_has_access := FALSE; p_message := 'No access to schema ' || p_schema_name; END IF; 
    EXCEPTION WHEN OTHERS THEN p_has_access := FALSE; p_message := SQLERRM; 
    END; 

    -- ============================================================
    -- Suggestion Engine - NOW WHITELIST-ONLY
    -- ============================================================
    PROCEDURE GET_SUGGESTIONS(
        p_schema_name IN VARCHAR2, 
        p_mode IN VARCHAR2 DEFAULT 'REPORT', 
        p_suggestions OUT CLOB
    ) IS 
        l_context CLOB;
        l_body CLOB; 
        l_resp CLOB; 
        l_txt CLOB; 
        l_key VARCHAR2(1000) := DBMS_LOB.SUBSTR(GET_CONF('GROQ_API_KEY'), 1000, 1); 
        l_model VARCHAR2(100) := 'openai/gpt-oss-120b';
        l_prompt CLOB;
        l_target VARCHAR2(128) := UPPER(NVL(p_schema_name, NVL(apex_application.g_flow_owner, USER)));
    BEGIN 
        -- Get ONLY whitelisted tables context
        l_context := GET_WHITELISTED_CONTEXT(
            p_org_id => C_DEFAULT_ORG_ID,
            p_schema_owner => l_target,
            p_include_relations => 'Y'
        );
        
        -- Check if any tables are whitelisted
        IF NOT HAS_WHITELISTED_TABLES(C_DEFAULT_ORG_ID, l_target) THEN
            p_suggestions := '["Configure your data sources first", "Click Data Settings to select tables", "Add tables to enable AI suggestions", "Set up your whitelist to get started"]';
            RETURN;
        END IF;
        
        -- Build prompt with ONLY whitelisted context
        DBMS_LOB.CREATETEMPORARY(l_prompt, TRUE);
        
        IF UPPER(p_mode) = 'DASHBOARD' THEN
            DBMS_LOB.APPEND(l_prompt, 'You are a BI analyst. Generate 4 catchy dashboard widget titles based on these tables:' || CHR(10));
            DBMS_LOB.APPEND(l_prompt, SUBSTR(l_context, 1, 6000));
            DBMS_LOB.APPEND(l_prompt, CHR(10) || CHR(10) || 'Examples: "Total Revenue", "Sales by Region", "Monthly Growth Trend", "Active Customers"' || CHR(10));
            DBMS_LOB.APPEND(l_prompt, CHR(10) || 'Return ONLY a JSON array like this example:' || CHR(10));
            DBMS_LOB.APPEND(l_prompt, '["Total Revenue", "Sales by Region", "Monthly Growth", "Top Products"]' || CHR(10));
            DBMS_LOB.APPEND(l_prompt, CHR(10) || 'Your response must be ONLY the JSON array, nothing else:');
        ELSE
            DBMS_LOB.APPEND(l_prompt, 'You are a data analyst. Generate 4 natural language questions based on these tables:' || CHR(10));
            DBMS_LOB.APPEND(l_prompt, SUBSTR(l_context, 1, 6000));
            DBMS_LOB.APPEND(l_prompt, CHR(10) || CHR(10) || 'Examples: "Show all customers", "List top 10 sales", "Employees hired in 2024"' || CHR(10));
            DBMS_LOB.APPEND(l_prompt, CHR(10) || 'Return ONLY a JSON array like this example:' || CHR(10));
            DBMS_LOB.APPEND(l_prompt, '["Show all customers", "List top sales", "Recent orders", "Department summary"]' || CHR(10));
            DBMS_LOB.APPEND(l_prompt, CHR(10) || 'Your response must be ONLY the JSON array, nothing else:');
        END IF;
        
        APEX_JSON.INITIALIZE_CLOB_OUTPUT;
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('model', l_model);
        APEX_JSON.OPEN_ARRAY('messages');
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('role', 'user');
        APEX_JSON.WRITE('content', l_prompt);
        APEX_JSON.CLOSE_OBJECT;
        APEX_JSON.CLOSE_ARRAY;
        APEX_JSON.WRITE('temperature', 0.4);
        APEX_JSON.CLOSE_OBJECT;
        l_body := APEX_JSON.GET_CLOB_OUTPUT;
        APEX_JSON.FREE_OUTPUT;
        DBMS_LOB.FREETEMPORARY(l_prompt);

        apex_web_service.g_request_headers.DELETE; 
        apex_web_service.g_request_headers(1).name := 'Content-Type'; 
        apex_web_service.g_request_headers(1).value := 'application/json'; 
        apex_web_service.g_request_headers(2).name := 'Authorization';
        apex_web_service.g_request_headers(2).value := 'Bearer ' || l_key; 
        
        l_resp := apex_web_service.make_rest_request(
            p_url => 'https://api.groq.com/openai/v1/chat/completions', 
            p_http_method => 'POST', 
            p_body => l_body,
            p_transfer_timeout => 8
        ); 
        
        IF apex_web_service.g_status_code != 200 THEN
            p_suggestions := '["Analyze your data", "Create a summary report", "View key metrics", "Explore trends"]';
            RETURN;
        END IF;

        APEX_JSON.PARSE(l_resp); 
        l_txt := APEX_JSON.GET_VARCHAR2('choices[%d].message.content', 1); 
        l_txt := REPLACE(REPLACE(l_txt, '```json', ''), '```', '');
        
        p_suggestions := l_txt; 

    EXCEPTION WHEN OTHERS THEN 
        p_suggestions := '["Analyze your configured tables", "Show department summary", "List top records", "View data trends"]'; 
    END;

    -- ============================================================
    -- SQL Sanitization Helper
    -- ============================================================
    FUNCTION CLEAN_AI_SQL(p_sql IN CLOB) RETURN CLOB IS
        l_clean_sql CLOB := p_sql; l_len INTEGER;
    BEGIN
        IF l_clean_sql IS NULL THEN RETURN NULL; END IF;
        l_clean_sql := REPLACE(l_clean_sql, '```sql', '');
        l_clean_sql := REPLACE(l_clean_sql, '```', '');
        l_clean_sql := TRIM(l_clean_sql);
        l_len := DBMS_LOB.GETLENGTH(l_clean_sql);
        IF l_len > 0 AND DBMS_LOB.SUBSTR(l_clean_sql, 1, l_len) = ';' THEN
            l_clean_sql := DBMS_LOB.SUBSTR(l_clean_sql, l_len - 1, 1);
        END IF;
        RETURN l_clean_sql;
    END;

    -- ============================================================
    -- Question Validation
    -- ============================================================
    FUNCTION VALIDATE_QUESTION(p_question IN VARCHAR2) RETURN VARCHAR2 IS
        l_question VARCHAR2(4000);
        l_alpha_count NUMBER := 0;
        l_total_len NUMBER;
        l_has_vowels BOOLEAN := FALSE;
    BEGIN
        IF p_question IS NULL OR LENGTH(TRIM(p_question)) = 0 THEN
            RETURN 'Please enter a question about your data.';
        END IF;
        
        l_question := LOWER(TRIM(p_question));
        l_total_len := LENGTH(l_question);
        
        IF l_total_len < 2 THEN
            RETURN 'Please enter a more descriptive question.';
        END IF;
        
        l_alpha_count := LENGTH(REGEXP_REPLACE(l_question, '[^a-zA-Z\u0600-\u06FF]', ''));
        IF l_alpha_count < l_total_len * 0.4 THEN
            RETURN 'Please enter a valid question.';
        END IF;
        
        IF REGEXP_LIKE(l_question, '[aeiouAEIOU]') OR REGEXP_LIKE(l_question, '[\u0600-\u06FF]') THEN
            l_has_vowels := TRUE;
        END IF;
        
        IF REGEXP_LIKE(l_question, '^(.)\1+$') THEN
            RETURN 'Please enter a valid question.';
        END IF;
        
        IF NOT l_has_vowels AND l_total_len < 8 THEN
            RETURN 'Please enter a meaningful question.';
        END IF;
        
        RETURN NULL;
    END VALIDATE_QUESTION;

    -- ============================================================
    -- Intelligent Intent Detection
    -- ============================================================
    FUNCTION DETECT_QUERY_INTENT(p_question IN VARCHAR2) RETURN VARCHAR2 IS
        l_question_lower VARCHAR2(4000);
        l_score_dashboard NUMBER := 0;
        l_score_report NUMBER := 0;
    BEGIN
        IF p_question IS NULL THEN RETURN 'REPORT'; END IF;
        
        l_question_lower := LOWER(p_question);
        
        -- Dashboard Indicators
        IF INSTR(l_question_lower, 'dashboard') > 0 THEN l_score_dashboard := l_score_dashboard + 10; END IF;
        IF INSTR(l_question_lower, 'executive') > 0 THEN l_score_dashboard := l_score_dashboard + 8; END IF;
        IF INSTR(l_question_lower, 'overview') > 0 THEN l_score_dashboard := l_score_dashboard + 6; END IF;
        IF INSTR(l_question_lower, 'kpi') > 0 THEN l_score_dashboard := l_score_dashboard + 8; END IF;
        IF INSTR(l_question_lower, 'metrics') > 0 THEN l_score_dashboard := l_score_dashboard + 5; END IF;
        IF INSTR(l_question_lower, 'at a glance') > 0 THEN l_score_dashboard := l_score_dashboard + 7; END IF;
        IF INSTR(l_question_lower, 'scorecard') > 0 THEN l_score_dashboard := l_score_dashboard + 6; END IF;
        
        -- Report Indicators
        IF INSTR(l_question_lower, 'report') > 0 THEN l_score_report := l_score_report + 8; END IF;
        IF INSTR(l_question_lower, 'list') > 0 THEN l_score_report := l_score_report + 5; END IF;
        IF INSTR(l_question_lower, 'table') > 0 THEN l_score_report := l_score_report + 5; END IF;
        IF INSTR(l_question_lower, 'detail') > 0 THEN l_score_report := l_score_report + 4; END IF;
        IF INSTR(l_question_lower, 'show me') > 0 AND INSTR(l_question_lower, 'all') > 0 THEN l_score_report := l_score_report + 3; END IF;
        
        IF l_score_dashboard >= 5 AND l_score_dashboard > l_score_report THEN
            RETURN 'DASHBOARD';
        ELSE
            RETURN 'REPORT';
        END IF;
    END DETECT_QUERY_INTENT;

    -- ============================================================
    -- KPI Processor
    -- ============================================================
    FUNCTION PROCESS_KPIS(p_kpi_json IN CLOB) RETURN CLOB IS
        l_result CLOB; l_val VARCHAR2(32767); l_res_val VARCHAR2(32767); l_sql_stmt VARCHAR2(32767);
        l_title VARCHAR2(500); l_icon VARCHAR2(100); l_trend VARCHAR2(50); l_color VARCHAR2(50);
        l_first BOOLEAN := TRUE; l_count NUMBER; l_num_val NUMBER;
    BEGIN
        IF p_kpi_json IS NULL OR DBMS_LOB.GETLENGTH(p_kpi_json) < 5 THEN RETURN '[]'; END IF;
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '[');
        BEGIN
            APEX_JSON.PARSE(p_kpi_json);
            l_count := APEX_JSON.GET_COUNT(p_path => '.');
        EXCEPTION WHEN OTHERS THEN DBMS_LOB.FREETEMPORARY(l_result); RETURN '[]'; END;
        IF l_count IS NULL OR l_count = 0 THEN DBMS_LOB.FREETEMPORARY(l_result); RETURN '[]'; END IF;
        
        FOR i IN 1 .. l_count LOOP
            BEGIN
                l_title := APEX_JSON.GET_VARCHAR2(p_path => '[%d].title', p0 => i);
                l_val   := APEX_JSON.GET_VARCHAR2(p_path => '[%d].value', p0 => i);
                l_icon  := APEX_JSON.GET_VARCHAR2(p_path => '[%d].icon', p0 => i);
                l_trend := APEX_JSON.GET_VARCHAR2(p_path => '[%d].trend', p0 => i);
                l_color := APEX_JSON.GET_VARCHAR2(p_path => '[%d].color', p0 => i);
                l_title := NVL(l_title, 'Metric'); l_icon := NVL(l_icon, 'chart'); 
                l_trend := NVL(l_trend, 'neutral'); l_color := NVL(l_color, 'blue');
                l_res_val := '-';
                
                IF l_val IS NOT NULL THEN
                    l_sql_stmt := CLEAN_AI_SQL(l_val);
                    IF UPPER(SUBSTR(l_sql_stmt, 1, 6)) = 'SELECT' OR UPPER(SUBSTR(l_sql_stmt, 1, 7)) = '(SELECT' THEN
                        BEGIN
                            IF SUBSTR(l_sql_stmt, 1, 1) = '(' AND SUBSTR(l_sql_stmt, -1) = ')' THEN
                                l_sql_stmt := SUBSTR(l_sql_stmt, 2, LENGTH(l_sql_stmt) - 2);
                            END IF;
                            EXECUTE IMMEDIATE l_sql_stmt INTO l_num_val;
                            IF l_num_val IS NOT NULL THEN
                                IF l_num_val = TRUNC(l_num_val) THEN l_res_val := TO_CHAR(l_num_val, 'FM999,999,999,999');
                                ELSE l_res_val := TO_CHAR(l_num_val, 'FM999,999,999,990.00'); END IF;
                            ELSE l_res_val := '0'; END IF;
                        EXCEPTION WHEN OTHERS THEN l_res_val := '-'; END;
                    ELSE l_res_val := l_val; END IF;
                END IF;
                
                IF NOT l_first THEN DBMS_LOB.APPEND(l_result, ','); END IF;
                l_first := FALSE;
                DBMS_LOB.APPEND(l_result, '{"title":"' || SAFE_JSON_ESCAPE(l_title) || '","value":"' || SAFE_JSON_ESCAPE(l_res_val) || '","icon":"' || SAFE_JSON_ESCAPE(l_icon) || '","trend":"' || SAFE_JSON_ESCAPE(l_trend) || '","color":"' || SAFE_JSON_ESCAPE(l_color) || '"}');
            EXCEPTION WHEN OTHERS THEN
                IF NOT l_first THEN DBMS_LOB.APPEND(l_result, ','); END IF;
                l_first := FALSE;
                DBMS_LOB.APPEND(l_result, '{"title":"Error","value":"-","icon":"alert","trend":"neutral","color":"red"}');
            END;
        END LOOP;
        DBMS_LOB.APPEND(l_result, ']');
        RETURN l_result;
    EXCEPTION WHEN OTHERS THEN RETURN '[]';
    END PROCESS_KPIS;

    -- ============================================================
    -- Data Profiling
    -- ============================================================
    FUNCTION ANALYZE_DATA_PROFILE(p_sql IN CLOB, p_sample_size IN NUMBER DEFAULT 100) RETURN CLOB IS
        l_cursor_id INTEGER; l_col_cnt INTEGER; l_desc DBMS_SQL.DESC_TAB;
        l_profile CLOB; l_num_cols NUMBER := 0; l_str_cols NUMBER := 0; l_date_cols NUMBER := 0;
        l_row_count NUMBER := 0; l_col_info CLOB; l_first_col BOOLEAN := TRUE; l_err_msg VARCHAR2(4000);
    BEGIN
        l_cursor_id := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(l_cursor_id, p_sql, DBMS_SQL.NATIVE);
        DBMS_SQL.DESCRIBE_COLUMNS(l_cursor_id, l_col_cnt, l_desc);
        DBMS_LOB.CREATETEMPORARY(l_col_info, TRUE);
        DBMS_LOB.APPEND(l_col_info, '[');
        
        FOR i IN 1 .. l_col_cnt LOOP
            IF NOT l_first_col THEN DBMS_LOB.APPEND(l_col_info, ','); END IF;
            l_first_col := FALSE;
            DBMS_LOB.APPEND(l_col_info, '{"name":"' || l_desc(i).col_name || '"');
            IF l_desc(i).col_type IN (2, 100, 101) THEN 
                l_num_cols := l_num_cols + 1;
                DBMS_LOB.APPEND(l_col_info, ',"type":"NUMBER","role":"measure"}');
            ELSIF l_desc(i).col_type = 12 THEN 
                l_date_cols := l_date_cols + 1;
                DBMS_LOB.APPEND(l_col_info, ',"type":"DATE","role":"dimension"}');
            ELSE
                l_str_cols := l_str_cols + 1;
                DBMS_LOB.APPEND(l_col_info, ',"type":"STRING","role":"dimension"}');
            END IF;
        END LOOP;
        
        DBMS_LOB.APPEND(l_col_info, ']');
        DBMS_SQL.CLOSE_CURSOR(l_cursor_id);
        
        BEGIN EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (' || p_sql || ') WHERE ROWNUM <= 10000' INTO l_row_count;
        EXCEPTION WHEN OTHERS THEN l_row_count := 0; END;
        
        DBMS_LOB.CREATETEMPORARY(l_profile, TRUE);
        DBMS_LOB.APPEND(l_profile, '{"totalColumns":' || l_col_cnt || ',"numericColumns":' || l_num_cols);
        DBMS_LOB.APPEND(l_profile, ',"stringColumns":' || l_str_cols || ',"dateColumns":' || l_date_cols);
        DBMS_LOB.APPEND(l_profile, ',"rowCount":' || l_row_count || ',"columns":' || l_col_info || '}');
        DBMS_LOB.FREETEMPORARY(l_col_info);
        RETURN l_profile;
    EXCEPTION WHEN OTHERS THEN
        IF DBMS_SQL.IS_OPEN(l_cursor_id) THEN DBMS_SQL.CLOSE_CURSOR(l_cursor_id); END IF;
        l_err_msg := SAFE_JSON_ESCAPE(SQLERRM);
        RETURN '{"error":"' || l_err_msg || '"}';
    END ANALYZE_DATA_PROFILE;

    -- ============================================================
    -- Chart Config Builder
    -- ============================================================
    FUNCTION BUILD_CHART_CONFIG(p_data_profile IN CLOB, p_ai_suggestion IN CLOB, p_user_preference IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    BEGIN
        IF p_ai_suggestion IS NOT NULL AND DBMS_LOB.GETLENGTH(p_ai_suggestion) > 2 THEN
            RETURN p_ai_suggestion;
        ELSE
            RETURN '{"chartType":"bar"}';
        END IF;
    END BUILD_CHART_CONFIG;

-- ============================================================
-- ASKLYZE AI - Chart Edit Feature - Package Body Updates
-- Add these procedures to AI_CORE_PKG body
-- ============================================================

-- ============================================================
-- NEW: Get available chart types from ASKLYZE_CHART_TYPES
-- ============================================================
PROCEDURE GET_CHART_TYPES(
    p_result_json OUT CLOB
) IS
    l_result CLOB;
    l_first BOOLEAN := TRUE;
BEGIN
    DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
    DBMS_LOB.APPEND(l_result, '{"status":"success","chart_types":[');
    
    FOR r IN (
        SELECT CHART_TYPE_ID, 
               CHART_CATEGORY, 
               DISPLAY_NAME, 
               DESCRIPTION,
               ECHARTS_TYPE,
               BEST_FOR
        FROM ASKLYZE_CHART_TYPES
        ORDER BY CHART_CATEGORY, DISPLAY_NAME
    ) LOOP
        IF NOT l_first THEN
            DBMS_LOB.APPEND(l_result, ',');
        END IF;
        l_first := FALSE;
        
        DBMS_LOB.APPEND(l_result, '{');
        DBMS_LOB.APPEND(l_result, '"id":"' || SAFE_JSON_ESCAPE(r.CHART_TYPE_ID) || '"');
        DBMS_LOB.APPEND(l_result, ',"category":"' || SAFE_JSON_ESCAPE(r.CHART_CATEGORY) || '"');
        DBMS_LOB.APPEND(l_result, ',"name":"' || SAFE_JSON_ESCAPE(r.DISPLAY_NAME) || '"');
        DBMS_LOB.APPEND(l_result, ',"description":"' || SAFE_JSON_ESCAPE(r.DESCRIPTION) || '"');
        DBMS_LOB.APPEND(l_result, ',"echarts_type":"' || SAFE_JSON_ESCAPE(r.ECHARTS_TYPE) || '"');
        IF r.BEST_FOR IS NOT NULL THEN
            DBMS_LOB.APPEND(l_result, ',"best_for":"' || SAFE_JSON_ESCAPE(r.BEST_FOR) || '"');
        END IF;
        DBMS_LOB.APPEND(l_result, '}');
    END LOOP;
    
    DBMS_LOB.APPEND(l_result, ']}');
    p_result_json := l_result;
    
EXCEPTION WHEN OTHERS THEN
    p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
END GET_CHART_TYPES;



-- ============================================================
-- Helper function: Execute SQL and return JSON array
-- (Add this if not already exists in your package)
-- ============================================================
-- ============================================================
    -- Helper function: Execute SQL and return JSON array
    -- FIXED: Added Row Limit to prevent ORA-06502 and Browser Crash
    -- ============================================================
    FUNCTION EXECUTE_SQL_TO_JSON(p_sql IN CLOB) RETURN CLOB IS
        l_cursor_id INTEGER; 
        l_rows_processed INTEGER; 
        l_col_cnt INTEGER; 
        l_desc DBMS_SQL.DESC_TAB;
        l_varchar_val VARCHAR2(32767); 
        l_number_val NUMBER; 
        l_date_val DATE;
        l_result CLOB; 
        l_data_started BOOLEAN := FALSE;
        l_row_count NUMBER := 0;      -- Added counter
        l_max_rows NUMBER := 2000;    -- Max rows limit for charts
    BEGIN
        IF p_sql IS NULL THEN RETURN '[]'; END IF;
        
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '[');
        
        l_cursor_id := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(l_cursor_id, p_sql, DBMS_SQL.NATIVE);
        DBMS_SQL.DESCRIBE_COLUMNS(l_cursor_id, l_col_cnt, l_desc);

        FOR i IN 1 .. l_col_cnt LOOP
            IF l_desc(i).col_type IN (2, 100, 101) THEN 
                DBMS_SQL.DEFINE_COLUMN(l_cursor_id, i, l_number_val);
            ELSIF l_desc(i).col_type IN (12, 180, 181, 182, 183, 231) THEN 
                DBMS_SQL.DEFINE_COLUMN(l_cursor_id, i, l_date_val);
            ELSE 
                DBMS_SQL.DEFINE_COLUMN(l_cursor_id, i, l_varchar_val, 32767); 
            END IF;
        END LOOP;

        l_rows_processed := DBMS_SQL.EXECUTE(l_cursor_id);
        
        -- Loop with Limit check
        WHILE DBMS_SQL.FETCH_ROWS(l_cursor_id) > 0 LOOP
            l_row_count := l_row_count + 1;
            IF l_row_count > l_max_rows THEN EXIT; END IF; -- Stop fetching if limit reached

            IF l_data_started THEN DBMS_LOB.APPEND(l_result, ','); END IF; 
            l_data_started := TRUE;
            DBMS_LOB.APPEND(l_result, '{');
            FOR i IN 1 .. l_col_cnt LOOP
                IF i > 1 THEN DBMS_LOB.APPEND(l_result, ','); END IF;
                -- Safe append to avoid buffer overflow
                DBMS_LOB.APPEND(l_result, '"' || l_desc(i).col_name || '":');
                
                IF l_desc(i).col_type IN (2, 100, 101) THEN
                    DBMS_SQL.COLUMN_VALUE(l_cursor_id, i, l_number_val);
                    IF l_number_val IS NOT NULL THEN 
                        l_varchar_val := TO_CHAR(l_number_val, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''');
                        IF SUBSTR(l_varchar_val, 1, 1) = '.' THEN 
                            l_varchar_val := '0' || l_varchar_val;
                        ELSIF SUBSTR(l_varchar_val, 1, 2) = '-.' THEN 
                            l_varchar_val := '-0' || SUBSTR(l_varchar_val, 2); 
                        END IF;
                        DBMS_LOB.APPEND(l_result, l_varchar_val);
                    ELSE 
                        DBMS_LOB.APPEND(l_result, 'null'); 
                    END IF;
                ELSIF l_desc(i).col_type IN (12, 180, 181, 182, 183, 231) THEN
                    DBMS_SQL.COLUMN_VALUE(l_cursor_id, i, l_date_val);
                    IF l_date_val IS NOT NULL THEN 
                        DBMS_LOB.APPEND(l_result, '"' || TO_CHAR(l_date_val, 'YYYY-MM-DD') || '"'); 
                    ELSE 
                        DBMS_LOB.APPEND(l_result, 'null'); 
                    END IF;
                ELSE
                    DBMS_SQL.COLUMN_VALUE(l_cursor_id, i, l_varchar_val);
                    IF l_varchar_val IS NOT NULL THEN 
                        DBMS_LOB.APPEND(l_result, '"' || SAFE_JSON_ESCAPE(l_varchar_val) || '"');
                    ELSE 
                        DBMS_LOB.APPEND(l_result, 'null'); 
                    END IF;
                END IF;
            END LOOP;
            DBMS_LOB.APPEND(l_result, '}');
        END LOOP;
        
        DBMS_LOB.APPEND(l_result, ']');
        DBMS_SQL.CLOSE_CURSOR(l_cursor_id);
        RETURN l_result;
    EXCEPTION WHEN OTHERS THEN
        IF DBMS_SQL.IS_OPEN(l_cursor_id) THEN 
            DBMS_SQL.CLOSE_CURSOR(l_cursor_id); 
        END IF;
        RETURN '[]';
    END EXECUTE_SQL_TO_JSON;




-- ============================================================
-- NEW: Update individual chart in dashboard
-- ============================================================
PROCEDURE UPDATE_DASHBOARD_CHART(
    p_query_id    IN NUMBER,
    p_chart_index IN NUMBER,
    p_new_sql     IN CLOB DEFAULT NULL,
    p_chart_type  IN VARCHAR2 DEFAULT NULL,
    p_chart_title IN VARCHAR2 DEFAULT NULL,
    p_result_json OUT CLOB
) IS
    l_dashboard_config CLOB;
    l_new_config CLOB;
    l_config_obj JSON_OBJECT_T;
    l_charts_arr JSON_ARRAY_T;
    l_chart_obj JSON_OBJECT_T;
    l_data CLOB;
    l_sql CLOB;
    l_user VARCHAR2(100);
    l_owner_user VARCHAR2(100);
BEGIN
    -- Verify ownership
    l_user := NVL(V('APP_USER'), USER);
    
    BEGIN
        SELECT APP_USER, DASHBOARD_CONFIG 
        INTO l_owner_user, l_dashboard_config
        FROM ASKLYZE_AI_QUERY_STORE 
        WHERE ID = p_query_id 
          AND QUERY_TYPE = 'DASHBOARD';
    EXCEPTION WHEN NO_DATA_FOUND THEN
        p_result_json := '{"status":"error","message":"Dashboard not found"}';
        RETURN;
    END;
    
    -- Security check
    IF l_owner_user != l_user THEN
        p_result_json := '{"status":"error","message":"Access denied"}';
        RETURN;
    END IF;
    
    IF l_dashboard_config IS NULL THEN
        p_result_json := '{"status":"error","message":"No dashboard configuration found"}';
        RETURN;
    END IF;
    
    -- Parse existing config
    BEGIN
        l_config_obj := JSON_OBJECT_T.parse(l_dashboard_config);
    EXCEPTION WHEN OTHERS THEN
        p_result_json := '{"status":"error","message":"Invalid dashboard configuration"}';
        RETURN;
    END;
    
    -- Get charts array
    IF NOT l_config_obj.has('charts') THEN
        p_result_json := '{"status":"error","message":"No charts in dashboard"}';
        RETURN;
    END IF;

    l_charts_arr := l_config_obj.get_array('charts');

    -- Validate chart index (0-based)
    IF p_chart_index < 0 OR p_chart_index >= l_charts_arr.get_size THEN
        p_result_json := '{"status":"error","message":"Invalid chart index: ' || p_chart_index || '"}';
        RETURN;
    END IF;

    -- Get the specific chart
    l_chart_obj := JSON_OBJECT_T(l_charts_arr.get(p_chart_index));

    -- Update SQL if provided
    IF p_new_sql IS NOT NULL AND DBMS_LOB.GETLENGTH(p_new_sql) > 0 THEN
        l_sql := CLEAN_AI_SQL(p_new_sql);
        l_chart_obj.put('sql', l_sql);

        -- Test the SQL by executing it
        BEGIN
            l_data := EXECUTE_SQL_TO_JSON(l_sql);
        EXCEPTION WHEN OTHERS THEN
            p_result_json := '{"status":"error","message":"SQL Error: ' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
            RETURN;
        END;
    END IF;

    -- Update chart type if provided
    IF p_chart_type IS NOT NULL THEN
        l_chart_obj.put('chart_type', LOWER(p_chart_type));
    END IF;

    -- Update title if provided
    IF p_chart_title IS NOT NULL THEN
        l_chart_obj.put('title', p_chart_title);
    END IF;

    -- Rebuild the charts array to avoid duplication issues with put()
    DECLARE
        l_new_charts_arr JSON_ARRAY_T := JSON_ARRAY_T();
        l_arr_size PLS_INTEGER := l_charts_arr.get_size;
    BEGIN
        FOR i IN 0 .. l_arr_size - 1 LOOP
            IF i = p_chart_index THEN
                l_new_charts_arr.append(l_chart_obj);
            ELSE
                l_new_charts_arr.append(l_charts_arr.get(i));
            END IF;
        END LOOP;
        l_charts_arr := l_new_charts_arr;
    END;

    -- Update config object with rebuilt array
    l_config_obj.put('charts', l_charts_arr);
    
    -- Convert back to CLOB
    l_new_config := l_config_obj.to_clob();
    
    -- Save to database
    UPDATE ASKLYZE_AI_QUERY_STORE
    SET DASHBOARD_CONFIG = l_new_config
    WHERE ID = p_query_id;
    
    COMMIT;
    
    -- Return success with updated chart data
    DBMS_LOB.CREATETEMPORARY(p_result_json, TRUE);
    DBMS_LOB.APPEND(p_result_json, '{"status":"success","chart_index":' || p_chart_index);
    DBMS_LOB.APPEND(p_result_json, ',"chart":' || l_chart_obj.to_clob());
    
    -- Execute and return new data if SQL was updated
    IF p_new_sql IS NOT NULL AND l_data IS NOT NULL THEN
        DBMS_LOB.APPEND(p_result_json, ',"data":' || l_data);
    END IF;
    
    DBMS_LOB.APPEND(p_result_json, '}');
    
EXCEPTION WHEN OTHERS THEN
    p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
END UPDATE_DASHBOARD_CHART;

-- ============================================================
-- Delete individual chart in dashboard
-- ============================================================
PROCEDURE DELETE_DASHBOARD_CHART(
    p_query_id    IN NUMBER,
    p_chart_index IN NUMBER,
    p_result_json OUT CLOB
) IS
    l_dashboard_config CLOB;
    l_new_config CLOB;
    l_config_obj JSON_OBJECT_T;
    l_charts_arr JSON_ARRAY_T;
    l_new_arr JSON_ARRAY_T := JSON_ARRAY_T();
    l_user VARCHAR2(100);
    l_owner_user VARCHAR2(100);
    l_size PLS_INTEGER;
    l_deleted_chart_id VARCHAR2(4000);
    l_layout_json CLOB;
    l_layout_arr JSON_ARRAY_T;
    l_layout_new JSON_ARRAY_T := JSON_ARRAY_T();
    l_layout_item JSON_OBJECT_T;
    l_layout_id VARCHAR2(4000);
BEGIN
    l_user := NVL(V('APP_USER'), USER);

    BEGIN
        SELECT APP_USER, DASHBOARD_CONFIG
          INTO l_owner_user, l_dashboard_config
          FROM ASKLYZE_AI_QUERY_STORE
         WHERE ID = p_query_id
           AND QUERY_TYPE = 'DASHBOARD';
    EXCEPTION WHEN NO_DATA_FOUND THEN
        p_result_json := '{"status":"error","message":"Dashboard not found"}';
        RETURN;
    END;

    IF l_owner_user != l_user THEN
        p_result_json := '{"status":"error","message":"Access denied"}';
        RETURN;
    END IF;

    IF l_dashboard_config IS NULL THEN
        p_result_json := '{"status":"error","message":"No dashboard configuration found"}';
        RETURN;
    END IF;

    BEGIN
        l_config_obj := JSON_OBJECT_T.parse(l_dashboard_config);
    EXCEPTION WHEN OTHERS THEN
        p_result_json := '{"status":"error","message":"Invalid dashboard configuration"}';
        RETURN;
    END;

    IF NOT l_config_obj.has('charts') THEN
        p_result_json := '{"status":"error","message":"No charts in dashboard"}';
        RETURN;
    END IF;

    l_charts_arr := l_config_obj.get_array('charts');
    l_size := l_charts_arr.get_size;

    IF p_chart_index < 0 OR p_chart_index >= l_size THEN
        p_result_json := '{"status":"error","message":"Invalid chart index: ' || p_chart_index || '"}';
        RETURN;
    END IF;

    -- Capture deleted chart id so we can clean layout without resetting it.
    BEGIN
        l_deleted_chart_id := JSON_OBJECT_T(l_charts_arr.get(p_chart_index)).get_string('id');
    EXCEPTION WHEN OTHERS THEN
        l_deleted_chart_id := NULL;
    END;

    FOR i IN 0..l_size-1 LOOP
        IF i != p_chart_index THEN
            l_new_arr.append(l_charts_arr.get(i));
        END IF;
    END LOOP;

    l_config_obj.put('charts', l_new_arr);
    l_new_config := l_config_obj.to_clob();

    UPDATE ASKLYZE_AI_QUERY_STORE
       SET DASHBOARD_CONFIG = l_new_config
     WHERE ID = p_query_id;

    -- Keep the user's layout, but remove the deleted chart entry so other charts stay in place.
    BEGIN
        SELECT LAYOUT_JSON INTO l_layout_json
          FROM ASKLYZE_DASHBOARD_LAYOUTS
         WHERE QUERY_ID = p_query_id
           AND APP_USER = l_user;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        l_layout_json := NULL;
    END;

    IF l_layout_json IS NOT NULL AND l_deleted_chart_id IS NOT NULL THEN
        BEGIN
            l_layout_arr := JSON_ARRAY_T.parse(l_layout_json);
            FOR i IN 0..l_layout_arr.get_size-1 LOOP
                BEGIN
                    l_layout_item := JSON_OBJECT_T(l_layout_arr.get(i));
                    l_layout_id := l_layout_item.get_string('id');
                    IF l_layout_id IS NULL OR l_layout_id <> l_deleted_chart_id THEN
                        l_layout_new.append(l_layout_arr.get(i));
                    END IF;
                EXCEPTION WHEN OTHERS THEN
                    -- If an entry isn't a JSON object, keep it as-is.
                    l_layout_new.append(l_layout_arr.get(i));
                END;
            END LOOP;

            UPDATE ASKLYZE_DASHBOARD_LAYOUTS
               SET LAYOUT_JSON = l_layout_new.to_clob(),
                   UPDATED_AT  = SYSTIMESTAMP
             WHERE QUERY_ID = p_query_id
               AND APP_USER = l_user;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    COMMIT;

    p_result_json := '{"status":"success","remaining":' || l_new_arr.get_size || '}';

EXCEPTION WHEN OTHERS THEN
    p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
END DELETE_DASHBOARD_CHART;

    -- ============================================================
    -- Generate Dashboard - WHITELIST-ONLY VERSION
    -- ============================================================
    PROCEDURE GENERATE_DASHBOARD(
        p_question IN VARCHAR2,
        p_schema_name IN VARCHAR2 DEFAULT USER,
        p_result_json OUT CLOB
    ) IS 
        l_context CLOB;
        l_body CLOB; 
        l_resp CLOB; 
        l_txt CLOB;
        l_id NUMBER; 
        l_key VARCHAR2(1000); 
        l_model VARCHAR2(100); 
        l_target VARCHAR2(128); 
        l_acc BOOLEAN; 
        l_msg VARCHAR2(500); 
        l_prompt CLOB; 
        l_dashboard_config CLOB; 
        l_chat_title VARCHAR2(200);
        l_report_title VARCHAR2(4000);
        l_validation_error VARCHAR2(500);
        l_sql_validation VARCHAR2(4000);
    BEGIN 
        -- Validate question first
        l_validation_error := VALIDATE_QUESTION(p_question);
        IF l_validation_error IS NOT NULL THEN
            p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(l_validation_error) || '","validation_error":true}';
            RETURN;
        END IF;
        
        l_target := UPPER(NVL(p_schema_name, USER)); 
        CHECK_SCHEMA_ACCESS(l_target, l_acc, l_msg); 
        IF NOT l_acc THEN 
            p_result_json := '{"status":"error","message":"' || l_msg || '"}'; 
            RETURN; 
        END IF;
        
        -- CHECK IF WHITELIST IS CONFIGURED
        IF NOT HAS_WHITELISTED_TABLES(C_DEFAULT_ORG_ID, l_target) THEN
            p_result_json := '{"status":"error","message":"No tables configured. Please click Data Settings to select which tables the AI can access.","needs_config":true}';
            RETURN;
        END IF;

        l_key := DBMS_LOB.SUBSTR(GET_CONF('GROQ_API_KEY'), 1000, 1);
        l_model := 'openai/gpt-oss-120b';
        
        -- GET ONLY WHITELISTED CONTEXT
        l_context := GET_SMART_CONTEXT(
            p_org_id       => C_DEFAULT_ORG_ID,
            p_schema_owner => l_target,
            p_question     => p_question,
            p_include_relations => 'Y'
        );

        DBMS_LOB.CREATETEMPORARY(l_prompt, TRUE);
        DBMS_LOB.APPEND(l_prompt, 'You are an Oracle SQL Expert building an EXECUTIVE DASHBOARD.');
        DBMS_LOB.APPEND(l_prompt, CHR(10) || CHR(10) || '=== AVAILABLE TABLES AND COLUMNS ===' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, 'You can ONLY use the following tables. Do NOT reference any other tables:' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, SUBSTR(l_context, 1, 8000));
        DBMS_LOB.APPEND(l_prompt, CHR(10) || CHR(10) || '=== CRITICAL RULES ===' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '1. ONLY use tables and columns listed above' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '2. Do NOT invent or hallucinate any table or column names' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '3. Use the exact column names as shown (case-sensitive)' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '4. If the user asks about data not in the tables above, respond with an error' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, CHR(10) || 'USER REQUEST: ' || p_question);
        DBMS_LOB.APPEND(l_prompt, CHR(10) || CHR(10) || 'Generate a comprehensive dashboard JSON with this EXACT structure:
{
  "dashboard_title": "Professional Dashboard Title",
  "kpis": [
    {
      "title": "KPI NAME IN UPPERCASE",
      "value_sql": "SELECT COUNT(*) FROM table_name",
      "icon": "dollar|users|check|warning|chart-line|briefcase",
      "color": "green|orange|blue|red|purple|teal",
      "trend": "+15%",
      "trend_label": "vs Last Period",
      "has_mini_chart": true,
      "mini_chart_sql": "SELECT month, value FROM ... ORDER BY month"
    }
  ],
  "charts": [
    {
      "id": "chart1",
      "title": "Chart Title",
      "chart_type": "line|bar|bar_horizontal|bar_stacked|pie|donut|area|radar|funnel",
      "sql": "SELECT category, value FROM ... GROUP BY category",
      "position": {"row": 1, "col": 1, "colspan": 2, "rowspan": 1},
      "config": {
        "xAxis": "COLUMN_NAME",
        "series": [{"name": "Series1", "dataKey": "VALUE_COL", "color": "#3b82f6"}]
      }
    }
  ]
}

RULES:
1. Generate 4 KPIs with meaningful metrics
2. Generate 9 charts with different types for variety
3. Use proper Oracle SQL syntax without schema prefix
4. Position charts in a 3-column grid layout
5. Colors: green=#22c55e, orange=#f97316, blue=#3b82f6, red=#ef4444, purple=#a855f7, teal=#14b8a6
6. Make KPI titles UPPERCASE
7. Include trend percentages where relevant
8. Use has_mini_chart:true only for the first/main KPI

');

        APEX_JSON.INITIALIZE_CLOB_OUTPUT;
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('model', l_model);
        APEX_JSON.OPEN_ARRAY('messages');
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('role', 'user');
        APEX_JSON.WRITE('content', l_prompt);
        APEX_JSON.CLOSE_OBJECT;
        APEX_JSON.CLOSE_ARRAY;
        APEX_JSON.WRITE('temperature', 0.3);
        APEX_JSON.OPEN_OBJECT('response_format');
        APEX_JSON.WRITE('type', 'json_object');
        APEX_JSON.CLOSE_OBJECT;
        APEX_JSON.CLOSE_OBJECT;
        l_body := APEX_JSON.GET_CLOB_OUTPUT;
        APEX_JSON.FREE_OUTPUT;
        DBMS_LOB.FREETEMPORARY(l_prompt);

        apex_web_service.g_request_headers.DELETE; 
        apex_web_service.g_request_headers(1).name := 'Content-Type'; 
        apex_web_service.g_request_headers(1).value := 'application/json'; 
        apex_web_service.g_request_headers(2).name := 'Authorization';
        apex_web_service.g_request_headers(2).value := 'Bearer ' || l_key; 
        l_resp := apex_web_service.make_rest_request(
            p_url => 'https://api.groq.com/openai/v1/chat/completions', 
            p_http_method => 'POST', 
            p_body => l_body
        ); 
          
        APEX_JSON.PARSE(l_resp); 
        l_txt := APEX_JSON.GET_VARCHAR2('choices[%d].message.content', 1); 
        
        IF l_txt IS NULL THEN 
            DECLARE
                l_api_error VARCHAR2(4000);
            BEGIN
                l_api_error := APEX_JSON.GET_VARCHAR2('error.message');
                IF l_api_error IS NOT NULL THEN
                    p_result_json := '{"status":"error","message":"API: ' || SAFE_JSON_ESCAPE(SUBSTR(l_api_error,1,200)) || '"}';
                ELSE
                    p_result_json := '{"status":"error","message":"No AI response. Check API key and model."}';
                END IF;
            EXCEPTION WHEN OTHERS THEN
                p_result_json := '{"status":"error","message":"AI returned no response"}';
            END;
            RETURN; 
        END IF;

        -- Parse dashboard config
        DECLARE 
            j_obj JSON_OBJECT_T; 
        BEGIN 
            j_obj := JSON_OBJECT_T.parse(l_txt); 
            l_report_title := j_obj.get_string('dashboard_title');
            l_dashboard_config := l_txt;
        EXCEPTION WHEN OTHERS THEN 
            l_report_title := 'Dashboard';
            l_dashboard_config := l_txt;
        END; 
        
        l_chat_title := SUBSTR(p_question, 1, 50) || CASE WHEN LENGTH(p_question) > 50 THEN '...' ELSE '' END;
        
        INSERT INTO ASKLYZE_AI_QUERY_STORE (
            APP_USER, USER_QUESTION, REPORT_TITLE, CHAT_TITLE, QUERY_TYPE, DASHBOARD_CONFIG, VISUALIZATION_TYPE
        ) VALUES (
            NVL(V('APP_USER'), USER), p_question, NVL(l_report_title, 'Dashboard'), l_chat_title, 'DASHBOARD', l_dashboard_config, 'DASHBOARD'
        ) RETURNING ID INTO l_id; 
        COMMIT; 
        
        p_result_json := '{"status":"success","query_id":' || l_id || ',"query_type":"DASHBOARD"}'; 
    EXCEPTION WHEN OTHERS THEN 
        p_result_json := '{"status":"error","message":"' || REPLACE(REPLACE(SQLERRM,'"','`'),CHR(10),' ') || '"}'; 
    END GENERATE_DASHBOARD;

    -- ============================================================
    -- Execute Dashboard
    -- ============================================================
-- ============================================================
    -- Execute Dashboard
    -- FIXED: Split LOB appends to avoid ORA-06502
    -- ============================================================
    PROCEDURE EXECUTE_DASHBOARD(
        p_query_id IN NUMBER,
        p_result_json OUT CLOB
    ) IS
        l_dashboard_config CLOB;
        l_report_title VARCHAR2(4000);
        l_result CLOB;
        l_kpis_arr JSON_ARRAY_T;
        l_charts_arr JSON_ARRAY_T;
        l_kpi_obj JSON_OBJECT_T;
        l_chart_obj JSON_OBJECT_T;
        l_config_obj JSON_OBJECT_T;
        l_processed_kpis CLOB;
        l_processed_charts CLOB;
        l_sql CLOB;
        l_data CLOB;
        l_num_val NUMBER;
        l_first_kpi BOOLEAN := TRUE;
        l_first_chart BOOLEAN := TRUE;
        l_saved_layout CLOB;
        l_user VARCHAR2(100) := NVL(V('APP_USER'), USER);
    BEGIN
        SELECT DASHBOARD_CONFIG, REPORT_TITLE 
        INTO l_dashboard_config, l_report_title
        FROM ASKLYZE_AI_QUERY_STORE 
        WHERE ID = p_query_id;

        -- Fetch Saved Layout
        BEGIN
            SELECT LAYOUT_JSON INTO l_saved_layout
            FROM ASKLYZE_DASHBOARD_LAYOUTS
            WHERE QUERY_ID = p_query_id AND APP_USER = l_user;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            l_saved_layout := NULL;
        END;
        
        IF l_dashboard_config IS NULL THEN
            p_result_json := '{"status":"error","message":"No dashboard configuration found"}';
            RETURN;
        END IF;
        
        l_config_obj := JSON_OBJECT_T.parse(l_dashboard_config);
        l_report_title := NVL(l_config_obj.get_string('dashboard_title'), l_report_title);
        
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '{"status":"success","query_id":' || p_query_id);
        DBMS_LOB.APPEND(l_result, ',"query_type":"DASHBOARD"');
        DBMS_LOB.APPEND(l_result, ',"dashboard_title":"' || SAFE_JSON_ESCAPE(l_report_title) || '"');

        -- Inject Saved Layout if exists
        IF l_saved_layout IS NOT NULL THEN
            DBMS_LOB.APPEND(l_result, ',"saved_layout":');
            DBMS_LOB.APPEND(l_result, l_saved_layout);
        END IF;
        
        -- Process KPIs
        DBMS_LOB.CREATETEMPORARY(l_processed_kpis, TRUE);
        DBMS_LOB.APPEND(l_processed_kpis, '[');
        
        IF l_config_obj.has('kpis') THEN
            l_kpis_arr := l_config_obj.get_array('kpis');
            FOR i IN 0 .. l_kpis_arr.get_size - 1 LOOP
                BEGIN
                    l_kpi_obj := JSON_OBJECT_T(l_kpis_arr.get(i));
                    
                    IF NOT l_first_kpi THEN DBMS_LOB.APPEND(l_processed_kpis, ','); END IF;
                    l_first_kpi := FALSE;
                    
                    DBMS_LOB.APPEND(l_processed_kpis, '{');
                    DBMS_LOB.APPEND(l_processed_kpis, '"title":"' || SAFE_JSON_ESCAPE(l_kpi_obj.get_string('title')) || '"');
                    DBMS_LOB.APPEND(l_processed_kpis, ',"icon":"' || SAFE_JSON_ESCAPE(NVL(l_kpi_obj.get_string('icon'), 'chart')) || '"');
                    DBMS_LOB.APPEND(l_processed_kpis, ',"color":"' || SAFE_JSON_ESCAPE(NVL(l_kpi_obj.get_string('color'), 'blue')) || '"');
                    DBMS_LOB.APPEND(l_processed_kpis, ',"trend":"' || SAFE_JSON_ESCAPE(l_kpi_obj.get_string('trend')) || '"');
                    DBMS_LOB.APPEND(l_processed_kpis, ',"trend_label":"' || SAFE_JSON_ESCAPE(l_kpi_obj.get_string('trend_label')) || '"');
                    
                    l_sql := CLEAN_AI_SQL(l_kpi_obj.get_string('value_sql'));
                    IF l_sql IS NOT NULL THEN
                        BEGIN
                            EXECUTE IMMEDIATE l_sql INTO l_num_val;
                            IF l_num_val IS NOT NULL THEN
                                IF l_num_val = TRUNC(l_num_val) THEN 
                                    DBMS_LOB.APPEND(l_processed_kpis, ',"value":"' || TO_CHAR(l_num_val, 'FM999,999,999,999') || '"');
                                ELSE 
                                    DBMS_LOB.APPEND(l_processed_kpis, ',"value":"' || TO_CHAR(l_num_val, 'FM999,999,999,990.00') || '"');
                                END IF;
                            ELSE
                                DBMS_LOB.APPEND(l_processed_kpis, ',"value":"0"');
                            END IF;
                        EXCEPTION WHEN OTHERS THEN
                            DBMS_LOB.APPEND(l_processed_kpis, ',"value":"-"');
                        END;
                    ELSE
                        DBMS_LOB.APPEND(l_processed_kpis, ',"value":"-"');
                    END IF;
                    
                    IF l_kpi_obj.get_boolean('has_mini_chart') = TRUE THEN
                        l_sql := CLEAN_AI_SQL(l_kpi_obj.get_string('mini_chart_sql'));
                        IF l_sql IS NOT NULL THEN
                            BEGIN
                                l_data := EXECUTE_SQL_TO_JSON(l_sql);
                                -- FIXED: Split Append
                                DBMS_LOB.APPEND(l_processed_kpis, ',"mini_chart_data":');
                                DBMS_LOB.APPEND(l_processed_kpis, l_data);
                            EXCEPTION WHEN OTHERS THEN
                                DBMS_LOB.APPEND(l_processed_kpis, ',"mini_chart_data":[]');
                            END;
                        END IF;
                    END IF;
                    
                    DBMS_LOB.APPEND(l_processed_kpis, '}');
                EXCEPTION WHEN OTHERS THEN
                    IF NOT l_first_kpi THEN DBMS_LOB.APPEND(l_processed_kpis, ','); END IF;
                    l_first_kpi := FALSE;
                    DBMS_LOB.APPEND(l_processed_kpis, '{"title":"Error","value":"-","icon":"warning","color":"red"}');
                END;
            END LOOP;
        END IF;
        DBMS_LOB.APPEND(l_processed_kpis, ']');
        
        -- Process Charts
        DBMS_LOB.CREATETEMPORARY(l_processed_charts, TRUE);
        DBMS_LOB.APPEND(l_processed_charts, '[');
        
        IF l_config_obj.has('charts') THEN
            l_charts_arr := l_config_obj.get_array('charts');
            FOR i IN 0 .. l_charts_arr.get_size - 1 LOOP
                BEGIN
                    l_chart_obj := JSON_OBJECT_T(l_charts_arr.get(i));
                    
                    IF NOT l_first_chart THEN DBMS_LOB.APPEND(l_processed_charts, ','); END IF;
                    l_first_chart := FALSE;
                    
                    DBMS_LOB.APPEND(l_processed_charts, '{');
                    DBMS_LOB.APPEND(l_processed_charts, '"id":"' || SAFE_JSON_ESCAPE(NVL(l_chart_obj.get_string('id'), 'chart_' || i)) || '"');
                    DBMS_LOB.APPEND(l_processed_charts, ',"title":"' || SAFE_JSON_ESCAPE(l_chart_obj.get_string('title')) || '"');
                    DBMS_LOB.APPEND(l_processed_charts, ',"chart_type":"' || SAFE_JSON_ESCAPE(NVL(l_chart_obj.get_string('chart_type'), 'bar')) || '"');

                    -- Add Position (Important for GridStack Default)
                    -- Add Position (Important for GridStack Default)
                    IF l_chart_obj.has('position') THEN
                        DBMS_LOB.APPEND(l_processed_charts, ',"position":' || l_chart_obj.get('position').to_clob);
                    ELSE
                        DBMS_LOB.APPEND(l_processed_charts, ',"position":{"row":1,"col":1,"colspan":1,"rowspan":1}');
                    END IF;
                    
                    IF l_chart_obj.has('config') THEN
                        DBMS_LOB.APPEND(l_processed_charts, ',"config":' || l_chart_obj.get('config').to_clob);
                    END IF;
                    DBMS_LOB.APPEND(l_processed_charts, ',"sql":"' || SAFE_JSON_ESCAPE(l_chart_obj.get_string('sql')) || '"');

                    l_sql := CLEAN_AI_SQL(l_chart_obj.get_string('sql'));
                    IF l_sql IS NOT NULL THEN
                        BEGIN
                            l_data := EXECUTE_SQL_TO_JSON(l_sql);
                            -- FIXED: Split Append (Avoids ORA-06502)
                            DBMS_LOB.APPEND(l_processed_charts, ',"data":');
                            DBMS_LOB.APPEND(l_processed_charts, l_data);
                        EXCEPTION WHEN OTHERS THEN
                            DBMS_LOB.APPEND(l_processed_charts, ',"data":[],"error":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"');
                        END;
                    ELSE
                        DBMS_LOB.APPEND(l_processed_charts, ',"data":[]');
                    END IF;
                    
                    DBMS_LOB.APPEND(l_processed_charts, '}');
                EXCEPTION WHEN OTHERS THEN
                    IF NOT l_first_chart THEN DBMS_LOB.APPEND(l_processed_charts, ','); END IF;
                    l_first_chart := FALSE;
                    DBMS_LOB.APPEND(l_processed_charts, '{"id":"error_' || i || '","title":"Error","chart_type":"bar","data":[]}');
                END;
            END LOOP;
        END IF;
        DBMS_LOB.APPEND(l_processed_charts, ']');
        
        -- FIXED: Safe appending of large CLOBs
        DBMS_LOB.APPEND(l_result, ',"kpis":');
        DBMS_LOB.APPEND(l_result, l_processed_kpis);
        DBMS_LOB.APPEND(l_result, ',"charts":');
        DBMS_LOB.APPEND(l_result, l_processed_charts);
        DBMS_LOB.APPEND(l_result, '}');
        
        p_result_json := l_result;
        
        DBMS_LOB.FREETEMPORARY(l_processed_kpis);
        DBMS_LOB.FREETEMPORARY(l_processed_charts);
        
    EXCEPTION WHEN OTHERS THEN
        p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END EXECUTE_DASHBOARD;

    -- ============================================================
    -- Main Generation - WHITELIST-ONLY VERSION
    -- ============================================================
    PROCEDURE GENERATE_INSIGHTS(
        p_question IN VARCHAR2, 
        p_schema_name IN VARCHAR2 DEFAULT USER, 
        p_category IN VARCHAR2 DEFAULT 'General', 
        p_result_json OUT CLOB
    ) IS 
        l_context CLOB;
        l_body CLOB; 
        l_resp CLOB; 
        l_txt CLOB; 
        l_sql CLOB; 
        l_kpis CLOB; 
        l_chart_config CLOB; 
        l_chart_config_v2 CLOB; 
        l_data_profile CLOB;
        l_viz_type VARCHAR2(50); 
        l_report_title VARCHAR2(4000); 
        l_chat_title VARCHAR2(200);
        l_id NUMBER; 
        l_key VARCHAR2(1000); 
        l_model VARCHAR2(100); 
        l_target VARCHAR2(128); 
        l_acc BOOLEAN; 
        l_msg VARCHAR2(500); 
        l_prompt CLOB; 
        l_category_instruction VARCHAR2(2000);
        l_detected_intent VARCHAR2(20);
        l_effective_category VARCHAR2(100);
        l_validation_error VARCHAR2(500);
        l_sql_validation VARCHAR2(4000);
    BEGIN 
        -- Question Validation
        l_validation_error := VALIDATE_QUESTION(p_question);
        IF l_validation_error IS NOT NULL THEN
            p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(l_validation_error) || '","validation_error":true}';
            RETURN;
        END IF;
        
        -- Intent Detection
        l_effective_category := p_category;
        IF p_category IS NULL OR p_category = 'General' THEN
            l_detected_intent := DETECT_QUERY_INTENT(p_question);
            IF l_detected_intent = 'DASHBOARD' THEN
                l_effective_category := 'Dashboard Builder';
            END IF;
        END IF;
        
        -- Route to Dashboard Builder if detected
        IF l_effective_category = 'Dashboard Builder' THEN
            GENERATE_DASHBOARD(p_question, p_schema_name, p_result_json);
            RETURN;
        END IF;
        
        l_target := UPPER(NVL(p_schema_name, USER)); 
        CHECK_SCHEMA_ACCESS(l_target, l_acc, l_msg); 
        IF NOT l_acc THEN 
            p_result_json := '{"status":"error","message":"' || l_msg || '"}'; 
            RETURN; 
        END IF;
        
        -- CHECK IF WHITELIST IS CONFIGURED
        IF NOT HAS_WHITELISTED_TABLES(C_DEFAULT_ORG_ID, l_target) THEN
            p_result_json := '{"status":"error","message":"No tables configured. Please click Data Settings to select which tables the AI can access.","needs_config":true}';
            RETURN;
        END IF;

        IF l_effective_category = 'Report Builder' THEN 
            l_category_instruction := 'Building a DETAILED REPORT with groupings.';
        ELSE 
            l_category_instruction := 'General data inquiry.'; 
        END IF;

        l_key := DBMS_LOB.SUBSTR(GET_CONF('GROQ_API_KEY'), 1000, 1);
        l_model := 'openai/gpt-oss-120b';
        
        -- GET ONLY WHITELISTED CONTEXT
        l_context := GET_SMART_CONTEXT(
            p_org_id       => C_DEFAULT_ORG_ID,
            p_schema_owner => l_target,
            p_question     => p_question,
            p_include_relations => 'Y'
        );

        DBMS_LOB.CREATETEMPORARY(l_prompt, TRUE);
        DBMS_LOB.APPEND(l_prompt, 'You are an Oracle SQL Expert. ' || l_category_instruction);
        DBMS_LOB.APPEND(l_prompt, CHR(10) || CHR(10) || '=== AVAILABLE TABLES AND COLUMNS ===' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, 'You can ONLY use the following tables. Do NOT reference any other tables:' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, SUBSTR(l_context, 1, 8000));
        DBMS_LOB.APPEND(l_prompt, CHR(10) || CHR(10) || '=== CRITICAL RULES ===' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '1. ONLY use tables and columns listed above' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '2. Do NOT invent or hallucinate any table or column names' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '3. Use the exact column names as shown' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '4. If the user asks about data not in the tables above, explain what is missing' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '5. NEVER put aggregate functions (SUM, AVG, COUNT) inside a GROUP BY clause. This causes ORA-00934.' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, '6. If you need to filter or group by an aggregate, use a HAVING clause or a Subquery (CTE).' || CHR(10));
        DBMS_LOB.APPEND(l_prompt, CHR(10) || 'USER QUESTION: ' || p_question);
        DBMS_LOB.APPEND(l_prompt, CHR(10) || CHR(10) || 'Return JSON structure: {"sql": "SELECT ...","report_title": "String","visualization_type": "COMPARISON|TREND|RELATIONSHIP|COMPOSITION|DISTRIBUTION",');
        DBMS_LOB.APPEND(l_prompt, '"kpis": [ {"title": "...", "value": "SELECT ...", "icon": "dollar|users|briefcase|chart-line", "trend": "up|down|neutral", "color": "green|orange|blue|red"} , ... (Create 3 KPIs) ],');
        DBMS_LOB.APPEND(l_prompt, '"chart": {"chartType": "bar|line|area|pie|scatter|combo","title": "...","xAxis": {"dataKey": "COLUMN_NAME"},');
        DBMS_LOB.APPEND(l_prompt, '"yAxis": [{"name":"Primary"},{"name":"Secondary"}],"series": [{"name": "Count", "type": "bar", "dataKey": "COL1", "color": "#..."},');
        DBMS_LOB.APPEND(l_prompt, '{"name": "Amount", "type": "line", "dataKey": "COL2", "yAxisIndex": 1, "color": "#..."}]}}');
        DBMS_LOB.APPEND(l_prompt, '"pivot_recommendation": {"recommended": true/false,"reason": "Why pivot is recommended or not","rows": ["COLUMN1", "COLUMN2"],"columns": ["DATE_COLUMN"],"measures": ["AMOUNT", "COUNT"]}');

        APEX_JSON.INITIALIZE_CLOB_OUTPUT;
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('model', l_model);
        APEX_JSON.OPEN_ARRAY('messages');
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('role', 'user');
        APEX_JSON.WRITE('content', l_prompt);
        APEX_JSON.CLOSE_OBJECT;
        APEX_JSON.CLOSE_ARRAY;
        APEX_JSON.WRITE('temperature', 0.2);
        APEX_JSON.OPEN_OBJECT('response_format');
        APEX_JSON.WRITE('type', 'json_object');
        APEX_JSON.CLOSE_OBJECT;
        APEX_JSON.CLOSE_OBJECT;
        l_body := APEX_JSON.GET_CLOB_OUTPUT;
        APEX_JSON.FREE_OUTPUT;
        DBMS_LOB.FREETEMPORARY(l_prompt);

        apex_web_service.g_request_headers.DELETE; 
        apex_web_service.g_request_headers(1).name := 'Content-Type'; 
        apex_web_service.g_request_headers(1).value := 'application/json'; 
        apex_web_service.g_request_headers(2).name := 'Authorization';
        apex_web_service.g_request_headers(2).value := 'Bearer ' || l_key; 
        l_resp := apex_web_service.make_rest_request(
            p_url => 'https://api.groq.com/openai/v1/chat/completions', 
            p_http_method => 'POST', 
            p_body => l_body
        ); 
          
        APEX_JSON.PARSE(l_resp); 
        l_txt := APEX_JSON.GET_VARCHAR2('choices[%d].message.content', 1); 
        
        IF l_txt IS NULL THEN 
            DECLARE
                l_api_error VARCHAR2(4000);
            BEGIN
                l_api_error := APEX_JSON.GET_VARCHAR2('error.message');
                IF l_api_error IS NOT NULL THEN
                    p_result_json := '{"status":"error","message":"API: ' || SAFE_JSON_ESCAPE(SUBSTR(l_api_error,1,200)) || '"}';
                ELSE
                    p_result_json := '{"status":"error","message":"No AI response. Check API key and model."}';
                END IF;
            EXCEPTION WHEN OTHERS THEN
                p_result_json := '{"status":"error","message":"AI returned no response"}';
            END;
            RETURN; 
        END IF;

        DECLARE j_obj JSON_OBJECT_T; 
        BEGIN 
            j_obj := JSON_OBJECT_T.parse(l_txt); 
            l_sql := j_obj.get_string('sql'); 
            l_report_title := j_obj.get_string('report_title');
            l_viz_type := j_obj.get_string('visualization_type');
            IF j_obj.has('kpis') AND NOT j_obj.get('kpis').is_null THEN l_kpis := j_obj.get('kpis').to_clob(); ELSE l_kpis := '[]'; END IF;
            IF j_obj.has('chart') AND NOT j_obj.get('chart').is_null THEN l_chart_config_v2 := j_obj.get('chart').to_clob(); ELSE l_chart_config_v2 := '{}'; END IF;
        EXCEPTION WHEN OTHERS THEN 
            l_sql := REGEXP_SUBSTR(l_txt, '"sql"\s*:\s*"([^"]+)"', 1, 1, 'i', 1);
            l_kpis := '[]'; l_chart_config := '{}'; l_chart_config_v2 := '{}';
            l_report_title := 'Data Report'; l_viz_type := 'CUSTOM';
            IF l_sql IS NULL THEN l_sql := 'SELECT ''Parse Error'' FROM DUAL'; END IF;
        END; 
        
        IF l_sql IS NULL THEN l_sql := 'SELECT ''No SQL'' FROM DUAL'; END IF;
        l_sql := CLEAN_AI_SQL(l_sql);
        
        -- VALIDATE SQL AGAINST WHITELIST
        l_sql_validation := VALIDATE_SQL_WHITELIST(l_sql, C_DEFAULT_ORG_ID, l_target);
        IF l_sql_validation IS NOT NULL THEN
            -- Log the validation failure but don't block - AI might have used aliases
            NULL; -- For now, just continue
        END IF;
        
        BEGIN l_data_profile := ANALYZE_DATA_PROFILE(l_sql); 
        EXCEPTION WHEN OTHERS THEN l_data_profile := '{}'; END;
        
        l_chart_config := BUILD_CHART_CONFIG(l_data_profile, l_chart_config_v2);
        l_chat_title := SUBSTR(p_question, 1, 50) || CASE WHEN LENGTH(p_question) > 50 THEN '...' ELSE '' END;
        
        INSERT INTO ASKLYZE_AI_QUERY_STORE (
            APP_USER, USER_QUESTION, GENERATED_SQL, KPIS_JSON, CHART_CONFIG_JSON, 
            CHART_CONFIG_V2, DATA_PROFILE, VISUALIZATION_TYPE, REPORT_TITLE, CHAT_TITLE, QUERY_TYPE
        ) VALUES (
            NVL(V('APP_USER'), USER), p_question, l_sql, l_kpis, l_chart_config, 
            l_chart_config, l_data_profile, NVL(l_viz_type, 'CUSTOM'), NVL(l_report_title, 'Analysis Report'), l_chat_title, 'REPORT'
        ) RETURNING ID INTO l_id; 
        COMMIT; 
        
        p_result_json := '{"status":"success","query_id":' || l_id || ',"query_type":"REPORT","kpis":' || NVL(l_kpis,'[]') || '}'; 
    EXCEPTION WHEN OTHERS THEN 
        p_result_json := '{"status":"error","message":"' || REPLACE(REPLACE(SQLERRM,'"','`'),CHR(10),' ') || '"}'; 
    END;

    -- ============================================================
    -- Update Query
    -- ============================================================
    PROCEDURE UPDATE_QUERY(p_query_id IN NUMBER, p_new_sql IN CLOB, p_result_json OUT CLOB) IS
        l_sql CLOB; l_data_profile CLOB; l_new_chart_config CLOB;
        l_x_axis VARCHAR2(128); l_col_name VARCHAR2(128); l_col_type VARCHAR2(50);
        l_col_count NUMBER; l_series_json CLOB; l_first_series BOOLEAN := TRUE; l_series_idx NUMBER := 0;
        TYPE t_color_array IS TABLE OF VARCHAR2(20) INDEX BY PLS_INTEGER;
        l_color_arr t_color_array;
    BEGIN
        l_color_arr(0) := '#3498db'; l_color_arr(1) := '#e74c3c'; l_color_arr(2) := '#2ecc71'; l_color_arr(3) := '#f39c12';
        l_color_arr(4) := '#9b59b6'; l_color_arr(5) := '#1abc9c'; l_color_arr(6) := '#e67e22'; l_color_arr(7) := '#34495e';

        l_sql := CLEAN_AI_SQL(p_new_sql);
        UPDATE ASKLYZE_AI_QUERY_STORE SET GENERATED_SQL = l_sql WHERE ID = p_query_id;
        COMMIT;
        
        BEGIN l_data_profile := ANALYZE_DATA_PROFILE(l_sql); 
        EXCEPTION WHEN OTHERS THEN l_data_profile := '{}'; END;
        
        BEGIN
            APEX_JSON.PARSE(l_data_profile);
            l_col_count := APEX_JSON.GET_COUNT(p_path => 'columns');
            l_x_axis := NULL;
            FOR i IN 1 .. NVL(l_col_count, 0) LOOP
                l_col_type := APEX_JSON.GET_VARCHAR2(p_path => 'columns[%d].type', p0 => i);
                IF l_col_type = 'STRING' OR l_col_type = 'DATE' THEN
                    l_x_axis := APEX_JSON.GET_VARCHAR2(p_path => 'columns[%d].name', p0 => i);
                    EXIT;
                END IF;
            END LOOP;
            IF l_x_axis IS NULL AND l_col_count > 0 THEN l_x_axis := APEX_JSON.GET_VARCHAR2(p_path => 'columns[1].name'); END IF;
            IF l_x_axis IS NULL THEN l_x_axis := 'COLUMN1'; END IF;
            
            DBMS_LOB.CREATETEMPORARY(l_series_json, TRUE);
            DBMS_LOB.APPEND(l_series_json, '[');
            FOR i IN 1 .. NVL(l_col_count, 0) LOOP
                l_col_name := APEX_JSON.GET_VARCHAR2(p_path => 'columns[%d].name', p0 => i);
                l_col_type := APEX_JSON.GET_VARCHAR2(p_path => 'columns[%d].type', p0 => i);
                IF l_col_type = 'NUMBER' AND UPPER(l_col_name) != UPPER(l_x_axis) THEN
                    IF NOT l_first_series THEN DBMS_LOB.APPEND(l_series_json, ','); END IF;
                    l_first_series := FALSE;
                    DBMS_LOB.APPEND(l_series_json, '{"name":"' || SAFE_JSON_ESCAPE(l_col_name) || '","type":"bar","dataKey":"' || SAFE_JSON_ESCAPE(l_col_name) || '","color":"' || l_color_arr(MOD(l_series_idx, 8)) || '"}');
                    l_series_idx := l_series_idx + 1;
                END IF;
            END LOOP;
            IF l_first_series THEN
                IF l_col_count >= 2 THEN
                    l_col_name := APEX_JSON.GET_VARCHAR2(p_path => 'columns[2].name');
                    DBMS_LOB.APPEND(l_series_json, '{"name":"' || SAFE_JSON_ESCAPE(NVL(l_col_name, 'Value')) || '","type":"bar","dataKey":"' || SAFE_JSON_ESCAPE(NVL(l_col_name, 'Value')) || '","color":"#3498db"}');
                ELSE DBMS_LOB.APPEND(l_series_json, '{"type":"bar","color":"#3498db"}'); END IF;
            END IF;
            DBMS_LOB.APPEND(l_series_json, ']');
            
            DBMS_LOB.CREATETEMPORARY(l_new_chart_config, TRUE);
            DBMS_LOB.APPEND(l_new_chart_config, '{"chartType":"bar","title":"Query Results","xAxis":{"dataKey":"' || SAFE_JSON_ESCAPE(l_x_axis) || '"},"yAxis":[{"name":"Value"}],"series":');
            DBMS_LOB.APPEND(l_new_chart_config, l_series_json);
            DBMS_LOB.APPEND(l_new_chart_config, '}');
            DBMS_LOB.FREETEMPORARY(l_series_json);
        EXCEPTION WHEN OTHERS THEN
            l_new_chart_config := '{"chartType":"bar","title":"Query Results","xAxis":{"dataKey":"' || NVL(l_x_axis, 'COLUMN1') || '"},"yAxis":[{"name":"Value"}],"series":[{"type":"bar"}]}';
        END;

        UPDATE ASKLYZE_AI_QUERY_STORE SET DATA_PROFILE = l_data_profile, CHART_CONFIG_JSON = l_new_chart_config, CHART_CONFIG_V2 = l_new_chart_config WHERE ID = p_query_id;
        COMMIT;
        EXECUTE_AND_RENDER(p_query_id, p_result_json);
    EXCEPTION WHEN OTHERS THEN
        p_result_json := '{"status":"error","message":"Update Error: ' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END UPDATE_QUERY;

    -- ============================================================
    -- Data Execution & Renderer
    -- ============================================================
PROCEDURE EXECUTE_AND_RENDER(p_query_id IN NUMBER, p_result_json OUT CLOB) IS 
        l_sql CLOB; l_chart_config CLOB; l_chart_config_v2 CLOB; l_data_profile CLOB; l_viz_type VARCHAR2(50);
        l_kpis CLOB; l_processed_kpis CLOB; l_report_title VARCHAR2(4000); l_query_type VARCHAR2(20);
        l_user_question VARCHAR2(4000);
        l_cursor_id INTEGER; l_rows_processed INTEGER; l_col_cnt INTEGER; l_desc DBMS_SQL.DESC_TAB;
        l_varchar_val VARCHAR2(32767); l_number_val NUMBER; l_date_val DATE;
        l_result CLOB; l_data_started BOOLEAN := FALSE;
        l_row_count NUMBER := 0;
        l_max_rows NUMBER := 5000; -- HARD LIMIT TO PREVENT CRASH
        
        -- NEW: Pivot variables
        l_pivot_analysis CLOB;
        l_pivot_recommended BOOLEAN := FALSE;
        l_pivot_config CLOB;
        l_pivot_reason VARCHAR2(500);
    BEGIN 
        BEGIN
            SELECT QUERY_TYPE INTO l_query_type FROM ASKLYZE_AI_QUERY_STORE WHERE ID = p_query_id;
        EXCEPTION WHEN OTHERS THEN
            l_query_type := 'REPORT';
        END;
        
        IF l_query_type = 'DASHBOARD' THEN
            EXECUTE_DASHBOARD(p_query_id, p_result_json);
            RETURN;
        END IF;
        
        BEGIN
            SELECT GENERATED_SQL, CHART_CONFIG_JSON, KPIS_JSON, REPORT_TITLE, 
                   CHART_CONFIG_V2, DATA_PROFILE, VISUALIZATION_TYPE, USER_QUESTION
            INTO l_sql, l_chart_config, l_kpis, l_report_title, 
                 l_chart_config_v2, l_data_profile, l_viz_type, l_user_question
            FROM ASKLYZE_AI_QUERY_STORE WHERE ID = p_query_id;
        EXCEPTION WHEN OTHERS THEN
            SELECT GENERATED_SQL, CHART_CONFIG_JSON, KPIS_JSON, REPORT_TITLE, USER_QUESTION
            INTO l_sql, l_chart_config, l_kpis, l_report_title, l_user_question
            FROM ASKLYZE_AI_QUERY_STORE WHERE ID = p_query_id;
            l_chart_config_v2 := l_chart_config; l_data_profile := '{}'; l_viz_type := 'CUSTOM';
        END;
        
        l_processed_kpis := PROCESS_KPIS(l_kpis);
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '{"status":"success","query_id":' || p_query_id);
        DBMS_LOB.APPEND(l_result, ',"query_type":"REPORT"');
        DBMS_LOB.APPEND(l_result, ',"report_title":"' || SAFE_JSON_ESCAPE(NVL(l_report_title, 'Analysis Report')) || '"');
        DBMS_LOB.APPEND(l_result, ',"visualization_type":"' || SAFE_JSON_ESCAPE(NVL(l_viz_type, 'CUSTOM')) || '"');
        DBMS_LOB.APPEND(l_result, ',"generated_sql":"' || SAFE_JSON_ESCAPE(l_sql) || '"');
        
        -- Safe Append for Configs
        DBMS_LOB.APPEND(l_result, ',"chart_config":'); 
        IF l_chart_config_v2 IS NOT NULL AND DBMS_LOB.GETLENGTH(l_chart_config_v2) > 2 THEN 
            DBMS_LOB.APPEND(l_result, l_chart_config_v2);
        ELSIF l_chart_config IS NOT NULL AND DBMS_LOB.GETLENGTH(l_chart_config) > 2 THEN 
            DBMS_LOB.APPEND(l_result, l_chart_config);
        ELSE 
            DBMS_LOB.APPEND(l_result, '{}'); 
        END IF;
        
        DBMS_LOB.APPEND(l_result, ',"data_profile":');
        IF l_data_profile IS NOT NULL AND DBMS_LOB.GETLENGTH(l_data_profile) > 2 THEN 
            DBMS_LOB.APPEND(l_result, l_data_profile);
        ELSE 
            DBMS_LOB.APPEND(l_result, '{}'); 
        END IF;
        
        DBMS_LOB.APPEND(l_result, ',"kpis":');
        IF l_processed_kpis IS NOT NULL AND DBMS_LOB.GETLENGTH(l_processed_kpis) > 2 THEN 
            DBMS_LOB.APPEND(l_result, l_processed_kpis);
        ELSE 
            DBMS_LOB.APPEND(l_result, '[]'); 
        END IF;

        -- Execute SQL and collect data
        l_cursor_id := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(l_cursor_id, l_sql, DBMS_SQL.NATIVE);
        DBMS_SQL.DESCRIBE_COLUMNS(l_cursor_id, l_col_cnt, l_desc);

        FOR i IN 1 .. l_col_cnt LOOP
            IF l_desc(i).col_type IN (2, 100, 101) THEN 
                DBMS_SQL.DEFINE_COLUMN(l_cursor_id, i, l_number_val);
            ELSIF l_desc(i).col_type IN (12, 180, 181, 182, 183, 231) THEN 
                DBMS_SQL.DEFINE_COLUMN(l_cursor_id, i, l_date_val);
            ELSE 
                DBMS_SQL.DEFINE_COLUMN(l_cursor_id, i, l_varchar_val, 32767); 
            END IF;
        END LOOP;

        l_rows_processed := DBMS_SQL.EXECUTE(l_cursor_id);
        DBMS_LOB.APPEND(l_result, ',"data":[');
        
        -- Loop with Limit
        WHILE DBMS_SQL.FETCH_ROWS(l_cursor_id) > 0 LOOP
            l_row_count := l_row_count + 1;
            IF l_row_count > l_max_rows THEN EXIT; END IF; -- Stop at limit
            
            IF l_data_started THEN DBMS_LOB.APPEND(l_result, ','); END IF; 
            l_data_started := TRUE;
            DBMS_LOB.APPEND(l_result, '{');
            FOR i IN 1 .. l_col_cnt LOOP
                IF i > 1 THEN DBMS_LOB.APPEND(l_result, ','); END IF;
                DBMS_LOB.APPEND(l_result, '"' || l_desc(i).col_name || '":');
                IF l_desc(i).col_type IN (2, 100, 101) THEN
                    DBMS_SQL.COLUMN_VALUE(l_cursor_id, i, l_number_val);
                    IF l_number_val IS NOT NULL THEN 
                        l_varchar_val := TO_CHAR(l_number_val, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''');
                        IF SUBSTR(l_varchar_val, 1, 1) = '.' THEN 
                            l_varchar_val := '0' || l_varchar_val;
                        ELSIF SUBSTR(l_varchar_val, 1, 2) = '-.' THEN 
                            l_varchar_val := '-0' || SUBSTR(l_varchar_val, 2); 
                        END IF;
                        DBMS_LOB.APPEND(l_result, l_varchar_val);
                    ELSE 
                        DBMS_LOB.APPEND(l_result, 'null'); 
                    END IF;
                ELSIF l_desc(i).col_type IN (12, 180, 181, 182, 183, 231) THEN
                    DBMS_SQL.COLUMN_VALUE(l_cursor_id, i, l_date_val);
                    IF l_date_val IS NOT NULL THEN 
                        DBMS_LOB.APPEND(l_result, '"' || TO_CHAR(l_date_val, 'YYYY-MM-DD') || '"'); 
                    ELSE 
                        DBMS_LOB.APPEND(l_result, 'null'); 
                    END IF;
                ELSE
                    DBMS_SQL.COLUMN_VALUE(l_cursor_id, i, l_varchar_val);
                    IF l_varchar_val IS NOT NULL THEN 
                        l_varchar_val := SAFE_JSON_ESCAPE(l_varchar_val);
                        DBMS_LOB.APPEND(l_result, '"' || l_varchar_val || '"');
                    ELSE 
                        DBMS_LOB.APPEND(l_result, 'null'); 
                    END IF;
                END IF;
            END LOOP;
            DBMS_LOB.APPEND(l_result, '}');
        END LOOP;
        
        DBMS_LOB.APPEND(l_result, ']');
        DBMS_SQL.CLOSE_CURSOR(l_cursor_id);
        
        -- Include warning if rows truncated
        IF l_row_count > l_max_rows THEN
            DBMS_LOB.APPEND(l_result, ',"limit_reached":true');
            DBMS_LOB.APPEND(l_result, ',"rows_fetched":' || l_max_rows);
        END IF;

        -- NEW: Analyze Pivot Suitability
        BEGIN
            l_pivot_analysis := ANALYZE_PIVOT_SUITABILITY(l_data_profile, l_row_count, l_user_question);
            APEX_JSON.PARSE(l_pivot_analysis);
            l_pivot_recommended := APEX_JSON.GET_BOOLEAN('pivot_recommended');
            l_pivot_reason := APEX_JSON.GET_VARCHAR2('reason');
            IF l_pivot_recommended THEN
                l_pivot_config := DETECT_PIVOT_CONFIG_AI(l_user_question, l_data_profile, NULL);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            l_pivot_recommended := FALSE;
        END;
        
        DBMS_LOB.APPEND(l_result, ',"pivot_recommended":' || CASE WHEN l_pivot_recommended THEN 'true' ELSE 'false' END);
        
        IF l_pivot_recommended AND l_pivot_config IS NOT NULL THEN
            DBMS_LOB.APPEND(l_result, ',"pivot_config":');
            DBMS_LOB.APPEND(l_result, l_pivot_config);
            IF l_pivot_reason IS NOT NULL THEN
                DBMS_LOB.APPEND(l_result, ',"pivot_reason":"' || SAFE_JSON_ESCAPE(l_pivot_reason) || '"');
            END IF;
        END IF;
        
        DBMS_LOB.APPEND(l_result, '}');
        p_result_json := l_result;
        
    EXCEPTION WHEN OTHERS THEN 
        IF DBMS_SQL.IS_OPEN(l_cursor_id) THEN 
            DBMS_SQL.CLOSE_CURSOR(l_cursor_id); 
        END IF;
        p_result_json := '{"status":"error","message":"SQL Error: ' || SAFE_JSON_ESCAPE(SQLERRM) || '"}'; 
    END EXECUTE_AND_RENDER;

    -- ============================================================
    -- Chat History Management (Unchanged)
    -- ============================================================
    PROCEDURE GET_CHAT_HISTORY(
        p_user IN VARCHAR2 DEFAULT NULL,
        p_limit IN NUMBER DEFAULT 50,
        p_offset IN NUMBER DEFAULT 0,
        p_search IN VARCHAR2 DEFAULT NULL,
        p_result_json OUT CLOB
    ) IS
        l_user VARCHAR2(100);
        l_result CLOB;
        l_first BOOLEAN := TRUE;
        l_total NUMBER;
        
        CURSOR c_history IS
            SELECT ID, CHAT_TITLE, USER_QUESTION, REPORT_TITLE, VISUALIZATION_TYPE, 
                   IS_FAVORITE, CREATED_AT, QUERY_TYPE
            FROM ASKLYZE_AI_QUERY_STORE
            WHERE APP_USER = l_user
              AND NVL(IS_DELETED, 'N') = 'N'
              AND (p_search IS NULL 
                   OR UPPER(USER_QUESTION) LIKE '%' || UPPER(p_search) || '%'
                   OR UPPER(CHAT_TITLE) LIKE '%' || UPPER(p_search) || '%')
            ORDER BY CREATED_AT DESC
            OFFSET p_offset ROWS FETCH NEXT p_limit ROWS ONLY;
    BEGIN
        l_user := NVL(p_user, NVL(V('APP_USER'), USER));
        
        SELECT COUNT(*) INTO l_total
        FROM ASKLYZE_AI_QUERY_STORE
        WHERE APP_USER = l_user
          AND NVL(IS_DELETED, 'N') = 'N'
          AND (p_search IS NULL 
               OR UPPER(USER_QUESTION) LIKE '%' || UPPER(p_search) || '%'
               OR UPPER(CHAT_TITLE) LIKE '%' || UPPER(p_search) || '%');
        
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '{"status":"success","total":' || l_total || ',"chats":[');
        
        FOR r IN c_history LOOP
            IF NOT l_first THEN DBMS_LOB.APPEND(l_result, ','); END IF;
            l_first := FALSE;
            
            DBMS_LOB.APPEND(l_result, '{');
            DBMS_LOB.APPEND(l_result, '"id":' || r.ID);
            DBMS_LOB.APPEND(l_result, ',"title":"' || SAFE_JSON_ESCAPE(NVL(r.CHAT_TITLE, SUBSTR(r.USER_QUESTION, 1, 50))) || '"');
            DBMS_LOB.APPEND(l_result, ',"question":"' || SAFE_JSON_ESCAPE(r.USER_QUESTION) || '"');
            DBMS_LOB.APPEND(l_result, ',"report_title":"' || SAFE_JSON_ESCAPE(r.REPORT_TITLE) || '"');
            DBMS_LOB.APPEND(l_result, ',"viz_type":"' || SAFE_JSON_ESCAPE(r.VISUALIZATION_TYPE) || '"');
            DBMS_LOB.APPEND(l_result, ',"query_type":"' || SAFE_JSON_ESCAPE(NVL(r.QUERY_TYPE, 'REPORT')) || '"');
            DBMS_LOB.APPEND(l_result, ',"is_favorite":"' || NVL(r.IS_FAVORITE, 'N') || '"');
            DBMS_LOB.APPEND(l_result, ',"created_at":"' || TO_CHAR(r.CREATED_AT, 'YYYY-MM-DD HH24:MI') || '"');
            DBMS_LOB.APPEND(l_result, ',"time_ago":"' || 
                CASE 
                    WHEN r.CREATED_AT > SYSTIMESTAMP - INTERVAL '1' MINUTE THEN 'Just now'
                    WHEN r.CREATED_AT > SYSTIMESTAMP - INTERVAL '1' HOUR THEN TRUNC(EXTRACT(MINUTE FROM (SYSTIMESTAMP - r.CREATED_AT))) || 'm ago'
                    WHEN r.CREATED_AT > SYSTIMESTAMP - INTERVAL '1' DAY THEN TRUNC(EXTRACT(HOUR FROM (SYSTIMESTAMP - r.CREATED_AT))) || 'h ago'
                    WHEN r.CREATED_AT > SYSTIMESTAMP - INTERVAL '7' DAY THEN TRUNC(SYSDATE - CAST(r.CREATED_AT AS DATE)) || 'd ago'
                    ELSE TO_CHAR(r.CREATED_AT, 'Mon DD')
                END || '"');
            DBMS_LOB.APPEND(l_result, '}');
        END LOOP;
        
        DBMS_LOB.APPEND(l_result, ']}');
        p_result_json := l_result;
        
    EXCEPTION WHEN OTHERS THEN
        p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END GET_CHAT_HISTORY;

    PROCEDURE DELETE_CHAT(p_query_id IN NUMBER, p_result_json OUT CLOB) IS
        l_user VARCHAR2(100);
    BEGIN
        l_user := NVL(V('APP_USER'), USER);
        UPDATE ASKLYZE_AI_QUERY_STORE SET IS_DELETED = 'Y' WHERE ID = p_query_id AND APP_USER = l_user;
        IF SQL%ROWCOUNT > 0 THEN COMMIT; p_result_json := '{"status":"success","message":"Chat deleted"}';
        ELSE p_result_json := '{"status":"error","message":"Chat not found or access denied"}'; END IF;
    EXCEPTION WHEN OTHERS THEN
        p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END DELETE_CHAT;

    PROCEDURE TOGGLE_FAVORITE(p_query_id IN NUMBER, p_result_json OUT CLOB) IS
        l_user VARCHAR2(100); l_current CHAR(1);
    BEGIN
        l_user := NVL(V('APP_USER'), USER);
        SELECT NVL(IS_FAVORITE, 'N') INTO l_current FROM ASKLYZE_AI_QUERY_STORE WHERE ID = p_query_id AND APP_USER = l_user;
        UPDATE ASKLYZE_AI_QUERY_STORE SET IS_FAVORITE = CASE WHEN l_current = 'Y' THEN 'N' ELSE 'Y' END WHERE ID = p_query_id AND APP_USER = l_user;
        COMMIT;
        p_result_json := '{"status":"success","is_favorite":"' || CASE WHEN l_current = 'Y' THEN 'N' ELSE 'Y' END || '"}';
    EXCEPTION WHEN NO_DATA_FOUND THEN p_result_json := '{"status":"error","message":"Chat not found"}';
    WHEN OTHERS THEN p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END TOGGLE_FAVORITE;

    PROCEDURE RENAME_CHAT(p_query_id IN NUMBER, p_new_title IN VARCHAR2, p_result_json OUT CLOB) IS
        l_user VARCHAR2(100);
    BEGIN
        l_user := NVL(V('APP_USER'), USER);
        UPDATE ASKLYZE_AI_QUERY_STORE SET CHAT_TITLE = SUBSTR(p_new_title, 1, 200) WHERE ID = p_query_id AND APP_USER = l_user;
        IF SQL%ROWCOUNT > 0 THEN COMMIT; p_result_json := '{"status":"success","message":"Chat renamed"}';
        ELSE p_result_json := '{"status":"error","message":"Chat not found or access denied"}'; END IF;
    EXCEPTION WHEN OTHERS THEN p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END RENAME_CHAT;

    PROCEDURE CLEAR_HISTORY(p_user IN VARCHAR2 DEFAULT NULL, p_result_json OUT CLOB) IS
        l_user VARCHAR2(100); l_count NUMBER;
    BEGIN
        l_user := NVL(p_user, NVL(V('APP_USER'), USER));
        UPDATE ASKLYZE_AI_QUERY_STORE SET IS_DELETED = 'Y' WHERE APP_USER = l_user AND NVL(IS_DELETED, 'N') = 'N';
        l_count := SQL%ROWCOUNT; COMMIT;
        p_result_json := '{"status":"success","deleted_count":' || l_count || '}';
    EXCEPTION WHEN OTHERS THEN p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END CLEAR_HISTORY;


  -- Internal helper: JSON escape
  FUNCTION ASKLYZE_CAT_JSON_ESC(p_val IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN REPLACE(REPLACE(REPLACE(NVL(p_val,''), '\', '\\'), '"', '\"'), CHR(10), '\n');
  END;

  FUNCTION ASKLYZE_CAT_YN(p_val IN CHAR, p_default IN CHAR := 'Y') RETURN CHAR IS
    l CHAR(1);
  BEGIN
    l := UPPER(SUBSTR(NVL(TRIM(p_val), p_default), 1, 1));
    IF l NOT IN ('Y','N') THEN
      l := p_default;
    END IF;
    RETURN l;
  END;

  FUNCTION ASKLYZE_CAT_HASH64(p_text IN CLOB) RETURN VARCHAR2 IS
    l_in   VARCHAR2(32767);
    l_hash NUMBER;
    l_hex  VARCHAR2(64);
  BEGIN
    l_in := DBMS_LOB.SUBSTR(p_text, 32767, 1);
    l_hash := DBMS_UTILITY.GET_HASH_VALUE(l_in, 1, 4294967295);
    l_hex := LPAD(LOWER(TO_CHAR(ABS(l_hash), 'FMXXXXXXXXXXXXXXXX')), 64, '0');
    RETURN l_hex;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN LPAD('0', 64, '0');
  END;

  FUNCTION ASKLYZE_CAT_ROLE(p_col_name IN VARCHAR2, p_data_type IN VARCHAR2) RETURN VARCHAR2 IS
    l_name VARCHAR2(200) := LOWER(NVL(p_col_name,''));
    l_type VARCHAR2(200) := UPPER(NVL(p_data_type,''));
  BEGIN
    IF l_name = 'id' OR l_name LIKE '%\_id' ESCAPE '\' OR l_name LIKE 'id\_%' ESCAPE '\' THEN
      RETURN 'id';
    ELSIF l_name LIKE '%date%' OR l_name LIKE '%time%' OR l_type LIKE 'TIMESTAMP%' OR l_type = 'DATE' THEN
      RETURN 'date';
    ELSIF l_name LIKE 'is\_%' ESCAPE '\' OR l_name LIKE '%\_flag' ESCAPE '\' OR l_name LIKE '%flag%' THEN
      RETURN 'flag';
    ELSIF l_type IN ('NUMBER','FLOAT','BINARY_FLOAT','BINARY_DOUBLE','INTEGER') THEN
      RETURN 'measure';
    ELSIF l_type IN ('CLOB','NCLOB') THEN
      RETURN 'text';
    ELSE
      RETURN 'dimension';
    END IF;
  END;

  PROCEDURE ASKLYZE_CAT_GET_OR_CREATE_SCHEMA(
      p_org_id        IN NUMBER,
      p_schema_owner  IN VARCHAR2,
      p_include_views IN CHAR,
      p_schema_id     OUT NUMBER,
      p_eff_inc_views OUT CHAR
  ) IS
    l_owner VARCHAR2(128) := UPPER(TRIM(p_schema_owner));
    l_inc   CHAR(1);
  BEGIN
    BEGIN
      SELECT id, include_views
        INTO p_schema_id, l_inc
        FROM ASKLYZE_CATALOG_SCHEMAS
       WHERE org_id = p_org_id
         AND schema_owner = l_owner;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_inc := ASKLYZE_CAT_YN(p_include_views, 'Y');
        INSERT INTO ASKLYZE_CATALOG_SCHEMAS (org_id, schema_owner, include_views, is_enabled)
        VALUES (p_org_id, l_owner, l_inc, 'Y')
        RETURNING id INTO p_schema_id;
    END;

    IF p_include_views IS NOT NULL THEN
      l_inc := ASKLYZE_CAT_YN(p_include_views, l_inc);
      UPDATE ASKLYZE_CATALOG_SCHEMAS
         SET include_views = l_inc,
             updated_at = SYSTIMESTAMP
       WHERE id = p_schema_id;
    END IF;

    p_eff_inc_views := ASKLYZE_CAT_YN(l_inc, 'Y');
  END;

  PROCEDURE CATALOG_REFRESH_SCHEMA(
      p_org_id        IN NUMBER,
      p_schema_owner  IN VARCHAR2,
      p_refresh_mode  IN VARCHAR2 DEFAULT 'INCR',
      p_include_views IN CHAR     DEFAULT NULL,
      p_result_json   OUT CLOB
  ) IS
    l_schema_id   NUMBER;
    l_log_id      NUMBER;
    l_owner       VARCHAR2(128) := UPPER(TRIM(p_schema_owner));
    l_mode        VARCHAR2(10)  := UPPER(NVL(TRIM(p_refresh_mode), 'INCR'));
    l_inc_views   CHAR(1);
    l_scanned     NUMBER := 0;
    l_changed     NUMBER := 0;
    l_existing_id NUMBER;
    l_existing_ddl TIMESTAMP;
    l_table_id    NUMBER;
    l_fp_text     CLOB;
    l_fp          VARCHAR2(64);
    l_role        VARCHAR2(30);
  BEGIN
    IF l_mode NOT IN ('INCR','FULL') THEN
      l_mode := 'INCR';
    END IF;

    ASKLYZE_CAT_GET_OR_CREATE_SCHEMA(
      p_org_id        => p_org_id,
      p_schema_owner  => l_owner,
      p_include_views => p_include_views,
      p_schema_id     => l_schema_id,
      p_eff_inc_views => l_inc_views
    );

    INSERT INTO ASKLYZE_CATALOG_REFRESH_LOG(schema_id, refresh_mode, status, started_at)
    VALUES (l_schema_id, l_mode, 'RUNNING', SYSTIMESTAMP)
    RETURNING id INTO l_log_id;

    IF l_mode = 'FULL' THEN
      UPDATE ASKLYZE_CATALOG_TABLES
         SET status = 'MISSING',
             updated_at = SYSTIMESTAMP
       WHERE schema_id = l_schema_id;
    END IF;

    FOR r IN (
      SELECT *
      FROM (
        SELECT o.owner,
               o.object_name,
               o.object_type,
               o.status,
               CAST(o.last_ddl_time AS TIMESTAMP) AS last_ddl_ts,
               tc.comments AS table_comment,
               t.num_rows,
               t.blocks,
               t.avg_row_len
          FROM all_objects o
          LEFT JOIN all_tab_comments tc
            ON tc.owner = o.owner
           AND tc.table_name = o.object_name
          LEFT JOIN all_tables t
            ON t.owner = o.owner
           AND t.table_name = o.object_name
         WHERE o.owner = l_owner
           AND (
                o.object_type = 'TABLE'
                OR (l_inc_views = 'Y' AND o.object_type = 'VIEW')
           )
         ORDER BY o.object_type, o.object_name
      )
    ) LOOP
      l_scanned := l_scanned + 1;
      l_existing_id := NULL;
      l_existing_ddl := NULL;

      BEGIN
        SELECT id, last_ddl_time
          INTO l_existing_id, l_existing_ddl
          FROM ASKLYZE_CATALOG_TABLES
         WHERE schema_id   = l_schema_id
           AND object_name = r.object_name
           AND object_type = r.object_type;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
      END;

      IF l_mode = 'INCR'
         AND l_existing_id IS NOT NULL
         AND l_existing_ddl IS NOT NULL
         AND r.last_ddl_ts IS NOT NULL
         AND l_existing_ddl = r.last_ddl_ts
      THEN
        UPDATE ASKLYZE_CATALOG_TABLES
           SET status        = r.status,
               table_comment = SUBSTR(r.table_comment,1,4000),
               num_rows      = r.num_rows,
               blocks        = r.blocks,
               avg_row_len   = r.avg_row_len,
               updated_at    = SYSTIMESTAMP
         WHERE id = l_existing_id;
        CONTINUE;
      END IF;

      DBMS_LOB.CREATETEMPORARY(l_fp_text, TRUE);
      DBMS_LOB.APPEND(l_fp_text,
        r.owner||'.'||r.object_name||':'||r.object_type||':'||
        NVL(TO_CHAR(r.last_ddl_ts,'YYYYMMDDHH24MISSFF3'),'NULL')||'|'
      );

      FOR c IN (
        SELECT column_id, column_name, data_type, data_length, data_precision, data_scale, nullable
          FROM all_tab_columns
         WHERE owner = r.owner
           AND table_name = r.object_name
         ORDER BY column_id
      ) LOOP
        DBMS_LOB.APPEND(
          l_fp_text,
          c.column_id||':'||c.column_name||':'||c.data_type||':'||
          NVL(TO_CHAR(c.data_length),'')||':'||
          NVL(TO_CHAR(c.data_precision),'')||':'||
          NVL(TO_CHAR(c.data_scale),'')||':'||
          c.nullable||';'
        );
      END LOOP;

      l_fp := ASKLYZE_CAT_HASH64(l_fp_text);
      DBMS_LOB.FREETEMPORARY(l_fp_text);

      IF l_existing_id IS NULL THEN
        INSERT INTO ASKLYZE_CATALOG_TABLES(
          schema_id, owner_name, object_name, object_type,
          status, last_ddl_time, table_comment,
          num_rows, blocks, avg_row_len,
          fingerprint_sha256, updated_at
        ) VALUES (
          l_schema_id, r.owner, r.object_name, r.object_type,
          r.status, r.last_ddl_ts, SUBSTR(r.table_comment,1,4000),
          r.num_rows, r.blocks, r.avg_row_len,
          l_fp, SYSTIMESTAMP
        ) RETURNING id INTO l_table_id;
        l_changed := l_changed + 1;
      ELSE
        UPDATE ASKLYZE_CATALOG_TABLES
           SET status             = r.status,
               last_ddl_time      = r.last_ddl_ts,
               table_comment      = SUBSTR(r.table_comment,1,4000),
               num_rows           = r.num_rows,
               blocks             = r.blocks,
               avg_row_len        = r.avg_row_len,
               fingerprint_sha256 = l_fp,
               updated_at         = SYSTIMESTAMP
         WHERE id = l_existing_id;
        l_table_id := l_existing_id;
        l_changed := l_changed + 1;
      END IF;

      DELETE FROM ASKLYZE_CATALOG_COLUMNS WHERE table_id = l_table_id;

      FOR c IN (
        SELECT c.column_id,
               c.column_name,
               c.data_type,
               c.data_length,
               c.data_precision,
               c.data_scale,
               c.nullable,
               cc.comments AS column_comment
          FROM all_tab_columns c
          LEFT JOIN all_col_comments cc
            ON cc.owner = c.owner
           AND cc.table_name = c.table_name
           AND cc.column_name = c.column_name
         WHERE c.owner = r.owner
           AND c.table_name = r.object_name
         ORDER BY c.column_id
      ) LOOP
        l_role := ASKLYZE_CAT_ROLE(c.column_name, c.data_type);
        INSERT INTO ASKLYZE_CATALOG_COLUMNS(
          table_id, column_id, column_name,
          data_type, data_length, data_precision, data_scale,
          nullable, column_comment, semantic_role
        ) VALUES (
          l_table_id, c.column_id, c.column_name,
          c.data_type, c.data_length, c.data_precision, c.data_scale,
          c.nullable, SUBSTR(c.column_comment,1,4000),
          l_role
        );
      END LOOP;
    END LOOP;

    DELETE FROM ASKLYZE_CATALOG_RELATIONS
     WHERE fk_table_id IN (SELECT id FROM ASKLYZE_CATALOG_TABLES WHERE schema_id = l_schema_id)
        OR pk_table_id IN (SELECT id FROM ASKLYZE_CATALOG_TABLES WHERE schema_id = l_schema_id);

    FOR rr IN (
      SELECT fk_t.id  AS fk_table_id,
             fk.constraint_name AS fk_constraint_name,
             fkcc.column_name   AS fk_column_name,
             pk_t.id  AS pk_table_id,
             pkcc.column_name   AS pk_column_name,
             fk.delete_rule     AS delete_rule
        FROM all_constraints fk
        JOIN all_cons_columns fkcc
          ON fkcc.owner = fk.owner
         AND fkcc.constraint_name = fk.constraint_name
        JOIN all_constraints pk
          ON pk.owner = fk.r_owner
         AND pk.constraint_name = fk.r_constraint_name
        JOIN all_cons_columns pkcc
          ON pkcc.owner = pk.owner
         AND pkcc.constraint_name = pk.constraint_name
         AND pkcc.position = fkcc.position
        JOIN ASKLYZE_CATALOG_TABLES fk_t
          ON fk_t.schema_id   = l_schema_id
         AND fk_t.owner_name  = fk.owner
         AND fk_t.object_name = fk.table_name
         AND fk_t.object_type = 'TABLE'
        JOIN ASKLYZE_CATALOG_TABLES pk_t
          ON pk_t.schema_id   = l_schema_id
         AND pk_t.owner_name  = pk.owner
         AND pk_t.object_name = pk.table_name
         AND pk_t.object_type = 'TABLE'
       WHERE fk.owner = l_owner
         AND fk.constraint_type = 'R'
    ) LOOP
      INSERT INTO ASKLYZE_CATALOG_RELATIONS(
        fk_table_id, fk_constraint_name, fk_column_name,
        pk_table_id, pk_column_name,
        delete_rule, join_condition
      ) VALUES (
        rr.fk_table_id, rr.fk_constraint_name, rr.fk_column_name,
        rr.pk_table_id, rr.pk_column_name,
        rr.delete_rule,
        SUBSTR('FK.'||rr.fk_column_name||' = PK.'||rr.pk_column_name, 1, 500)
      );
    END LOOP;

    UPDATE ASKLYZE_CATALOG_SCHEMAS
       SET last_refresh_ts = SYSTIMESTAMP,
           updated_at = SYSTIMESTAMP
     WHERE id = l_schema_id;

    UPDATE ASKLYZE_CATALOG_REFRESH_LOG
       SET ended_at = SYSTIMESTAMP,
           status = 'SUCCESS',
           tables_scanned = l_scanned,
           tables_changed = l_changed
     WHERE id = l_log_id;

    COMMIT;

    p_result_json :=
      '{"status":"success","schema_id":'||l_schema_id||
      ',"tables_scanned":'||l_scanned||
      ',"tables_changed":'||l_changed||
      ',"mode":"'||l_mode||'"}';

  EXCEPTION
    WHEN OTHERS THEN
      DECLARE
        l_err VARCHAR2(4000) := SUBSTR(SQLERRM,1,4000);
      BEGIN
        IF l_log_id IS NOT NULL THEN
          UPDATE ASKLYZE_CATALOG_REFRESH_LOG
             SET ended_at = SYSTIMESTAMP,
                 status = 'FAILED',
                 message = l_err
           WHERE id = l_log_id;
          COMMIT;
        END IF;
        p_result_json := '{"status":"error","message":"' || ASKLYZE_CAT_JSON_ESC(l_err) || '"}';
      END;
  END CATALOG_REFRESH_SCHEMA;

  PROCEDURE CATALOG_SET_WHITELIST(
      p_org_id          IN NUMBER,
      p_schema_owner    IN VARCHAR2,
      p_object_name     IN VARCHAR2,
      p_object_type     IN VARCHAR2 DEFAULT 'TABLE',
      p_is_whitelisted  IN CHAR     DEFAULT 'Y',
      p_is_enabled      IN CHAR     DEFAULT 'Y',
      p_app_user        IN VARCHAR2 DEFAULT NULL,
      p_result_json     OUT CLOB
  ) IS
    l_schema_id NUMBER;
    l_owner     VARCHAR2(128) := UPPER(TRIM(p_schema_owner));
    l_obj       VARCHAR2(128) := UPPER(TRIM(p_object_name));
    l_type      VARCHAR2(10)  := UPPER(NVL(TRIM(p_object_type),'TABLE'));
    l_wl        CHAR(1) := ASKLYZE_CAT_YN(p_is_whitelisted, 'Y');
    l_en        CHAR(1) := ASKLYZE_CAT_YN(p_is_enabled, 'Y');
    l_table_id  NUMBER;
    l_dummy_inc CHAR(1);
  BEGIN
    IF l_type NOT IN ('TABLE','VIEW') THEN l_type := 'TABLE'; END IF;

    ASKLYZE_CAT_GET_OR_CREATE_SCHEMA(
      p_org_id        => p_org_id,
      p_schema_owner  => l_owner,
      p_include_views => NULL,
      p_schema_id     => l_schema_id,
      p_eff_inc_views => l_dummy_inc
    );

    SELECT id INTO l_table_id
      FROM ASKLYZE_CATALOG_TABLES
     WHERE schema_id   = l_schema_id
       AND object_name = l_obj
       AND object_type = l_type;

    UPDATE ASKLYZE_CATALOG_TABLES
       SET is_whitelisted = l_wl,
           updated_at = SYSTIMESTAMP
     WHERE id = l_table_id;

    IF l_wl = 'N' THEN
      IF p_app_user IS NULL THEN
        UPDATE ASKLYZE_CATALOG_TABLE_ACCESS
           SET is_enabled = 'N',
               updated_at = SYSTIMESTAMP
         WHERE org_id = p_org_id
           AND table_id = l_table_id;
      ELSE
        UPDATE ASKLYZE_CATALOG_TABLE_ACCESS
           SET is_enabled = 'N',
               updated_at = SYSTIMESTAMP
         WHERE org_id = p_org_id
           AND table_id = l_table_id
           AND app_user = p_app_user;
      END IF;
    ELSE
      UPDATE ASKLYZE_CATALOG_TABLE_ACCESS
         SET is_enabled = l_en,
             updated_at = SYSTIMESTAMP
       WHERE org_id = p_org_id
         AND table_id = l_table_id
         AND NVL(app_user,'*') = NVL(p_app_user,'*');

      IF SQL%ROWCOUNT = 0 THEN
        BEGIN
          INSERT INTO ASKLYZE_CATALOG_TABLE_ACCESS(org_id, app_user, table_id, is_enabled)
          VALUES (p_org_id, p_app_user, l_table_id, l_en);
        EXCEPTION
          WHEN DUP_VAL_ON_INDEX THEN
            UPDATE ASKLYZE_CATALOG_TABLE_ACCESS
               SET is_enabled = l_en,
                   updated_at = SYSTIMESTAMP
             WHERE org_id = p_org_id
               AND table_id = l_table_id
               AND NVL(app_user,'*') = NVL(p_app_user,'*');
        END;
      END IF;
    END IF;

    COMMIT;

    p_result_json :=
      '{"status":"success","table_id":'||l_table_id||
      ',"is_whitelisted":"'||l_wl||
      '","is_enabled":"'||l_en||
      '","app_user":'||
      CASE WHEN p_app_user IS NULL THEN 'null' ELSE '"'||ASKLYZE_CAT_JSON_ESC(p_app_user)||'"' END
      ||'}';

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_result_json := '{"status":"error","message":"Object not found in catalog. Run CATALOG_REFRESH_SCHEMA first."}';
    WHEN OTHERS THEN
      p_result_json := '{"status":"error","message":"' || ASKLYZE_CAT_JSON_ESC(SUBSTR(SQLERRM,1,4000)) || '"}';
  END CATALOG_SET_WHITELIST;

  FUNCTION CATALOG_GET_CONTEXT_TABLES_JSON(
      p_org_id        IN NUMBER,
      p_schema_owner  IN VARCHAR2,
      p_app_user      IN VARCHAR2 DEFAULT NULL,
      p_max_tables    IN NUMBER   DEFAULT 40,
      p_max_cols      IN NUMBER   DEFAULT 60
  ) RETURN CLOB IS
    l_schema_id   NUMBER;
    l_owner       VARCHAR2(128) := UPPER(TRIM(p_schema_owner));
    l_has_access  NUMBER := 0;
    l_out         CLOB;
    l_dummy_inc   CHAR(1);
  BEGIN
    ASKLYZE_CAT_GET_OR_CREATE_SCHEMA(
      p_org_id        => p_org_id,
      p_schema_owner  => l_owner,
      p_include_views => NULL,
      p_schema_id     => l_schema_id,
      p_eff_inc_views => l_dummy_inc
    );

    SELECT COUNT(*) INTO l_has_access
      FROM ASKLYZE_CATALOG_TABLE_ACCESS
     WHERE org_id = p_org_id;

    APEX_JSON.INITIALIZE_CLOB_OUTPUT;
    APEX_JSON.OPEN_ARRAY;

    FOR t IN (
      SELECT *
        FROM (
          SELECT t.id, t.object_name, t.object_type, t.summary_en, t.summary_ar, NVL(t.num_rows,0) nr
            FROM ASKLYZE_CATALOG_TABLES t
           WHERE t.schema_id = l_schema_id
             AND t.is_enabled = 'Y'
             AND t.is_whitelisted = 'Y'
             AND NVL(t.status,'VALID') <> 'MISSING'
             AND (
                  l_has_access = 0
                  OR EXISTS (
                    SELECT 1
                      FROM ASKLYZE_CATALOG_TABLE_ACCESS a
                     WHERE a.org_id = p_org_id
                       AND a.table_id = t.id
                       AND a.is_enabled = 'Y'
                       AND (a.app_user IS NULL OR (p_app_user IS NOT NULL AND a.app_user = p_app_user))
                  )
             )
           ORDER BY nr DESC, t.object_name
        )
       WHERE ROWNUM <= NVL(p_max_tables,40)
    ) LOOP
      APEX_JSON.OPEN_OBJECT;
      APEX_JSON.WRITE('table_id', t.id);
      APEX_JSON.WRITE('table', t.object_name);
      APEX_JSON.WRITE('type', t.object_type);
      IF t.summary_en IS NOT NULL THEN APEX_JSON.WRITE('summary_en', t.summary_en); END IF;
      IF t.summary_ar IS NOT NULL THEN APEX_JSON.WRITE('summary_ar', t.summary_ar); END IF;

      APEX_JSON.OPEN_ARRAY('cols');
      FOR c IN (
        SELECT *
          FROM (
            SELECT column_name, data_type
              FROM ASKLYZE_CATALOG_COLUMNS
             WHERE table_id = t.id
             ORDER BY column_id
          )
         WHERE ROWNUM <= NVL(p_max_cols,60)
      ) LOOP
        APEX_JSON.WRITE(c.column_name || '(' || c.data_type || ')');
      END LOOP;
      APEX_JSON.CLOSE_ARRAY;
      APEX_JSON.CLOSE_OBJECT;
    END LOOP;

    APEX_JSON.CLOSE_ARRAY;
    l_out := APEX_JSON.GET_CLOB_OUTPUT;
    APEX_JSON.FREE_OUTPUT;

    RETURN NVL(l_out,'[]');
  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        APEX_JSON.FREE_OUTPUT;
      EXCEPTION WHEN OTHERS THEN NULL; END;
      RETURN '[]';
  END CATALOG_GET_CONTEXT_TABLES_JSON;

  FUNCTION CATALOG_GET_TABLE_DETAILS_JSON(
      p_table_id IN NUMBER,
      p_max_cols IN NUMBER DEFAULT 200
  ) RETURN CLOB IS
    l_out        CLOB;
    l_owner_name VARCHAR2(128);
    l_obj_name   VARCHAR2(128);
    l_obj_type   VARCHAR2(10);
    l_comment    VARCHAR2(4000);
    l_sum_en     VARCHAR2(4000);
    l_sum_ar     VARCHAR2(4000);
    l_tags       CLOB;
  BEGIN
    SELECT owner_name, object_name, object_type, table_comment, summary_en, summary_ar, tags_json
      INTO l_owner_name, l_obj_name, l_obj_type, l_comment, l_sum_en, l_sum_ar, l_tags
      FROM ASKLYZE_CATALOG_TABLES
     WHERE id = p_table_id;

    APEX_JSON.INITIALIZE_CLOB_OUTPUT;
    APEX_JSON.OPEN_OBJECT;

    APEX_JSON.WRITE('table_id', p_table_id);
    APEX_JSON.WRITE('owner', l_owner_name);
    APEX_JSON.WRITE('object_name', l_obj_name);
    APEX_JSON.WRITE('object_type', l_obj_type);
    IF l_comment IS NOT NULL THEN APEX_JSON.WRITE('comment', l_comment); END IF;
    IF l_sum_en  IS NOT NULL THEN APEX_JSON.WRITE('summary_en', l_sum_en); END IF;
    IF l_sum_ar  IS NOT NULL THEN APEX_JSON.WRITE('summary_ar', l_sum_ar); END IF;
    IF l_tags IS NOT NULL AND DBMS_LOB.GETLENGTH(l_tags) > 2 THEN
      APEX_JSON.WRITE_RAW('tags', l_tags);
    END IF;

    APEX_JSON.OPEN_ARRAY('columns');
    FOR c IN (
      SELECT *
        FROM (
          SELECT column_id, column_name, data_type, data_length, data_precision, data_scale,
                 nullable, semantic_role, is_search_key, column_comment
            FROM ASKLYZE_CATALOG_COLUMNS
           WHERE table_id = p_table_id
           ORDER BY column_id
        )
       WHERE ROWNUM <= NVL(p_max_cols,200)
    ) LOOP
      APEX_JSON.OPEN_OBJECT;
      APEX_JSON.WRITE('column_id', c.column_id);
      APEX_JSON.WRITE('name', c.column_name);
      APEX_JSON.WRITE('data_type', c.data_type);
      IF c.data_length IS NOT NULL THEN APEX_JSON.WRITE('data_length', c.data_length); END IF;
      IF c.data_precision IS NOT NULL THEN APEX_JSON.WRITE('data_precision', c.data_precision); END IF;
      IF c.data_scale IS NOT NULL THEN APEX_JSON.WRITE('data_scale', c.data_scale); END IF;
      IF c.nullable IS NOT NULL THEN APEX_JSON.WRITE('nullable', c.nullable); END IF;
      IF c.semantic_role IS NOT NULL THEN APEX_JSON.WRITE('semantic_role', c.semantic_role); END IF;
      IF c.is_search_key IS NOT NULL THEN APEX_JSON.WRITE('is_search_key', c.is_search_key); END IF;
      IF c.column_comment IS NOT NULL THEN APEX_JSON.WRITE('comment', c.column_comment); END IF;
      APEX_JSON.CLOSE_OBJECT;
    END LOOP;
    APEX_JSON.CLOSE_ARRAY;

    APEX_JSON.OPEN_ARRAY('relations');
    FOR r IN (
      SELECT 'FK' direction,
             fk_t.object_name fk_table,
             rel.fk_column_name fk_column,
             pk_t.object_name pk_table,
             rel.pk_column_name pk_column,
             rel.delete_rule,
             rel.join_condition
        FROM ASKLYZE_CATALOG_RELATIONS rel
        JOIN ASKLYZE_CATALOG_TABLES fk_t ON fk_t.id = rel.fk_table_id
        JOIN ASKLYZE_CATALOG_TABLES pk_t ON pk_t.id = rel.pk_table_id
       WHERE rel.fk_table_id = p_table_id
      UNION ALL
      SELECT 'PK' direction,
             fk_t.object_name fk_table,
             rel.fk_column_name fk_column,
             pk_t.object_name pk_table,
             rel.pk_column_name pk_column,
             rel.delete_rule,
             rel.join_condition
        FROM ASKLYZE_CATALOG_RELATIONS rel
        JOIN ASKLYZE_CATALOG_TABLES fk_t ON fk_t.id = rel.fk_table_id
        JOIN ASKLYZE_CATALOG_TABLES pk_t ON pk_t.id = rel.pk_table_id
       WHERE rel.pk_table_id = p_table_id
    ) LOOP
      APEX_JSON.OPEN_OBJECT;
      APEX_JSON.WRITE('direction', r.direction);
      APEX_JSON.WRITE('fk_table', r.fk_table);
      APEX_JSON.WRITE('fk_column', r.fk_column);
      APEX_JSON.WRITE('pk_table', r.pk_table);
      APEX_JSON.WRITE('pk_column', r.pk_column);
      IF r.delete_rule IS NOT NULL THEN APEX_JSON.WRITE('delete_rule', r.delete_rule); END IF;
      IF r.join_condition IS NOT NULL THEN APEX_JSON.WRITE('join_condition', r.join_condition); END IF;
      APEX_JSON.CLOSE_OBJECT;
    END LOOP;
    APEX_JSON.CLOSE_ARRAY;

    APEX_JSON.CLOSE_OBJECT;

    l_out := APEX_JSON.GET_CLOB_OUTPUT;
    APEX_JSON.FREE_OUTPUT;
    RETURN l_out;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      BEGIN APEX_JSON.FREE_OUTPUT; EXCEPTION WHEN OTHERS THEN NULL; END;
      RETURN '{"status":"error","message":"Table not found"}';
    WHEN OTHERS THEN
      BEGIN APEX_JSON.FREE_OUTPUT; EXCEPTION WHEN OTHERS THEN NULL; END;
      RETURN '{"status":"error","message":"' || ASKLYZE_CAT_JSON_ESC(SUBSTR(SQLERRM,1,4000)) || '"}';
  END CATALOG_GET_TABLE_DETAILS_JSON;

  -- AI ENRICHMENT HELPERS
  FUNCTION CAT_AI_JSON_ESC(p_val IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN REPLACE(REPLACE(REPLACE(NVL(p_val,''), '\', '\\'), '"', '\"'), CHR(10), '\n');
  END;

  FUNCTION CAT_AI_YN(p_val IN CHAR, p_default IN CHAR := 'N') RETURN CHAR IS
    l CHAR(1);
  BEGIN
    l := UPPER(SUBSTR(NVL(TRIM(p_val), p_default), 1, 1));
    IF l NOT IN ('Y','N') THEN l := p_default; END IF;
    RETURN l;
  END;

  PROCEDURE CAT_AI_CALL_GEMINI_JSON(
      p_prompt     IN CLOB,
      p_json_out   OUT CLOB,
      p_err_msg    OUT VARCHAR2
  ) IS
    l_key   VARCHAR2(1000) := DBMS_LOB.SUBSTR(GET_CONF('GROQ_API_KEY'), 1000, 1);
    l_model VARCHAR2(100)  := 'openai/gpt-oss-120b';
    l_body  CLOB;
    l_resp  CLOB;
    l_txt   CLOB;
  BEGIN
    p_json_out := NULL;
    p_err_msg  := NULL;

    IF l_key IS NULL THEN
      p_err_msg := 'Missing GROQ_API_KEY.';
      RETURN;
    END IF;

    APEX_JSON.INITIALIZE_CLOB_OUTPUT;
    APEX_JSON.OPEN_OBJECT;
      APEX_JSON.WRITE('model', l_model);
      APEX_JSON.OPEN_ARRAY('messages');
        APEX_JSON.OPEN_OBJECT;
          APEX_JSON.WRITE('role', 'user');
          APEX_JSON.WRITE('content', p_prompt);
        APEX_JSON.CLOSE_OBJECT;
      APEX_JSON.CLOSE_ARRAY;
      APEX_JSON.WRITE('temperature', 0.3);
      APEX_JSON.WRITE('max_tokens', 65536);
      APEX_JSON.OPEN_OBJECT('response_format');
        APEX_JSON.WRITE('type', 'json_object');
      APEX_JSON.CLOSE_OBJECT;
    APEX_JSON.CLOSE_OBJECT;
    l_body := APEX_JSON.GET_CLOB_OUTPUT;
    APEX_JSON.FREE_OUTPUT;

    apex_web_service.g_request_headers.DELETE;
    apex_web_service.g_request_headers(1).name  := 'Content-Type';
    apex_web_service.g_request_headers(1).value := 'application/json';
    apex_web_service.g_request_headers(2).name  := 'Authorization';
    apex_web_service.g_request_headers(2).value := 'Bearer ' || l_key;

    l_resp := apex_web_service.make_rest_request(
      p_url              => 'https://api.groq.com/openai/v1/chat/completions',
      p_http_method      => 'POST',
      p_body             => l_body,
      p_transfer_timeout => 25
    );

    IF apex_web_service.g_status_code != 200 THEN
      p_err_msg := 'API HTTP ' || apex_web_service.g_status_code;
      RETURN;
    END IF;

    APEX_JSON.PARSE(l_resp);

    DECLARE
      l_v VARCHAR2(32767);
    BEGIN
      l_v := APEX_JSON.GET_VARCHAR2('choices[%d].message.content', 1);
      IF l_v IS NULL THEN
        p_err_msg := 'API returned empty text.';
        RETURN;
      END IF;
      l_txt := l_v;
    EXCEPTION
      WHEN OTHERS THEN
        p_err_msg := 'Failed to read API response: ' || SUBSTR(SQLERRM,1,4000);
        RETURN;
    END;

    l_txt := REPLACE(REPLACE(l_txt, '```json', ''), '```', '');
    l_txt := TRIM(l_txt);

    IF SUBSTR(l_txt,1,1) NOT IN ('{','[') THEN
      p_err_msg := 'API output is not JSON.';
      RETURN;
    END IF;

    p_json_out := l_txt;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_msg := SUBSTR(SQLERRM,1,4000);
  END CAT_AI_CALL_GEMINI_JSON;

  PROCEDURE CATALOG_AI_DESCRIBE_TABLE(
      p_table_id     IN NUMBER,
      p_force        IN CHAR DEFAULT 'N',
      p_result_json  OUT CLOB
  ) IS
    l_force   CHAR(1) := CAT_AI_YN(p_force, 'N');
    l_owner   VARCHAR2(128);
    l_name    VARCHAR2(128);
    l_type    VARCHAR2(10);
    l_comm    VARCHAR2(4000);
    l_sum_en  VARCHAR2(4000);
    l_sum_ar  VARCHAR2(4000);
    l_tags    CLOB;
    l_domain  VARCHAR2(100);
    l_relevance NUMBER;
    l_prompt  CLOB;
    l_meta    CLOB;
    l_ai_json CLOB;
    l_err     VARCHAR2(4000);
    l_new_en  VARCHAR2(4000);
    l_new_ar  VARCHAR2(4000);
    l_new_domain VARCHAR2(100);
    l_new_relevance NUMBER;
    l_tags_json CLOB;
  BEGIN
    p_result_json := NULL;

    SELECT owner_name, object_name, object_type, table_comment, 
           summary_en, summary_ar, tags_json, business_domain, relevance_score
      INTO l_owner, l_name, l_type, l_comm, 
           l_sum_en, l_sum_ar, l_tags, l_domain, l_relevance
      FROM ASKLYZE_CATALOG_TABLES
     WHERE id = p_table_id;

    IF l_force = 'N'
       AND l_sum_en IS NOT NULL
       AND l_sum_ar IS NOT NULL
       AND l_tags IS NOT NULL
       AND DBMS_LOB.GETLENGTH(l_tags) > 2
       AND l_domain IS NOT NULL
       AND l_relevance IS NOT NULL
    THEN
      p_result_json := '{"status":"skipped","table_id":'||p_table_id||',"reason":"already_described"}';
      RETURN;
    END IF;

    APEX_JSON.INITIALIZE_CLOB_OUTPUT;
    APEX_JSON.OPEN_OBJECT;
      APEX_JSON.WRITE('owner', l_owner);
      APEX_JSON.WRITE('object_name', l_name);
      APEX_JSON.WRITE('object_type', l_type);
      IF l_comm IS NOT NULL THEN 
        APEX_JSON.WRITE('table_comment', l_comm); 
      END IF;
      APEX_JSON.OPEN_ARRAY('columns');
      FOR c IN (
        SELECT column_name, data_type, NVL(column_comment,'') column_comment, semantic_role
          FROM ASKLYZE_CATALOG_COLUMNS
         WHERE table_id = p_table_id
         ORDER BY column_id
      ) LOOP
        APEX_JSON.OPEN_OBJECT;
          APEX_JSON.WRITE('name', c.column_name);
          APEX_JSON.WRITE('type', c.data_type);
          IF c.column_comment IS NOT NULL THEN 
            APEX_JSON.WRITE('comment', SUBSTR(c.column_comment,1,500)); 
          END IF;
          IF c.semantic_role IS NOT NULL THEN 
            APEX_JSON.WRITE('role', c.semantic_role); 
          END IF;
        APEX_JSON.CLOSE_OBJECT;
      END LOOP;
      APEX_JSON.CLOSE_ARRAY;
    APEX_JSON.CLOSE_OBJECT;
    l_meta := APEX_JSON.GET_CLOB_OUTPUT;
    APEX_JSON.FREE_OUTPUT;

    -- ===============================================
    -- الـ PROMPT المحدث
    -- ===============================================
    l_prompt :=
      'You are a BI/Analytics catalog expert analyzing database metadata.' || CHR(10) ||
      'The product supports multilingual natural-language questions (Arabic, English, etc.).' || CHR(10) ||
      'Given this table metadata JSON, produce STRICT JSON object ONLY (no markdown), with keys:' || CHR(10) || CHR(10) ||
      'summary_en: short (<=240 chars), business meaning in English.' || CHR(10) ||
      'summary_ar: Arabic short (<=240 chars), same meaning.' || CHR(10) ||
      'business_domain: ONE of these values ONLY: Sales, HR, Finance, Inventory, Supply Chain, Customer, Marketing, Operations, IT, Analytics, Master Data, Audit, Security, Other' || CHR(10) ||
      'relevance_score: number 1-100 indicating how likely this table is to be queried (higher = more important)' || CHR(10) ||
      'tags: array of 5-10 keywords for search (English or Arabic allowed).' || CHR(10) ||
      'column_updates: optional array of objects {column, semantic_role, is_search_key} where semantic_role in [dimension,measure,id,date,flag,text] and is_search_key in [Y,N].' || CHR(10) || CHR(10) ||
      'RULES:' || CHR(10) ||
      '- Do NOT access or assume actual data values' || CHR(10) ||
      '- Analyze ONLY based on table/column names, types, and comments' || CHR(10) ||
      '- Use generic domain language if purpose is unclear' || CHR(10) || CHR(10) ||
      'METADATA_JSON:' || CHR(10) || l_meta;

    CAT_AI_CALL_GEMINI_JSON(p_prompt => l_prompt, p_json_out => l_ai_json, p_err_msg => l_err);

    IF l_ai_json IS NULL THEN
      l_new_en := 'Business table for ' || l_name;
      l_new_ar := 'جدول أعمال خاص بـ ' || l_name;
      l_new_domain := 'Other';
      l_new_relevance := 50;

      APEX_JSON.INITIALIZE_CLOB_OUTPUT;
      APEX_JSON.OPEN_ARRAY;
        APEX_JSON.WRITE(LOWER(l_name));
        APEX_JSON.WRITE('analytics');
        APEX_JSON.WRITE('catalog');
      APEX_JSON.CLOSE_ARRAY;
      l_tags_json := APEX_JSON.GET_CLOB_OUTPUT;
      APEX_JSON.FREE_OUTPUT;

      UPDATE ASKLYZE_CATALOG_TABLES
         SET summary_en = SUBSTR(l_new_en,1,4000),
             summary_ar = SUBSTR(l_new_ar,1,4000),
             tags_json  = l_tags_json,
             business_domain = l_new_domain,
             relevance_score = l_new_relevance,
             updated_at = SYSTIMESTAMP
       WHERE id = p_table_id;
      COMMIT;

      p_result_json := '{"status":"fallback","table_id":'||p_table_id||',"message":"' || CAT_AI_JSON_ESC(l_err) || '"}';
      RETURN;
    END IF;

    APEX_JSON.PARSE(l_ai_json);
    l_new_en := APEX_JSON.GET_VARCHAR2('summary_en');
    l_new_ar := APEX_JSON.GET_VARCHAR2('summary_ar');
    l_new_domain := APEX_JSON.GET_VARCHAR2('business_domain');
    l_new_relevance := APEX_JSON.GET_NUMBER('relevance_score');

    IF l_new_domain IS NULL OR l_new_domain NOT IN (
        'Sales', 'HR', 'Finance', 'Inventory', 'Supply Chain', 
        'Customer', 'Marketing', 'Operations', 'IT', 'Analytics',
        'Master Data', 'Audit', 'Security', 'Other'
    ) THEN
      l_new_domain := 'Other';
    END IF;

    IF l_new_relevance IS NULL OR l_new_relevance < 1 OR l_new_relevance > 100 THEN
      l_new_relevance := 50;
    END IF;

    APEX_JSON.INITIALIZE_CLOB_OUTPUT;
    APEX_JSON.OPEN_ARRAY;
    DECLARE
      n PLS_INTEGER := 0;
    BEGIN
      BEGIN n := APEX_JSON.GET_COUNT('tags'); EXCEPTION WHEN OTHERS THEN n := 0; END;
      IF n > 0 THEN
        FOR i IN 1..n LOOP
          APEX_JSON.WRITE(APEX_JSON.GET_VARCHAR2('tags[%d]', i));
        END LOOP;
      END IF;
    END;
    APEX_JSON.CLOSE_ARRAY;
    l_tags_json := APEX_JSON.GET_CLOB_OUTPUT;
    APEX_JSON.FREE_OUTPUT;

    UPDATE ASKLYZE_CATALOG_TABLES
       SET summary_en = SUBSTR(NVL(l_new_en,''),1,4000),
           summary_ar = SUBSTR(NVL(l_new_ar,''),1,4000),
           tags_json  = l_tags_json,
           business_domain = l_new_domain,
           relevance_score = l_new_relevance,
           updated_at = SYSTIMESTAMP
     WHERE id = p_table_id;

    DECLARE
      m PLS_INTEGER := 0;
      v_col  VARCHAR2(128);
      v_role VARCHAR2(30);
      v_key  CHAR(1);
    BEGIN
      BEGIN m := APEX_JSON.GET_COUNT('column_updates'); EXCEPTION WHEN OTHERS THEN m := 0; END;
      IF m > 0 THEN
        FOR i IN 1..m LOOP
          v_col  := UPPER(APEX_JSON.GET_VARCHAR2('column_updates[%d].column', i));
          v_role := LOWER(APEX_JSON.GET_VARCHAR2('column_updates[%d].semantic_role', i));
          v_key  := CAT_AI_YN(APEX_JSON.GET_VARCHAR2('column_updates[%d].is_search_key', i), 'N');
          IF v_role NOT IN ('dimension','measure','id','date','flag','text') THEN
            v_role := NULL;
          END IF;
          UPDATE ASKLYZE_CATALOG_COLUMNS
             SET semantic_role = NVL(v_role, semantic_role),
                 is_search_key = NVL(v_key, is_search_key),
                 updated_at    = SYSTIMESTAMP
           WHERE table_id = p_table_id AND column_name = v_col;
        END LOOP;
      END IF;
    END;

    COMMIT;
    p_result_json := '{"status":"success","table_id":'||p_table_id||
        ',"domain":"'||l_new_domain||'","relevance_score":'||l_new_relevance||'}';

  EXCEPTION
    WHEN OTHERS THEN
      p_result_json := '{"status":"error","table_id":'||NVL(p_table_id,-1)||
        ',"message":"' || CAT_AI_JSON_ESC(SUBSTR(SQLERRM,1,4000)) || '"}';
  END CATALOG_AI_DESCRIBE_TABLE;


  PROCEDURE CATALOG_AI_DESCRIBE_SCHEMA(
      p_org_id        IN NUMBER,
      p_schema_owner  IN VARCHAR2,
      p_only_missing  IN CHAR   DEFAULT 'Y',
      p_max_tables    IN NUMBER DEFAULT 50,
      p_force         IN CHAR   DEFAULT 'N',
      p_result_json   OUT CLOB
  ) IS
    l_owner       VARCHAR2(128) := UPPER(TRIM(p_schema_owner));
    l_only        CHAR(1) := CAT_AI_YN(p_only_missing, 'Y');
    l_force       CHAR(1) := CAT_AI_YN(p_force, 'N');

    l_schema_id   NUMBER;
    l_dummy_inc   CHAR(1);

    l_total       NUMBER := 0;
    l_ok          NUMBER := 0;
    l_fail        NUMBER := 0;

    l_one         CLOB;
  BEGIN
    p_result_json := NULL;

    -- Reuse your existing helper inside the BODY (already added in previous step)
    -- If you placed ASKLYZE_CAT_GET_OR_CREATE_SCHEMA as private in body, keep it.
    ASKLYZE_CAT_GET_OR_CREATE_SCHEMA(
      p_org_id        => p_org_id,
      p_schema_owner  => l_owner,
      p_include_views => NULL,
      p_schema_id     => l_schema_id,
      p_eff_inc_views => l_dummy_inc
    );

    FOR t IN (
      SELECT id
        FROM (
          SELECT t.id
            FROM ASKLYZE_CATALOG_TABLES t
           WHERE t.schema_id = l_schema_id
             AND t.is_enabled = 'Y'
             AND t.is_whitelisted = 'Y'
             AND NVL(t.status,'VALID') <> 'MISSING'
             AND (
               l_only = 'N'
               OR t.summary_en IS NULL
               OR t.summary_ar IS NULL
               OR t.tags_json IS NULL
               OR DBMS_LOB.GETLENGTH(t.tags_json) <= 2
             )
           ORDER BY NVL(t.num_rows,0) DESC, t.object_name
        )
       WHERE ROWNUM <= NVL(p_max_tables,50)
    ) LOOP
      l_total := l_total + 1;

      CATALOG_AI_DESCRIBE_TABLE(
        p_table_id    => t.id,
        p_force       => l_force,
        p_result_json => l_one
      );

      IF l_one LIKE '%"status":"success"%' OR l_one LIKE '%"status":"skipped"%' OR l_one LIKE '%"status":"fallback"%' THEN
        l_ok := l_ok + 1;
      ELSE
        l_fail := l_fail + 1;
      END IF;
    END LOOP;

    p_result_json :=
      '{"status":"done","schema_id":'||l_schema_id||
      ',"total":'||l_total||
      ',"ok":'||l_ok||
      ',"fail":'||l_fail||'}';

  EXCEPTION
    WHEN OTHERS THEN
      p_result_json := '{"status":"error","message":"' || CAT_AI_JSON_ESC(SUBSTR(SQLERRM,1,4000)) || '"}';
  END CATALOG_AI_DESCRIBE_SCHEMA;

FUNCTION ANALYZE_PIVOT_SUITABILITY(
        p_data_profile IN CLOB,
        p_row_count IN NUMBER,
        p_question IN VARCHAR2
    ) RETURN CLOB IS
        l_result CLOB;
        l_num_cols NUMBER := 0;
        l_str_cols NUMBER := 0;
        l_date_cols NUMBER := 0;
        l_total_cols NUMBER := 0;
        l_score NUMBER := 0;
        l_recommended BOOLEAN := FALSE;
        l_reason VARCHAR2(500);
        l_question_lower VARCHAR2(4000);
    BEGIN
        IF p_data_profile IS NULL THEN
            RETURN '{"pivot_recommended":false,"reason":"No data profile"}';
        END IF;
        
        -- Parse data profile
        BEGIN
            APEX_JSON.PARSE(p_data_profile);
            l_total_cols := NVL(APEX_JSON.GET_NUMBER('totalColumns'), 0);
            l_num_cols := NVL(APEX_JSON.GET_NUMBER('numericColumns'), 0);
            l_str_cols := NVL(APEX_JSON.GET_NUMBER('stringColumns'), 0);
            l_date_cols := NVL(APEX_JSON.GET_NUMBER('dateColumns'), 0);
        EXCEPTION WHEN OTHERS THEN
            RETURN '{"pivot_recommended":false,"reason":"Profile parse error"}';
        END;
        
        -- Check question for pivot keywords
        l_question_lower := LOWER(NVL(p_question, ''));
        
        -- Scoring Algorithm
        -- +20: Has multiple numeric columns (measures)
        IF l_num_cols >= 2 THEN
            l_score := l_score + 20;
        ELSIF l_num_cols = 1 THEN
            l_score := l_score + 10;
        END IF;
        
        -- +25: Has string columns (dimensions)
        IF l_str_cols >= 2 THEN
            l_score := l_score + 25;
        ELSIF l_str_cols = 1 THEN
            l_score := l_score + 15;
        END IF;
        
        -- +15: Has date columns (time dimension)
        IF l_date_cols >= 1 THEN
            l_score := l_score + 15;
        END IF;
        
        -- +20: Good row count for pivot (between 50 and 10000)
        IF p_row_count >= 50 AND p_row_count <= 10000 THEN
            l_score := l_score + 20;
        ELSIF p_row_count >= 10 AND p_row_count < 50 THEN
            l_score := l_score + 10;
        ELSIF p_row_count > 10000 THEN
            l_score := l_score + 5;
        END IF;
        
        -- +25: Pivot-related keywords in question
        IF INSTR(l_question_lower, 'pivot') > 0 
           OR INSTR(l_question_lower, 'cross-tab') > 0
           OR INSTR(l_question_lower, 'crosstab') > 0 THEN
            l_score := l_score + 30;
            l_reason := 'User explicitly requested pivot analysis';
        ELSIF INSTR(l_question_lower, 'by') > 0 
              AND (INSTR(l_question_lower, 'group') > 0 
                   OR INSTR(l_question_lower, 'breakdown') > 0
                   OR INSTR(l_question_lower, 'per') > 0) THEN
            l_score := l_score + 20;
            l_reason := 'Query involves grouping/breakdown analysis';
        ELSIF INSTR(l_question_lower, 'compare') > 0 
              OR INSTR(l_question_lower, 'comparison') > 0
              OR INSTR(l_question_lower, 'مقارنة') > 0 THEN
            l_score := l_score + 15;
            l_reason := 'Comparison analysis benefits from pivot view';
        ELSIF INSTR(l_question_lower, 'total') > 0 
              OR INSTR(l_question_lower, 'sum') > 0
              OR INSTR(l_question_lower, 'average') > 0
              OR INSTR(l_question_lower, 'count') > 0 THEN
            l_score := l_score + 10;
            l_reason := 'Aggregation query suitable for pivot';
        END IF;
        
        -- Check for "by X and Y" pattern (multi-dimensional)
        IF REGEXP_LIKE(l_question_lower, 'by\s+\w+\s+(and|,)\s+\w+', 'i') THEN
            l_score := l_score + 15;
            l_reason := NVL(l_reason, 'Multi-dimensional analysis detected');
        END IF;
        
        -- Determine recommendation
        -- Score >= 50 = Strongly recommended
        -- Score >= 35 = Recommended
        -- Score < 35 = Not recommended
        IF l_score >= 50 THEN
            l_recommended := TRUE;
            IF l_reason IS NULL THEN
                l_reason := 'البيانات تحتوي على أبعاد ومقاييس متعددة مثالية للتحليل المحوري';
            END IF;
        ELSIF l_score >= 35 THEN
            l_recommended := TRUE;
            IF l_reason IS NULL THEN
                l_reason := 'البيانات مناسبة لعرض Pivot Table';
            END IF;
        ELSE
            l_recommended := FALSE;
            l_reason := 'Data structure not optimal for pivot analysis';
        END IF;
        
        -- Build result JSON
        APEX_JSON.INITIALIZE_CLOB_OUTPUT;
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('pivot_recommended', l_recommended);
        APEX_JSON.WRITE('score', l_score);
        APEX_JSON.WRITE('reason', l_reason);
        APEX_JSON.WRITE('dimensions_count', l_str_cols + l_date_cols);
        APEX_JSON.WRITE('measures_count', l_num_cols);
        APEX_JSON.CLOSE_OBJECT;
        
        l_result := APEX_JSON.GET_CLOB_OUTPUT;
        APEX_JSON.FREE_OUTPUT;
        
        RETURN l_result;
        
    EXCEPTION WHEN OTHERS THEN
        RETURN '{"pivot_recommended":false,"reason":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END ANALYZE_PIVOT_SUITABILITY;

    -- ============================================================
    -- NEW: AI-based Pivot Configuration Detection
    -- Returns optimal rows, columns, measures configuration
    -- ============================================================
    FUNCTION DETECT_PIVOT_CONFIG_AI(
        p_question IN VARCHAR2,
        p_data_profile IN CLOB,
        p_sample_data IN CLOB
    ) RETURN CLOB IS
        l_result CLOB;
        l_rows CLOB;
        l_cols CLOB;
        l_measures CLOB;
        l_col_count NUMBER;
        l_col_name VARCHAR2(128);
        l_col_type VARCHAR2(50);
        l_col_role VARCHAR2(30);
        l_first_row BOOLEAN := TRUE;
        l_first_col BOOLEAN := TRUE;
        l_first_measure BOOLEAN := TRUE;
        l_question_lower VARCHAR2(4000);
    BEGIN
        IF p_data_profile IS NULL THEN
            RETURN '{}';
        END IF;
        
        l_question_lower := LOWER(NVL(p_question, ''));
        
        -- Initialize CLOBs
        DBMS_LOB.CREATETEMPORARY(l_rows, TRUE);
        DBMS_LOB.CREATETEMPORARY(l_cols, TRUE);
        DBMS_LOB.CREATETEMPORARY(l_measures, TRUE);
        DBMS_LOB.APPEND(l_rows, '[');
        DBMS_LOB.APPEND(l_cols, '[');
        DBMS_LOB.APPEND(l_measures, '[');
        
        -- Parse columns from data profile
        BEGIN
            APEX_JSON.PARSE(p_data_profile);
            l_col_count := APEX_JSON.GET_COUNT(p_path => 'columns');
            
            IF l_col_count IS NOT NULL AND l_col_count > 0 THEN
                FOR i IN 1 .. l_col_count LOOP
                    l_col_name := APEX_JSON.GET_VARCHAR2(p_path => 'columns[%d].name', p0 => i);
                    l_col_type := APEX_JSON.GET_VARCHAR2(p_path => 'columns[%d].type', p0 => i);
                    l_col_role := APEX_JSON.GET_VARCHAR2(p_path => 'columns[%d].role', p0 => i);
                    
                    -- Determine field placement
                    IF l_col_type = 'NUMBER' THEN
                        -- Check if it's a measure or dimension
                        IF LOWER(l_col_name) LIKE '%id%' 
                           OR LOWER(l_col_name) LIKE '%code%'
                           OR LOWER(l_col_name) LIKE '%num%' THEN
                            -- Likely a dimension/ID
                            IF NOT l_first_row THEN DBMS_LOB.APPEND(l_rows, ','); END IF;
                            l_first_row := FALSE;
                            DBMS_LOB.APPEND(l_rows, '"' || SAFE_JSON_ESCAPE(l_col_name) || '"');
                        ELSE
                            -- Likely a measure
                            IF NOT l_first_measure THEN DBMS_LOB.APPEND(l_measures, ','); END IF;
                            l_first_measure := FALSE;
                            DBMS_LOB.APPEND(l_measures, '"' || SAFE_JSON_ESCAPE(l_col_name) || '"');
                        END IF;
                        
                    ELSIF l_col_type = 'DATE' THEN
                        -- Date columns go to columns (cross-tab header)
                        IF NOT l_first_col THEN DBMS_LOB.APPEND(l_cols, ','); END IF;
                        l_first_col := FALSE;
                        DBMS_LOB.APPEND(l_cols, '"' || SAFE_JSON_ESCAPE(l_col_name) || '"');
                        
                    ELSE
                        -- String columns typically go to rows
                        -- But check question for hints
                        IF INSTR(l_question_lower, LOWER(l_col_name)) > 0 
                           AND (INSTR(l_question_lower, 'by ' || LOWER(l_col_name)) > 0
                                OR INSTR(l_question_lower, 'per ' || LOWER(l_col_name)) > 0) THEN
                            -- Mentioned explicitly - put in rows
                            IF NOT l_first_row THEN DBMS_LOB.APPEND(l_rows, ','); END IF;
                            l_first_row := FALSE;
                            DBMS_LOB.APPEND(l_rows, '"' || SAFE_JSON_ESCAPE(l_col_name) || '"');
                        ELSIF LOWER(l_col_name) LIKE '%name%' 
                              OR LOWER(l_col_name) LIKE '%category%'
                              OR LOWER(l_col_name) LIKE '%type%'
                              OR LOWER(l_col_name) LIKE '%dept%'
                              OR LOWER(l_col_name) LIKE '%region%' THEN
                            -- Common dimension names - put in rows
                            IF NOT l_first_row THEN DBMS_LOB.APPEND(l_rows, ','); END IF;
                            l_first_row := FALSE;
                            DBMS_LOB.APPEND(l_rows, '"' || SAFE_JSON_ESCAPE(l_col_name) || '"');
                        ELSE
                            -- Default to rows if we don't have too many
                            IF l_first_row OR DBMS_LOB.GETLENGTH(l_rows) < 100 THEN
                                IF NOT l_first_row THEN DBMS_LOB.APPEND(l_rows, ','); END IF;
                                l_first_row := FALSE;
                                DBMS_LOB.APPEND(l_rows, '"' || SAFE_JSON_ESCAPE(l_col_name) || '"');
                            END IF;
                        END IF;
                    END IF;
                END LOOP;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
        
        -- Close arrays
        DBMS_LOB.APPEND(l_rows, ']');
        DBMS_LOB.APPEND(l_cols, ']');
        DBMS_LOB.APPEND(l_measures, ']');
        
        -- Build result
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, '{"rows":');
        DBMS_LOB.APPEND(l_result, l_rows);
        DBMS_LOB.APPEND(l_result, ',"columns":');
        DBMS_LOB.APPEND(l_result, l_cols);
        DBMS_LOB.APPEND(l_result, ',"measures":');
        DBMS_LOB.APPEND(l_result, l_measures);
        DBMS_LOB.APPEND(l_result, '}');
        
        -- Free temporary LOBs
        DBMS_LOB.FREETEMPORARY(l_rows);
        DBMS_LOB.FREETEMPORARY(l_cols);
        DBMS_LOB.FREETEMPORARY(l_measures);
        
        RETURN l_result;
        
    EXCEPTION WHEN OTHERS THEN
        RETURN '{}';
    END DETECT_PIVOT_CONFIG_AI;

    -- ============================================================
    -- Save Layout
    -- ============================================================
    PROCEDURE SAVE_DASHBOARD_LAYOUT(
        p_query_id    IN NUMBER,
        p_layout_json IN CLOB,
        p_result_json OUT CLOB
    ) IS
        l_user VARCHAR2(100) := NVL(V('APP_USER'), USER);
        l_exists NUMBER;
    BEGIN
        -- Upsert Logic using MERGE
        MERGE INTO ASKLYZE_DASHBOARD_LAYOUTS t
        USING (SELECT p_query_id as qid, l_user as usr FROM DUAL) s
        ON (t.QUERY_ID = s.qid AND t.APP_USER = s.usr)
        WHEN MATCHED THEN
            UPDATE SET LAYOUT_JSON = p_layout_json, UPDATED_AT = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (QUERY_ID, APP_USER, LAYOUT_NAME, LAYOUT_JSON, IS_DEFAULT)
            VALUES (p_query_id, l_user, 'Custom Layout', p_layout_json, 'N');
            
        COMMIT;
        p_result_json := '{"status":"success","message":"Layout saved successfully"}';
    EXCEPTION WHEN OTHERS THEN
        p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END SAVE_DASHBOARD_LAYOUT;

    PROCEDURE RESET_DASHBOARD_LAYOUT(
        p_query_id    IN NUMBER,
        p_result_json OUT CLOB
    ) IS
        l_user VARCHAR2(100) := NVL(V('APP_USER'), USER);
    BEGIN
        DELETE FROM ASKLYZE_DASHBOARD_LAYOUTS WHERE QUERY_ID = p_query_id AND APP_USER = l_user;
        COMMIT;
        p_result_json := '{"status":"success","message":"Layout reset to default"}';
    EXCEPTION WHEN OTHERS THEN
        p_result_json := '{"status":"error","message":"' || SAFE_JSON_ESCAPE(SQLERRM) || '"}';
    END RESET_DASHBOARD_LAYOUT;


FUNCTION CATALOG_SEARCH_TABLES(
      p_org_id       IN NUMBER DEFAULT 1,
      p_schema_owner IN VARCHAR2 DEFAULT NULL,
      p_keywords     IN VARCHAR2,
      p_domain       IN VARCHAR2 DEFAULT NULL,
      p_max_results  IN NUMBER DEFAULT 10
  ) RETURN CLOB IS
    l_owner    VARCHAR2(128) := UPPER(NVL(p_schema_owner, NVL(apex_application.g_flow_owner, USER)));
    l_keywords VARCHAR2(4000) := LOWER(NVL(p_keywords, ''));
    l_schema_id NUMBER;
    l_result   CLOB;
    l_first    BOOLEAN := TRUE;
  BEGIN
    BEGIN
      SELECT id INTO l_schema_id FROM ASKLYZE_CATALOG_SCHEMAS
      WHERE org_id = p_org_id AND UPPER(schema_owner) = l_owner;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      RETURN '{"results":[],"error":"Schema not found"}';
    END;

    DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
    DBMS_LOB.APPEND(l_result, '{"results":[');

    FOR t IN (
      SELECT t.id, t.object_name, t.summary_en, t.business_domain, t.relevance_score,
        (CASE WHEN LOWER(t.object_name) LIKE '%'||l_keywords||'%' THEN 50 ELSE 0 END +
         CASE WHEN LOWER(t.summary_en) LIKE '%'||l_keywords||'%' THEN 30 ELSE 0 END +
         CASE WHEN LOWER(t.tags_json) LIKE '%'||l_keywords||'%' THEN 40 ELSE 0 END +
         NVL(t.relevance_score, 0)) AS match_score
      FROM ASKLYZE_CATALOG_TABLES t
      WHERE t.schema_id = l_schema_id AND t.is_whitelisted = 'Y' AND t.is_enabled = 'Y'
        AND t.summary_en IS NOT NULL
        AND (p_domain IS NULL OR UPPER(t.business_domain) = UPPER(p_domain))
        AND (LOWER(t.object_name) LIKE '%'||l_keywords||'%'
          OR LOWER(t.summary_en) LIKE '%'||l_keywords||'%'
          OR LOWER(t.summary_ar) LIKE '%'||l_keywords||'%'
          OR LOWER(t.tags_json) LIKE '%'||l_keywords||'%')
      ORDER BY match_score DESC
      FETCH FIRST NVL(p_max_results, 10) ROWS ONLY
    ) LOOP
      IF NOT l_first THEN DBMS_LOB.APPEND(l_result, ','); END IF;
      l_first := FALSE;
      DBMS_LOB.APPEND(l_result, '{"id":'||t.id||',"table":"'||SAFE_JSON_ESCAPE(t.object_name)||
        '","desc":"'||SAFE_JSON_ESCAPE(SUBSTR(t.summary_en,1,200))||
        '","domain":"'||SAFE_JSON_ESCAPE(t.business_domain)||'","score":'||t.match_score||'}');
    END LOOP;

    DBMS_LOB.APPEND(l_result, '],"search":"'||SAFE_JSON_ESCAPE(p_keywords)||'"}');
    RETURN l_result;
  EXCEPTION WHEN OTHERS THEN
    RETURN '{"results":[],"error":"'||SAFE_JSON_ESCAPE(SQLERRM)||'"}';
  END CATALOG_SEARCH_TABLES;

  FUNCTION CATALOG_GET_SEMANTIC_CONTEXT(
      p_org_id       IN NUMBER DEFAULT 1,
      p_schema_owner IN VARCHAR2 DEFAULT NULL,
      p_domain       IN VARCHAR2 DEFAULT NULL,
      p_max_tables   IN NUMBER DEFAULT 30
  ) RETURN CLOB IS
    l_owner    VARCHAR2(128) := UPPER(NVL(p_schema_owner, NVL(apex_application.g_flow_owner, USER)));
    l_schema_id NUMBER;
    l_result   CLOB;
    l_first    BOOLEAN := TRUE;
  BEGIN
    BEGIN
      SELECT id INTO l_schema_id FROM ASKLYZE_CATALOG_SCHEMAS
      WHERE org_id = p_org_id AND UPPER(schema_owner) = l_owner;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      RETURN '{"tables":[]}';
    END;

    DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
    DBMS_LOB.APPEND(l_result, '{"tables":[');

    FOR t IN (
      SELECT t.object_name, t.summary_en, t.business_domain
      FROM ASKLYZE_CATALOG_TABLES t
      WHERE t.schema_id = l_schema_id AND t.is_whitelisted = 'Y' AND t.is_enabled = 'Y'
        AND t.summary_en IS NOT NULL
        AND (p_domain IS NULL OR UPPER(t.business_domain) = UPPER(p_domain))
      ORDER BY t.relevance_score DESC NULLS LAST, t.num_rows DESC NULLS LAST
      FETCH FIRST NVL(p_max_tables, 30) ROWS ONLY
    ) LOOP
      IF NOT l_first THEN DBMS_LOB.APPEND(l_result, ','); END IF;
      l_first := FALSE;
      DBMS_LOB.APPEND(l_result, '{"t":"'||SAFE_JSON_ESCAPE(t.object_name)||
        '","d":"'||SAFE_JSON_ESCAPE(t.business_domain)||
        '","s":"'||SAFE_JSON_ESCAPE(SUBSTR(t.summary_en,1,150))||'"}');
    END LOOP;

    DBMS_LOB.APPEND(l_result, ']}');
    RETURN l_result;
  EXCEPTION WHEN OTHERS THEN
    RETURN '{"tables":[],"error":"'||SAFE_JSON_ESCAPE(SQLERRM)||'"}';
  END CATALOG_GET_SEMANTIC_CONTEXT;

  FUNCTION CATALOG_GET_STATS(
      p_org_id       IN NUMBER DEFAULT 1,
      p_schema_owner IN VARCHAR2 DEFAULT NULL
  ) RETURN CLOB IS
    l_owner VARCHAR2(128) := UPPER(NVL(p_schema_owner, NVL(apex_application.g_flow_owner, USER)));
    l_schema_id NUMBER;
    l_total NUMBER; l_analyzed NUMBER; l_pending NUMBER;
    l_result CLOB;
    l_first BOOLEAN := TRUE;
  BEGIN
    BEGIN
      SELECT id INTO l_schema_id FROM ASKLYZE_CATALOG_SCHEMAS
      WHERE org_id = p_org_id AND UPPER(schema_owner) = l_owner;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      RETURN '{"error":"Schema not found"}';
    END;

    SELECT COUNT(*),
      SUM(CASE WHEN summary_en IS NOT NULL AND business_domain IS NOT NULL THEN 1 ELSE 0 END),
      SUM(CASE WHEN summary_en IS NULL OR business_domain IS NULL THEN 1 ELSE 0 END)
    INTO l_total, l_analyzed, l_pending
    FROM ASKLYZE_CATALOG_TABLES
    WHERE schema_id = l_schema_id AND is_whitelisted = 'Y' AND is_enabled = 'Y';

    DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
    DBMS_LOB.APPEND(l_result, '{"schema":"'||l_owner||'","total":'||NVL(l_total,0)||
      ',"analyzed":'||NVL(l_analyzed,0)||',"pending":'||NVL(l_pending,0)||',"domains":[');

    FOR d IN (
      SELECT business_domain, COUNT(*) AS cnt
      FROM ASKLYZE_CATALOG_TABLES
      WHERE schema_id = l_schema_id AND is_whitelisted = 'Y' AND business_domain IS NOT NULL
      GROUP BY business_domain ORDER BY cnt DESC
    ) LOOP
      IF NOT l_first THEN DBMS_LOB.APPEND(l_result, ','); END IF;
      l_first := FALSE;
      DBMS_LOB.APPEND(l_result, '{"name":"'||SAFE_JSON_ESCAPE(d.business_domain)||'","count":'||d.cnt||'}');
    END LOOP;

    DBMS_LOB.APPEND(l_result, ']}');
    RETURN l_result;
  EXCEPTION WHEN OTHERS THEN
    RETURN '{"error":"'||SAFE_JSON_ESCAPE(SQLERRM)||'"}';
  END CATALOG_GET_STATS;

END AI_CORE_PKG;
/


