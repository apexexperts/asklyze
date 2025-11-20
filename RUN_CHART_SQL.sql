-- Ajax callback process called RUN_CHART_SQL
-- Fixed version with better TABLE support and debugging
DECLARE
    l_sql       CLOB := apex_application.g_x01;
    l_cursor    INTEGER;
    l_col_cnt   INTEGER;
    l_desc_tab  DBMS_SQL.DESC_TAB2;
    l_status    INTEGER;
    
    -- Column buffers
    l_val_vc    VARCHAR2(32767);
    l_val_num   NUMBER;
    l_val_date  DATE;
    l_val_clob  CLOB;
    
    l_rows      PLS_INTEGER := 0;
    c_max_rows  CONSTANT PLS_INTEGER := 100; -- Safety limit for table rows
    
    -- Debug flag
    l_debug     BOOLEAN := FALSE;
BEGIN
    -- 1. Basic Validation
    IF l_sql IS NULL THEN
        apex_json.open_object;
        apex_json.write('ok', false);
        apex_json.write('error', 'No SQL provided');
        apex_json.close_object;
        RETURN;
    END IF;
    
    IF NOT REGEXP_LIKE(TRIM(LOWER(l_sql)), '^select\s') THEN
        apex_json.open_object;
        apex_json.write('ok', false);
        apex_json.write('error', 'Only SELECT statements are allowed');
        apex_json.close_object;
        RETURN;
    END IF;
    
    IF INSTR(l_sql, ';') > 0 THEN
        apex_json.open_object;
        apex_json.write('ok', false);
        apex_json.write('error', 'Semicolons are not allowed');
        apex_json.close_object;
        RETURN;
    END IF;
    
    -- Debug logging
    IF l_debug THEN
        apex_debug.message('RUN_CHART_SQL: Starting execution');
        apex_debug.message('SQL: %s', SUBSTR(l_sql, 1, 4000));
    END IF;
    
    -- 2. Open and Parse using DBMS_SQL
    l_cursor := dbms_sql.open_cursor;
    
    BEGIN
        dbms_sql.parse(l_cursor, l_sql, dbms_sql.native);
        dbms_sql.describe_columns2(l_cursor, l_col_cnt, l_desc_tab);
        
        IF l_debug THEN
            apex_debug.message('Column count: %s', l_col_cnt);
        END IF;
        
        -- 3. Define Columns dynamically
        FOR i IN 1 .. l_col_cnt LOOP
            IF l_debug THEN
                apex_debug.message('Column %s: %s (Type: %s)', 
                    i, l_desc_tab(i).col_name, l_desc_tab(i).col_type);
            END IF;
            
            -- Type 2 = NUMBER
            IF l_desc_tab(i).col_type = 2 THEN 
                dbms_sql.define_column(l_cursor, i, l_val_num);
                
            -- Types 12, 180, 181, 231 = Dates/Timestamps
            ELSIF l_desc_tab(i).col_type IN (12, 180, 181, 231) THEN 
                dbms_sql.define_column(l_cursor, i, l_val_date);
                
            -- Type 112 = CLOB - Define as VARCHAR2
            ELSIF l_desc_tab(i).col_type = 112 THEN
                dbms_sql.define_column(l_cursor, i, l_val_vc, 4000);
                
            -- All other types as VARCHAR2
            ELSE 
                dbms_sql.define_column(l_cursor, i, l_val_vc, 4000); 
            END IF;
        END LOOP;
        
        -- 4. Execute
        l_status := dbms_sql.execute(l_cursor);
        
        IF l_debug THEN
            apex_debug.message('Execute status: %s', l_status);
        END IF;
        
        -- 5. Output JSON
        apex_json.open_object;
        apex_json.write('ok', true);
        
        -- Output Column Headers
        apex_json.open_array('columns');
        FOR i IN 1 .. l_col_cnt LOOP
            apex_json.write(l_desc_tab(i).col_name);
        END LOOP;
        apex_json.close_array;
        
        -- Output Data (Array of Arrays)
        apex_json.open_array('data');
        
        LOOP
            EXIT WHEN dbms_sql.fetch_rows(l_cursor) = 0 OR l_rows >= c_max_rows;
            l_rows := l_rows + 1;
            
            apex_json.open_array; -- Start Row
            
            FOR i IN 1 .. l_col_cnt LOOP
                BEGIN
                    -- NUMBER type
                    IF l_desc_tab(i).col_type = 2 THEN
                        dbms_sql.column_value(l_cursor, i, l_val_num);
                        IF l_val_num IS NULL THEN
                            apex_json.write_raw('null');
                        ELSE
                            apex_json.write(l_val_num);
                        END IF;
                        
                    -- DATE types
                    ELSIF l_desc_tab(i).col_type IN (12, 180, 181, 231) THEN
                        dbms_sql.column_value(l_cursor, i, l_val_date);
                        IF l_val_date IS NULL THEN
                            apex_json.write_raw('null');
                        ELSE
                            apex_json.write(TO_CHAR(l_val_date, 'YYYY-MM-DD"T"HH24:MI:SS'));
                        END IF;
                        
                    -- STRING/CLOB types
                    ELSE
                        dbms_sql.column_value(l_cursor, i, l_val_vc);
                        apex_json.write(l_val_vc);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        -- If any column fails, write null
                        apex_json.write_raw('null');
                        IF l_debug THEN
                            apex_debug.message('Column %s fetch error: %s', i, SQLERRM);
                        END IF;
                END;
            END LOOP;
            
            apex_json.close_array; -- End Row
        END LOOP;
        
        apex_json.close_array; -- End Data Array
        
        -- Add metadata
        apex_json.write('rowCount', l_rows);
        apex_json.write('columnCount', l_col_cnt);
        
        apex_json.close_object;
        
        IF l_debug THEN
            apex_debug.message('Successfully returned %s rows', l_rows);
        END IF;
        
    EXCEPTION 
        WHEN OTHERS THEN
            IF l_debug THEN
                apex_debug.message('Error in RUN_CHART_SQL: %s', SQLERRM);
                apex_debug.message('Error backtrace: %s', DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            END IF;
            
            apex_json.open_object;
            apex_json.write('ok', false);
            apex_json.write('error', SQLERRM);
            apex_json.write('sql', SUBSTR(l_sql, 1, 200));
            apex_json.close_object;
    END;
    
    -- Clean up
    IF dbms_sql.is_open(l_cursor) THEN
        dbms_sql.close_cursor(l_cursor);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Outer exception handler
        apex_json.open_object;
        apex_json.write('ok', false);
        apex_json.write('error', 'Unexpected error: ' || SQLERRM);
        apex_json.close_object;
        
        IF l_cursor IS NOT NULL AND dbms_sql.is_open(l_cursor) THEN
            dbms_sql.close_cursor(l_cursor);
        END IF;
END;
