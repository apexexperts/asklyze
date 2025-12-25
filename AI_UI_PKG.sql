create or replace PACKAGE AI_UI_PKG AS 
    PROCEDURE render_dashboard( 
        p_region IN apex_plugin.t_region, 
        p_plugin IN apex_plugin.t_plugin, 
        p_param  IN apex_plugin.t_region_render_param, 
        p_result IN OUT NOCOPY apex_plugin.t_region_render_result 
    ); 
    PROCEDURE ajax_handler( 
        p_region IN apex_plugin.t_region, 
        p_plugin IN apex_plugin.t_plugin, 
        p_param  IN apex_plugin.t_region_ajax_param, 
        p_result IN OUT NOCOPY apex_plugin.t_region_ajax_result 
    ); 
END AI_UI_PKG;
/


create or replace PACKAGE BODY AI_UI_PKG AS

    -- Helper to output JavaScript || operator safely
    FUNCTION JS_OR RETURN VARCHAR2 IS
    BEGIN
        RETURN CHR(124) || CHR(124);
    END JS_OR;

-- Helper to print CLOBs larger than 32k
    PROCEDURE PRINT_CLOB(p_clob IN CLOB) IS
        l_offset NUMBER := 1;
        l_length NUMBER;
        l_amount NUMBER := 8000; -- Chunk size (safe for varchar2)
    BEGIN
        IF p_clob IS NULL THEN
            RETURN;
        END IF;
        
        l_length := DBMS_LOB.GETLENGTH(p_clob);
        
        WHILE l_offset <= l_length LOOP
            htp.prn(DBMS_LOB.SUBSTR(p_clob, l_amount, l_offset));
            l_offset := l_offset + l_amount;
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        htp.p('{"status":"error","message":"Error printing CLOB"}');
    END PRINT_CLOB;

    PROCEDURE render_dashboard(
        p_region IN apex_plugin.t_region,
        p_plugin IN apex_plugin.t_plugin,
        p_param  IN apex_plugin.t_region_render_param,
        p_result IN OUT NOCOPY apex_plugin.t_region_render_result
    ) IS
        l_id    VARCHAR2(255); 
        l_ajax  VARCHAR2(4000);
        l_js    CLOB;
        l_or    VARCHAR2(5) := CHR(124) || CHR(124); -- JavaScript || operator
    BEGIN
        IF p_param.is_printer_friendly THEN RETURN; END IF;
        l_id := p_region.static_id;
        l_ajax := apex_plugin.get_ajax_identifier;

        -- Libraries
        htp.p('<script src="https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"></script>');
        htp.p('<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css">');
        htp.p('<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/theme/dracula.min.css">');
        htp.p('<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js"></script>');
        htp.p('<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/sql/sql.min.js"></script>');
        htp.p('<script src="https://unpkg.com/sql-formatter@4.0.2/dist/sql-formatter.min.js"></script>');
        htp.p('<script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>');
        htp.p('<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>');
        htp.p('<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.5.31/jspdf.plugin.autotable.min.js"></script>');
        htp.p('<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/gridstack@9.4.0/dist/gridstack.min.css">');
        htp.p('<script src="https://cdn.jsdelivr.net/npm/gridstack@9.4.0/dist/gridstack-all.js"></script>');
        htp.p('<link href="https://cdn.webdatarocks.com/latest/webdatarocks.min.css" rel="stylesheet">');
        htp.p('<script src="https://cdn.webdatarocks.com/latest/webdatarocks.toolbar.min.js"></script>');
        htp.p('<script src="https://cdn.webdatarocks.com/latest/webdatarocks.js"></script>');

        htp.p('<style>');
        
        -- Main Container

        htp.p('#' || l_id || '.apex-ai-container { font-family: "Segoe UI", Roboto, sans-serif; background: #f5f7fa; height: 85vh; position: relative;  overflow: hidden; display: flex; flex-direction: row; border: 1px solid #e0e4e8; box-shadow: 0 2px 12px rgba(0,0,0,0.08); }');


        -- Sidebar
        htp.p('#' || l_id || ' .rw-sidebar { width: var(--rw-sidebar-width); min-width: 320px; max-width: 600px; height: 100%; background: var(--rw-bg-primary); border-right: 1px solid var(--rw-border-subtle); display: flex; flex-direction: column; }');
        htp.p('#' || l_id || ' .rw-sidebar-header { height: var(--rw-header-height); padding: 0 20px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid var(--rw-border-subtle); background: var(--rw-bg-primary); flex-shrink: 0; }');
        htp.p('#' || l_id || ' .rw-logo { display: flex; align-items: center; gap: 12px; }');
        htp.p('#' || l_id || ' .rw-logo-icon { width: 36px; height: 36px; background: var(--rw-accent-gradient); border-radius: var(--rw-radius-md); display: flex; align-items: center; justify-content: center; font-size: 18px; color: white; box-shadow: var(--rw-shadow-sm); }');
        htp.p('#' || l_id || ' .rw-logo-text { font-size: 18px; font-weight: 600; color: var(--rw-text-primary); }');
        htp.p('#' || l_id || ' .rw-logo-badge { font-size: 10px; font-weight: 600; padding: 3px 8px; background: var(--rw-accent-light); color: var(--rw-accent-primary); border-radius: 9999px; text-transform: uppercase; }');
        htp.p('#' || l_id || ' .rw-header-actions { display: flex; gap: 4px; }');
        htp.p('#' || l_id || ' .rw-icon-btn { width: 36px; height: 36px; border: none; background: transparent; color: var(--rw-text-tertiary); border-radius: var(--rw-radius-sm); cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.15s ease; }');
        htp.p('#' || l_id || ' .rw-icon-btn:hover { background: var(--rw-bg-hover); color: var(--rw-text-primary); }');
        htp.p('#' || l_id || ' .rw-icon-btn svg { width: 18px; height: 18px; }');

        -- Sidebar Styles
        htp.p('.aid-sidebar { width: 280px; min-width: 280px; background: linear-gradient(180deg, #1d4cd2 0%, #1d4bd1 100%); display: flex; flex-direction: column; transition: all 0.3s ease; border-right: 1px solid #2d3a4a; height: 100%; }');
        htp.p('.aid-sidebar.collapsed { width: 0; min-width: 0; overflow: hidden; }');
        htp.p('.aid-sidebar-header { padding: 18px 15px; border-bottom: 1px solid #2d3a4a; display: flex; align-items: center; justify-content: space-between; }');
        htp.p('.aid-sidebar-title { color: #fff; font-size: 14px; font-weight: 600; display: flex; align-items: center; gap: 8px; }');
        htp.p('.aid-new-chat-btn { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: white; border: none; border-radius: 8px; padding: 10px 16px; font-size: 12px; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; transition: all 0.2s; box-shadow: 0 2px 8px rgba(59,130,246,0.3); }');
        htp.p('.aid-new-chat-btn:hover { background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); transform: translateY(-1px); }');
        htp.p('.aid-search-box { padding: 12px 15px; border-bottom: 1px solid #2d3a4a; }');
        htp.p('.aid-search-input { width: 100%; background: #f2f2f2; border: 1px solid #3d4a5a; border-radius: 8px; padding: 10px 14px; color: #000000; font-size: 13px; outline: none; transition: all 0.2s; }');
        htp.p('.aid-search-input::placeholder { color: #6b7a8a; }');
        htp.p('.aid-search-input:focus { border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,0.2); }');
        htp.p('.aid-tabs-container { padding: 0 15px; border-bottom: 1px solid #2d3a4a; display: flex; gap: 20px; }');
        htp.p('.aid-hist-tab { background: transparent; border: none; color: #6b7a8a; padding: 14px 0; font-size: 12px; font-weight: 600; cursor: pointer; position: relative; transition: all 0.2s; }');
        htp.p('.aid-hist-tab:hover { color: #94a3b8; }');
        htp.p('.aid-hist-tab.active { color: #fff; }');
        htp.p('.aid-hist-tab.active::after { content: ""; position: absolute; bottom: 0; left: 0; width: 100%; height: 3px; background: linear-gradient(90deg, #3b82f6, #60a5fa); border-radius: 3px 3px 0 0; }');
        htp.p('.aid-chat-list { flex: 1; min-height: 0; overflow-y: auto; padding: 10px 0; }');
        htp.p('.aid-chat-list::-webkit-scrollbar { width: 6px; }');
        htp.p('.aid-chat-list::-webkit-scrollbar-track { background: transparent; }');
        htp.p('.aid-chat-list::-webkit-scrollbar-thumb { background: #3d4a5a; border-radius: 3px; }');
        htp.p('.aid-date-group { padding: 10px 15px 6px; color: #6b7a8a; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; }');
        htp.p('.aid-chat-item { padding: 12px 15px; cursor: pointer; display: flex; align-items: flex-start; gap: 12px; transition: all 0.2s; position: relative; border-left: 3px solid transparent; margin: 2px 0; }');
        htp.p('.aid-chat-item:hover { background: rgba(59,130,246,0.1); }');
        htp.p('.aid-chat-item.active { background: rgba(59,130,246,0.15); border-left-color: #3b82f6; }');
        htp.p('.aid-chat-item.favorite { border-left-color: #f59e0b; }');
        htp.p('.aid-chat-item.favorite .aid-chat-name:after { content: " ★"; color: #f59e0b; font-size: 11px; margin-left: 4px; }');
        htp.p('.aid-chat-item.dashboard .aid-chat-icon { background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); }');
        htp.p('.aid-chat-icon { width: 36px; height: 36px; background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 14px; flex-shrink: 0; color: #fff; }');
        htp.p('.aid-chat-info { flex: 1; min-width: 0; }');
        htp.p('.aid-chat-title-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; }');
        htp.p('.aid-chat-name { color: #e2e8f0; font-size: 13px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1; }');
        htp.p('.aid-chat-time { color: #6b7a8a; font-size: 11px; white-space: nowrap; }');
        htp.p('.aid-chat-preview { color: #6b7a8a; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 4px; }');
        htp.p('.aid-chat-actions { position: absolute; right: 10px; top: 50%; transform: translateY(-50%); display: none; gap: 4px; background: #2d3a4a; padding: 4px; border-radius: 6px; }');
        htp.p('.aid-chat-item:hover .aid-chat-actions { display: flex; }');
        htp.p('.aid-action-btn { background: transparent; border: none; color: #6b7a8a; padding: 5px 7px; border-radius: 4px; cursor: pointer; font-size: 12px; transition: all 0.2s; }');
        htp.p('.aid-action-btn:hover { background: #3d4a5a; color: #fff; }');
        htp.p('.aid-action-btn.delete:hover { color: #ef4444; }');
        htp.p('.aid-action-btn.favorite.active { color: #f59e0b !important; }');
        htp.p('.aid-sidebar-footer { padding: 12px 15px; border-top: 1px solid #2d3a4a; }');
        htp.p('.aid-clear-btn { width: 100%; background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 10px; border-radius: 8px; font-size: 12px; font-weight: 600; cursor: pointer; transition: all 0.2s; }');
        htp.p('.aid-clear-btn:hover { background: #ef4444; color: #fff; }');
        
        -- Settings Button
        htp.p('.aid-settings-btn { width: 100%; background: transparent; border: 1px solid #3b82f6; color: #cfe3ff; padding: 10px; border-radius: 8px; font-size: 12px; font-weight: 700; cursor: pointer; transition: all 0.2s; margin-bottom: 10px; }');
        htp.p('.aid-settings-btn:hover { background: rgba(59,130,246,0.15); color: #fff; }');

        -- =====================================================
        -- PROFESSIONAL WIZARD MODAL STYLES
        -- =====================================================
        htp.p('.ai-wizard-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(15, 23, 42, 0.8); z-index: 9999; justify-content: center; align-items: center; backdrop-filter: blur(8px); animation: fadeIn 0.3s ease; }');
        htp.p('@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }');
        htp.p('@keyframes slideUp { from { opacity: 0; transform: translateY(30px); } to { opacity: 1; transform: translateY(0); } }');
        htp.p('@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }');
        htp.p('@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }');
        htp.p('@keyframes progressBar { from { width: 0%; } to { width: 100%; } }');
        
        -- Wizard Container
        htp.p('.ai-wizard { background: #fff; border-radius: 20px; width: 95%; max-width: 1000px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 25px 80px rgba(0,0,0,0.4); animation: slideUp 0.4s ease; overflow: hidden; }');
        
        -- Wizard Header
        htp.p('.ai-wizard-header { background: linear-gradient(135deg, #1e40af 0%, #3b82f6 50%, #0ea5e9 100%); padding: 24px 30px; position: relative; overflow: hidden; }');
        htp.p('.ai-wizard-header::before { content: ""; position: absolute; top: -50%; right: -50%; width: 100%; height: 200%; background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 60%); pointer-events: none; }');
        htp.p('.ai-wizard-header-content { display: flex; align-items: center; justify-content: space-between; position: relative; z-index: 1; }');
        htp.p('.ai-wizard-title-area { display: flex; align-items: center; gap: 16px; }');
        htp.p('.ai-wizard-icon { width: 52px; height: 52px; background: rgba(255,255,255,0.2); border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 26px; backdrop-filter: blur(10px); }');
        htp.p('.ai-wizard-title { color: #fff; font-size: 22px; font-weight: 700; margin: 0; text-shadow: 0 2px 4px rgba(0,0,0,0.1); }');
        htp.p('.ai-wizard-subtitle { color: rgba(255,255,255,0.85); font-size: 13px; margin-top: 4px; }');
        htp.p('.ai-wizard-close { background: rgba(255,255,255,0.15); border: none; color: #fff; width: 40px; height: 40px; border-radius: 10px; cursor: pointer; font-size: 20px; display: flex; align-items: center; justify-content: center; transition: all 0.2s; backdrop-filter: blur(10px); }');
        htp.p('.ai-wizard-close:hover { background: rgba(255,255,255,0.25); transform: rotate(90deg); }');
        
        -- Stepper
        htp.p('.ai-wizard-stepper { display: flex; padding: 20px 30px; background: linear-gradient(180deg, #f8fafc 0%, #fff 100%); border-bottom: 1px solid #e2e8f0; gap: 8px; }');
        htp.p('.ai-wizard-step { flex: 1; display: flex; align-items: center; gap: 12px; padding: 14px 18px; border-radius: 12px; background: #f1f5f9; border: 2px solid transparent; transition: all 0.3s ease; cursor: default; }');
        htp.p('.ai-wizard-step.active { background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%); border-color: #3b82f6; box-shadow: 0 4px 15px rgba(59,130,246,0.2); }');
        htp.p('.ai-wizard-step.completed { background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%); border-color: #22c55e; }');
        htp.p('.ai-wizard-step-num { width: 32px; height: 32px; border-radius: 50%; background: #cbd5e1; color: #64748b; font-weight: 700; font-size: 14px; display: flex; align-items: center; justify-content: center; transition: all 0.3s; }');
        htp.p('.ai-wizard-step.active .ai-wizard-step-num { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: #fff; box-shadow: 0 3px 10px rgba(59,130,246,0.4); }');
        htp.p('.ai-wizard-step.completed .ai-wizard-step-num { background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); color: #fff; }');
        htp.p('.ai-wizard-step-info { flex: 1; }');
        htp.p('.ai-wizard-step-title { font-size: 13px; font-weight: 700; color: #64748b; transition: color 0.3s; }');
        htp.p('.ai-wizard-step.active .ai-wizard-step-title { color: #1e40af; }');
        htp.p('.ai-wizard-step.completed .ai-wizard-step-title { color: #166534; }');
        htp.p('.ai-wizard-step-desc { font-size: 11px; color: #94a3b8; margin-top: 2px; }');
        
        -- Wizard Body
        htp.p('.ai-wizard-body { flex: 1; overflow: hidden; display: flex; flex-direction: column; min-height: 400px; }');
        
        -- Step 1: Table Selection
        htp.p('.ai-wizard-content { flex: 1; overflow: hidden; display: none; flex-direction: column; }');
        htp.p('.ai-wizard-content.active { display: flex; }');
        
        -- Search & Filter Bar
        htp.p('.ai-table-toolbar { display: flex; gap: 12px; padding: 20px 30px; background: #fff; border-bottom: 1px solid #e2e8f0; align-items: center; flex-wrap: wrap; }');
        htp.p('.ai-search-box { flex: 1; min-width: 250px; position: relative; }');
        htp.p('.ai-search-box input { width: 100%; padding: 12px 16px 12px 44px; border: 2px solid #e2e8f0; border-radius: 12px; font-size: 14px; outline: none; transition: all 0.2s; background: #f8fafc; }');
        htp.p('.ai-search-box input:focus { border-color: #3b82f6; background: #fff; box-shadow: 0 0 0 4px rgba(59,130,246,0.1); }');
        htp.p('.ai-search-box::before { content: "🔍"; position: absolute; left: 16px; top: 50%; transform: translateY(-50%); font-size: 16px; }');
        htp.p('.ai-filter-chips { display: flex; gap: 8px; flex-wrap: wrap; }');
        htp.p('.ai-filter-chip { padding: 8px 16px; border-radius: 20px; font-size: 12px; font-weight: 600; cursor: pointer; transition: all 0.2s; border: 2px solid #e2e8f0; background: #fff; color: #64748b; }');
        htp.p('.ai-filter-chip:hover { border-color: #3b82f6; color: #3b82f6; }');
        htp.p('.ai-filter-chip.active { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: #fff; border-color: transparent; box-shadow: 0 3px 10px rgba(59,130,246,0.3); }');
        htp.p('.ai-selection-info { display: flex; align-items: center; gap: 12px; padding: 8px 16px; background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border-radius: 10px; font-size: 13px; font-weight: 600; color: #92400e; }');
        htp.p('.ai-select-actions { display: flex; gap: 8px; }');
        htp.p('.ai-select-btn { padding: 6px 12px; border-radius: 6px; font-size: 11px; font-weight: 700; cursor: pointer; border: none; transition: all 0.2s; }');
        htp.p('.ai-select-all { background: #3b82f6; color: #fff; }');
        htp.p('.ai-select-none { background: #e2e8f0; color: #64748b; }');
        
        -- Table List
        htp.p('.ai-table-list-container { flex: 1; overflow-y: auto; padding: 20px 30px; background: linear-gradient(180deg, #f8fafc 0%, #fff 100%); }');
        htp.p('.ai-table-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; }');
        htp.p('.ai-table-card { background: #fff; border: 2px solid #e2e8f0; border-radius: 14px; padding: 18px; cursor: pointer; transition: all 0.3s ease; position: relative; overflow: hidden; }');
        htp.p('.ai-table-card:hover { border-color: #3b82f6; transform: translateY(-3px); box-shadow: 0 10px 30px rgba(59,130,246,0.15); }');
        htp.p('.ai-table-card.selected { border-color: #22c55e; background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%); }');
        htp.p('.ai-table-card.selected::after { content: "✓"; position: absolute; top: 12px; right: 12px; width: 26px; height: 26px; background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); color: #fff; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 700; box-shadow: 0 3px 10px rgba(34,197,94,0.4); }');
        htp.p('.ai-table-card-header { display: flex; align-items: flex-start; gap: 14px; margin-bottom: 12px; }');
        htp.p('.ai-table-card-icon { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 20px; flex-shrink: 0; }');
        htp.p('.ai-table-card-icon.table { background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%); }');
        htp.p('.ai-table-card-icon.view { background: linear-gradient(135deg, #fae8ff 0%, #e9d5ff 100%); }');
        htp.p('.ai-table-card-info { flex: 1; min-width: 0; }');
        htp.p('.ai-table-card-name { font-size: 14px; font-weight: 700; color: #1e293b; margin-bottom: 4px; word-break: break-word; }');
        htp.p('.ai-table-card-type { display: inline-flex; padding: 3px 10px; border-radius: 6px; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }');
        htp.p('.ai-table-card-type.table { background: #dbeafe; color: #1e40af; }');
        htp.p('.ai-table-card-type.view { background: #f3e8ff; color: #7c3aed; }');
        htp.p('.ai-table-card-desc { font-size: 12px; color: #64748b; line-height: 1.5; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }');
        htp.p('.ai-table-card-meta { display: flex; gap: 12px; margin-top: 12px; padding-top: 12px; border-top: 1px solid #e2e8f0; }');
        htp.p('.ai-table-card-stat { display: flex; align-items: center; gap: 6px; font-size: 11px; color: #64748b; }');
        htp.p('.ai-table-card-badge { padding: 4px 10px; border-radius: 6px; font-size: 10px; font-weight: 700; }');
        htp.p('.ai-table-card-badge.ai { background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); color: #92400e; }');
        htp.p('.ai-table-card-badge.db { background: #f1f5f9; color: #64748b; }');
        
        -- Step 2: Building Metadata with Progress
        htp.p('.ai-build-container { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 40px; text-align: center; }');
        htp.p('.ai-build-animation { width: 200px; height: 200px; position: relative; margin-bottom: 30px; }');
        htp.p('.ai-build-circle { position: absolute; width: 100%; height: 100%; border: 4px solid #e2e8f0; border-radius: 50%; }');
        htp.p('.ai-build-circle.spinning { border-color: transparent; border-top-color: #3b82f6; border-right-color: #22c55e; animation: spin 1.5s linear infinite; }');
        htp.p('.ai-build-icon { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); font-size: 60px; }');
        htp.p('.ai-build-title { font-size: 24px; font-weight: 700; color: #1e293b; margin-bottom: 10px; }');
        htp.p('.ai-build-subtitle { font-size: 14px; color: #64748b; margin-bottom: 30px; max-width: 400px; }');
        
        -- Progress Bar
        htp.p('.ai-progress-container { width: 100%; max-width: 500px; margin-bottom: 24px; }');
        htp.p('.ai-progress-bar { height: 12px; background: #e2e8f0; border-radius: 6px; overflow: hidden; position: relative; }');
        htp.p('.ai-progress-fill { height: 100%; background: linear-gradient(90deg, #3b82f6, #22c55e, #3b82f6); background-size: 200% 100%; border-radius: 6px; transition: width 0.5s ease; animation: shimmer 2s infinite; }');
        htp.p('@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }');
        htp.p('.ai-progress-text { display: flex; justify-content: space-between; margin-top: 10px; font-size: 13px; color: #64748b; }');
        htp.p('.ai-progress-percent { font-weight: 700; color: #3b82f6; }');

                -- NEW: Domain Badge Colors
        htp.p('.ai-table-card-domain { display: inline-block; font-size: 9px; font-weight: 700; padding: 2px 8px; border-radius: 10px; margin-left: 4px; text-transform: uppercase; }');
        htp.p('.ai-table-card-domain.sales { background: #dcfce7; color: #166534; }');
        htp.p('.ai-table-card-domain.hr { background: #fef3c7; color: #92400e; }');
        htp.p('.ai-table-card-domain.finance { background: #dbeafe; color: #1e40af; }');
        htp.p('.ai-table-card-domain.inventory { background: #f3e8ff; color: #7c3aed; }');
        htp.p('.ai-table-card-domain.supply-chain { background: #ffedd5; color: #c2410c; }');
        htp.p('.ai-table-card-domain.customer { background: #fce7f3; color: #be185d; }');
        htp.p('.ai-table-card-domain.marketing { background: #fee2e2; color: #dc2626; }');
        htp.p('.ai-table-card-domain.operations { background: #fed7aa; color: #ea580c; }');
        htp.p('.ai-table-card-domain.it { background: #e0e7ff; color: #4338ca; }');
        htp.p('.ai-table-card-domain.analytics { background: #ccfbf1; color: #0f766e; }');
        htp.p('.ai-table-card-domain.master-data { background: #f5f5f4; color: #57534e; }');
        htp.p('.ai-table-card-domain.audit { background: #fef9c3; color: #a16207; }');
        htp.p('.ai-table-card-domain.security { background: #fecaca; color: #b91c1c; }');
        htp.p('.ai-table-card-domain.other { background: #f3f4f6; color: #4b5563; }');
        
        -- NEW: Relevance Score Bar
        htp.p('.ai-table-card-score { display: flex; align-items: center; gap: 6px; margin-top: 10px; padding-top: 10px; border-top: 1px dashed #e5e7eb; }');
        htp.p('.ai-table-card-score-label { font-size: 10px; color: #9ca3af; }');
        htp.p('.ai-table-card-score-bar { flex: 1; height: 6px; background: #e5e7eb; border-radius: 3px; overflow: hidden; }');
        htp.p('.ai-table-card-score-fill { height: 100%; border-radius: 3px; }');
        htp.p('.ai-table-card-score-fill.high { background: linear-gradient(90deg, #22c55e, #16a34a); }');
        htp.p('.ai-table-card-score-fill.medium { background: linear-gradient(90deg, #f59e0b, #d97706); }');
        htp.p('.ai-table-card-score-fill.low { background: linear-gradient(90deg, #ef4444, #dc2626); }');
        htp.p('.ai-table-card-score-val { font-size: 11px; font-weight: 700; color: #6b7280; min-width: 32px; text-align: right; }');
        
        -- NEW: Row Count
        htp.p('.ai-table-card-rows { font-size: 10px; color: #9ca3af; margin-top: 6px; display: flex; align-items: center; gap: 4px; }');

        
        -- NEW: Domain Filter Select
        htp.p('.ai-domain-select { padding: 8px 12px; border: 2px solid #e2e8f0; border-radius: 10px; font-size: 12px; font-weight: 600; background: #fff; cursor: pointer; min-width: 140px; }');
        htp.p('.ai-domain-select:focus { outline: none; border-color: #3b82f6; }');
        
        -- Log Area
        htp.p('.ai-build-log { width: 100%; max-width: 600px; background: #0f172a; border-radius: 12px; padding: 16px; text-align: left; max-height: 200px; overflow-y: auto; font-family: "Fira Code", monospace; }');
        htp.p('.ai-log-line { font-size: 12px; color: #94a3b8; padding: 4px 0; display: flex; align-items: flex-start; gap: 10px; }');
        htp.p('.ai-log-line.success { color: #4ade80; }');
        htp.p('.ai-log-line.error { color: #f87171; }');
        htp.p('.ai-log-line.info { color: #60a5fa; }');
        htp.p('.ai-log-time { color: #64748b; font-size: 11px; flex-shrink: 0; }');
        
        -- Step 3: Complete
        htp.p('.ai-complete-container { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 40px; text-align: center; }');
        htp.p('.ai-complete-icon { width: 120px; height: 120px; background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 60px; margin-bottom: 24px; box-shadow: 0 20px 50px rgba(34,197,94,0.3); animation: bounceIn 0.6s ease; }');
        htp.p('@keyframes bounceIn { 0% { transform: scale(0); } 50% { transform: scale(1.1); } 100% { transform: scale(1); } }');
        htp.p('.ai-complete-title { font-size: 28px; font-weight: 700; color: #1e293b; margin-bottom: 10px; }');
        htp.p('.ai-complete-subtitle { font-size: 15px; color: #64748b; margin-bottom: 30px; }');
        htp.p('.ai-complete-stats { display: flex; gap: 30px; margin-bottom: 30px; }');
        htp.p('.ai-complete-stat { text-align: center; padding: 20px 30px; background: #f8fafc; border-radius: 12px; }');
        htp.p('.ai-complete-stat-value { font-size: 32px; font-weight: 800; color: #3b82f6; }');
        htp.p('.ai-complete-stat-label { font-size: 12px; color: #64748b; margin-top: 4px; }');
        
        -- Wizard Footer
        htp.p('.ai-wizard-footer { display: flex; justify-content: space-between; align-items: center; padding: 20px 30px; background: #f8fafc; border-top: 1px solid #e2e8f0; }');
        htp.p('.ai-wizard-btn { padding: 12px 28px; border-radius: 10px; font-size: 14px; font-weight: 700; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 8px; }');
        htp.p('.ai-wizard-btn:disabled { opacity: 0.5; cursor: not-allowed; }');
        htp.p('.ai-wizard-btn-secondary { background: #fff; color: #64748b; border: 2px solid #e2e8f0; }');
        htp.p('.ai-wizard-btn-secondary:hover:not(:disabled) { border-color: #3b82f6; color: #3b82f6; }');
        htp.p('.ai-wizard-btn-primary { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: #fff; border: none; box-shadow: 0 4px 15px rgba(59,130,246,0.4); }');
        htp.p('.ai-wizard-btn-primary:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(59,130,246,0.5); }');
        htp.p('.ai-wizard-btn-success { background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); color: #fff; border: none; box-shadow: 0 4px 15px rgba(34,197,94,0.4); }');
        
        -- Empty State
        htp.p('.ai-empty-state { text-align: center; padding: 60px 20px; color: #94a3b8; }');
        htp.p('.ai-empty-state-icon { font-size: 60px; margin-bottom: 16px; opacity: 0.5; }');
        htp.p('.ai-empty-state-title { font-size: 18px; font-weight: 600; color: #64748b; margin-bottom: 8px; }');
        htp.p('.ai-empty-state-desc { font-size: 14px; }');
        
        -- Loading Skeleton for tables
        htp.p('.ai-table-skeleton { background: #fff; border: 2px solid #e2e8f0; border-radius: 14px; padding: 18px; }');
        htp.p('.ai-skeleton-line { background: linear-gradient(90deg, #e2e8f0 25%, #f1f5f9 50%, #e2e8f0 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; border-radius: 6px; }');
        
        -- =====================================================
        -- END WIZARD STYLES
        -- =====================================================

        htp.p('.aid-sidebar-toggle { position: absolute; left: 280px; top: 50%; transform: translateY(-50%); background: #1e2a3a; border: 1px solid #2d3a4a; color: #fff; width: 24px; height: 48px; border-radius: 0 8px 8px 0; cursor: pointer; display: flex; align-items: center; justify-content: center; z-index: 10; transition: left 0.3s ease; }');
        htp.p('.aid-sidebar-toggle.collapsed { left: 0; }');
        htp.p('.aid-sidebar-toggle:hover { background: #2d3a4a; }');

        -- Main Content Area
        htp.p('.aid-main-content { flex: 1; display: flex; flex-direction: column; overflow-y: auto; overflow-x: hidden; position: relative; background: #f5f7fa; min-height: 0; }');
        htp.p('.hidden { display: none !important; }');

        -- Skeleton Loading Animation Styles
        htp.p('@keyframes skeleton-shimmer { 0% { background-position: -200% 0; } 100% { background-position: 200% 0; } }');
        htp.p('.skeleton { background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%); background-size: 200% 100%; animation: skeleton-shimmer 1.5s ease-in-out infinite; border-radius: 8px; }');
        htp.p('.skeleton-text { height: 14px; margin-bottom: 8px; }');
        htp.p('.skeleton-text-sm { height: 10px; width: 60%; }');
        htp.p('.skeleton-title { height: 24px; width: 70%; margin-bottom: 12px; }');
        
        -- Skeleton Container Styles
        htp.p('.aid-skeleton-container { display: none; flex-direction: column; height: 100%; padding: 20px; background: linear-gradient(135deg, #f0f4f8 0%, #e2e8f0 100%); overflow: auto; }');
        htp.p('.aid-skeleton-container.active { display: flex; }');
        
        -- Report Skeleton Styles
        htp.p('.skel-report-title { height: 60px; border-radius: 12px; margin-bottom: 20px; }');
        htp.p('.skel-kpis-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }');
        htp.p('@media (max-width: 1200px) { .skel-kpis-row { grid-template-columns: repeat(2, 1fr); } }');
        htp.p('.skel-kpi-card { background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.06); border: 1px solid #e5e7eb; }');
        htp.p('.skel-kpi-header { height: 36px; }');
        htp.p('.skel-kpi-body { padding: 20px; display: flex; align-items: center; justify-content: space-between; }');
        htp.p('.skel-kpi-value { height: 36px; width: 80px; border-radius: 6px; }');
        htp.p('.skel-kpi-icon { width: 48px; height: 48px; border-radius: 12px; }');
        htp.p('.skel-tabs { display: flex; gap: 8px; margin-bottom: 20px; }');
        htp.p('.skel-tab { height: 40px; width: 100px; border-radius: 8px; }');
        htp.p('.skel-table-container { background: #fff; border-radius: 12px; flex: 1; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.06); border: 1px solid #e5e7eb; }');
        htp.p('.skel-table-toolbar { height: 56px; border-bottom: 1px solid #e5e7eb; padding: 12px 16px; display: flex; align-items: center; justify-content: space-between; }');
        htp.p('.skel-search { height: 32px; width: 200px; border-radius: 8px; }');
        htp.p('.skel-export-btn { height: 32px; width: 100px; border-radius: 8px; }');
        htp.p('.skel-table-header { height: 48px; background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%); }');
        htp.p('.skel-table-row { height: 52px; border-bottom: 1px solid #f1f5f9; display: flex; align-items: center; padding: 0 18px; gap: 20px; }');
        htp.p('.skel-table-cell { height: 16px; border-radius: 4px; flex: 1; }');
        htp.p('.skel-table-cell:nth-child(1) { flex: 0.5; }');
        htp.p('.skel-table-cell:nth-child(2) { flex: 1.5; }');
        
        -- Dashboard Skeleton Styles
        htp.p('.skel-dash-title { height: 70px; border-radius: 12px; margin-bottom: 20px; }');
        htp.p('.skel-dash-kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 20px; }');
        htp.p('@media (max-width: 1200px) { .skel-dash-kpis { grid-template-columns: repeat(2, 1fr); } }');
        htp.p('.skel-dash-kpi { background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.08); border-left: 5px solid #e5e7eb; }');
        htp.p('.skel-dash-kpi:nth-child(1) { border-left-color: #22c55e; }');
        htp.p('.skel-dash-kpi:nth-child(2) { border-left-color: #f97316; }');
        htp.p('.skel-dash-kpi:nth-child(3) { border-left-color: #3b82f6; }');
        htp.p('.skel-dash-kpi:nth-child(4) { border-left-color: #ef4444; }');
        htp.p('.skel-dash-kpi-header { height: 40px; }');
        htp.p('.skel-dash-kpi-body { padding: 20px; min-height: 100px; display: flex; align-items: center; justify-content: space-between; background: #fff; }');
        htp.p('.skel-dash-kpi-main { flex: 1; }');
        htp.p('.skel-dash-kpi-value { height: 40px; width: 100px; border-radius: 6px; margin-bottom: 10px; }');
        htp.p('.skel-dash-kpi-trend { height: 18px; width: 80px; border-radius: 4px; }');
        htp.p('.skel-dash-kpi-icon { width: 56px; height: 56px; border-radius: 12px; }');
        htp.p('.skel-dash-charts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; flex: 1; }');
        htp.p('@media (max-width: 1200px) { .skel-dash-charts { grid-template-columns: repeat(2, 1fr); } }');
        htp.p('@media (max-width: 800px) { .skel-dash-charts { grid-template-columns: 1fr; } }');
        htp.p('.skel-dash-chart { background: #fff; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.06); border: 1px solid #e5e7eb; overflow: hidden; min-height: 280px; display: flex; flex-direction: column; }');
        htp.p('.skel-dash-chart.colspan-2 { grid-column: span 2; }');
        htp.p('.skel-dash-chart-header { padding: 14px 18px; border-bottom: 1px solid #e5e7eb; }');
        htp.p('.skel-dash-chart-title { height: 20px; width: 60%; border-radius: 4px; }');
        htp.p('.skel-dash-chart-body { flex: 1; padding: 20px; display: flex; align-items: flex-end; justify-content: space-around; gap: 12px; }');
        htp.p('.skel-bar { border-radius: 4px 4px 0 0; width: 100%; max-width: 40px; }');
        htp.p('.skel-bar:nth-child(1) { height: 60%; }');
        htp.p('.skel-bar:nth-child(2) { height: 80%; }');
        htp.p('.skel-bar:nth-child(3) { height: 45%; }');
        htp.p('.skel-bar:nth-child(4) { height: 90%; }');
        htp.p('.skel-bar:nth-child(5) { height: 70%; }');
        htp.p('.skel-bar:nth-child(6) { height: 55%; }');
        htp.p('.skel-pie-container { flex: 1; display: flex; align-items: center; justify-content: center; }');
        htp.p('.skel-pie { width: 150px; height: 150px; border-radius: 50%; }');
        htp.p('.skel-line-container { flex: 1; display: flex; flex-direction: column; justify-content: center; gap: 15px; padding: 20px; }');
        htp.p('.skel-line { height: 3px; border-radius: 2px; }');

        -- Dashboard View Styles
        htp.p('.aid-dashboard-view { display: none; flex-direction: column; height: 100%; flex: 1; min-height: 0; overflow-y: auto; overflow-x: hidden; padding: 16px; background: linear-gradient(135deg, #f0f4f8 0%, #e2e8f0 100%); }');
        htp.p('.aid-dashboard-view.active { display: flex; }');
        htp.p('.aid-dash-title { background: linear-gradient(135deg, #1e40af 0%, #1d4ed8 100%); color: white; padding: 20px 30px; border-radius: 12px; margin-bottom: 20px; font-size: 22px; font-weight: 700; text-transform: uppercase; letter-spacing: 2px; text-align: center; box-shadow: 0 4px 15px rgba(30,64,175,0.3); }');
        htp.p('.aid-dash-kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 20px; }');
        htp.p('@media (max-width: 1200px) { .aid-dash-kpis { grid-template-columns: repeat(2, 1fr); } }');
        htp.p('.aid-dash-kpi { border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.08); transition: all 0.3s ease; position: relative; }');
        htp.p('.aid-dash-kpi:hover { transform: translateY(-5px); box-shadow: 0 8px 25px rgba(0,0,0,0.12); }');
        htp.p('.aid-dash-kpi-header { padding: 12px 16px; font-size: 11px; font-weight: 700; text-transform: uppercase; color: #fff; letter-spacing: 1px; }');
        htp.p('.aid-dash-kpi-body { padding: 20px; background: #fff; display: flex; align-items: center; justify-content: space-between; min-height: 100px; }');
        htp.p('.aid-dash-kpi-main { flex: 1; }');
        htp.p('.aid-dash-kpi-value { font-size: 36px; font-weight: 800; color: #1f2937; line-height: 1; margin-bottom: 8px; }');
        htp.p('.aid-dash-kpi-trend { font-size: 14px; font-weight: 600; display: flex; align-items: center; gap: 6px; }');
        htp.p('.aid-dash-kpi-trend.positive { color: #22c55e; }');
        htp.p('.aid-dash-kpi-trend.negative { color: #ef4444; }');
        htp.p('.aid-dash-kpi-trend-label { font-size: 12px; color: #6b7280; margin-left: 4px; }');
        htp.p('.aid-dash-kpi-icon { width: 56px; height: 56px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 28px; }');
        htp.p('.aid-dash-kpi-minichart { width: 80px; height: 50px; margin-left: 10px; }');
        
        -- KPI Color Variants
        htp.p('.aid-dash-kpi.green .aid-dash-kpi-header { background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); }');
        htp.p('.aid-dash-kpi.green { border-left: 5px solid #22c55e; }');
        htp.p('.aid-dash-kpi.green .aid-dash-kpi-icon { background: rgba(34,197,94,0.1); color: #22c55e; }');
        htp.p('.aid-dash-kpi.orange .aid-dash-kpi-header { background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); }');
        htp.p('.aid-dash-kpi.orange { border-left: 5px solid #f97316; }');
        htp.p('.aid-dash-kpi.orange .aid-dash-kpi-icon { background: rgba(249,115,22,0.1); color: #f97316; }');
        htp.p('.aid-dash-kpi.blue .aid-dash-kpi-header { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); }');
        htp.p('.aid-dash-kpi.blue { border-left: 5px solid #3b82f6; }');
        htp.p('.aid-dash-kpi.blue .aid-dash-kpi-icon { background: rgba(59,130,246,0.1); color: #3b82f6; }');
        htp.p('.aid-dash-kpi.red .aid-dash-kpi-header { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); }');
        htp.p('.aid-dash-kpi.red { border-left: 5px solid #ef4444; }');
        htp.p('.aid-dash-kpi.red .aid-dash-kpi-icon { background: rgba(239,68,68,0.1); color: #ef4444; }');
        htp.p('.aid-dash-kpi.purple .aid-dash-kpi-header { background: linear-gradient(135deg, #a855f7 0%, #9333ea 100%); }');
        htp.p('.aid-dash-kpi.purple { border-left: 5px solid #a855f7; }');
        htp.p('.aid-dash-kpi.purple .aid-dash-kpi-icon { background: rgba(168,85,247,0.1); color: #a855f7; }');
        htp.p('.aid-dash-kpi.teal .aid-dash-kpi-header { background: linear-gradient(135deg, #14b8a6 0%, #0d9488 100%); }');
        htp.p('.aid-dash-kpi.teal { border-left: 5px solid #14b8a6; }');
        htp.p('.aid-dash-kpi.teal .aid-dash-kpi-icon { background: rgba(20,184,166,0.1); color: #14b8a6; }');

        -- Dashboard Charts Grid (GridStack-friendly)
        htp.p('.aid-dash-charts { position: relative; width: 100%; min-height: 320px; overflow: visible; }');
        htp.p('.aid-dash-charts.grid-stack { display: block; }');
        htp.p('.aid-dash-chart { background: #fff; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.06); border: 1px solid #e5e7eb; overflow: hidden; display: flex; flex-direction: column; height: 100%; }');
        htp.p('.aid-dash-chart-header { padding: 14px 18px; border-bottom: 1px solid #e5e7eb; display: flex; align-items: center; justify-content: space-between; cursor: grab; user-select: none; }');
        htp.p('.aid-dash-chart-title { font-size: 14px; font-weight: 700; color: #1f2937; display: flex; align-items: center; gap: 8px; }');
        htp.p('.aid-dash-chart-body { flex: 1; padding: 10px; min-height: 220px; height: 100%; }');
        
        -- Report View Styles
        htp.p('.aid-report-view { display: none; flex-direction: column; height: 100%; flex: 1; min-height: 0; overflow-y: auto; }');
        htp.p('.aid-report-view.active { display: flex; }');
        htp.p('.aid-results-area { flex-grow: 1; overflow: hidden; padding: 24px 30px; display: flex; flex-direction: column; }');
        htp.p('.ai-flex-col { display: flex; flex-direction: column; flex: 1; overflow: hidden; min-height: 0; }');
        
        -- Report KPIs
        htp.p('.aid-kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 20px; margin-bottom: 24px; flex-shrink: 0; }');
        htp.p('.aid-kpi { background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.06); border: 1px solid #e5e7eb; transition: all 0.3s ease; display: flex; flex-direction: column; }');
        htp.p('.aid-kpi:hover { transform: translateY(-4px); box-shadow: 0 8px 25px rgba(0,0,0,0.1); }');
        htp.p('.aid-kpi-header { padding: 10px 16px; font-size: 11px; font-weight: 700; text-transform: uppercase; color: #fff; letter-spacing: 0.8px; }');
        htp.p('.aid-kpi-body { padding: 20px; background: #fff; display: flex; align-items: center; justify-content: space-between; flex: 1; }');
        htp.p('.aid-kpi-content { flex: 1; }');
        htp.p('.aid-kpi-value { font-size: 32px; font-weight: 800; color: #1f2937; margin-bottom: 6px; line-height: 1; }');
        htp.p('.aid-kpi-sub { font-size: 13px; color: #6b7280; display: flex; align-items: center; gap: 6px; }');
        htp.p('.aid-kpi-icon { width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 24px; }');
        
        -- KPI Colors
        htp.p('.aid-kpi.kpi-green .aid-kpi-header { background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); }');
        htp.p('.aid-kpi.kpi-green { border-left: 4px solid #22c55e; }');
        htp.p('.aid-kpi.kpi-green .aid-kpi-icon { background: rgba(34,197,94,0.1); color: #22c55e; }');
        htp.p('.aid-kpi.kpi-orange .aid-kpi-header { background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); }');
        htp.p('.aid-kpi.kpi-orange { border-left: 4px solid #f97316; }');
        htp.p('.aid-kpi.kpi-orange .aid-kpi-icon { background: rgba(249,115,22,0.1); color: #f97316; }');
        htp.p('.aid-kpi.kpi-purple .aid-kpi-header { background: linear-gradient(135deg, #a855f7 0%, #9333ea 100%); }');
        htp.p('.aid-kpi.kpi-purple { border-left: 4px solid #a855f7; }');
        htp.p('.aid-kpi.kpi-purple .aid-kpi-icon { background: rgba(168,85,247,0.1); color: #a855f7; }');
        htp.p('.aid-kpi.kpi-red .aid-kpi-header { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); }');
        htp.p('.aid-kpi.kpi-red { border-left: 4px solid #ef4444; }');
        htp.p('.aid-kpi.kpi-red .aid-kpi-icon { background: rgba(239,68,68,0.1); color: #ef4444; }');
        htp.p('.aid-kpi.kpi-blue .aid-kpi-header { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); }');
        htp.p('.aid-kpi.kpi-blue { border-left: 4px solid #3b82f6; }');
        htp.p('.aid-kpi.kpi-blue .aid-kpi-icon { background: rgba(59,130,246,0.1); color: #3b82f6; }');
        htp.p('.aid-kpi.kpi-teal .aid-kpi-header { background: linear-gradient(135deg, #14b8a6 0%, #0d9488 100%); }');
        htp.p('.aid-kpi.kpi-teal { border-left: 4px solid #14b8a6; }');
        htp.p('.aid-kpi.kpi-teal .aid-kpi-icon { background: rgba(20,184,166,0.1); color: #14b8a6; }');

        -- Table Styles
        htp.p('.ai-table-container { background: #fff; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); overflow: visible; flex: 1; min-height: 0; border: 1px solid #e5e7eb; display: flex; flex-direction: column; }');
        htp.p('.ai-table-toolbar { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb; background: #fff; border-radius: 12px 12px 0 0; }');
        htp.p('.ai-search-sm { padding: 8px 14px; border: 1px solid #e5e7eb; border-radius: 8px; font-size: 13px; width: 220px; outline: none; transition: all 0.2s; background: #f9fafb; }');
        htp.p('.ai-search-sm:focus { border-color: #3b82f6; background: #fff; box-shadow: 0 0 0 3px rgba(59,130,246,0.1); }');
        htp.p('.ai-toolbar-actions { display: flex; gap: 10px; }');
        htp.p('.ai-table-scroll-area { flex: 1; overflow: auto; width: 100%; border-radius: 0 0 12px 12px; }');
        htp.p('.ai-dropdown { position: relative; display: inline-block; }');
        htp.p('.ai-drop-btn { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: #fff; padding: 8px 16px; font-size: 12px; border: none; border-radius: 8px; cursor: pointer; display: flex; align-items: center; gap: 6px; transition: all 0.2s; font-weight: 600; box-shadow: 0 2px 6px rgba(59,130,246,0.3); }');
        htp.p('.ai-drop-btn:hover { background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); transform: translateY(-1px); }');
        htp.p('.ai-dropdown-content { display: none; position: absolute; right: 0; background-color: #fff; min-width: 160px; box-shadow: 0 10px 40px rgba(0,0,0,0.15); z-index: 1000; border-radius: 10px; border: 1px solid #e5e7eb; overflow: hidden; margin-top: 4px; }');
        htp.p('.ai-dropdown-content a { color: #374151; padding: 12px 18px; text-decoration: none; display: flex; align-items: center; gap: 10px; font-size: 13px; cursor: pointer; transition: all 0.15s; font-weight: 500; }');
        htp.p('.ai-dropdown-content a:hover { background: #f0f9ff; color: #3b82f6; }');
        htp.p('.ai-dropdown:hover .ai-dropdown-content { display: block; }');
        htp.p('.ai-dyn-table { width: 100%; border-collapse: separate; border-spacing: 0; }');
        htp.p('.ai-dyn-table th { background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%); color: #1e40af; font-weight: 700; font-size: 12px; padding: 14px 18px; text-align: left; border-bottom: 2px solid #93c5fd; position: sticky; top: 0; z-index: 5; text-transform: uppercase; letter-spacing: 0.5px; }');
        htp.p('.ai-dyn-table td { padding: 14px 18px; color: #374151; border-bottom: 1px solid #f1f5f9; font-size: 14px; background: #fff; }');
        htp.p('.ai-dyn-table tr:hover td { background: #f8fafc; }');
        htp.p('.ai-dyn-table tr:nth-child(even) td { background: #fafbfc; }');

        -- Tabs
        htp.p('.ai-tabs { display: flex; gap: 0; margin-bottom: 20px; background: #fff; border-radius: 10px; padding: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); flex-shrink: 0; border: 1px solid #e5e7eb; width: fit-content; }');
        htp.p('.ai-tab-btn { background: transparent; border: none; padding: 10px 24px; font-size: 14px; font-weight: 600; color: #6b7280; cursor: pointer; border-radius: 6px; transition: all 0.2s; position: relative; }');
        htp.p('.ai-tab-btn:hover { color: #3b82f6; background: #f0f9ff; }');
        htp.p('.ai-tab-btn.active { color: #3b82f6; background: #eff6ff; }');
        htp.p('.ai-view-content { display: none; height: 100%; }');
        htp.p('.ai-view-content.active { display: flex; flex-direction: column; flex: 1; overflow: hidden; }');
        htp.p('@keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }');
        htp.p('#chart_container_' || l_id || ' { width: 100%; height: 100%; min-height: 400px; flex: 1; background: #fff; border-radius: 12px; border: 1px solid #e5e7eb; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }');

        -- Chart View Layout with Type Selector
        htp.p('.ai-chart-view-wrapper.active { flex-direction: row !important; gap: 20px; }');
        htp.p('.ai-chart-main-area { flex: 1; display: flex; flex-direction: column; min-width: 0; }');
        htp.p('.ai-chart-type-panel { width: 280px; flex-shrink: 0; background: #fff; border-radius: 12px; border: 1px solid #e5e7eb; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); overflow-y: auto; max-height: 100%; }');
        htp.p('.ai-chart-type-panel-header { margin-bottom: 16px; }');
        htp.p('.ai-chart-type-panel-header h3 { font-size: 16px; font-weight: 600; color: #1f2937; margin: 0 0 4px 0; }');
        htp.p('.ai-chart-type-panel-header span { font-size: 13px; color: #6b7280; }');
        htp.p('.ai-report-chart-types { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }');
        htp.p('.ai-report-chart-type-item { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 12px 8px; border: 2px solid #e5e7eb; border-radius: 10px; cursor: pointer; transition: all 0.2s; background: #fff; }');
        htp.p('.ai-report-chart-type-item:hover { border-color: #93c5fd; background: #f0f9ff; }');
        htp.p('.ai-report-chart-type-item.selected { border-color: #3b82f6; background: #eff6ff; box-shadow: 0 0 0 3px rgba(59,130,246,0.1); }');
        htp.p('.ai-report-chart-type-item.selected .ai-rct-icon { color: #3b82f6; }');
        htp.p('.ai-rct-icon { font-size: 24px; margin-bottom: 6px; color: #6b7280; transition: color 0.2s; }');
        htp.p('.ai-rct-icon svg { width: 24px; height: 24px; }');
        htp.p('.ai-rct-name { font-size: 11px; color: #374151; text-align: center; font-weight: 500; }');

        -- Interaction Container
        htp.p('.ai-interaction-container { position: absolute; width: 100%; display: flex; flex-direction: column; align-items: center; z-index: 100; padding: 0 20px; transition: all 0.6s cubic-bezier(0.34, 1.56, 0.64, 1); }');
        htp.p('.ai-interaction-container.centered { top: 45%; left: 50%; transform: translate(-50%, -50%); max-width: 800px; }');
        htp.p('.ai-interaction-container.bottom { top: auto; bottom: 0; left: 0; transform: none; width: 100%; padding-bottom: 30px; padding-top: 40px; background: linear-gradient(to top, #f5f7fa 85%, rgba(245,247,250,0)); pointer-events: none; }');
        htp.p('.ai-interaction-container.bottom > * { pointer-events: auto; }');
        htp.p('.ai-search-wrapper { width: 100%; max-width: 900px; background: #fff; border-radius: 16px; padding: 10px 18px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); display: flex; align-items: flex-end; gap: 14px; border: 2px solid #e5e7eb; transition: all 0.3s; }');
        htp.p('.ai-search-wrapper:focus-within { box-shadow: 0 8px 30px rgba(59,130,246,0.15); border-color: #3b82f6; }');
        htp.p('.ai-active-cat-chip { display: none; background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%); color: #1d4ed8; padding: 6px 12px; border-radius: 8px; font-size: 12px; font-weight: 700; white-space: nowrap; align-self: center; margin-right: 5px; border: 1px solid #bfdbfe; }');
        htp.p('.ai-active-cat-chip.visible { display: inline-flex; align-items: center; gap: 6px; }');
        htp.p('.ai-active-cat-chip.dashboard { background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%); color: #166534; border-color: #86efac; }');
        htp.p('.ai-cat-remove { cursor: pointer; opacity: 0.6; font-size: 14px; }');
        htp.p('.ai-cat-remove:hover { opacity: 1; }');
        htp.p('.ai-input { flex: 1; border: none; outline: none; font-size: 15px; resize: none; max-height: 150px; font-family: inherit; padding: 10px 0; line-height: 1.5; color: #1f2937; }');
        htp.p('.ai-input::placeholder { color: #9ca3af; }');
        htp.p('.ai-send-btn { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: white; border: none; border-radius: 10px; width: 40px; height: 40px; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.2s; margin-bottom: 5px; box-shadow: 0 2px 8px rgba(59,130,246,0.4); }');
        htp.p('.ai-send-btn:hover { background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); transform: scale(1.05); }');
       
       -- Suggestions Container
        htp.p('.ai-suggestions-container { width: 100%; max-width: 900px; margin-bottom: 20px; }');
        
        -- Section Header
        htp.p('.ai-sugg-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }');
        htp.p('.ai-sugg-title { display: flex; align-items: center; gap: 10px; font-size: 14px; font-weight: 600; color: #64748b; }');
        htp.p('.ai-sugg-title-icon { width: 32px; height: 32px; background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 16px; }');
        htp.p('.ai-sugg-refresh { background: transparent; border: 1px solid #e2e8f0; color: #64748b; padding: 8px 14px; border-radius: 8px; font-size: 12px; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; transition: all 0.2s; }');
        htp.p('.ai-sugg-refresh:hover { border-color: #3b82f6; color: #3b82f6; background: #f0f9ff; }');
        htp.p('.ai-sugg-refresh svg { transition: transform 0.3s; }');
        htp.p('.ai-sugg-refresh:hover svg { transform: rotate(180deg); }');
        
        -- Suggestions Grid
        htp.p('.ai-sugg-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; }');
        htp.p('@media (max-width: 700px) { .ai-sugg-grid { grid-template-columns: 1fr; } }');
        
        -- Individual Suggestion Card
        htp.p('.ai-sugg-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 16px 18px; cursor: pointer; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); display: flex; align-items: flex-start; gap: 14px; position: relative; overflow: hidden; }');
        htp.p('.ai-sugg-card::before { content: ""; position: absolute; top: 0; left: 0; width: 4px; height: 100%; background: linear-gradient(180deg, #3b82f6, #8b5cf6); opacity: 0; transition: opacity 0.3s; }');
        htp.p('.ai-sugg-card:hover { border-color: #3b82f6; transform: translateY(-3px); box-shadow: 0 10px 30px rgba(59, 130, 246, 0.12); }');
        htp.p('.ai-sugg-card:hover::before { opacity: 1; }');
        htp.p('.ai-sugg-card:active { transform: translateY(-1px); }');
        
        -- Card Icon
        htp.p('.ai-sugg-icon { width: 42px; height: 42px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 20px; flex-shrink: 0; transition: transform 0.3s; }');
        htp.p('.ai-sugg-card:hover .ai-sugg-icon { transform: scale(1.1); }');
        htp.p('.ai-sugg-icon.blue { background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%); }');
        htp.p('.ai-sugg-icon.green { background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%); }');
        htp.p('.ai-sugg-icon.purple { background: linear-gradient(135deg, #f3e8ff 0%, #e9d5ff 100%); }');
        htp.p('.ai-sugg-icon.orange { background: linear-gradient(135deg, #ffedd5 0%, #fed7aa 100%); }');
        htp.p('.ai-sugg-icon.pink { background: linear-gradient(135deg, #fce7f3 0%, #fbcfe8 100%); }');
        htp.p('.ai-sugg-icon.teal { background: linear-gradient(135deg, #ccfbf1 0%, #99f6e4 100%); }');
        
        -- Card Content
        htp.p('.ai-sugg-content { flex: 1; min-width: 0; }');
        htp.p('.ai-sugg-text { font-size: 14px; font-weight: 500; color: #1e293b; line-height: 1.5; margin-bottom: 6px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }');
        htp.p('.ai-sugg-meta { display: flex; align-items: center; gap: 8px; }');
        htp.p('.ai-sugg-tag { font-size: 10px; font-weight: 700; padding: 3px 8px; border-radius: 5px; text-transform: uppercase; letter-spacing: 0.5px; }');
        htp.p('.ai-sugg-tag.report { background: #dbeafe; color: #1e40af; }');
        htp.p('.ai-sugg-tag.dashboard { background: #dcfce7; color: #166534; }');
        htp.p('.ai-sugg-tag.analytics { background: #f3e8ff; color: #7c3aed; }');
        htp.p('.ai-sugg-tag.trending { background: #fef3c7; color: #92400e; }');
        
        -- Arrow Icon
        htp.p('.ai-sugg-arrow { color: #cbd5e1; font-size: 18px; transition: all 0.3s; flex-shrink: 0; align-self: center; }');
        htp.p('.ai-sugg-card:hover .ai-sugg-arrow { color: #3b82f6; transform: translateX(4px); }');
        
        -- Skeleton Loading
        htp.p('.ai-sugg-skeleton { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 16px 18px; display: flex; align-items: flex-start; gap: 14px; }');
        htp.p('.ai-sugg-skeleton .skel-icon { width: 42px; height: 42px; border-radius: 12px; background: linear-gradient(90deg, #e2e8f0 25%, #f1f5f9 50%, #e2e8f0 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; }');
        htp.p('.ai-sugg-skeleton .skel-content { flex: 1; }');
        htp.p('.ai-sugg-skeleton .skel-line { height: 14px; border-radius: 4px; background: linear-gradient(90deg, #e2e8f0 25%, #f1f5f9 50%, #e2e8f0 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; margin-bottom: 8px; }');
        htp.p('.ai-sugg-skeleton .skel-line:last-child { width: 60%; margin-bottom: 0; }');
        
        -- Empty State
        htp.p('.ai-sugg-empty { text-align: center; padding: 30px 20px; background: #f8fafc; border-radius: 14px; border: 2px dashed #e2e8f0; }');
        htp.p('.ai-sugg-empty-icon { font-size: 40px; margin-bottom: 12px; opacity: 0.5; }');
        htp.p('.ai-sugg-empty-text { color: #64748b; font-size: 14px; }');
        
        -- Category Pills (Optional - for filtering)
        htp.p('.ai-sugg-categories { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }');
        htp.p('.ai-sugg-cat-pill { padding: 6px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid #e2e8f0; background: #fff; color: #64748b; transition: all 0.2s; }');
        htp.p('.ai-sugg-cat-pill:hover { border-color: #3b82f6; color: #3b82f6; }');
        htp.p('.ai-sugg-cat-pill.active { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: #fff; border-color: transparent; }');
        htp.p('.ai-shortcuts { margin-top: 16px; display: flex; gap: 12px; justify-content: center; flex-wrap: wrap; }');
        htp.p('.ai-pill { background: #fff; border: 1px solid #e5e7eb; padding: 10px 20px; border-radius: 25px; font-size: 13px; color: #4b5563; cursor: pointer; font-weight: 600; transition: all 0.2s; box-shadow: 0 2px 4px rgba(0,0,0,0.04); }');
        htp.p('.ai-pill:hover { border-color: #3b82f6; color: #3b82f6; background: #f0f9ff; transform: translateY(-2px); }');
        htp.p('.ai-pill.dashboard { border-color: #22c55e; }');
        htp.p('.ai-pill.dashboard:hover { border-color: #16a34a; color: #16a34a; background: #f0fdf4; }');

        -- Mode Toggle Styles
        htp.p('.ai-mode-toggle-bar { display: flex; gap: 0; background: #fff; border-radius: 12px; padding: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); border: 1px solid #e5e7eb; margin-bottom: 16px; width: fit-content; }');
        htp.p('.ai-mode-btn { padding: 12px 24px; border: none; background: transparent; font-size: 14px; font-weight: 600; color: #6b7280; cursor: pointer; border-radius: 8px; transition: all 0.2s; display: flex; align-items: center; gap: 8px; }');
        htp.p('.ai-mode-btn:hover { color: #374151; background: #f9fafb; }');
        htp.p('.ai-mode-btn.active { color: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.15); }');
        htp.p('.ai-mode-btn.active.report-mode { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); }');
        htp.p('.ai-mode-btn.active.dashboard-mode { background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); }');
        htp.p('.ai-auto-detect-hint { font-size: 11px; color: #9ca3af; text-align: center; margin-top: 8px; }');

        -- Modal & Other
        htp.p('.ai-modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 2000; justify-content: center; align-items: center; backdrop-filter: blur(4px); }');
        htp.p('.ai-modal { background: #fff; padding: 30px; border-radius: 16px; width: 90%; max-width: 420px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); text-align: center; }');
        htp.p('.ai-modal h3 { margin: 0 0 12px 0; color: #1f2937; font-size: 20px; font-weight: 700; }');
        htp.p('.ai-modal p { color: #6b7280; margin-bottom: 28px; font-size: 14px; line-height: 1.6; }');
        htp.p('.ai-modal-btns { display: flex; gap: 12px; justify-content: center; }');
        htp.p('.ai-btn { padding: 12px 28px; border-radius: 10px; font-size: 14px; font-weight: 600; cursor: pointer; border: none; transition: all 0.2s; }');
        htp.p('.ai-btn-cancel { background: #f3f4f6; color: #4b5563; }');
        htp.p('.ai-btn-cancel:hover { background: #e5e7eb; }');
        htp.p('.ai-btn-confirm { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); color: white; }');
        htp.p('.ai-btn-confirm:hover { background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%); }');
        htp.p('.ai-report-title-bar { background: linear-gradient(135deg, #1e40af 0%, #1d4ed8 100%); color: white; padding: 20px 30px; border-radius: 12px; margin-bottom: 20px; font-size: 22px; font-weight: 700; text-transform: uppercase; letter-spacing: 2px; text-align: left; box-shadow: 0 4px 15px rgba(30,64,175,0.3); }');
        htp.p('.ai-report-title-bar::before { content: "📊"; font-size: 22px; }');
        htp.p('.ai-welcome-text { text-align: center; margin-bottom: 35px; color: #1f2937; }');
        htp.p('.ai-welcome-text h2 { font-size: 28px; margin-bottom: 8px; font-weight: 300; letter-spacing: -0.5px; }');
        htp.p('.ai-welcome-text span { color: #3b82f6; font-weight: 700; }');
        htp.p('.ai-sql-container { background: #1e293b; border-radius: 12px; overflow: hidden; display: flex; flex-direction: column; height: 100%; flex: 1; }');
        htp.p('.ai-sql-toolbar { background: #0f172a; padding: 10px 16px; display: flex; justify-content: flex-end; }');
        htp.p('.ai-sql-run-btn { background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); color: white; border: none; padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 700; cursor: pointer; }');
        htp.p('.CodeMirror { height: 100%; flex: 1; font-family: "Fira Code", Consolas, monospace; font-size: 14px; }');
        
        htp.p('.ai-thinking { display: none; padding: 24px 30px; text-align: left; color: #4b5563; font-size: 15px; align-items: center; gap: 12px; width: 100%; }');
        htp.p('.ai-thinking-dots span { display: inline-block; width: 10px; height: 10px; background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); border-radius: 50%; animation: bounce 1.4s infinite ease-in-out both; }');
        htp.p('.ai-thinking-dots span:nth-child(1) { animation-delay: -0.32s; }');
        htp.p('.ai-thinking-dots span:nth-child(2) { animation-delay: -0.16s; }');
        htp.p('@keyframes bounce { 0%, 80%, 100% { transform: scale(0); } 40% { transform: scale(1); } }');
        htp.p('.aid-err { display: none; margin: 20px 30px; padding: 16px 20px; background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%); color: #dc2626; border: 1px solid #fecaca; border-radius: 12px; font-weight: 500; }');
        
        htp.p('.aid-loading-history { padding: 24px; text-align: center; color: #6b7a8a; }');
        htp.p('.aid-empty-history { padding: 50px 20px; text-align: center; color: #6b7a8a; }');
        htp.p('.ai-no-data { padding: 40px; text-align: center; color: #9ca3af; font-size: 15px; }');

        -- Chart Edit Modal Styles
        htp.p('.ai-chart-edit-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(15, 23, 42, 0.85); z-index: 10000; justify-content: center; align-items: center; backdrop-filter: blur(8px); }');
        htp.p('.ai-chart-edit-modal { background: #fff; border-radius: 16px; width: 95%; max-width: 900px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 25px 80px rgba(0,0,0,0.4); animation: slideUp 0.3s ease; }');
        htp.p('.ai-chart-edit-header { background: linear-gradient(135deg, #1e40af 0%, #3b82f6 100%); padding: 20px 24px; border-radius: 16px 16px 0 0; display: flex; align-items: center; justify-content: space-between; }');
        htp.p('.ai-chart-edit-title { color: #fff; font-size: 18px; font-weight: 700; display: flex; align-items: center; gap: 10px; }');
        htp.p('.ai-chart-edit-close { background: rgba(255,255,255,0.15); border: none; color: #fff; width: 36px; height: 36px; border-radius: 8px; cursor: pointer; font-size: 18px; transition: all 0.2s; }');
        htp.p('.ai-chart-edit-close:hover { background: rgba(255,255,255,0.25); }');
        htp.p('.ai-chart-edit-body { flex: 1; overflow-y: auto; padding: 24px; display: flex; flex-direction: column; gap: 20px; }');

        -- Form Group Styles
        htp.p('.ai-edit-form-group { display: flex; flex-direction: column; gap: 8px; }');
        htp.p('.ai-edit-label { font-size: 13px; font-weight: 700; color: #374151; display: flex; align-items: center; gap: 6px; }');
        htp.p('.ai-edit-label-icon { font-size: 16px; }');
        htp.p('.ai-edit-input { padding: 12px 16px; border: 2px solid #e5e7eb; border-radius: 10px; font-size: 14px; outline: none; transition: all 0.2s; }');
        htp.p('.ai-edit-input:focus { border-color: #3b82f6; box-shadow: 0 0 0 4px rgba(59,130,246,0.1); }');

        -- Chart Type Selector
        htp.p('.ai-chart-type-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 10px; max-height: 280px; overflow-y: auto; padding: 4px; }');
        htp.p('.ai-chart-type-item { padding: 14px 12px; border: 2px solid #e5e7eb; border-radius: 12px; cursor: pointer; text-align: center; transition: all 0.2s; background: #fff; }');
        htp.p('.ai-chart-type-item:hover { border-color: #3b82f6; background: #f0f9ff; transform: translateY(-2px); }');
        htp.p('.ai-chart-type-item.selected { border-color: #3b82f6; background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%); box-shadow: 0 4px 12px rgba(59,130,246,0.2); }');
        htp.p('.ai-chart-type-icon { font-size: 28px; margin-bottom: 6px; }');
        htp.p('.ai-chart-type-name { font-size: 12px; font-weight: 600; color: #374151; }');
        htp.p('.ai-chart-type-category { font-size: 10px; color: #9ca3af; margin-top: 2px; }');

        -- SQL Editor Container
        htp.p('.ai-sql-edit-container { border: 2px solid #e5e7eb; border-radius: 12px; overflow: hidden; background: #1e293b; }');
        htp.p('.ai-sql-edit-header { background: #0f172a; padding: 10px 16px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #334155; }');
        htp.p('.ai-sql-edit-label { color: #94a3b8; font-size: 12px; font-weight: 600; display: flex; align-items: center; gap: 6px; }');
        htp.p('.ai-sql-test-btn { background: #22c55e; color: #fff; border: none; padding: 6px 14px; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 4px; transition: all 0.2s; }');
        htp.p('.ai-sql-test-btn:hover { background: #16a34a; }');
        htp.p('.ai-sql-edit-area { height: 200px; }');
        htp.p('.ai-sql-edit-area .CodeMirror { height: 100%; font-size: 13px; }');

        -- Preview Area
        htp.p('.ai-chart-preview { border: 2px solid #e5e7eb; border-radius: 12px; overflow: hidden; background: #fff; }');
        htp.p('.ai-chart-preview-header { background: #f8fafc; padding: 12px 16px; border-bottom: 1px solid #e5e7eb; display: flex; align-items: center; justify-content: space-between; }');
        htp.p('.ai-chart-preview-title { font-size: 13px; font-weight: 600; color: #374151; display: flex; align-items: center; gap: 6px; }');
        htp.p('.ai-chart-preview-body { height: 250px; padding: 10px; }');
        htp.p('.ai-preview-loading { display: flex; align-items: center; justify-content: center; height: 100%; color: #9ca3af; }');
        htp.p('.ai-preview-error { padding: 20px; color: #dc2626; background: #fef2f2; border-radius: 8px; text-align: center; }');

        -- Footer
        htp.p('.ai-chart-edit-footer { padding: 16px 24px; background: #f8fafc; border-top: 1px solid #e5e7eb; display: flex; justify-content: flex-end; gap: 12px; border-radius: 0 0 16px 16px; }');
        htp.p('.ai-edit-btn { padding: 12px 24px; border-radius: 10px; font-size: 14px; font-weight: 600; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 6px; }');
        htp.p('.ai-edit-btn-cancel { background: #fff; border: 2px solid #e5e7eb; color: #64748b; }');
        htp.p('.ai-edit-btn-cancel:hover { border-color: #3b82f6; color: #3b82f6; }');
        htp.p('.ai-edit-btn-save { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); border: none; color: #fff; box-shadow: 0 4px 12px rgba(59,130,246,0.3); }');
        htp.p('.ai-edit-btn-save:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(59,130,246,0.4); }');
        htp.p('.ai-edit-btn-save:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }');
        htp.p('.ai-edit-btn-danger { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); border: none; color: #fff; box-shadow: 0 4px 12px rgba(239,68,68,0.3); }');
        htp.p('.ai-edit-btn-danger:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(239,68,68,0.4); }');

        -- Dropdown in chart header
        htp.p('.aid-dash-chart-menu { position: relative; }');
        htp.p('.aid-chart-menu-btn { background: transparent; border: 1px solid #e5e7eb; color: #6b7280; padding: 6px 10px; border-radius: 6px; cursor: pointer; font-size: 12px; transition: all 0.2s; display: flex; align-items: center; gap: 4px; }');
        htp.p('.aid-chart-menu-btn:hover { background: #f3f4f6; border-color: #3b82f6; color: #3b82f6; }');
        htp.p('.aid-chart-menu-dropdown { display: none; position: absolute; right: 0; top: 100%; margin-top: 4px; background: #fff; border: 1px solid #e5e7eb; border-radius: 8px; box-shadow: 0 10px 30px rgba(0,0,0,0.15); z-index: 100; min-width: 150px; overflow: hidden; }');
        htp.p('.aid-dash-chart-menu:hover .aid-chart-menu-dropdown { display: block; }');
        htp.p('.aid-chart-menu-item { padding: 10px 14px; font-size: 13px; color: #374151; cursor: pointer; display: flex; align-items: center; gap: 8px; transition: all 0.15s; }');
        htp.p('.aid-chart-menu-item:hover { background: #f0f9ff; color: #3b82f6; }');
        htp.p('.aid-chart-menu-item.danger:hover { background: #fef2f2; color: #dc2626; }');

        -- Pivot Table Styles
        htp.p('.ai-pivot-container { background: #fff; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); overflow: hidden; flex: 1; min-height: 400px; border: 1px solid #e5e7eb; display: flex; flex-direction: column; }');
        htp.p('.ai-pivot-toolbar { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb; background: #f8fafc; }');
        htp.p('.ai-pivot-title { font-size: 14px; font-weight: 600; color: #374151; display: flex; align-items: center; gap: 8px; }');
        htp.p('.ai-pivot-actions { display: flex; gap: 8px; }');
        htp.p('.ai-pivot-btn { padding: 8px 14px; border-radius: 8px; font-size: 12px; font-weight: 600; cursor: pointer; transition: all 0.2s; border: 1px solid #e5e7eb; background: #fff; color: #374151; display: flex; align-items: center; gap: 6px; }');
        htp.p('.ai-pivot-btn:hover { border-color: #3b82f6; color: #3b82f6; background: #f0f9ff; }');
        htp.p('.ai-pivot-btn.active { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: #fff; border-color: transparent; }');
        htp.p('.ai-pivot-content { flex: 1; min-height: 350px; }');
        htp.p('#wdr-component { height: 100% !important; }');
        htp.p('.wdr-ui { font-family: "Segoe UI", Roboto, sans-serif !important; }');
        htp.p('.ai-pivot-recommendation { background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border-radius: 10px; padding: 12px 16px; margin-bottom: 16px; display: flex; align-items: center; gap: 12px; }');
        htp.p('.ai-pivot-recommendation-icon { font-size: 24px; }');
        htp.p('.ai-pivot-recommendation-text { flex: 1; }');
        htp.p('.ai-pivot-recommendation-title { font-weight: 600; color: #92400e; font-size: 14px; }');
        htp.p('.ai-pivot-recommendation-desc { font-size: 12px; color: #a16207; margin-top: 2px; }');
        htp.p('.ai-pivot-recommendation-btn { background: #fff; border: 1px solid #d97706; color: #d97706; padding: 8px 16px; border-radius: 8px; font-size: 12px; font-weight: 600; cursor: pointer; transition: all 0.2s; }');
        htp.p('.ai-pivot-recommendation-btn:hover { background: #d97706; color: #fff; }');

        -- GridStack Customizations
        htp.p('#' || l_id || ' .grid-stack { overflow-y: visible; }');
        -- Use inner padding for consistent spacing in both directions (vertical/horizontal)
        htp.p('#' || l_id || ' .grid-stack > .grid-stack-item > .grid-stack-item-content { padding: 8px; box-sizing: border-box; background: transparent; height: 100%; }');


        htp.p('</style>');

        -- HTML STRUCTURE
        htp.p('<div id="' || l_id || '" class="apex-ai-container">');
        
        -- Confirmation Modal (Delete/Clear) - SEPARATE
        htp.p('<div id="modal_' || l_id || '" class="ai-modal-overlay">');
        htp.p('<div class="ai-modal">');
        htp.p('<h3 id="modal_title_' || l_id || '">Confirm</h3>');
        htp.p('<p id="modal_msg_' || l_id || '">Are you sure?</p>');
        htp.p('<div class="ai-modal-btns">');
        htp.p('<button type="button" class="ai-btn ai-btn-cancel" onclick="window.AID_' || l_id || '.closeModal()">Cancel</button>');
        htp.p('<button type="button" class="ai-btn ai-btn-confirm" onclick="window.AID_' || l_id || '.confirmAction()">Delete</button>');
        htp.p('</div></div></div>');

        -- =====================================================
        -- PROFESSIONAL WIZARD MODAL (Data Settings)
        -- =====================================================
        htp.p('<div id="wizard_' || l_id || '" class="ai-wizard-overlay">');
        htp.p('<div class="ai-wizard">');
        
        -- Wizard Header
        htp.p('<div class="ai-wizard-header">');
        htp.p('<div class="ai-wizard-header-content">');
        htp.p('<div class="ai-wizard-title-area">');
        htp.p('<div class="ai-wizard-icon">⚙️</div>');
        htp.p('<div>');
        htp.p('<h2 class="ai-wizard-title">Data Configuration</h2>');
        htp.p('<div class="ai-wizard-subtitle">Configure which tables AI can access and analyze</div>');
        htp.p('</div></div>');
        htp.p('<button type="button" class="ai-wizard-close" onclick="window.AID_' || l_id || '.closeWizard()">✕</button>');
        htp.p('</div></div>');
        
        -- Stepper
        htp.p('<div class="ai-wizard-stepper">');
        htp.p('<div id="wiz_step1_' || l_id || '" class="ai-wizard-step active">');
        htp.p('<div class="ai-wizard-step-num">1</div>');
        htp.p('<div class="ai-wizard-step-info">');
        htp.p('<div class="ai-wizard-step-title">Select Tables</div>');
        htp.p('<div class="ai-wizard-step-desc">Choose data sources</div>');
        htp.p('</div></div>');
        htp.p('<div id="wiz_step2_' || l_id || '" class="ai-wizard-step">');
        htp.p('<div class="ai-wizard-step-num">2</div>');
        htp.p('<div class="ai-wizard-step-info">');
        htp.p('<div class="ai-wizard-step-title">Build Metadata</div>');
        htp.p('<div class="ai-wizard-step-desc">AI analyzes structure</div>');
        htp.p('</div></div>');
        htp.p('<div id="wiz_step3_' || l_id || '" class="ai-wizard-step">');
        htp.p('<div class="ai-wizard-step-num">3</div>');
        htp.p('<div class="ai-wizard-step-info">');
        htp.p('<div class="ai-wizard-step-title">Complete</div>');
        htp.p('<div class="ai-wizard-step-desc">Ready to use</div>');
        htp.p('</div></div>');
        htp.p('<select id="wiz_domain_' || l_id || '" class="ai-domain-select" onchange="window.AID_' || l_id || '.renderWizardTables()">');
        htp.p('<option value="all">🏷️ All Domains</option>');
        htp.p('<option value="Sales">💰 Sales</option>');
        htp.p('<option value="HR">👥 HR</option>');
        htp.p('<option value="Finance">💵 Finance</option>');
        htp.p('<option value="Inventory">📦 Inventory</option>');
        htp.p('<option value="Supply Chain">🚚 Supply Chain</option>');
        htp.p('<option value="Customer">🧑‍💼 Customer</option>');
        htp.p('<option value="Marketing">📢 Marketing</option>');
        htp.p('<option value="Operations">⚙️ Operations</option>');
        htp.p('<option value="IT">💻 IT</option>');
        htp.p('<option value="Analytics">📊 Analytics</option>');
        htp.p('<option value="Master Data">🗂️ Master Data</option>');
        htp.p('<option value="Audit">📋 Audit</option>');
        htp.p('<option value="Security">🔒 Security</option>');
        htp.p('<option value="Other">📁 Other</option>');
        htp.p('</select>');
        htp.p('</div>');
        
        -- Wizard Body
        htp.p('<div class="ai-wizard-body">');
        
        -- Step 1 Content: Table Selection
        htp.p('<div id="wiz_content1_' || l_id || '" class="ai-wizard-content active">');
        htp.p('<div class="ai-table-toolbar">');
        htp.p('<div class="ai-search-box">');
        htp.p('<input type="text" id="wiz_search_' || l_id || '" placeholder="Search tables and views..." onkeyup="window.AID_' || l_id || '.filterWizardTables(this.value)">');
        htp.p('</div>');
        htp.p('<div class="ai-filter-chips">');
        htp.p('<button type="button" class="ai-filter-chip active" data-filter="all" onclick="window.AID_' || l_id || '.setWizardFilter(''all'', this)">All</button>');
        htp.p('<button type="button" class="ai-filter-chip" data-filter="TABLE" onclick="window.AID_' || l_id || '.setWizardFilter(''TABLE'', this)">Tables</button>');
        htp.p('<button type="button" class="ai-filter-chip" data-filter="VIEW" onclick="window.AID_' || l_id || '.setWizardFilter(''VIEW'', this)">Views</button>');
        htp.p('<button type="button" class="ai-filter-chip" data-filter="selected" onclick="window.AID_' || l_id || '.setWizardFilter(''selected'', this)">Selected</button>');
        htp.p('</div>');
        htp.p('<div id="wiz_selection_info_' || l_id || '" class="ai-selection-info">');
        htp.p('<span>📊 <strong id="wiz_count_' || l_id || '">0</strong> tables selected</span>');
        htp.p('<div class="ai-select-actions">');
        htp.p('<button type="button" class="ai-select-btn ai-select-all" onclick="window.AID_' || l_id || '.selectAllTables()">Select All</button>');
        htp.p('<button type="button" class="ai-select-btn ai-select-none" onclick="window.AID_' || l_id || '.selectNoneTables()">Clear</button>');
        htp.p('</div></div></div>');
        htp.p('<div id="wiz_table_list_' || l_id || '" class="ai-table-list-container">');
        htp.p('<div class="ai-table-grid" id="wiz_grid_' || l_id || '"></div>');
        htp.p('</div></div>');
        
        -- Step 2 Content: Building Metadata
        htp.p('<div id="wiz_content2_' || l_id || '" class="ai-wizard-content">');
        htp.p('<div class="ai-build-container">');
        htp.p('<div class="ai-build-animation">');
        htp.p('<div class="ai-build-circle"></div>');
        htp.p('<div class="ai-build-circle spinning"></div>');
        htp.p('<div class="ai-build-icon">🤖</div>');
        htp.p('</div>');
        htp.p('<h3 class="ai-build-title">Building AI Knowledge Base</h3>');
        htp.p('<p class="ai-build-subtitle">AI is analyzing your table structures, relationships, and data patterns to provide intelligent insights.</p>');
        htp.p('<div class="ai-progress-container">');
        htp.p('<div class="ai-progress-bar"><div id="wiz_progress_' || l_id || '" class="ai-progress-fill" style="width: 0%"></div></div>');
        htp.p('<div class="ai-progress-text">');
        htp.p('<span id="wiz_progress_status_' || l_id || '">Initializing...</span>');
        htp.p('<span id="wiz_progress_pct_' || l_id || '" class="ai-progress-percent">0%</span>');
        htp.p('</div></div>');
        htp.p('<div id="wiz_log_' || l_id || '" class="ai-build-log"></div>');
        htp.p('</div></div>');
        
        -- Step 3 Content: Complete
        htp.p('<div id="wiz_content3_' || l_id || '" class="ai-wizard-content">');
        htp.p('<div class="ai-complete-container">');
        htp.p('<div class="ai-complete-icon">✓</div>');
        htp.p('<h3 class="ai-complete-title">Configuration Complete!</h3>');
        htp.p('<p class="ai-complete-subtitle">Your AI assistant is now ready to analyze your data and provide intelligent insights.</p>');
        htp.p('<div class="ai-complete-stats">');
        htp.p('<div class="ai-complete-stat"><div id="wiz_stat_tables_' || l_id || '" class="ai-complete-stat-value">0</div><div class="ai-complete-stat-label">Tables Configured</div></div>');
        htp.p('<div class="ai-complete-stat"><div id="wiz_stat_cols_' || l_id || '" class="ai-complete-stat-value">0</div><div class="ai-complete-stat-label">Columns Analyzed</div></div>');
        htp.p('<div class="ai-complete-stat"><div id="wiz_stat_ai_' || l_id || '" class="ai-complete-stat-value">0</div><div class="ai-complete-stat-label">AI Descriptions</div></div>');
        htp.p('</div></div></div>');
        
        htp.p('</div>'); -- End wizard body
        
        -- Wizard Footer
        htp.p('<div class="ai-wizard-footer">');
        htp.p('<button type="button" id="wiz_back_' || l_id || '" class="ai-wizard-btn ai-wizard-btn-secondary" onclick="window.AID_' || l_id || '.wizardBack()" style="visibility:hidden;">← Back</button>');
        htp.p('<button type="button" id="wiz_next_' || l_id || '" class="ai-wizard-btn ai-wizard-btn-primary" onclick="window.AID_' || l_id || '.wizardNext()">Continue →</button>');
        htp.p('</div>');
        
        htp.p('</div></div>'); -- End wizard
        -- =====================================================
        -- END WIZARD MODAL
        -- =====================================================

        -- SIDEBAR
        htp.p('<div id="sidebar_' || l_id || '" class="aid-sidebar">');
        htp.p('<div class="aid-sidebar-header">');
        htp.p('<span class="aid-sidebar-title">💬 Chat History</span>');
        htp.p('<button type="button" class="aid-new-chat-btn" onclick="window.AID_' || l_id || '.newChat()">+ New</button>');
        htp.p('</div>');
        htp.p('<div class="aid-search-box">');
        htp.p('<input type="text" id="search_history_' || l_id || '" class="aid-search-input" placeholder="Search conversations..." onkeyup="window.AID_' || l_id || '.searchHistory(this.value)">');
        htp.p('</div>');
        htp.p('<div class="aid-tabs-container">');
        htp.p('<button type="button" id="tab_all_' || l_id || '" class="aid-hist-tab active" onclick="window.AID_' || l_id || '.setHistoryFilter(''all'')">All Chats</button>');
        htp.p('<button type="button" id="tab_fav_' || l_id || '" class="aid-hist-tab" onclick="window.AID_' || l_id || '.setHistoryFilter(''fav'')">Favorites ★</button>');
        htp.p('</div>');
        htp.p('<div id="chat_list_' || l_id || '" class="aid-chat-list"><div class="aid-loading-history">Loading...</div></div>');
        htp.p('<div class="aid-sidebar-footer">');
        htp.p('<button type="button" class="aid-settings-btn" onclick="window.AID_' || l_id || '.openWizard()">⚙ Data Settings</button>');
        htp.p('<button type="button" class="aid-clear-btn" onclick="window.AID_' || l_id || '.clearHistory()">🗑️ Clear All History</button>');
        htp.p('</div></div>');
        
        -- Toggle
        htp.p('<button type="button" id="toggle_' || l_id || '" class="aid-sidebar-toggle" onclick="window.AID_' || l_id || '.toggleSidebar()">');
        htp.p('<span id="toggle_icon_' || l_id || '">◀</span></button>');
        
        -- MAIN CONTENT
        htp.p('<div class="aid-main-content">');
        
        -- Error div
        htp.p('<div id="err_' || l_id || '" class="aid-err"></div>');

        -- Report Skeleton Container
        htp.p('<div id="skeleton_report_' || l_id || '" class="aid-skeleton-container">');
        htp.p('<div class="skel-report-title skeleton"></div>');
        htp.p('<div class="skel-kpis-row">');
        FOR i IN 1..4 LOOP
            htp.p('<div class="skel-kpi-card"><div class="skel-kpi-header skeleton"></div><div class="skel-kpi-body"><div class="skel-kpi-value skeleton"></div><div class="skel-kpi-icon skeleton"></div></div></div>');
        END LOOP;
        htp.p('</div>');
        htp.p('<div class="skel-tabs"><div class="skel-tab skeleton"></div><div class="skel-tab skeleton"></div><div class="skel-tab skeleton"></div></div>');
        htp.p('<div class="skel-table-container"><div class="skel-table-toolbar"><div class="skel-search skeleton"></div><div class="skel-export-btn skeleton"></div></div><div class="skel-table-header skeleton"></div>');
        FOR i IN 1..6 LOOP
            htp.p('<div class="skel-table-row"><div class="skel-table-cell skeleton"></div><div class="skel-table-cell skeleton"></div><div class="skel-table-cell skeleton"></div><div class="skel-table-cell skeleton"></div></div>');
        END LOOP;
        htp.p('</div></div>');
        
        -- Dashboard Skeleton Container
        htp.p('<div id="skeleton_dashboard_' || l_id || '" class="aid-skeleton-container">');
        htp.p('<div class="skel-dash-title skeleton"></div>');
        htp.p('<div class="skel-dash-kpis">');
        FOR i IN 1..4 LOOP
            htp.p('<div class="skel-dash-kpi"><div class="skel-dash-kpi-header skeleton"></div><div class="skel-dash-kpi-body"><div class="skel-dash-kpi-main"><div class="skel-dash-kpi-value skeleton"></div><div class="skel-dash-kpi-trend skeleton"></div></div><div class="skel-dash-kpi-icon skeleton"></div></div></div>');
        END LOOP;
        htp.p('</div>');
        htp.p('<div class="skel-dash-charts">');
        htp.p('<div class="skel-dash-chart colspan-2"><div class="skel-dash-chart-header"><div class="skel-dash-chart-title skeleton"></div></div><div class="skel-dash-chart-body">');
        FOR i IN 1..6 LOOP htp.p('<div class="skel-bar skeleton"></div>'); END LOOP;
        htp.p('</div></div>');
        htp.p('<div class="skel-dash-chart"><div class="skel-dash-chart-header"><div class="skel-dash-chart-title skeleton"></div></div><div class="skel-pie-container"><div class="skel-pie skeleton"></div></div></div>');
        htp.p('<div class="skel-dash-chart"><div class="skel-dash-chart-header"><div class="skel-dash-chart-title skeleton"></div></div><div class="skel-line-container">');
        FOR i IN 1..4 LOOP htp.p('<div class="skel-line skeleton"></div>'); END LOOP;
        htp.p('</div></div>');
        htp.p('<div class="skel-dash-chart"><div class="skel-dash-chart-header"><div class="skel-dash-chart-title skeleton"></div></div><div class="skel-dash-chart-body">');
        FOR i IN 1..5 LOOP htp.p('<div class="skel-bar skeleton"></div>'); END LOOP;
        htp.p('</div></div>');
        htp.p('<div class="skel-dash-chart"><div class="skel-dash-chart-header"><div class="skel-dash-chart-title skeleton"></div></div><div class="skel-pie-container"><div class="skel-pie skeleton"></div></div></div>');
        htp.p('</div></div>');

        -- Dashboard View Container
        htp.p('<div id="dashboard_view_' || l_id || '" class="aid-dashboard-view">');
        htp.p('<div class="aid-dash-toolbar">');
        htp.p('</div>');
        htp.p('<div id="dash_title_' || l_id || '" class="aid-dash-title"></div>');
        htp.p('<div id="dash_kpis_' || l_id || '" class="aid-dash-kpis"></div>');
        htp.p('<div id="dash_charts_' || l_id || '" class="aid-dash-charts grid-stack"></div>');
        htp.p('</div>');
        
        -- Report View Container
        htp.p('<div id="report_view_' || l_id || '" class="aid-report-view">');
        htp.p('<div id="res_area_' || l_id || '" class="aid-results-area">');
        htp.p('<div id="content_wrapper_' || l_id || '" class="ai-flex-col" style="display:none;">');
        htp.p('<div id="report_title_' || l_id || '" class="ai-report-title-bar" style="display:none"></div>');
        htp.p('<div id="kpis_' || l_id || '" class="aid-kpis"></div>');
        htp.p('<div class="ai-tabs" id="tabs_' || l_id || '">');
        htp.p('<button type="button" class="ai-tab-btn active" onclick="window.AID_' || l_id || '.switchTab(''report'')">📋 Report</button>');
        htp.p('<button type="button" class="ai-tab-btn" onclick="window.AID_' || l_id || '.switchTab(''pivot'')">🔄 Pivot</button>');
        htp.p('<button type="button" class="ai-tab-btn" onclick="window.AID_' || l_id || '.switchTab(''chart'')">📈 Chart</button>');
        htp.p('<button type="button" class="ai-tab-btn" onclick="window.AID_' || l_id || '.switchTab(''sql'')">💻 SQL</button>');
        htp.p('</div>');
        htp.p('<div id="view_report_' || l_id || '" class="ai-view-content active"><div id="dyn_content_' || l_id || '" class="ai-flex-col"></div></div>');
        htp.p('<div id="view_pivot_' || l_id || '" class="ai-view-content">');
        htp.p('<div id="pivot_recommendation_' || l_id || '" class="ai-pivot-recommendation" style="display:none;">');
        htp.p('<div class="ai-pivot-recommendation-icon">💡</div>');
        htp.p('<div class="ai-pivot-recommendation-text">');
        htp.p('<div class="ai-pivot-recommendation-title">AI Recommendation</div>');
        htp.p('<div id="pivot_reason_' || l_id || '" class="ai-pivot-recommendation-desc"></div>');
        htp.p('</div>');
        htp.p('<button type="button" class="ai-pivot-recommendation-btn" onclick="window.AID_' || l_id || '.applyPivotConfig()">Apply Suggested Config</button>');
        htp.p('</div>');
        htp.p('<div class="ai-pivot-container">');
        htp.p('<div class="ai-pivot-toolbar">');
        htp.p('<div class="ai-pivot-title">🔄 Pivot Analysis</div>');
        htp.p('<div class="ai-pivot-actions">');
        htp.p('<button type="button" class="ai-pivot-btn" onclick="window.AID_' || l_id || '.pivotExpandAll()">➕ Expand All</button>');
        htp.p('<button type="button" class="ai-pivot-btn" onclick="window.AID_' || l_id || '.pivotCollapseAll()">➖ Collapse All</button>');
        htp.p('<button type="button" class="ai-pivot-btn" onclick="window.AID_' || l_id || '.pivotExport(''excel'')">📊 Excel</button>');
        htp.p('<button type="button" class="ai-pivot-btn" onclick="window.AID_' || l_id || '.pivotExport(''pdf'')">📄 PDF</button>');
        htp.p('</div></div>');
        htp.p('<div id="pivot_container_' || l_id || '" class="ai-pivot-content"></div>');
        htp.p('</div></div>');
        htp.p('<div id="view_chart_' || l_id || '" class="ai-view-content ai-chart-view-wrapper">');
        htp.p('<div class="ai-chart-main-area"><div id="chart_container_' || l_id || '"></div></div>');
        htp.p('<div class="ai-chart-type-panel">');
        htp.p('<div class="ai-chart-type-panel-header"><h3>Chart Types</h3><span>Select a visualization</span></div>');
        htp.p('<div id="report_chart_types_' || l_id || '" class="ai-report-chart-types"></div>');
        htp.p('</div></div>');
        htp.p('<div id="view_sql_' || l_id || '" class="ai-view-content">');
        htp.p('<div class="ai-sql-container">');
        htp.p('<div class="ai-sql-toolbar"><button type="button" class="ai-sql-run-btn" onclick="window.AID_' || l_id || '.runSql()">▶ Run & Save Query</button></div>');
        htp.p('<textarea id="sql_editor_' || l_id || '"></textarea>');
        htp.p('</div></div></div></div></div>');

        -- Interaction Container
        htp.p('<div id="interaction_' || l_id || '" class="ai-interaction-container centered">');
        htp.p('<div id="welcome_' || l_id || '" class="ai-welcome-text">');
        htp.p('<h2>Hi <span>' || apex_escape.html(apex_application.g_user) || '</span>, how can I help you?</h2>');
        htp.p('</div>');
        htp.p('<div id="suggestions_' || l_id || '" class="ai-suggestions-container"></div>');
        
        htp.p('<div class="ai-mode-toggle-bar">');
        htp.p('<button type="button" id="mode_report_' || l_id || '" class="ai-mode-btn report-mode active" onclick="window.AID_' || l_id || '.setMode(''report'')">');
        htp.p('<span>📊</span> Report</button>');
        htp.p('<button type="button" id="mode_dashboard_' || l_id || '" class="ai-mode-btn dashboard-mode" onclick="window.AID_' || l_id || '.setMode(''dashboard'')">');
        htp.p('<span>📈</span> Dashboard</button>');
        htp.p('</div>');
        
        htp.p('<div class="ai-search-wrapper">');
        htp.p('<div id="active_cat_' || l_id || '" class="ai-active-cat-chip">');
        htp.p('<span id="cat_text_' || l_id || '">General</span>');
        htp.p('<span class="ai-cat-remove" onclick="window.AID_' || l_id || '.clearCat()">✕</span>');
        htp.p('</div>');
        htp.p('<textarea id="inp_' || l_id || '" class="ai-input" rows="1" placeholder="Ask anything about your data..."></textarea>');
        htp.p('<button type="button" class="ai-send-btn" onclick="window.AID_' || l_id || '.go()">');
        htp.p('<svg viewBox="0 0 24 24" style="width:20px;height:20px;fill:white;"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>');
        htp.p('</button></div>');
        
        htp.p('<div class="ai-auto-detect-hint">💡 AI auto-detects intent. Keywords: dashboard, executive, overview, KPI → Dashboard mode</div>');
        htp.p('</div>');
        
        htp.p('</div></div>');


                -- Chart Edit Modal
        htp.p('<div id="chart_edit_' || l_id || '" class="ai-chart-edit-overlay">');
        htp.p('<div class="ai-chart-edit-modal">');
        htp.p('<div class="ai-chart-edit-header">');
        htp.p('<div class="ai-chart-edit-title"><span>✏️</span> Edit Chart</div>');
        htp.p('<button type="button" class="ai-chart-edit-close" onclick="window.AID_' || l_id || '.closeChartEdit()">✕</button>');
        htp.p('</div>');
        htp.p('<div class="ai-chart-edit-body">');

        -- Title Input
        htp.p('<div class="ai-edit-form-group">');
        htp.p('<label class="ai-edit-label"><span class="ai-edit-label-icon">📝</span> Chart Title</label>');
        htp.p('<input type="text" id="chart_edit_title_' || l_id || '" class="ai-edit-input" placeholder="Enter chart title...">');
        htp.p('</div>');

        -- Chart Type Selector
        htp.p('<div class="ai-edit-form-group">');
        htp.p('<label class="ai-edit-label"><span class="ai-edit-label-icon">📊</span> Chart Type</label>');
        htp.p('<div id="chart_type_grid_' || l_id || '" class="ai-chart-type-grid"></div>');
        htp.p('</div>');

        -- SQL Editor
        htp.p('<div class="ai-edit-form-group">');
        htp.p('<label class="ai-edit-label"><span class="ai-edit-label-icon">💻</span> SQL Query</label>');
        htp.p('<div class="ai-sql-edit-container">');
        htp.p('<div class="ai-sql-edit-header">');
        htp.p('<span class="ai-sql-edit-label">🔧 Oracle SQL</span>');
        htp.p('<button type="button" class="ai-sql-test-btn" onclick="window.AID_' || l_id || '.testChartSql()">▶ Test Query</button>');
        htp.p('</div>');
        htp.p('<div class="ai-sql-edit-area"><textarea id="chart_sql_editor_' || l_id || '"></textarea></div>');
        htp.p('</div></div>');

        -- Preview
        htp.p('<div class="ai-edit-form-group">');
        htp.p('<label class="ai-edit-label"><span class="ai-edit-label-icon">👁️</span> Preview</label>');
        htp.p('<div class="ai-chart-preview">');
        htp.p('<div class="ai-chart-preview-header">');
        htp.p('<span class="ai-chart-preview-title">📈 Chart Preview</span>');
        htp.p('</div>');
        htp.p('<div id="chart_preview_' || l_id || '" class="ai-chart-preview-body">');
        htp.p('<div class="ai-preview-loading">Click "Test Query" to preview</div>');
        htp.p('</div></div></div>');

        htp.p('</div>'); -- End body

        -- Footer
        htp.p('<div class="ai-chart-edit-footer">');
        htp.p('<button type="button" class="ai-edit-btn ai-edit-btn-cancel" onclick="window.AID_' || l_id || '.closeChartEdit()">Cancel</button>');
        htp.p('<button type="button" id="chart_delete_btn_' || l_id || '" class="ai-edit-btn ai-edit-btn-danger" onclick="window.AID_' || l_id || '.deleteChart()">🗑 Delete Chart</button>');
        htp.p('<button type="button" id="chart_save_btn_' || l_id || '" class="ai-edit-btn ai-edit-btn-save" onclick="window.AID_' || l_id || '.saveChartEdit()">💾 Save Changes</button>');
        htp.p('</div>');

        -- Close Chart Edit Modal
        htp.p('</div></div>');


        -- JAVASCRIPT
        DBMS_LOB.CREATETEMPORARY(l_js, TRUE);
        
        -- Part 1: Core setup and wizard functions
        DBMS_LOB.APPEND(l_js, 'window.AID_' || l_id || ' = {
            id: "' || l_id || '",
            ajax: "' || l_ajax || '",
            currentCategory: "General",
            echartsInstance: null,
            dashboardCharts: {},
            grid: null,
            currentQueryId: null,
            cmEditor: null,
            chatHistory: [],
            historyFilter: "all",
            searchTimeout: null,
            pendingAction: null,
            kpiColors: ["kpi-green","kpi-orange","kpi-purple","kpi-red","kpi-blue","kpi-teal"],
            kpiIcons: ["💰","👥","✅","⚠️","📊","🎯"],
            colors: ["#3b82f6","#22c55e","#f97316","#a855f7","#ef4444","#14b8a6","#f59e0b","#6366f1"],
            iconMap: {"briefcase":"💼","dollar":"💲","users":"👥","check":"✅","warning":"⚠️","star":"⭐","calculator":"🧮","bullseye":"🎯","rocket":"🚀"},
            // Pivot Table Properties
            pivotInstance: null,
            pivotData: null,
            pivotConfig: null,
            pivotRecommended: false,
            pivotInitialized: false,
            
            // Chart Edit Properties
            chartEditIndex: null,
            chartEditData: null,
            chartEditEditor: null,
            chartPreviewInstance: null,
            availableChartTypes: [],
            currentDashboardCharts: [],
            layoutSaveTimer: null,
            layoutInitializing: false,
                
            // ===============================
            // WIZARD STATE & FUNCTIONS
            // ===============================
            wizardStep: 1,
            wizardTables: [],
            wizardFilter: "all",
            wizardSelected: new Set(),

            openWizard: function() {
                var $=apex.jQuery, self=this;
                this.wizardStep = 1;
                this.wizardSelected = new Set();
                this.updateWizardUI();
                $("#wizard_"+this.id).css("display","flex");
                this.loadWizardTables();
            },

            closeWizard: function() {
                apex.jQuery("#wizard_"+this.id).hide();
            },

            updateWizardUI: function() {
                var $=apex.jQuery, self=this;
                // Update stepper
                for(var i=1; i<=3; i++) {
                    var step = $("#wiz_step"+i+"_"+this.id);
                    var content = $("#wiz_content"+i+"_"+this.id);
                    step.removeClass("active completed");
                    content.removeClass("active");
                    if(i < this.wizardStep) step.addClass("completed");
                    else if(i === this.wizardStep) step.addClass("active");
                    if(i === this.wizardStep) content.addClass("active");
                }
                // Update buttons
                var backBtn = $("#wiz_back_"+this.id);
                var nextBtn = $("#wiz_next_"+this.id);
                backBtn.css("visibility", this.wizardStep > 1 ? "visible" : "hidden");
                if(this.wizardStep === 1) {
                    nextBtn.text("Continue →").removeClass("ai-wizard-btn-success").addClass("ai-wizard-btn-primary").prop("disabled", false);
                } else if(this.wizardStep === 2) {
                    nextBtn.text("Building...").prop("disabled", true);
                } else if(this.wizardStep === 3) {
                    nextBtn.text("Finish ✓").removeClass("ai-wizard-btn-primary").addClass("ai-wizard-btn-success").prop("disabled", false);
                }
            },

            wizardBack: function() {
                if(this.wizardStep > 1) {
                    this.wizardStep--;
                    this.updateWizardUI();
                }
            },

            wizardNext: function() {
                var self = this;
                if(this.wizardStep === 1) {
                    if(this.wizardSelected.size === 0) {
                        alert("Please select at least one table.");
                        return;
                    }
                    this.wizardStep = 2;
                    this.updateWizardUI();
                    this.startBuildMetadata();
                } else if(this.wizardStep === 3) {
                    this.closeWizard();
                    this.loadSuggestions();
                }
            },

            loadWizardTables: function() {
                var $=apex.jQuery, self=this;
                var grid = $("#wiz_grid_"+this.id);
                grid.html(this.getTableSkeletons(8));
                
                apex.server.plugin(self.ajax, { x01:"CAT_LIST" }, {
                    success: function(r){
                        if(!r || r.status!=="success") {
                            grid.html("<div class=''ai-empty-state''><div class=''ai-empty-state-icon''>📭</div><div class=''ai-empty-state-title''>No tables found</div><div class=''ai-empty-state-desc''>No tables available in the catalog</div></div>");
                            return;
                        }
                        self.wizardTables = (r.tables && Array.isArray(r.tables)) ? r.tables : [];
                        // Pre-select whitelisted tables
                        self.wizardTables.forEach(function(t) {
                            if(t.is_whitelisted === "Y") self.wizardSelected.add(t.object_name);
                        });
                        self.renderWizardTables();
                    },
                    error: function(){
                        grid.html("<div class=''ai-empty-state''><div class=''ai-empty-state-icon''>⚠️</div><div class=''ai-empty-state-title''>Error loading tables</div></div>");
                    }
                });
            },

            getTableSkeletons: function(count) {
                var html = "";
                for(var i=0; i<count; i++) {
                    html += "<div class=''ai-table-skeleton''><div class=''ai-skeleton-line'' style=''width:60%;height:20px;margin-bottom:12px''></div><div class=''ai-skeleton-line'' style=''width:40%;height:14px;margin-bottom:8px''></div><div class=''ai-skeleton-line'' style=''width:80%;height:12px''></div></div>";
                }
                return html;
            },

             renderWizardTables: function() {
                var $=apex.jQuery, self=this;
                var grid = $("#wiz_grid_"+this.id);
                var search = ($("#wiz_search_"+this.id).val() || "").toLowerCase();
                var domainFilter = ($("#wiz_domain_"+this.id).val() || "all");
                
                var filtered = this.wizardTables.filter(function(t) {
                    var matchSearch = !search || 
                        t.object_name.toLowerCase().indexOf(search) > -1 ||
                        (t.summary_en && t.summary_en.toLowerCase().indexOf(search) > -1);
                    var matchType = self.wizardFilter === "all" || 
                                    (self.wizardFilter === "selected" && self.wizardSelected.has(t.object_name)) ||
                                    t.object_type === self.wizardFilter;
                    var matchDomain = domainFilter === "all" || 
                                      (t.business_domain && t.business_domain === domainFilter);
                    return matchSearch && matchType && matchDomain;
                });

                // Sort by relevance score descending
                filtered.sort(function(a, b) {
                    var scoreA = a.relevance_score || 0;
                    var scoreB = b.relevance_score || 0;
                    if(scoreB !== scoreA) return scoreB - scoreA;
                    return a.object_name.localeCompare(b.object_name);
                });

                if(filtered.length === 0) {
                    grid.html("<div class=''ai-empty-state''><div class=''ai-empty-state-icon''>🔍</div><div class=''ai-empty-state-title''>No tables found</div><div class=''ai-empty-state-desc''>Try adjusting your search or filters</div></div>");
                    return;
                }

                var html = "";
                filtered.forEach(function(t) {
                    var isSelected = self.wizardSelected.has(t.object_name);
                    var selectedClass = isSelected ? " selected" : "";
                    var typeClass = (t.object_type === "VIEW") ? "view" : "table";
                    var typeIcon = (t.object_type === "VIEW") ? "👁️" : "📋";
                    var hasAi = (t.summary_en && String(t.summary_en).trim().length > 0);
                    var desc = hasAi ? String(t.summary_en) : (t.table_comment ? String(t.table_comment) : "No description available");
                    var badge = hasAi ? "<span class=''ai-table-card-badge ai''>✨ AI</span>" : "<span class=''ai-table-card-badge db''>DB</span>";
                    
                    // Domain Badge
                    var domainBadge = "";
                    if(t.business_domain) {
                        var domainClass = t.business_domain.toLowerCase().replace(/\s+/g, "-");
                        domainBadge = "<span class=''ai-table-card-domain "+domainClass+"''>"+self.escapeHtml(t.business_domain)+"</span>";
                    }
                    
                    // Relevance Score
                    var scoreHtml = "";
                    if(t.relevance_score !== null && t.relevance_score !== undefined) {
                        var score = parseInt(t.relevance_score) || 0;
                        var scoreClass = score >= 70 ? "high" : (score >= 40 ? "medium" : "low");
                        scoreHtml = "<div class=''ai-table-card-score''>";
                        scoreHtml += "<span class=''ai-table-card-score-label''>Relevance:</span>";
                        scoreHtml += "<div class=''ai-table-card-score-bar''><div class=''ai-table-card-score-fill "+scoreClass+"'' style=''width:"+score+"%''></div></div>";
                        scoreHtml += "<span class=''ai-table-card-score-val''>"+score+"%</span>";
                        scoreHtml += "</div>";
                    }
                    
                    // Row Count
                    var rowsHtml = "";
                    if(t.num_rows && t.num_rows > 0) {
                        var rc = parseInt(t.num_rows);
                        var rcFmt = rc >= 1000000 ? (rc/1000000).toFixed(1)+"M" : (rc >= 1000 ? (rc/1000).toFixed(1)+"K" : rc);
                        rowsHtml = "<div class=''ai-table-card-rows''>📊 "+rcFmt+" rows</div>";
                    }
                    
                    html += "<div class=''ai-table-card"+selectedClass+"'' data-name=''"+self.escapeHtml(t.object_name)+"'' data-type=''"+t.object_type+"'' onclick=''window.AID_"+self.id+".toggleTableSelection(this)''>";
                    html += "<div class=''ai-table-card-header''>";
                    html += "<div class=''ai-table-card-icon "+typeClass+"''>"+typeIcon+"</div>";
                    html += "<div class=''ai-table-card-info''>";
                    html += "<div class=''ai-table-card-name''>"+self.escapeHtml(t.object_name)+"</div>";
                    html += "<div style=''display:flex;flex-wrap:wrap;gap:4px;align-items:center;''>";
                    html += "<span class=''ai-table-card-type "+typeClass+"''>"+t.object_type+"</span>";
                    html += badge;
                    html += domainBadge;
                    html += "</div>";
                    html += "</div></div>";
                    html += "<div class=''ai-table-card-desc''>"+self.escapeHtml(desc)+"</div>";
                    html += rowsHtml;
                    html += scoreHtml;
                    html += "</div>";
                });

                grid.html(html);
                this.updateSelectionCount();
            },

            toggleTableSelection: function(el) {
                var $=apex.jQuery;
                var name = $(el).attr("data-name");
                if(this.wizardSelected.has(name)) {
                    this.wizardSelected.delete(name);
                    $(el).removeClass("selected");
                } else {
                    this.wizardSelected.add(name);
                    $(el).addClass("selected");
                }
                this.updateSelectionCount();
            },

            updateSelectionCount: function() {
                apex.jQuery("#wiz_count_"+this.id).text(this.wizardSelected.size);
            },

            selectAllTables: function() {
                var self = this;
                this.wizardTables.forEach(function(t) {
                    self.wizardSelected.add(t.object_name);
                });
                this.renderWizardTables();
            },

            selectNoneTables: function() {
                this.wizardSelected.clear();
                this.renderWizardTables();
            },

            filterWizardTables: function(val) {
                var self = this;
                clearTimeout(this.searchTimeout);
                this.searchTimeout = setTimeout(function() {
                    self.renderWizardTables();
                }, 200);
            },

            setWizardFilter: function(f, btn) {
                var $=apex.jQuery;
                this.wizardFilter = f;
                $(".ai-filter-chip").removeClass("active");
                $(btn).addClass("active");
                this.renderWizardTables();
            },

            startBuildMetadata: function() {
                var $=apex.jQuery, self=this;
                var log = $("#wiz_log_"+this.id);
                var progress = $("#wiz_progress_"+this.id);
                var status = $("#wiz_progress_status_"+this.id);
                var pct = $("#wiz_progress_pct_"+this.id);
                
                log.empty();
                progress.css("width", "0%");
                this.addLog("🚀 Starting configuration...", "info");

                var selected = Array.from(this.wizardSelected);
                var payload = {
                    selected: selected,
                    only_missing: "Y",
                    max_tables: 50,
                    force: "N"
                };

                // Simulate progress stages
                var stages = [
                    { pct: 10, msg: "Applying whitelist settings...", status: "Applying settings" },
                    { pct: 30, msg: "Refreshing catalog metadata...", status: "Refreshing catalog" },
                    { pct: 50, msg: "Analyzing table structures...", status: "Analyzing structures" },
                    { pct: 70, msg: "🤖 AI is generating descriptions...", status: "AI generating" },
                    { pct: 90, msg: "Finalizing configuration...", status: "Finalizing" }
                ];

                var stageIdx = 0;
                var stageInterval = setInterval(function() {
                    if(stageIdx < stages.length) {
                        var s = stages[stageIdx];
                        progress.css("width", s.pct+"%");
                        pct.text(s.pct+"%");
                        status.text(s.status);
                        self.addLog(s.msg, "info");
                        stageIdx++;
                    }
                }, 800);

                apex.server.plugin(self.ajax, { x01:"CAT_APPLY", x03: JSON.stringify(payload) }, {
                    success: function(r) {
                        clearInterval(stageInterval);
                        progress.css("width", "100%");
                        pct.text("100%");
                        
                        if(!r || r.status!=="success") {
                            var msg = (r && r.message) ? r.message : "Configuration failed";
                            self.addLog("❌ Error: "+msg, "error");
                            status.text("Error occurred");
                            $("#wiz_next_"+self.id).text("Retry").prop("disabled", false);
                            return;
                        }

                        self.addLog("✅ Configuration completed successfully!", "success");
                        status.text("Complete!");
                        
                        // Update stats
                        $("#wiz_stat_tables_"+self.id).text(selected.length);
                        var colCount = r.ai && r.ai.columns_count ? r.ai.columns_count : Math.floor(selected.length * 8);
                        var aiCount = r.ai && r.ai.ai_count ? r.ai.ai_count : selected.length;
                        $("#wiz_stat_cols_"+self.id).text(colCount);
                        $("#wiz_stat_ai_"+self.id).text(aiCount);

                        setTimeout(function() {
                            self.wizardStep = 3;
                            self.updateWizardUI();
                        }, 1000);
                    },
                    error: function(x,s,e) {
                        clearInterval(stageInterval);
                        self.addLog("❌ Error: "+e, "error");
                        status.text("Error occurred");
                        $("#wiz_next_"+self.id).text("Retry").prop("disabled", false);
                    }
                });
            },

            addLog: function(msg, type) {
                var $=apex.jQuery;
                var log = $("#wiz_log_"+this.id);
                var time = new Date().toLocaleTimeString();
                var typeClass = type ? " "+type : "";
                log.append("<div class=''ai-log-line"+typeClass+"''><span class=''ai-log-time''>["+time+"]</span><span>"+this.escapeHtml(msg)+"</span></div>");
                log.scrollTop(log[0].scrollHeight);
            },

            // ===============================
            // END WIZARD FUNCTIONS
            // ===============================

            init: function() {
                var self = this;
                var ta = document.getElementById("inp_"+this.id);
                ta.addEventListener("input", function() {
                    this.style.height = "auto";
                    this.style.height = (this.scrollHeight) + "px";
                    if(this.value === "") this.style.height = "auto";
                });
                ta.addEventListener("keydown", function(e) {
                    if(e.which === 13 && !e.shiftKey) { e.preventDefault(); self.go(); }
                });
                this.currentCategory = "Report Builder";
                this.loadHistory();
                this.loadSuggestions();
            },
            
            getIconEmoji: function(n) { 
                if(!n) return null; 
                var k=n.toString().toLowerCase().replace(/^fa[srldb]?\s+fa-/,"").replace(/^fa-/,"").replace(/-/g,""); 
                return this.iconMap[k] ? this.iconMap[k] : null; 
            },
            escapeHtml: function(t) { if(!t) return ""; var d=document.createElement("div"); d.textContent=t; return d.innerHTML; },
            
            setHistoryFilter: function(f) { var $=apex.jQuery; this.historyFilter=f; $(".aid-hist-tab").removeClass("active"); $("#tab_"+f+"_"+this.id).addClass("active"); this.renderHistory(); },
            showModal: function(t,m,c) { var $=apex.jQuery; $("#modal_title_"+this.id).text(t); $("#modal_msg_"+this.id).text(m); this.pendingAction=c; $("#modal_"+this.id).css("display","flex"); },
            closeModal: function() { apex.jQuery("#modal_"+this.id).hide(); this.pendingAction=null; },
            confirmAction: function() { if(this.pendingAction) this.pendingAction(); this.closeModal(); },
            
            showSkeleton: function(mode) {
                var $=apex.jQuery;
                $("#skeleton_report_"+this.id).removeClass("active");
                $("#skeleton_dashboard_"+this.id).removeClass("active");
                $("#dashboard_view_"+this.id).removeClass("active");
                $("#report_view_"+this.id).removeClass("active");
                $("#content_wrapper_"+this.id).hide();
                if(mode === "dashboard" || this.currentCategory === "Dashboard Builder") {
                    $("#skeleton_dashboard_"+this.id).addClass("active");
                } else {
                    $("#skeleton_report_"+this.id).addClass("active");
                }
            },
            
            hideSkeleton: function() {
                var $=apex.jQuery;
                $("#skeleton_report_"+this.id).removeClass("active");
                $("#skeleton_dashboard_"+this.id).removeClass("active");
            },
            
 loadSuggestions: function() {
                var $=apex.jQuery, self=this, container=$("#suggestions_"+this.id);
                var mode = (self.currentCategory === "Dashboard Builder") ? "DASHBOARD" : "REPORT";
                
                container.html(self.getSuggestionSkeletons(4));
                
                apex.server.plugin(self.ajax, {x01:"SUGGEST", x02:mode}, {
                    success: function(r) {
                        if(r.suggestions && Array.isArray(r.suggestions) && r.suggestions.length > 0) {
                            self.renderSuggestions(r.suggestions, mode);
                        } else {
                            self.renderEmptySuggestions();
                        }
                    },
                    error: function() { 
                        self.renderEmptySuggestions();
                    }
                });
            },

            getSuggestionSkeletons: function(count) {
                var html = "<div class=\"ai-sugg-grid\">";
                for(var i=0; i<count; i++) {
                    html += "<div class=\"ai-sugg-skeleton\">";
                    html += "<div class=\"skel-icon\"></div>";
                    html += "<div class=\"skel-content\">";
                    html += "<div class=\"skel-line\"></div>";
                    html += "<div class=\"skel-line\"></div>";
                    html += "</div></div>";
                }
                html += "</div>";
                return html;
            },

            renderSuggestions: function(suggestions, mode) {
                var $=apex.jQuery, self=this, container=$("#suggestions_"+this.id);
                
                var iconColors = ["blue", "green", "purple", "orange", "pink", "teal"];
                var defaultIcons = ["📊", "👥", "💰", "📈", "🎯", "⭐", "📋", "🔍"];
                
                var html = "";
                
                html += "<div class=\"ai-sugg-header\">";
                html += "<div class=\"ai-sugg-title\">";
                html += "<div class=\"ai-sugg-title-icon\">💡</div>";
                html += "<span>Suggested Questions</span>";
                html += "</div>";
                html += "<button type=\"button\" class=\"ai-sugg-refresh\" onclick=\"window.AID_"+self.id+".loadSuggestions()\">";
                html += "<svg width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\">";
                html += "<path d=\"M23 4v6h-6M1 20v-6h6M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15\"/>";
                html += "</svg>";
                html += "Refresh";
                html += "</button>";
                html += "</div>";
                
                html += "<div class=\"ai-sugg-grid\">";
                
                suggestions.forEach(function(s, idx) {
                    var q = (typeof s === "object" && s.question) ? s.question : s;
                    var colorClass = iconColors[idx % iconColors.length];
                    var icon = self.detectQuestionIcon(q, defaultIcons[idx % defaultIcons.length]);
                    var tag = self.detectQuestionTag(q, mode);
                    
                    html += "<div class=\"ai-sugg-card\" onclick=\"window.AID_"+self.id+".useSuggestion(this)\" data-question=\""+self.escapeHtml(q).replace(/"/g,"&quot;")+"\">";
                    html += "<div class=\"ai-sugg-icon "+colorClass+"\">"+icon+"</div>";
                    html += "<div class=\"ai-sugg-content\">";
                    html += "<div class=\"ai-sugg-text\">"+self.escapeHtml(q)+"</div>";
                    html += "<div class=\"ai-sugg-meta\">";
                    html += "<span class=\"ai-sugg-tag "+tag.tagClass+"\">"+tag.label+"</span>";
                    html += "</div>";
                    html += "</div>";
                    html += "<span class=\"ai-sugg-arrow\">→</span>";
                    html += "</div>";
                });
                
                html += "</div>";
                
                container.html(html);
            },

            renderEmptySuggestions: function() {
                var container = apex.jQuery("#suggestions_"+this.id);
                var html = "<div class=\"ai-sugg-empty\">";
                html += "<div class=\"ai-sugg-empty-icon\">💭</div>";
                html += "<div class=\"ai-sugg-empty-text\">No suggestions available. Try asking a question!</div>";
                html += "</div>";
                container.html(html);
            },

            detectQuestionIcon: function(question, defaultIcon) {
                if(!question) return defaultIcon;
                var q = question.toLowerCase();
                if(q.indexOf("employee") > -1 || q.indexOf("staff") > -1 || q.indexOf("worker") > -1) return "👥";
                if(q.indexOf("salary") > -1 || q.indexOf("pay") > -1 || q.indexOf("revenue") > -1 || q.indexOf("cost") > -1 || q.indexOf("price") > -1) return "💰";
                if(q.indexOf("department") > -1 || q.indexOf("team") > -1 || q.indexOf("division") > -1) return "🏢";
                if(q.indexOf("top") > -1 || q.indexOf("best") > -1 || q.indexOf("highest") > -1 || q.indexOf("rank") > -1) return "🏆";
                if(q.indexOf("trend") > -1 || q.indexOf("growth") > -1 || q.indexOf("increase") > -1 || q.indexOf("over time") > -1) return "📈";
                if(q.indexOf("average") > -1 || q.indexOf("total") > -1 || q.indexOf("sum") > -1 || q.indexOf("count") > -1) return "📊";
                if(q.indexOf("year") > -1 || q.indexOf("month") > -1 || q.indexOf("date") > -1 || q.indexOf("time") > -1) return "📅";
                if(q.indexOf("list") > -1 || q.indexOf("show") > -1 || q.indexOf("display") > -1 || q.indexOf("all") > -1) return "📋";
                if(q.indexOf("find") > -1 || q.indexOf("search") > -1 || q.indexOf("identify") > -1 || q.indexOf("locate") > -1) return "🔍";
                if(q.indexOf("order") > -1 || q.indexOf("purchase") > -1 || q.indexOf("sale") > -1) return "🛒";
                if(q.indexOf("customer") > -1 || q.indexOf("client") > -1) return "👤";
                if(q.indexOf("product") > -1 || q.indexOf("item") > -1) return "📦";
                return defaultIcon;
            },

            detectQuestionTag: function(question, mode) {
                if(!question) return { label: "Report", tagClass: "report" };
                var q = question.toLowerCase();
                if(mode === "DASHBOARD") return { label: "Dashboard", tagClass: "dashboard" };
                if(q.indexOf("trend") > -1 || q.indexOf("over time") > -1 || q.indexOf("growth") > -1 || q.indexOf("compare") > -1) return { label: "Analytics", tagClass: "analytics" };
                if(q.indexOf("top") > -1 || q.indexOf("best") > -1 || q.indexOf("most") > -1 || q.indexOf("highest") > -1 || q.indexOf("lowest") > -1) return { label: "Trending", tagClass: "trending" };
                return { label: "Report", tagClass: "report" };
            },

            useSuggestion: function(el) {
                var $=apex.jQuery;
                var question = $(el).attr("data-question");
                if(!question) {
                    question = $(el).find(".ai-sugg-text").text();
                }
                var ta = document.getElementById("inp_"+this.id);
                if(ta) {
                    ta.value = question;
                    ta.focus();
                }
            },


            toggleSidebar: function() { var $=apex.jQuery; var sb=$("#sidebar_"+this.id), tg=$("#toggle_"+this.id), ic=$("#toggle_icon_"+this.id); if(sb.hasClass("collapsed")){sb.removeClass("collapsed");tg.removeClass("collapsed");ic.text("◀");}else{sb.addClass("collapsed");tg.addClass("collapsed");ic.text("▶");} },
            
            loadHistory: function(s) {
                var $=apex.jQuery, self=this, list=$("#chat_list_"+this.id);
                list.html("<div class=\"aid-loading-history\">Loading...</div>");
                var searchVal = s ? s : "";
                apex.server.plugin(self.ajax, {x01:"HISTORY",x02:searchVal}, {
                    success: function(r) { if(r.status==="success"){self.chatHistory=r.chats?r.chats:[];self.renderHistory();}else{list.html("<div class=\"aid-empty-history\">Error</div>");} },
                    error: function() { list.html("<div class=\"aid-empty-history\">Error</div>"); }
                });
            },');
        
        -- Part 2: History rendering and more functions
        DBMS_LOB.APPEND(l_js, '
            renderHistory: function() {
                var $=apex.jQuery, self=this, list=$("#chat_list_"+this.id);
                var fc=this.chatHistory;
                if(this.historyFilter==="fav") fc=fc.filter(function(c){return c.is_favorite==="Y";});
                if(!fc || fc.length===0){
                    var msg=this.historyFilter==="fav"?"No favorites yet":"No conversations yet";
                    list.html("<div class=\"aid-empty-history\"><p>"+msg+"</p></div>");
                    return;
                }
                var html="",lastDate="",today=new Date().toDateString(),yesterday=new Date(Date.now()-86400000).toDateString();
                fc.forEach(function(chat){
                    var chatDate=new Date(chat.created_at).toDateString(),dateLabel="";
                    if(chatDate!==lastDate){
                        if(chatDate===today)dateLabel="Today";
                        else if(chatDate===yesterday)dateLabel="Yesterday";
                        else dateLabel=new Date(chat.created_at).toLocaleDateString("en-US",{month:"short",day:"numeric"});
                        html+="<div class=\"aid-date-group\">"+dateLabel+"</div>";
                        lastDate=chatDate;
                    }
                    var activeClass=(self.currentQueryId==chat.id)?" active":"";
                    var favClass=(chat.is_favorite==="Y")?" favorite":"";
                    var qType = chat.query_type ? chat.query_type : "REPORT";
                    var dashClass=(qType==="DASHBOARD")?" dashboard":"";
                    var icon=(qType==="DASHBOARD")?"📈":self.getVizIcon(chat.viz_type);
                    html+="<div class=\"aid-chat-item"+activeClass+favClass+dashClass+"\" data-id=\""+chat.id+"\" data-type=\""+qType+"\" onclick=\"window.AID_' || l_id || '.loadChat("+chat.id+",''"+qType+"'')\">";
                    html+="<div class=\"aid-chat-icon\">"+icon+"</div>";
                    html+="<div class=\"aid-chat-info\"><div class=\"aid-chat-title-row\"><span class=\"aid-chat-name\">"+self.escapeHtml(chat.title)+"</span><span class=\"aid-chat-time\">"+chat.time_ago+"</span></div>";
                    var rptTitle = chat.report_title ? chat.report_title : "";
                    html+="<div class=\"aid-chat-preview\">"+self.escapeHtml(rptTitle)+"</div></div>";
                    html+="<div class=\"aid-chat-actions\">";
                    html+="<button type=\"button\" class=\"aid-action-btn favorite"+(chat.is_favorite==="Y"?" active":"")+"\" onclick=\"event.preventDefault();event.stopPropagation();window.AID_' || l_id || '.toggleFavorite("+chat.id+",this)\">★</button>";
                    html+="<button type=\"button\" class=\"aid-action-btn delete\" onclick=\"event.preventDefault();event.stopPropagation();window.AID_' || l_id || '.deleteChat("+chat.id+")\">🗑</button>";
                    html+="</div></div>";
                });
                list.html(html);
            },
            getVizIcon: function(t) { 
                var icons = {"COMPARISON":"📊","TREND":"📈","COMPOSITION":"🥧","DASHBOARD":"📈"};
                return icons[t] ? icons[t] : "💬"; 
            },
            searchHistory: function(t) { var self=this; clearTimeout(this.searchTimeout); this.searchTimeout=setTimeout(function(){self.loadHistory(t);},300); },
            
            loadChat: function(queryId, queryType) {
                var $=apex.jQuery, self=this;
                $(".aid-chat-item").removeClass("active"); 
                $(".aid-chat-item[data-id=\""+queryId+"\"]").addClass("active");
                $("#welcome_"+this.id).addClass("hidden");
                $("#interaction_"+this.id).addClass("hidden");
                self.currentQueryId = queryId;
                self.showSkeleton(queryType === "DASHBOARD" ? "dashboard" : "report");
                
                apex.server.plugin(self.ajax, {x01:"DATA",x02:String(queryId)}, {
                    success: function(d) { 
                        self.hideSkeleton();
                        if(d.query_type === "DASHBOARD") {
                            self.renderDashboard(d);
                        } else {
                            self.processResult(d);
                        }
                    },
                    error: function(x,s,e) { 
                        self.hideSkeleton();
                        $("#err_"+self.id).text("Error: "+e).show(); 
                    }
                });
            },
            
            newChat: function() {
                var $=apex.jQuery; this.currentQueryId=null;
                $(".aid-chat-item").removeClass("active");
                this.hideSkeleton();
                $("#welcome_"+this.id).removeClass("hidden");
                $("#content_wrapper_"+this.id).hide();
                $("#dashboard_view_"+this.id).removeClass("active");
                $("#report_view_"+this.id).removeClass("active");
                $("#interaction_"+this.id).removeClass("hidden bottom").addClass("centered");
                $("#inp_"+this.id).val("").focus();
                $("#err_"+this.id).hide();
                if(this.cmEditor) this.cmEditor.setValue("");
                this.loadSuggestions();
            },
            
            deleteChat: function(id) { var self=this; this.showModal("Delete Conversation","Are you sure?",function(){apex.server.plugin(self.ajax,{x01:"DELETE_CHAT",x02:String(id)},{success:function(r){if(r.status==="success"){self.chatHistory=self.chatHistory.filter(function(c){return c.id!=id;});if(self.currentQueryId==id)self.newChat();self.renderHistory();}}});}); },
            toggleFavorite: function(id,btn) { var self=this,$=apex.jQuery,$btn=$(btn);var isFav=$btn.hasClass("active");$btn.toggleClass("active");$btn.closest(".aid-chat-item").toggleClass("favorite");var chat=self.chatHistory.find(function(c){return c.id==id;});if(chat){chat.is_favorite=isFav?"N":"Y";if(self.historyFilter==="fav")self.renderHistory();}apex.server.plugin(self.ajax,{x01:"TOGGLE_FAV",x02:String(id)},{success:function(r){if(r.status!=="success")self.loadHistory();}}); },
            clearHistory: function() { var self=this; this.showModal("Clear All History","Delete ALL chat history?",function(){apex.server.plugin(self.ajax,{x01:"CLEAR_HISTORY"},{success:function(r){if(r.status==="success"){self.newChat();self.loadHistory();}}});}); },
            
            setCat: function(c) { var $=apex.jQuery; this.currentCategory=c; $("#cat_text_"+this.id).text(c); var chip=$("#active_cat_"+this.id); chip.addClass("visible"); if(c==="Dashboard Builder")chip.addClass("dashboard"); else chip.removeClass("dashboard"); $("#inp_"+this.id).focus(); },
            clearCat: function() { var $=apex.jQuery; this.currentCategory="Report Builder"; $("#active_cat_"+this.id).removeClass("visible dashboard"); },
            
            setMode: function(mode) {
                var $=apex.jQuery, self=this;
                $(".ai-mode-btn").removeClass("active");
                if(mode === "dashboard") {
                    this.currentCategory = "Dashboard Builder";
                    $("#mode_dashboard_"+this.id).addClass("active");
                } else {
                    this.currentCategory = "Report Builder";  
                    $("#mode_report_"+this.id).addClass("active");
                }
                this.loadSuggestions();
                $("#inp_"+this.id).focus();
            },
            
            detectIntent: function(question) {
                if(!question) return "report";
                var q = question.toLowerCase();
                var dashboardKeywords = ["dashboard", "executive", "overview", "kpi", "metrics", "at a glance", "scorecard", "cockpit", "monitor"];
                for(var i=0; i<dashboardKeywords.length; i++) {
                    if(q.indexOf(dashboardKeywords[i]) > -1) return "dashboard";
                }
                return "report";
            },
            
            validateQuestion: function(question) {
                if(!question || question.trim().length === 0) return "Please enter a question about your data.";
                var q = question.trim().toLowerCase(), len = q.length;
                if(len < 2) return "Please enter a more descriptive question.";
                if(/^(.)\1+$/.test(q)) return "Please enter a valid question.";
                var hasVowels = /[aeiou]/i.test(q), hasArabic = /[\u0600-\u06FF]/.test(q);
                if(!hasVowels && !hasArabic && len < 8) return "Please enter a meaningful question.";
                var alphaCount = (q.match(/[a-zA-Z\u0600-\u06FF]/g) || []).length;
                if(alphaCount < len * 0.4) return "Please enter a valid question.";
                return null;
            },
            
            initEditor: function() { if(!this.cmEditor){var ta=document.getElementById("sql_editor_"+this.id);if(ta){this.cmEditor=CodeMirror.fromTextArea(ta,{mode:"text/x-sql",theme:"dracula",lineNumbers:true,matchBrackets:true,smartIndent:true});}} },
            switchTab: function(t) { 
            var $=apex.jQuery, self=this; 
            $(".ai-tab-btn").removeClass("active"); 
            var idx = {"report":0, "pivot":1, "chart":2, "sql":3}[t] || 0;
            $(".ai-tab-btn").eq(idx).addClass("active"); 
            $(".ai-view-content").removeClass("active"); 
            $("#view_"+t+"_"+this.id).addClass("active"); 
            
            if(t==="chart" && this.echartsInstance) {
                setTimeout(function(){self.echartsInstance.resize();}, 100);
            }
            if(t==="pivot") {
                if(this.pivotData && this.pivotData.length > 0 && !this.pivotInitialized) {
                    this.initPivot(this.pivotData, this.pivotConfig);
                } else if(this.pivotInstance) {
                    setTimeout(function() {
                        if(self.pivotInstance) self.pivotInstance.refresh();
                    }, 100);
                }
            }
            if(t==="sql") {
                this.initEditor();
                setTimeout(function(){if(self.cmEditor)self.cmEditor.refresh();}, 200);
            }
        },

        
            formatSql: function(sql) { if(!sql)return""; if(window.sqlFormatter){try{return window.sqlFormatter.format(sql,{language:"sql"});}catch(e){}} return sql; },');

        
        -- Part 3: Dashboard rendering
        DBMS_LOB.APPEND(l_js, '
            renderDashboard: function(d) {
                var $=apex.jQuery, self=this;
                $("#report_view_"+this.id).removeClass("active");
                $("#dashboard_view_"+this.id).addClass("active");
                $("#interaction_"+this.id).addClass("hidden");
                var dashTitle = d.dashboard_title ? d.dashboard_title : "Dashboard";
                $("#dash_title_"+this.id).text(dashTitle);
                var kpisArr = d.kpis ? d.kpis : [];
                this.renderDashKPIs(kpisArr);
                var chartsArr = d.charts ? d.charts : [];
                var savedLayout = d.saved_layout
                    ? (typeof d.saved_layout === "string" ? JSON.parse(d.saved_layout) : d.saved_layout)
                    : null;
                this.initGridStack(chartsArr, savedLayout);
                $(".aid-chat-item").removeClass("active");
                $(".aid-chat-item[data-id=\""+self.currentQueryId+"\"]").addClass("active");
            },
                initGridStack: function(charts, savedLayout) {
    var $=apex.jQuery, self=this;
    var gridEl = document.getElementById("dash_charts_" + this.id);
    if(!gridEl) return;

    // Make sure container is a gridstack root
    if(!gridEl.classList.contains("grid-stack")) {
        gridEl.classList.add("grid-stack");
    }
    this.layoutInitializing = true;

    // Dispose ECharts BEFORE destroying grid (while DOM still exists)
    if(this.dashboardCharts) {
        Object.keys(this.dashboardCharts).forEach(function(k) {
            if(self.dashboardCharts[k]) {
                try { self.dashboardCharts[k].dispose(); } catch(e) {}
            }
        });
    }
    this.dashboardCharts = {};

    // Remove all widgets from grid before destroying
    if(this.grid) {
        try {
            this.grid.removeAll(false);
            this.grid.destroy(false);
        } catch(e) {}
        this.grid = null;
    }

    // Clear any remaining content
    gridEl.innerHTML = "";

    this.currentDashboardCharts = charts;
    var layoutBucketsByBase = {};
    if(savedLayout && savedLayout.forEach) {
        savedLayout.forEach(function(l) {
            var key = String(l.id);
            var baseKey = key.replace(/_\d+$/, "");
            if(!layoutBucketsByBase[baseKey]) layoutBucketsByBase[baseKey] = [];
            layoutBucketsByBase[baseKey].push(l);
        });
    }

    var gridCols = 12;
    var chartsPerRow = 3;
    var wUnit = Math.floor(gridCols / chartsPerRow);
    var hUnit = 4;

    // Determine if we need an occurrence suffix for duplicate ids
    var baseCounts = {};
    charts.forEach(function(chart) {
        var baseId = chart.id != null ? String(chart.id) : "chart";
        baseCounts[baseId] = (baseCounts[baseId] || 0) + 1;
    });
    var needsIndexSuffix = Object.keys(baseCounts).some(function(k){ return baseCounts[k] > 1; });

    // Build a stable "order" key from saved layout / AI position, then pack into a strict 3-column grid
    var occIndex = {};
    var chartMetas = [];
    charts.forEach(function(chart, idx) {
        var baseId = chart.id != null ? String(chart.id) : "chart";
        occIndex[baseId] = (occIndex[baseId] || 0) + 1;
        var occ = occIndex[baseId];

        // pull layout by occurrence order
        var layoutList = layoutBucketsByBase[baseId] || [];
        var layoutForOcc = layoutList.length > 0 ? layoutList.shift() : null;

        var rankY = null;
        var rankX = null;

        if(layoutForOcc && layoutForOcc.x != null && layoutForOcc.y != null) {
            rankX = Number(layoutForOcc.x);
            rankY = Number(layoutForOcc.y);
        } else if(chart.position && chart.position.col && chart.position.row) {
            rankX = (Number(chart.position.col) - 1) * wUnit;
            rankY = (Number(chart.position.row) - 1) * hUnit;
        } else {
            rankX = (idx % chartsPerRow) * wUnit;
            rankY = Math.floor(idx / chartsPerRow) * hUnit;
        }

        if(isNaN(rankX)) rankX = Number.POSITIVE_INFINITY;
        if(isNaN(rankY)) rankY = Number.POSITIVE_INFINITY;

        var widgetId = needsIndexSuffix ? (baseId + "_" + (occ - 1)) : baseId;
        chartMetas.push({ chart: chart, idx: idx, widgetId: widgetId, rankY: rankY, rankX: rankX });
    });

    chartMetas.sort(function(a, b) {
        if(a.rankY !== b.rankY) return a.rankY - b.rankY;
        if(a.rankX !== b.rankX) return a.rankX - b.rankX;
        return a.idx - b.idx;
    });

    var items = [];
    chartMetas.forEach(function(m, i) {
        items.push({
            id: m.widgetId,
            x: (i % chartsPerRow) * wUnit,
            y: Math.floor(i / chartsPerRow) * hUnit,
            w: wUnit,
            h: hUnit,
            content: self.buildChartWidgetHTML(m.chart, m.idx)
        });
    });

    // Init GridStack
	    this.grid = GridStack.init({
	        column: 12,
	        cellHeight: 80,
	        minRow: 1,
	        margin: 0,
	        animate: true,
	        float: false,
	        disableOneColumnMode: true,
	        disableResize: true,
	        draggable: { handle: ".aid-dash-chart-header", cancel: ".aid-chart-menu-btn,.aid-chart-menu-dropdown" }
	    }, gridEl);

    // Add Widgets
    this.grid.batchUpdate();
    items.forEach(function(item) {
        self.grid.addWidget({
            id: item.id,
            x: item.x, y: item.y, w: item.w, h: item.h,
            content: item.content
        });
    });
    this.grid.commit();
    this.layoutInitializing = false;

    // Render ECharts inside widgets (delay to ensure final sizes after GridStack paint)
    setTimeout(function() {
        charts.forEach(function(chart, idx) {
            var domId = "dashchart_" + idx + "_" + self.id; // keep old pattern
            self.renderSingleChart(domId, chart);
        });
    }, 300);

    var resizeAndSave = function(el) {
        var content = el.querySelector(".aid-dash-chart-body");
        if(content) {
            var inst = echarts.getInstanceByDom(content);
            if(inst) inst.resize();
        }
        if(!self.layoutInitializing) self.queueLayoutSave();
    };

    // Resize ECharts on widget resize + persist layout
    this.grid.on("resizestop", function(event, el) {
        resizeAndSave(el);
    });
    this.grid.on("dragstop", function(event, el) {
        resizeAndSave(el);
    });
    this.grid.on("change", function() {
        if(self.layoutInitializing) return;
        self.queueLayoutSave();
    });
},

buildChartWidgetHTML: function(chart, idx) {
    var self = this;
    var domId = "dashchart_" + idx + "_" + self.id; // keep old pattern (important for exportChart compatibility)

    // Note: GridStack already creates the outer .grid-stack-item-content wrapper
    var html = "<div class=\"aid-dash-chart\">";
    html += "<div class=\"aid-dash-chart-header\">";
    html += "<div class=\"aid-dash-chart-title\">" + self.escapeHtml(chart.title) + "</div>";

    html += "<div class=\"aid-dash-chart-menu\">";
    html += "<button type=\"button\" class=\"aid-chart-menu-btn\">⚙️ ▾</button>";
    html += "<div class=\"aid-chart-menu-dropdown\">";
    html += "<div class=\"aid-chart-menu-item\" onclick=\"window.AID_"+self.id+".openChartEdit("+idx+")\">✏️ Edit Chart</div>";
    html += "<div class=\"aid-chart-menu-item\" onclick=\"window.AID_"+self.id+".refreshChart("+idx+")\">🔄 Refresh</div>";
    html += "<div class=\"aid-chart-menu-item\" onclick=\"window.AID_"+self.id+".exportChart("+idx+")\">📥 Export</div>";
    html += "<div class=\"aid-chart-menu-item danger\" onclick=\"window.AID_"+self.id+".deleteChart("+idx+")\">🗑 Delete</div>";
    html += "</div></div>";

    html += "</div>";
    html += "<div class=\"aid-dash-chart-body\" id=\"" + domId + "\"></div>";
    html += "</div>";

    return html;
},

queueLayoutSave: function() {
    var self = this;
    if(self.layoutSaveTimer) clearTimeout(self.layoutSaveTimer);
    self.layoutSaveTimer = setTimeout(function() {
        self.saveLayout();
    }, 600);
},

saveLayout: function() {
    var $=apex.jQuery, self=this;
    if(!this.grid || !this.currentQueryId || this.layoutInitializing) return;
    if(this.layoutSaveTimer) this.layoutSaveTimer = null;
    var layout = this.grid.save(false) || [];
    if(!layout || layout.length === 0) return;
    layout = layout.map(function(n) {
        var nid = n.id || (n.el && (n.el.getAttribute("gs-id") || n.el.id)) || "";
        return { id: String(nid), x: n.x, y: n.y, w: n.w, h: n.h };
    }).filter(function(n){ return n.id !== ""; });

    apex.server.plugin(self.ajax, {
        x01: "SAVE_LAYOUT",
        x02: String(self.currentQueryId),
        x03: JSON.stringify(layout)
    });
},

resetLayout: function() {
    var $=apex.jQuery, self=this;
    if(!confirm("Reset dashboard layout to default?")) return;

    apex.server.plugin(self.ajax, {
        x01: "RESET_LAYOUT",
        x02: String(self.currentQueryId)
    }, {
        success: function() {
            self.loadChat(self.currentQueryId, "DASHBOARD");
        }
    });
},

            
            renderDashKPIs: function(kpis) {
                var $=apex.jQuery, self=this, container=$("#dash_kpis_"+this.id);
                container.empty();
                var colorArr = ["green","orange","blue","red","purple","teal"];
                kpis.forEach(function(kpi, idx) {
                    var color = kpi.color ? kpi.color : colorArr[idx % 6];
                    var iconEmoji = self.getIconEmoji(kpi.icon);
                    var icon = iconEmoji ? iconEmoji : self.kpiIcons[idx % self.kpiIcons.length];
                    var trend = kpi.trend ? kpi.trend : "";
                    var trendClass = "";
                    if(trend.indexOf("+") > -1) trendClass = "positive";
                    else if(trend.indexOf("-") > -1) trendClass = "negative";
                    
                    var html = "<div class=\"aid-dash-kpi " + color + "\">";
                    html += "<div class=\"aid-dash-kpi-header\">" + self.escapeHtml(kpi.title) + "</div>";
                    html += "<div class=\"aid-dash-kpi-body\">";
                    html += "<div class=\"aid-dash-kpi-main\">";
                    var kpiVal = kpi.value ? kpi.value : "-";
                    html += "<div class=\"aid-dash-kpi-value\">" + self.escapeHtml(kpiVal) + "</div>";
                    if(trend) {
                        html += "<div class=\"aid-dash-kpi-trend " + trendClass + "\">" + self.escapeHtml(trend);
                        if(kpi.trend_label) html += "<span class=\"aid-dash-kpi-trend-label\">" + self.escapeHtml(kpi.trend_label) + "</span>";
                        html += "</div>";
                    }
                    html += "</div>";
                    html += "<div class=\"aid-dash-kpi-icon\">" + icon + "</div>";
                    html += "</div></div>";
                    
                    container.append(html);
                });
            },
            
            renderDashCharts: function(charts) {
                var $=apex.jQuery, self=this, container=$("#dash_charts_"+this.id);
                container.empty();
                
                // Store charts for editing
                this.currentDashboardCharts = charts;
                
                Object.keys(this.dashboardCharts).forEach(function(k) {
                    if(self.dashboardCharts[k]) {
                        try { self.dashboardCharts[k].dispose(); } catch(e) {}
                    }
                });
                this.dashboardCharts = {};
                
                charts.forEach(function(chart, idx) {
                    var pos = chart.position ? chart.position : {};
                    var colspan = pos.colspan ? pos.colspan : 1;
                    var rowspan = pos.rowspan ? pos.rowspan : 1;
                    var colspanClass = colspan > 1 ? " colspan-2" : "";
                    var rowspanClass = rowspan > 1 ? " rowspan-2" : "";
                    var chartId = "dashchart_" + idx + "_" + self.id;
                    
                    var html = "<div class=\"aid-dash-chart" + colspanClass + rowspanClass + "\">";
                    html += "<div class=\"aid-dash-chart-header\">";
                    html += "<div class=\"aid-dash-chart-title\">" + self.escapeHtml(chart.title) + "</div>";
                    
                    // Add edit menu
                    html += "<div class=\"aid-dash-chart-menu\">";
                    html += "<button type=\"button\" class=\"aid-chart-menu-btn\">⚙️ ▾</button>";
                    html += "<div class=\"aid-chart-menu-dropdown\">";
                    html += "<div class=\"aid-chart-menu-item\" onclick=\"window.AID_"+self.id+".openChartEdit("+idx+")\">✏️ Edit Chart</div>";
                    html += "<div class=\"aid-chart-menu-item\" onclick=\"window.AID_"+self.id+".refreshChart("+idx+")\">🔄 Refresh</div>";
                    html += "<div class=\"aid-chart-menu-item\" onclick=\"window.AID_"+self.id+".exportChart("+idx+")\">📥 Export</div>";
                    html += "<div class=\"aid-chart-menu-item danger\" onclick=\"window.AID_"+self.id+".deleteChart("+idx+")\">🗑 Delete</div>";
                    html += "</div></div>";
                    
                    html += "</div>";
                    html += "<div class=\"aid-dash-chart-body\" id=\"" + chartId + "\"></div>";
                    html += "</div>";
                    
                    container.append(html);
                    
                    setTimeout(function() {
                        self.renderSingleChart(chartId, chart);
                    }, 100 + (idx * 50));
                });
            },
            
            renderSingleChart: function(domId, chartConfig) {
                var self = this;
                var dom = document.getElementById(domId);
                if(!dom) return;
                
                var data = chartConfig.data ? chartConfig.data : [];
                if(data.length === 0) {
                    dom.innerHTML = "<div class=\"ai-no-data\">No data</div>";
                    return;
                }
                
                var chart = echarts.init(dom);
                this.dashboardCharts[domId] = chart;
                
                var chartType = chartConfig.chart_type ? chartConfig.chart_type : "bar";
                var type = chartType.toLowerCase().replace(/_/g, "").replace(/-/g, "");
                var config = chartConfig.config ? chartConfig.config : {};
                var opt = this.buildChartOption(type, data, config, chartConfig.title);
                
                chart.setOption(opt);
                window.addEventListener("resize", function() {
                    if(self.dashboardCharts[domId]) self.dashboardCharts[domId].resize();
                });
            },
            
            ');

        -- Part 3.1: Chart option builders
        DBMS_LOB.APPEND(l_js, '

            buildChartOption: function(type, data, config, title) {
                var self = this;
                if(!data || data.length === 0) return {};
                var keys = Object.keys(data[0]);
                var catKey = config && config.xAxis ? config.xAxis : (keys && keys.length > 0 ? keys[0] : "");
                if(!catKey || !data[0].hasOwnProperty(catKey)) {
                    catKey = keys && keys.length > 0 ? keys[0] : "";
                }
                var valueKeys = keys.filter(function(k) { return k !== catKey && typeof data[0][k] === "number"; });
                if(valueKeys.length === 0) valueKeys = [keys[1]];
                
                switch(type) {
                    case "pie": case "donut":
                        return this.buildPieOption(data, catKey, valueKeys[0], type === "donut");
                    case "barhorizontal":
                        return this.buildHBarOption(data, catKey, valueKeys, config);
                    case "barstacked": case "bargrouped":
                        var opt = this.buildBarOption(data, catKey, valueKeys, config);
                        if(type === "barstacked") opt.series.forEach(function(s) { s.stack = "total"; });
                        return opt;
                    case "line": case "linesmooth":
                        return this.buildLineOption(data, catKey, valueKeys, config, false, type === "linesmooth");
                    case "area": case "areastacked":
                        return this.buildLineOption(data, catKey, valueKeys, config, true, true);
                    case "radar":
                        return this.buildRadarOption(data, catKey, valueKeys);
                    case "treemap":
                        return this.buildTreemapOption(data, catKey, valueKeys[0]);
                    case "funnel":
                        return this.buildFunnelOption(data, catKey, valueKeys[0]);
                    case "scatter": case "bubble":
                        return this.buildScatterOption(data, catKey, valueKeys, type === "bubble");
                    case "gauge":
                        return this.buildGaugeOption(data, catKey, valueKeys[0]);
                    case "heatmap":
                        return this.buildHeatmapOption(data, keys, config);
                    case "sankey":
                        return this.buildSankeyOption(data);
                    default:
                        return this.buildBarOption(data, catKey, valueKeys, config);
                }
            },
            
            buildBarOption: function(data, catKey, valueKeys, config) {
                var self = this;
                var categories = data.map(function(d) { return d[catKey]; });
                var series = valueKeys.map(function(vk, i) {
                    return {
                        name: vk, type: "bar", 
                        data: data.map(function(d) { return d[vk]; }),
                        itemStyle: { color: self.colors[i % self.colors.length], borderRadius: [4,4,0,0] },
                        barMaxWidth: 40
                    };
                });
                return {
                    tooltip: { trigger: "axis", axisPointer: { type: "shadow" } },
                    legend: { show: series.length > 1, top: 5, textStyle: { fontSize: 11 } },
                    grid: { left: "3%", right: "4%", bottom: "10%", top: series.length > 1 ? "15%" : "10%", containLabel: true },
                    xAxis: { type: "category", data: categories, axisLabel: { rotate: categories.length > 5 ? 30 : 0, fontSize: 11 } },
                    yAxis: { type: "value", splitLine: { lineStyle: { type: "dashed" } } },
                    series: series
                };
            },
            
            buildHBarOption: function(data, catKey, valueKeys, config) {
                var self = this;
                var categories = data.map(function(d) { return d[catKey]; });
                var series = valueKeys.map(function(vk, i) {
                    return {
                        name: vk, type: "bar",
                        data: data.map(function(d) { return d[vk]; }),
                        itemStyle: { color: self.colors[i % self.colors.length], borderRadius: [0,4,4,0] },
                        barMaxWidth: 20
                    };
                });
                return {
                    tooltip: { trigger: "axis", axisPointer: { type: "shadow" } },
                    legend: { show: series.length > 1, top: 5 },
                    grid: { left: "25%", right: "5%", bottom: "5%", top: "10%", containLabel: false },
                    yAxis: { type: "category", data: categories, inverse: true, axisLabel: { fontSize: 11 } },
                    xAxis: { type: "value", splitLine: { lineStyle: { type: "dashed" } } },
                    series: series
                };
            },
            
            buildLineOption: function(data, catKey, valueKeys, config, isArea, isSmooth) {
    var self = this;
    var categories = data.map(function(d) { return d[catKey]; });
    var series = valueKeys.map(function(vk, i) {
        var s = {
            name: vk, 
            type: "line", 
            smooth: isSmooth || false,
            data: data.map(function(d) { return d[vk]; }),
            lineStyle: { width: 3 },
            itemStyle: { color: self.colors[i % self.colors.length] },
            symbol: "circle", 
            symbolSize: 6
        };
        if(isArea) s.areaStyle = { opacity: 0.3 };
        return s;
    });
    return {
        tooltip: { trigger: "axis" },
        legend: { show: series.length > 1, top: 5 },
        grid: { left: "3%", right: "4%", bottom: "10%", top: series.length > 1 ? "15%" : "10%", containLabel: true },
        xAxis: { type: "category", data: categories, boundaryGap: false, axisLabel: { fontSize: 11 } },
        yAxis: { type: "value", splitLine: { lineStyle: { type: "dashed" } } },
        series: series
    };
},
            
            buildPieOption: function(data, catKey, valueKey, isDonut) {
                var self = this;
                var pieData = data.map(function(d, i) {
                    return { name: d[catKey], value: d[valueKey], itemStyle: { color: self.colors[i % self.colors.length] } };
                });
                return {
                    tooltip: { trigger: "item", formatter: "{b}: {c} ({d}%)" },
                    legend: { orient: "vertical", right: 10, top: "center", textStyle: { fontSize: 11 } },
                    series: [{
                        type: "pie",
                        radius: isDonut ? ["45%", "70%"] : "70%",
                        center: ["40%", "50%"],
                        data: pieData,
                        label: { show: false },
                        emphasis: { label: { show: true, fontSize: 14, fontWeight: "bold" } }
                    }]
                };
            },
            
            buildRadarOption: function(data, catKey, valueKeys) {
                var self = this;
                var indicator = valueKeys.map(function(k) {
                    var maxVal = 0;
                    data.forEach(function(d) { if(d[k] > maxVal) maxVal = d[k]; });
                    return { name: k, max: maxVal * 1.2 };
                });
                var radarData = data.map(function(d, i) {
                    return {
                        name: d[catKey],
                        value: valueKeys.map(function(k) { return d[k]; }),
                        areaStyle: { opacity: 0.3 }
                    };
                });
                return {
                    tooltip: {},
                    legend: { top: 5, textStyle: { fontSize: 11 } },
                    radar: { indicator: indicator, radius: "60%" },
                    series: [{ type: "radar", data: radarData }]
                };
            },
            
            // Treemap Chart
buildTreemapOption: function(data, catKey, valueKey) {
    var self = this;
    var treemapData = data.map(function(d, i) {
        return {
            name: d[catKey],
            value: d[valueKey],
            itemStyle: { color: self.colors[i % self.colors.length] }
        };
    });
    return {
        tooltip: { trigger: "item", formatter: "{b}: {c}" },
        series: [{
            type: "treemap",
            data: treemapData,
            leafDepth: 1,
            roam: false,
            nodeClick: false,
            breadcrumb: { show: false },
            label: { show: true, formatter: "{b}\n{c}", fontSize: 12 },
            itemStyle: { borderColor: "#fff", borderWidth: 2, gapWidth: 2 },
            levels: [{
                itemStyle: { borderColor: "#fff", borderWidth: 2, gapWidth: 2 }
            }]
        }]
    };
},

// Funnel Chart
buildFunnelOption: function(data, catKey, valueKey) {
    var self = this;
    var sortedData = data.slice().sort(function(a, b) { return b[valueKey] - a[valueKey]; });
    var funnelData = sortedData.map(function(d, i) {
        return {
            name: d[catKey],
            value: d[valueKey],
            itemStyle: { color: self.colors[i % self.colors.length] }
        };
    });
    return {
        tooltip: { trigger: "item", formatter: "{b}: {c} ({d}%)" },
        legend: { orient: "vertical", right: 10, top: "center", textStyle: { fontSize: 11 } },
        series: [{
            type: "funnel",
            left: "10%",
            top: 20,
            bottom: 20,
            width: "60%",
            min: 0,
            minSize: "0%",
            maxSize: "100%",
            sort: "descending",
            gap: 2,
            label: { show: true, position: "inside", formatter: "{b}: {c}", fontSize: 11 },
            itemStyle: { borderColor: "#fff", borderWidth: 1 },
            data: funnelData
        }]
    };
},

// Scatter / Bubble Chart
buildScatterOption: function(data, catKey, valueKeys, isBubble) {
    var self = this;
    var scatterData = data.map(function(d, i) {
        var point = [d[valueKeys[0]] || 0, d[valueKeys[1]] || d[valueKeys[0]] || 0];
        if(isBubble && valueKeys.length > 2) {
            point.push(d[valueKeys[2]] || 10);
        }
        point.push(d[catKey]);
        return point;
    });
    return {
        tooltip: {
            trigger: "item",
            formatter: function(params) {
                var d = params.data;
                return d[d.length - 1] + "<br/>X: " + d[0] + "<br/>Y: " + d[1];
            }
        },
        xAxis: { type: "value", splitLine: { lineStyle: { type: "dashed" } } },
        yAxis: { type: "value", splitLine: { lineStyle: { type: "dashed" } } },
        series: [{
            type: "scatter",
            data: scatterData,
            symbolSize: isBubble ? function(d) { return Math.sqrt(d[2]) * 3; } : 15,
            itemStyle: { color: self.colors[0], opacity: 0.7 },
            emphasis: { itemStyle: { opacity: 1 } }
        }]
    };
},

// Gauge Chart
buildGaugeOption: function(data, catKey, valueKey) {
    var self = this;
    var value = data.length > 0 ? (data[0][valueKey] || 0) : 0;
    var maxVal = 0;
    data.forEach(function(d) { if(d[valueKey] > maxVal) maxVal = d[valueKey]; });
    if(maxVal === 0) maxVal = 100;
    
    return {
        tooltip: { formatter: "{b}: {c}" },
        series: [{
            type: "gauge",
            min: 0,
            max: Math.ceil(maxVal * 1.2),
            progress: { show: true, width: 18 },
            axisLine: { lineStyle: { width: 18 } },
            axisTick: { show: false },
            splitLine: { length: 15, lineStyle: { width: 2, color: "#999" } },
            axisLabel: { distance: 25, color: "#999", fontSize: 11 },
            anchor: { show: true, showAbove: true, size: 20, itemStyle: { borderWidth: 8 } },
            title: { show: true, offsetCenter: [0, "70%"], fontSize: 14 },
            detail: {
                valueAnimation: true,
                fontSize: 28,
                fontWeight: "bold",
                offsetCenter: [0, "40%"],
                formatter: "{value}",
                color: self.colors[0]
            },
            data: [{ value: value, name: data.length > 0 ? data[0][catKey] : "" }]
        }]
    };
},

// Heatmap Chart
buildHeatmapOption: function(data, keys, config) {
    var self = this;
    var xData = [], yData = [], heatData = [];
    var xKey = keys[0], yKey = keys[1], valKey = keys[2] || keys[1];
    
    data.forEach(function(d) {
        if(xData.indexOf(d[xKey]) === -1) xData.push(d[xKey]);
        if(yData.indexOf(d[yKey]) === -1) yData.push(d[yKey]);
    });
    
    var maxVal = 0;
    data.forEach(function(d) {
        var xi = xData.indexOf(d[xKey]);
        var yi = yData.indexOf(d[yKey]);
        var val = d[valKey] || 0;
        if(val > maxVal) maxVal = val;
        heatData.push([xi, yi, val]);
    });
    
    return {
        tooltip: { position: "top", formatter: function(p) { return xData[p.data[0]] + ", " + yData[p.data[1]] + ": " + p.data[2]; } },
        grid: { left: "15%", right: "10%", top: "10%", bottom: "15%" },
        xAxis: { type: "category", data: xData, splitArea: { show: true }, axisLabel: { fontSize: 10, rotate: 45 } },
        yAxis: { type: "category", data: yData, splitArea: { show: true }, axisLabel: { fontSize: 10 } },
        visualMap: { min: 0, max: maxVal || 100, calculable: true, orient: "horizontal", left: "center", bottom: 0, inRange: { color: ["#e0f3f8", "#abd9e9", "#74add1", "#4575b4", "#313695"] } },
        series: [{ type: "heatmap", data: heatData, label: { show: true, fontSize: 10 }, emphasis: { itemStyle: { shadowBlur: 10, shadowColor: "rgba(0,0,0,0.5)" } } }]
    };
},

// Sankey Chart
buildSankeyOption: function(data) {
    var nodes = [], links = [], nodeSet = {};
    var keys = Object.keys(data[0]);
    var sourceKey = keys[0], targetKey = keys[1], valueKey = keys[2] || keys[1];
    
    data.forEach(function(d) {
        var source = String(d[sourceKey]);
        var target = String(d[targetKey]);
        if(!nodeSet[source]) { nodeSet[source] = true; nodes.push({ name: source }); }
        if(!nodeSet[target]) { nodeSet[target] = true; nodes.push({ name: target }); }
        links.push({ source: source, target: target, value: d[valueKey] || 1 });
    });
    
    return {
        tooltip: { trigger: "item", triggerOn: "mousemove" },
        series: [{
            type: "sankey",
            data: nodes,
            links: links,
            emphasis: { focus: "adjacency" },
            lineStyle: { color: "gradient", curveness: 0.5 },
            label: { fontSize: 11 }
        }]
    };
},

        ');

        -- Part 3.2: Pivot functions
        DBMS_LOB.APPEND(l_js, '

initPivot: function(data, config) {
    var self = this;
    var container = document.getElementById("pivot_container_" + this.id);
    if(!container) return;
    if(this.pivotInstance) { try { this.pivotInstance.dispose(); } catch(e) {} this.pivotInstance = null; }
    if(!data || data.length === 0) { container.innerHTML = "<div class=\"ai-pivot-empty\">No data</div>"; return; }
    var fields = this.analyzePivotFields(data);
    var slice = config ? config : this.getDefaultSlice(fields);
    this.pivotInstance = new WebDataRocks({
        container: container, toolbar: true,
        report: { dataSource: { data: data }, slice: slice,
            options: { grid: { type: "compact", showFilter: true, showTotals: "on", showGrandTotals: "on" }, configuratorButton: true },
            formats: [{ name: "", thousandsSeparator: ",", decimalSeparator: ".", decimalPlaces: 2 }]
        }
    });
    this.pivotInitialized = true;
},

analyzePivotFields: function(data) {
    if(!data || data.length === 0) return { dimensions: [], measures: [], dates: [] };
    var sample = data[0], keys = Object.keys(sample), dimensions = [], measures = [], dates = [];
    keys.forEach(function(key) {
        var val = sample[key], kl = key.toLowerCase();
        if(kl.indexOf("date") > -1 || kl.indexOf("time") > -1) dates.push(key);
        else if(typeof val === "number" && kl.indexOf("id") === -1) measures.push(key);
        else dimensions.push(key);
    });
    if(measures.length === 0) for(var i = keys.length - 1; i >= 0; i--) if(typeof sample[keys[i]] === "number") { measures.push(keys[i]); break; }
    return { dimensions: dimensions, measures: measures, dates: dates };
},

getDefaultSlice: function(fields) {
    var rows = [], columns = [], measures = [];
    var dims = fields.dimensions.filter(function(d) { return fields.dates.indexOf(d) === -1; });
    for(var i = 0; i < Math.min(2, dims.length); i++) rows.push({ uniqueName: dims[i] });
    if(fields.dates.length > 0) columns.push({ uniqueName: fields.dates[0] });
    for(var j = 0; j < Math.min(3, fields.measures.length); j++) measures.push({ uniqueName: fields.measures[j], aggregation: "sum" });
    if(measures.length === 0 && dims.length > 0) measures.push({ uniqueName: dims[0], aggregation: "count" });
    return { rows: rows, columns: columns, measures: measures };
},

applyPivotConfig: function() {
    if(!this.pivotInstance || !this.pivotConfig) return;
    var slice = { rows: [], columns: [], measures: [] };
    if(this.pivotConfig.rows) this.pivotConfig.rows.forEach(function(r) { slice.rows.push({ uniqueName: r }); });
    if(this.pivotConfig.columns) this.pivotConfig.columns.forEach(function(c) { slice.columns.push({ uniqueName: c }); });
    if(this.pivotConfig.measures) this.pivotConfig.measures.forEach(function(m) { slice.measures.push({ uniqueName: m, aggregation: "sum" }); });
    this.pivotInstance.setReport({ dataSource: { data: this.pivotData }, slice: slice });
    this.hidePivotRecommendation();
},

pivotExpandAll: function() { if(this.pivotInstance) this.pivotInstance.expandAllData(); },
pivotCollapseAll: function() { if(this.pivotInstance) this.pivotInstance.collapseAllData(); },
pivotExport: function(format) { if(!this.pivotInstance) return; var fn = "pivot_" + new Date().toISOString().slice(0,10); this.pivotInstance.exportTo(format === "excel" ? "excel" : "pdf", { filename: fn }); },
showPivotRecommendation: function(reason, config) { this.pivotConfig = config; apex.jQuery("#pivot_reason_"+this.id).text(reason); apex.jQuery("#pivot_recommendation_"+this.id).show(); },
hidePivotRecommendation: function() { apex.jQuery("#pivot_recommendation_"+this.id).hide(); },
            
            ');
            

        -- Part 3.5: Chart Edit Functions - FIXED
        DBMS_LOB.APPEND(l_js, '
            chartPreviewDebounce: null,
            isUpdatingPreview: false,
            
            loadChartTypes: function() {
                var self = this;
                if(this.availableChartTypes.length > 0) return;
                apex.server.plugin(self.ajax, {x01:"CHART_TYPES"}, {
                    success: function(r) {
                        if(r.status === "success" && r.chart_types) {
                            self.availableChartTypes = r.chart_types;
                        }
                    }
                });
            },

            openChartEdit: function(chartIndex) {
                var $=apex.jQuery, self=this;
                var charts = this.currentDashboardCharts;
                if(!charts || chartIndex >= charts.length) return;
                var chart = charts[chartIndex];
                this.chartEditIndex = chartIndex;
                this.chartEditData = JSON.parse(JSON.stringify(chart));
                this.isUpdatingPreview = false;
                if(this.chartPreviewDebounce) { clearTimeout(this.chartPreviewDebounce); this.chartPreviewDebounce = null; }
                if(this.availableChartTypes.length === 0) {
                    this.loadChartTypesAndOpen(chart);
                } else {
                    this.populateChartEditModal(chart);
                }
            },

            loadChartTypesAndOpen: function(chart) {
                var self = this;
                apex.server.plugin(self.ajax, {x01:"CHART_TYPES"}, {
                    success: function(r) {
                        if(r.status === "success" && r.chart_types) self.availableChartTypes = r.chart_types;
                        self.populateChartEditModal(chart);
                    },
                    error: function() { self.populateChartEditModal(chart); }
                });
            },

            populateChartEditModal: function(chart) {
                var $=apex.jQuery, self=this;
                $("#chart_edit_title_"+this.id).val(chart.title || "");
                this.renderChartTypeSelector(chart.chart_type);
                this.initChartSqlEditor(chart.sql || "");
                $("#chart_edit_"+this.id).css("display", "flex");
                var dom = document.getElementById("chart_preview_"+this.id);
                if(dom) {
                    this.disposePreviewChart();
                    dom.innerHTML = "";
                    var d = document.createElement("div");
                    d.className = "ai-preview-loading";
                    d.textContent = "Click Test Query to preview";
                    dom.appendChild(d);
                }
            },

            renderChartTypeSelector: function(currentType) {
                var $=apex.jQuery, self=this;
                var grid = $("#chart_type_grid_"+this.id);
                var icons = {"BAR":"📊","BAR_HORIZONTAL":"📊","BAR_STACKED":"📊","LINE":"📈","LINE_SMOOTH":"📈","AREA":"📈","PIE":"🥧","DONUT":"🍩","SCATTER":"⚬","RADAR":"🕸️","FUNNEL":"▼","HEATMAP":"🔥","GAUGE":"⏱️","TREEMAP":"🌳","SANKEY":"🔀"};
                var types = this.availableChartTypes.length > 0 ? this.availableChartTypes : [
                    {id:"BAR",name:"Bar Chart",category:"COMPARISON"},{id:"LINE",name:"Line Chart",category:"TREND"},
                    {id:"PIE",name:"Pie Chart",category:"COMPOSITION"},{id:"DONUT",name:"Donut Chart",category:"COMPOSITION"},
                    {id:"AREA",name:"Area Chart",category:"TREND"},{id:"BAR_HORIZONTAL",name:"Horizontal Bar",category:"RANKING"}
                ];
                var currUp = currentType ? currentType.toUpperCase().replace(/-/g,"_") : "";
                var h = "";
                for(var i=0; i<types.length; i++) {
                    var t = types[i];
                    var tid = t.id || t.CHART_TYPE_ID;
                    var tname = t.name || t.DISPLAY_NAME;
                    var tcat = t.category || t.CHART_CATEGORY || "";
                    var icon = icons[tid] || "📊";
                    var sel = (currUp === tid.toUpperCase()) ? " selected" : "";
                    h += "<div cla" + "ss=\"ai-chart-type-item" + sel + "\" data-type=\"" + tid + "\" onclick=\"window.AID_"+self.id+".selectChartType(this)\">";
                    h += "<div cla" + "ss=\"ai-chart-type-icon\">" + icon + "</div>";
                    h += "<div cla" + "ss=\"ai-chart-type-name\">" + self.escapeHtml(tname) + "</div>";
                    h += "<div cla" + "ss=\"ai-chart-type-category\">" + self.escapeHtml(tcat) + "</div>";
                    h += "</div>";
                }
                grid.html(h);
            },

            selectChartType: function(el) {
                var $=apex.jQuery, self=this;
                if($(el).is(".selected")) return;
                var grid = document.getElementById("chart_type_grid_"+this.id);
                if(grid) {
                    var items = grid.querySelectorAll(".ai-chart-type-item");
                    for(var i=0; i<items.length; i++) { items[i].className = "ai-chart-type-item"; }
                }
                el.className = "ai-chart-type-item selected";
                if(this.chartEditData && this.chartEditData.data && this.chartEditData.data.length > 0) {
                    var me = this;
                    if(this.chartPreviewDebounce) clearTimeout(this.chartPreviewDebounce);
                    this.chartPreviewDebounce = setTimeout(function(){ me.updateChartPreview(); }, 150);
                }
            },

            initChartSqlEditor: function(sql) {
                var self = this;
                var ta = document.getElementById("chart_sql_editor_"+this.id);
                if(!ta) return;
                if(this.chartEditEditor) { try { this.chartEditEditor.toTextArea(); } catch(e) {} this.chartEditEditor = null; }
                var fmt = sql;
                if(window.sqlFormatter) { try { fmt = window.sqlFormatter.format(sql, {language:"sql"}); } catch(e) {} }
                ta.value = fmt;
                this.chartEditEditor = CodeMirror.fromTextArea(ta, {mode:"text/x-sql",theme:"dracula",lineNumbers:true,matchBrackets:true,smartIndent:true,lineWrapping:true});
                setTimeout(function(){ if(self.chartEditEditor) self.chartEditEditor.refresh(); }, 100);
            },

            disposePreviewChart: function() {
                var dom = document.getElementById("chart_preview_"+this.id);
                if(this.chartPreviewInstance) { try { this.chartPreviewInstance.dispose(); } catch(e) {} this.chartPreviewInstance = null; }
                if(dom) { var inst = echarts.getInstanceByDom(dom); if(inst) { try { inst.dispose(); } catch(e) {} } }
            },

            testChartSql: function() {
                var $=apex.jQuery, self=this;
                var sql = this.chartEditEditor ? this.chartEditEditor.getValue() : "";
                var dom = document.getElementById("chart_preview_"+this.id);
                if(!sql || !sql.trim()) {
                    if(dom) { self.disposePreviewChart(); dom.innerHTML = ""; var d=document.createElement("div"); d.className="ai-preview-error"; d.textContent="Please enter SQL"; dom.appendChild(d); }
                    return;
                }
                if(dom) { self.disposePreviewChart(); dom.innerHTML = ""; var ld=document.createElement("div"); ld.className="ai-preview-loading"; ld.textContent="⏳ Testing..."; dom.appendChild(ld); }
                apex.server.plugin(self.ajax, {x01:"TEST_SQL", x03:sql}, {
                    success: function(r) {
                        if(r.status === "success" && r.data) { self.chartEditData.data = r.data; self.updateChartPreview(); }
                        else { var d=document.getElementById("chart_preview_"+self.id); if(d){ self.disposePreviewChart(); d.innerHTML=""; var e=document.createElement("div"); e.className="ai-preview-error"; e.textContent="❌ "+(r.message||"No data"); d.appendChild(e); } }
                    },
                    error: function(x,s,e) { var d=document.getElementById("chart_preview_"+self.id); if(d){ self.disposePreviewChart(); d.innerHTML=""; var ed=document.createElement("div"); ed.className="ai-preview-error"; ed.textContent="❌ "+e; d.appendChild(ed); } }
                });
            },

            updateChartPreview: function() {
                var $=apex.jQuery, self=this;
                if(this.isUpdatingPreview) return;
                this.isUpdatingPreview = true;
                var dom = document.getElementById("chart_preview_"+this.id);
                if(!dom) { this.isUpdatingPreview = false; return; }
                this.disposePreviewChart();
                var data = this.chartEditData ? this.chartEditData.data : null;
                if(!data || data.length === 0) {
                    dom.innerHTML = "";
                    var d = document.createElement("div"); d.className = "ai-preview-loading"; d.textContent = "No data"; dom.appendChild(d);
                    this.isUpdatingPreview = false; return;
                }
                dom.innerHTML = "";
                var selEl = document.querySelector("#chart_type_grid_"+this.id+" .selected");
                var selType = selEl ? selEl.getAttribute("data-type") : "bar";
                var type = selType.toLowerCase().replace(/_/g, "");
                try {
                    this.chartPreviewInstance = echarts.init(dom);
                    var opt = this.buildChartOption(type, data, {}, "Preview");
                    this.chartPreviewInstance.setOption(opt, {notMerge:true});
                } catch(e) { dom.innerHTML = ""; var ed=document.createElement("div"); ed.className="ai-preview-error"; ed.textContent="Error: "+e.message; dom.appendChild(ed); }
                this.isUpdatingPreview = false;
            },

            closeChartEdit: function() {
                var $=apex.jQuery;
                if(this.chartPreviewDebounce) { clearTimeout(this.chartPreviewDebounce); this.chartPreviewDebounce = null; }
                this.disposePreviewChart();
                if(this.chartEditEditor) { try { this.chartEditEditor.toTextArea(); } catch(e) {} this.chartEditEditor = null; }
                $("#chart_edit_"+this.id).hide();
                this.chartEditIndex = null; this.chartEditData = null; this.isUpdatingPreview = false;
            },

            saveChartEdit: function() {
                var $=apex.jQuery, self=this;
                if(this.chartEditIndex === null || !this.currentQueryId) { alert("No chart selected"); return; }
                var newTitle = $("#chart_edit_title_"+this.id).val().trim();
                var newSql = this.chartEditEditor ? this.chartEditEditor.getValue() : "";
                var selEl = document.querySelector("#chart_type_grid_"+this.id+" .selected");
                var newType = selEl ? selEl.getAttribute("data-type") : null;
                var saveBtn = $("#chart_save_btn_"+this.id);
                saveBtn.prop("disabled", true).html("⏳ Saving...");
                apex.server.plugin(self.ajax, { x01:"UPDATE_CHART", x02:String(this.currentQueryId), x03:JSON.stringify({chart_index:this.chartEditIndex, sql:newSql, chart_type:newType, title:newTitle}) }, {
                    success: function(r) {
                        saveBtn.prop("disabled", false).html("💾 Save Changes");
                        if(r.status === "success") { self.closeChartEdit(); setTimeout(function(){ self.loadChat(self.currentQueryId, "DASHBOARD"); }, 100); }
                        else { alert("Error: " + (r.message || "Failed")); }
                    },
                    error: function(x,s,e) { saveBtn.prop("disabled", false).html("💾 Save Changes"); alert("Error: " + e); }
                });
            },
            refreshChart: function(idx) { if(this.currentQueryId) this.loadChat(this.currentQueryId, "DASHBOARD"); },

            exportChart: function(idx) {
                var chart = this.dashboardCharts["dashchart_" + idx + "_" + this.id];
                if(!chart) return;
                var url = chart.getDataURL({type:"png",pixelRatio:2,backgroundColor:"#fff"});
                var a = document.createElement("a"); a.download = "chart_" + idx + ".png"; a.href = url;
                document.body.appendChild(a); a.click(); document.body.removeChild(a);
            },

            deleteChart: function(idx) {
                var self = this, $=apex.jQuery;
                var targetIdx = (typeof idx === "number") ? idx : this.chartEditIndex;
                if(targetIdx === null || targetIdx === undefined) { alert("No chart selected"); return; }
                if(!this.currentQueryId) { alert("No dashboard loaded"); return; }
                this.showModal("Delete Chart", "Are you sure you want to delete this chart?", function() {
                    var deleteBtn = $("#chart_delete_btn_"+self.id);
                    if(deleteBtn.length) deleteBtn.prop("disabled", true).text("Deleting...");
                    apex.server.plugin(self.ajax, {x01:"DELETE_CHART", x02:String(self.currentQueryId), x03:String(targetIdx)}, {
                        success: function(r) {
                            if(deleteBtn.length) deleteBtn.prop("disabled", false).text("🗑 Delete Chart");
                            if(r && r.status === "success") {
                                self.closeChartEdit();
                                self.loadChat(self.currentQueryId, "DASHBOARD");
                            } else {
                                alert("Error: " + (r && r.message ? r.message : "Delete failed"));
                            }
                        },
                        error: function(x,s,e) {
                            if(deleteBtn.length) deleteBtn.prop("disabled", false).text("🗑 Delete Chart");
                            alert("Error: " + e);
                        }
                    });
                });
            },
');


        -- Part 4: Report rendering and remaining functions
        DBMS_LOB.APPEND(l_js, '
            renderKPIs: function(kpiData) {
                var $=apex.jQuery, self=this, k=$("#kpis_"+this.id); k.empty();
                try {
                    var d=(typeof kpiData==="string")?JSON.parse(kpiData):kpiData;
                    if(Array.isArray(d)) d.forEach(function(i, idx){
                        var t=i.title?i.title:"Metric"; 
                        var v=i.value?i.value:"-";
                        var colorClass=self.kpiColors[idx % self.kpiColors.length];
                        var iconEmoji=self.getIconEmoji(i.icon);
                        var icon=iconEmoji?iconEmoji:self.kpiIcons[idx % self.kpiIcons.length];
                        var html="<div class=\"aid-kpi "+colorClass+"\">";
                        html+="<div class=\"aid-kpi-header\">"+self.escapeHtml(t)+"</div>";
                        html+="<div class=\"aid-kpi-body\"><div class=\"aid-kpi-content\">";
                        html+="<div class=\"aid-kpi-value\">"+self.escapeHtml(String(v))+"</div>";
                        html+="</div><div class=\"aid-kpi-icon\">"+icon+"</div></div></div>";
                        k.append(html);
                    });
                }catch(e){ console.error("KPI render error:", e); }
            },

            renderDynamicTable: function(data) {
                var $=apex.jQuery,self=this,c=$("#dyn_content_"+this.id);c.empty();
                if(!data || !data.data || data.data.length===0){c.html("<div class=\"ai-no-data\">📭 No data available</div>");return;}
                var toolbarHtml="<div class=\"ai-table-toolbar\"><input type=\"text\" class=\"ai-search-sm\" placeholder=\"🔍 Filter...\" onkeyup=\"window.AID_' || l_id || '.filterTable(this.value)\"><div class=\"ai-toolbar-actions\"><div class=\"ai-dropdown\"><button type=\"button\" class=\"ai-drop-btn\">⬇️ Export ▼</button><div class=\"ai-dropdown-content\"><a onclick=\"window.AID_' || l_id || '.exportXLSX()\">📊 Excel</a><a onclick=\"window.AID_' || l_id || '.exportHTML()\">🌐 HTML</a><a onclick=\"window.AID_' || l_id || '.exportPDF()\">📄 PDF</a></div></div></div></div>";
                var h=Object.keys(data.data[0]),html="<div class=\"ai-table-container\">"+toolbarHtml+"<div class=\"ai-table-scroll-area\"><table id=\"tbl_' || l_id || '\" class=\"ai-dyn-table\"><thead><tr>";
                h.forEach(function(k){html+="<th>"+k+"</th>";});
                html+="</tr></thead><tbody>";
                data.data.forEach(function(r){html+="<tr>";h.forEach(function(k){var v=r[k];html+="<td>"+(v!==null?(typeof v==="number"?v.toLocaleString():v):"")+"</td>";});html+="</tr>";});
                html+="</tbody></table></div></div>";
                c.html(html);
            },

            filterTable: function(txt) { var f=txt.toUpperCase(),tbl=document.getElementById("tbl_"+this.id); if(!tbl)return; var tr=tbl.getElementsByTagName("tr"); for(var i=1;i<tr.length;i++){var td=tr[i].getElementsByTagName("td"),show=false; for(var j=0;j<td.length;j++){if(td[j]){var t=td[j].textContent; if(t && t.toUpperCase().indexOf(f)>-1){show=true;break;}}}tr[i].style.display=show?"":"none";} },
            exportXLSX: function() { var tbl=document.getElementById("tbl_"+this.id); if(!tbl)return; var wb=XLSX.utils.table_to_book(tbl,{sheet:"Sheet1"}); XLSX.writeFile(wb,"report_data.xlsx"); },
            exportHTML: function() { var tbl=document.getElementById("tbl_"+this.id); if(!tbl)return; var html="<html><head><style>table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:8px}th{background:#3b82f6;color:#fff}</style></head><body>"+tbl.outerHTML+"</body></html>"; var blob=new Blob([html],{type:"text/html"}); var link=document.createElement("a"); link.href=URL.createObjectURL(blob); link.download="report.html"; document.body.appendChild(link); link.click(); document.body.removeChild(link); },
            exportPDF: function() { var tbl=document.getElementById("tbl_"+this.id); if(!tbl)return; try{var jsPDFObj=window.jspdf;var doc=new jsPDFObj.jsPDF();doc.autoTable({html:"#tbl_"+this.id,startY:20});doc.save("report.pdf");}catch(e){alert("PDF error");} },

            renderChart: function(data,config,overrideType) {
                var $=apex.jQuery,self=this,dom=document.getElementById("chart_container_"+this.id);
                if(!dom)return;
                try{if(this.echartsInstance){this.echartsInstance.dispose();this.echartsInstance=null;}}catch(e){}
                if(!data || !data.data || data.data.length===0){$(dom).html("<div class=\"ai-no-data\">📈 No chart data</div>");return;}
                var cfg=config?config:{}; if(typeof config==="string"){try{cfg=JSON.parse(config);}catch(e){}}
                this.echartsInstance=echarts.init(dom);
                var chartType = overrideType ? overrideType : (cfg.chartType ? cfg.chartType : (cfg.type ? cfg.type : "bar"));
                this.currentReportChartType = chartType;
                var type=chartType.toLowerCase().replace(/_/g,"").replace(/-/g,"");
                var opt=this.buildChartOption(type,data.data,cfg,"");
                this.echartsInstance.setOption(opt);
                window.addEventListener("resize",function(){if(self.echartsInstance)self.echartsInstance.resize();});
            },

            renderReportChartTypes: function(currentType) {
                var $=apex.jQuery, self=this;
                var grid = $("#report_chart_types_"+this.id);
                if(!grid.length) return;
                var types = [
                    {id:"column",name:"Column",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"10\" width=\"4\" height=\"10\" rx=\"1\"/><rect x=\"10\" y=\"6\" width=\"4\" height=\"14\" rx=\"1\"/><rect x=\"17\" y=\"3\" width=\"4\" height=\"17\" rx=\"1\"/></svg>"},
                    {id:"stacked_column",name:"Stacked Column",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"10\" width=\"4\" height=\"10\" rx=\"1\"/><rect x=\"3\" y=\"6\" width=\"4\" height=\"4\" rx=\"0\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"10\" y=\"6\" width=\"4\" height=\"14\" rx=\"1\"/><rect x=\"10\" y=\"2\" width=\"4\" height=\"4\" rx=\"0\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"17\" y=\"8\" width=\"4\" height=\"12\" rx=\"1\"/><rect x=\"17\" y=\"4\" width=\"4\" height=\"4\" rx=\"0\" fill=\"currentColor\" opacity=\"0.3\"/></svg>"},
                    {id:"bar",name:"Bar",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"4\" y=\"3\" width=\"10\" height=\"4\" rx=\"1\"/><rect x=\"4\" y=\"10\" width=\"16\" height=\"4\" rx=\"1\"/><rect x=\"4\" y=\"17\" width=\"7\" height=\"4\" rx=\"1\"/></svg>"},
                    {id:"stacked_bar",name:"Stacked Bar",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"4\" y=\"3\" width=\"8\" height=\"4\" rx=\"1\"/><rect x=\"12\" y=\"3\" width=\"4\" height=\"4\" rx=\"0\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"4\" y=\"10\" width=\"12\" height=\"4\" rx=\"1\"/><rect x=\"16\" y=\"10\" width=\"4\" height=\"4\" rx=\"0\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"4\" y=\"17\" width=\"6\" height=\"4\" rx=\"1\"/><rect x=\"10\" y=\"17\" width=\"3\" height=\"4\" rx=\"0\" fill=\"currentColor\" opacity=\"0.3\"/></svg>"},
                    {id:"line",name:"Line",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><polyline points=\"4,18 8,12 12,15 16,8 20,4\"/><circle cx=\"4\" cy=\"18\" r=\"1.5\" fill=\"currentColor\"/><circle cx=\"8\" cy=\"12\" r=\"1.5\" fill=\"currentColor\"/><circle cx=\"12\" cy=\"15\" r=\"1.5\" fill=\"currentColor\"/><circle cx=\"16\" cy=\"8\" r=\"1.5\" fill=\"currentColor\"/><circle cx=\"20\" cy=\"4\" r=\"1.5\" fill=\"currentColor\"/></svg>"},
                    {id:"combo",name:"Combo",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"12\" width=\"4\" height=\"8\" rx=\"1\"/><rect x=\"10\" y=\"8\" width=\"4\" height=\"12\" rx=\"1\"/><rect x=\"17\" y=\"10\" width=\"4\" height=\"10\" rx=\"1\"/><polyline points=\"5,8 12,4 19,6\" stroke-dasharray=\"2,1\"/></svg>"},
                    {id:"area",name:"Area",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M4,18 L8,12 L12,14 L16,8 L20,10 L20,20 L4,20 Z\" fill=\"currentColor\" opacity=\"0.2\"/><polyline points=\"4,18 8,12 12,14 16,8 20,10\"/></svg>"},
                    {id:"stacked_area",name:"Stacked Area",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M4,18 L8,14 L12,16 L16,12 L20,14 L20,20 L4,20 Z\" fill=\"currentColor\" opacity=\"0.2\"/><path d=\"M4,14 L8,10 L12,12 L16,8 L20,10 L20,14 L16,12 L12,16 L8,14 L4,18 Z\" fill=\"currentColor\" opacity=\"0.3\"/></svg>"},
                    {id:"pie",name:"Pie",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12,3 L12,12 L20,8\" fill=\"currentColor\" opacity=\"0.2\"/></svg>"},
                    {id:"donut",name:"Donut",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"9\"/><circle cx=\"12\" cy=\"12\" r=\"5\"/><path d=\"M12,3 A9,9 0 0,1 21,12 L17,12 A5,5 0 0,0 12,7 Z\" fill=\"currentColor\" opacity=\"0.2\"/></svg>"},
                    {id:"scatter",name:"Scatter",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"6\" cy=\"16\" r=\"2\" fill=\"currentColor\"/><circle cx=\"10\" cy=\"10\" r=\"2\" fill=\"currentColor\"/><circle cx=\"14\" cy=\"14\" r=\"2\" fill=\"currentColor\"/><circle cx=\"18\" cy=\"6\" r=\"2\" fill=\"currentColor\"/><circle cx=\"8\" cy=\"6\" r=\"2\" fill=\"currentColor\"/></svg>"},
                    {id:"bubble",name:"Bubble",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"7\" cy=\"15\" r=\"4\" fill=\"currentColor\" opacity=\"0.2\"/><circle cx=\"15\" cy=\"10\" r=\"5\" fill=\"currentColor\" opacity=\"0.2\"/><circle cx=\"17\" cy=\"17\" r=\"3\" fill=\"currentColor\" opacity=\"0.2\"/></svg>"},
                    {id:"pareto",name:"Pareto",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"14\" width=\"3\" height=\"6\" rx=\"1\"/><rect x=\"8\" y=\"10\" width=\"3\" height=\"10\" rx=\"1\"/><rect x=\"13\" y=\"12\" width=\"3\" height=\"8\" rx=\"1\"/><rect x=\"18\" y=\"16\" width=\"3\" height=\"4\" rx=\"1\"/><polyline points=\"4,10 9,6 14,4 19,3\"/></svg>"},
                    {id:"waterfall",name:"Waterfall",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"2\" y=\"14\" width=\"3\" height=\"6\" rx=\"1\"/><rect x=\"7\" y=\"10\" width=\"3\" height=\"4\" rx=\"1\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"12\" y=\"6\" width=\"3\" height=\"4\" rx=\"1\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"17\" y=\"6\" width=\"4\" height=\"14\" rx=\"1\"/><line x1=\"5\" y1=\"14\" x2=\"7\" y2=\"14\" stroke-dasharray=\"2,1\"/><line x1=\"10\" y1=\"10\" x2=\"12\" y2=\"10\" stroke-dasharray=\"2,1\"/></svg>"},
                    {id:"treemap",name:"Treemap",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"3\" width=\"10\" height=\"10\" rx=\"1\"/><rect x=\"15\" y=\"3\" width=\"6\" height=\"6\" rx=\"1\" fill=\"currentColor\" opacity=\"0.2\"/><rect x=\"15\" y=\"11\" width=\"6\" height=\"10\" rx=\"1\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"3\" y=\"15\" width=\"5\" height=\"6\" rx=\"1\" fill=\"currentColor\" opacity=\"0.2\"/><rect x=\"10\" y=\"15\" width=\"3\" height=\"6\" rx=\"1\"/></svg>"},
                    {id:"heatmap",name:"Heatmap",icon:"<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"3\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.8\"/><rect x=\"10\" y=\"3\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.4\"/><rect x=\"17\" y=\"3\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.2\"/><rect x=\"3\" y=\"10\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.5\"/><rect x=\"10\" y=\"10\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.9\"/><rect x=\"17\" y=\"10\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"3\" y=\"17\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.3\"/><rect x=\"10\" y=\"17\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.6\"/><rect x=\"17\" y=\"17\" width=\"5\" height=\"5\" rx=\"1\" fill=\"currentColor\" opacity=\"0.7\"/></svg>"}
                ];
                var currUp = currentType ? currentType.toLowerCase().replace(/-/g,"_") : "column";
                var h = "";
                for(var i=0; i<types.length; i++) {
                    var t = types[i];
                    var sel = (currUp === t.id) ? " selected" : "";
                    h += "<div class=\"ai-report-chart-type-item" + sel + "\" data-type=\"" + t.id + "\" onclick=\"window.AID_"+self.id+".selectReportChartType(this)\">";
                    h += "<div class=\"ai-rct-icon\">" + t.icon + "</div>";
                    h += "<div class=\"ai-rct-name\">" + t.name + "</div>";
                    h += "</div>";
                }
                grid.html(h);
            },

            selectReportChartType: function(el) {
                var $=apex.jQuery, self=this;
                var newType = el.getAttribute("data-type");
                if(!newType || !this.currentReportData) return;
                var grid = document.getElementById("report_chart_types_"+this.id);
                if(grid) {
                    var items = grid.querySelectorAll(".ai-report-chart-type-item");
                    for(var i=0; i<items.length; i++) { items[i].classList.remove("selected"); }
                }
                el.classList.add("selected");
                this.renderChart(this.currentReportData, this.currentReportConfig, newType);
                this.saveReportChartType(newType);
            },

            saveReportChartType: function(chartType) {
                var self = this;
                if(!this.currentQueryId) return;
                apex.server.plugin(self.ajax, {
                    x01: "SAVE_CHART_TYPE",
                    x02: String(this.currentQueryId),
                    x03: chartType
                }, {
                    success: function(r) { },
                    error: function() { }
                });
            },

            processResult: function(d) {
                var $=apex.jQuery, self=this;
                if(d.status==="error"){$("#err_"+self.id).text(d.message).show();return;}

                $("#dashboard_view_"+this.id).removeClass("active");
                $("#report_view_"+this.id).addClass("active");
                $("#welcome_"+self.id).addClass("hidden");
                $("#content_wrapper_"+self.id).css("display","flex");

                if(d.query_id) self.currentQueryId=d.query_id;
                if(d.report_title) $("#report_title_"+self.id).html(d.report_title).fadeIn();
                $("#interaction_"+self.id).addClass("hidden");

                if(d.data && d.data.length>0)$("#tabs_"+self.id).css("display","flex");
                if(d.kpis)self.renderKPIs(d.kpis);
                self.renderDynamicTable(d);

                // Store data for chart type changes
                self.currentReportData = d;
                self.currentReportConfig = d.chart_config;
                var savedChartType = d.saved_chart_type || (d.chart_config && d.chart_config.chartType) || "column";
                self.renderChart(d, d.chart_config, savedChartType);
                self.renderReportChartTypes(savedChartType);
                
                if(d.generated_sql){var fmtSql=self.formatSql(d.generated_sql);if(self.cmEditor)self.cmEditor.setValue(fmtSql);else $("#sql_editor_"+self.id).val(fmtSql);}
                $(".aid-chat-item").removeClass("active");
                                if(d.data && d.data.length > 0) {
                    self.pivotData = d.data;
                    self.pivotInitialized = false;
                    
                    if(d.pivot_recommended && d.pivot_config) {
                        self.pivotConfig = d.pivot_config;
                        if(d.pivot_reason) {
                            self.showPivotRecommendation(d.pivot_reason, d.pivot_config);
                        }
                    } else {
                        self.hidePivotRecommendation();
                    }
                    
                    // Dispose old pivot instance
                    if(self.pivotInstance) {
                        try { self.pivotInstance.dispose(); } catch(e) {}
                        self.pivotInstance = null;
                    }
                }
                $(".aid-chat-item[data-id=\""+self.currentQueryId+"\"]").addClass("active");
            },

            go: function() {
                var $=apex.jQuery,self=this,q=$("#inp_"+self.id).val().trim();
                if(!q)return;
                
                // Client-side validation for meaningless input
                var validationError = self.validateQuestion(q);
                if(validationError) {
                    $("#err_"+self.id).text(validationError).show();
                    // Keep input visible so user can fix it
                    return;
                }
                
                // Hide error from previous attempts
                $("#err_"+self.id).hide();
                
                // Smart Intent Detection: Auto-detect dashboard intent from keywords
                var detectedIntent = self.detectIntent(q);
                if(detectedIntent === "dashboard" && self.currentCategory !== "Dashboard Builder") {
                    self.currentCategory = "Dashboard Builder";
                    $(".ai-mode-btn").removeClass("active");
                    $("#mode_dashboard_"+self.id).addClass("active");
                }
                
                var err=$("#err_"+self.id);
                $("#interaction_"+self.id).addClass("hidden");
                $("#welcome_"+self.id).addClass("hidden");
                $("#content_wrapper_"+self.id).hide();
                
                // Show skeleton based on detected intent
                self.showSkeleton(detectedIntent);
                
                apex.server.plugin(self.ajax,{x01:"GENERATE",x02:q,x04:self.currentCategory},{
                    success:function(r){
                        if(!r || r.status==="error"){
                            var errMsg = r ? r.message : "Error";
                            self.hideSkeleton();
                            err.text(errMsg).show();
                            // Show interaction area again if validation error
                            if(r && r.validation_error) {
                                $("#interaction_"+self.id).removeClass("hidden");
                            }
                            return;
                        }
                        self.currentQueryId=r.query_id;
                        self.loadHistory();
                        $("#inp_"+self.id).val("").css("height","auto");
                        
                        apex.server.plugin(self.ajax,{x01:"DATA",x02:String(r.query_id)},{
                            success:function(d){
                                self.hideSkeleton();
                                if(d.query_type==="DASHBOARD"){
                                    self.renderDashboard(d);
                                }else{
                                    self.processResult(d);
                                }
                            },
                            error:function(x,s,e){
                                self.hideSkeleton();
                                err.text("Error: "+e).show();
                            }
                        });
                    },
                    error:function(x,s,e){
                        self.hideSkeleton();
                        err.text("Error: "+e).show();
                    }
                });
            },

            runSql: function() {
                var $=apex.jQuery,self=this;
                var sql=self.cmEditor?self.cmEditor.getValue():$("#sql_editor_"+self.id).val();
                if(!sql || !sql.trim() || !self.currentQueryId)return;
                var err=$("#err_"+self.id);
                err.hide();
                self.showSkeleton("report");
                apex.server.plugin(self.ajax,{x01:"UPDATE_SQL",x02:String(self.currentQueryId),x03:sql},{
                    success:function(d){self.hideSkeleton();self.processResult(d);self.switchTab("report");},
                    error:function(x,s,e){self.hideSkeleton();err.text("Error: "+e).show();}
                });
            }
        };
        
        window.AID_' || l_id || '.init();');


        


        htp.p('<script type="text/javascript">');
        htp.p('document.addEventListener("DOMContentLoaded", function() {');
        
        DECLARE
            l_chunk_size CONSTANT PLS_INTEGER := 3000;
            l_offset     PLS_INTEGER := 1;
            l_clob_len   PLS_INTEGER;
        BEGIN
            l_clob_len := dbms_lob.getlength(l_js);
            WHILE l_offset <= l_clob_len LOOP
                htp.prn(dbms_lob.substr(l_js, l_chunk_size, l_offset));
                l_offset := l_offset + l_chunk_size;
            END LOOP;
        END;
        
        htp.p('});');
        htp.p('</script>');

        DBMS_LOB.FREETEMPORARY(l_js);
    END render_dashboard;

    -- AJAX Handler
-- AJAX Handler
    PROCEDURE ajax_handler(
        p_region IN apex_plugin.t_region,
        p_plugin IN apex_plugin.t_plugin,
        p_param IN apex_plugin.t_region_ajax_param,
        p_result IN OUT NOCOPY apex_plugin.t_region_ajax_result
    ) IS
        l_act VARCHAR2(50) := apex_application.g_x01;
        l_p1 VARCHAR2(4000) := apex_application.g_x02;
        l_p2 CLOB := apex_application.g_x03;
        l_p3 VARCHAR2(4000) := apex_application.g_x04;
        l_current_schema VARCHAR2(128);
        l_out CLOB;
    BEGIN
        -- Set JSON header
        owa_util.mime_header('application/json', FALSE);
        owa_util.http_header_close;
        
        l_current_schema := NVL(apex_application.g_flow_owner, USER);
        
        BEGIN
            IF l_act = 'SUGGEST' THEN
                AI_CORE_PKG.GET_SUGGESTIONS(l_current_schema, NVL(l_p1, 'REPORT'), l_out);
                htp.p('{"suggestions":'); -- Start Object
                PRINT_CLOB(NVL(l_out,'[]'));
                htp.p('}'); -- End Object
                
            ELSIF l_act = 'GENERATE' THEN
                AI_CORE_PKG.GENERATE_INSIGHTS(TO_CLOB(l_p1), l_current_schema, NVL(l_p3,'General'), l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error","message":"Empty response"}'));
                
            ELSIF l_act = 'DATA' THEN
                AI_CORE_PKG.EXECUTE_AND_RENDER(TO_NUMBER(l_p1), l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error","message":"No data returned"}'));
                
            ELSIF l_act = 'UPDATE_SQL' THEN
                AI_CORE_PKG.UPDATE_QUERY(TO_NUMBER(l_p1), l_p2, l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error","message":"Update failed"}'));

            ELSIF l_act = 'SAVE_CHART_TYPE' THEN
                -- l_p1 = Query ID, l_p2 = Chart Type (stored in x03 but passed as l_p2 in this context, actually x03)
                DECLARE
                    l_query_id NUMBER := TO_NUMBER(l_p1);
                    l_chart_type VARCHAR2(100) := SUBSTR(l_p2, 1, 100);
                BEGIN
                    UPDATE ASKLYZE_AI_QUERY_STORE
                    SET SAVED_CHART_TYPE = l_chart_type
                    WHERE ID = l_query_id;
                    COMMIT;
                    htp.p('{"status":"success"}');
                EXCEPTION WHEN OTHERS THEN
                    htp.p('{"status":"error","message":"' || REPLACE(SQLERRM, '"', '''') || '"}');
                END;

            ELSIF l_act = 'HISTORY' THEN
                AI_CORE_PKG.GET_CHAT_HISTORY(p_user => NULL, p_limit => 50, p_offset => 0, p_search => l_p1, p_result_json => l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error","message":"History empty"}'));
                
            ELSIF l_act = 'DELETE_CHAT' THEN
                AI_CORE_PKG.DELETE_CHAT(TO_NUMBER(l_p1), l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error"}'));
                
            ELSIF l_act = 'TOGGLE_FAV' THEN
                AI_CORE_PKG.TOGGLE_FAVORITE(TO_NUMBER(l_p1), l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error"}'));
                
            ELSIF l_act = 'RENAME_CHAT' THEN
                AI_CORE_PKG.RENAME_CHAT(TO_NUMBER(l_p1), l_p3, l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error"}'));
                
            ELSIF l_act = 'CLEAR_HISTORY' THEN
                AI_CORE_PKG.CLEAR_HISTORY(NULL, l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error"}'));

                ELSIF l_act = 'SAVE_LAYOUT' THEN
                -- l_p1 = Query ID, l_p2 = Layout JSON
                AI_CORE_PKG.SAVE_DASHBOARD_LAYOUT(TO_NUMBER(l_p1), l_p2, l_out);
                PRINT_CLOB(l_out);

            ELSIF l_act = 'RESET_LAYOUT' THEN
                AI_CORE_PKG.RESET_DASHBOARD_LAYOUT(TO_NUMBER(l_p1), l_out);
                PRINT_CLOB(l_out);

                        ELSIF l_act = 'CAT_LIST' THEN
                DECLARE
                    l_org_id NUMBER := 1;
                    l_owner VARCHAR2(128) := l_current_schema;
                    l_has_schema NUMBER := 0;
                BEGIN
                    SELECT COUNT(*) INTO l_has_schema FROM asklyze_catalog_schemas WHERE org_id = l_org_id AND UPPER(schema_owner) = UPPER(l_owner);
                    IF l_has_schema = 0 THEN
                        AI_CORE_PKG.CATALOG_REFRESH_SCHEMA(l_org_id, l_owner, 'FULL', NULL, l_out);
                    END IF;
                    
                    apex_json.initialize_clob_output;
                    apex_json.open_object;
                    apex_json.write('status', 'success');
                    apex_json.open_array('tables');
                    FOR r IN (
                        SELECT t.id, t.object_name, t.object_type, 
                               NVL(t.is_whitelisted,'N') w, 
                               NVL(t.is_enabled,'Y') e, 
                               t.summary_en, 
                               t.table_comment,
                               t.business_domain,
                               t.relevance_score,
                               t.num_rows
                        FROM asklyze_catalog_tables t 
                        JOIN asklyze_catalog_schemas s ON s.id = t.schema_id
                        WHERE s.org_id = l_org_id AND UPPER(s.schema_owner) = UPPER(l_owner)
                        ORDER BY t.is_whitelisted DESC, t.relevance_score DESC NULLS LAST, t.object_type, t.object_name
                    ) LOOP
                        apex_json.open_object;
                        apex_json.write('id', r.id);
                        apex_json.write('object_name', r.object_name);
                        apex_json.write('object_type', r.object_type);
                        apex_json.write('is_whitelisted', r.w);
                        apex_json.write('is_enabled', r.e);
                        apex_json.write('summary_en', r.summary_en);
                        apex_json.write('table_comment', r.table_comment);
                        apex_json.write('business_domain', r.business_domain);
                        apex_json.write('relevance_score', r.relevance_score);
                        apex_json.write('num_rows', r.num_rows);
                        apex_json.close_object;
                    END LOOP;
                    apex_json.close_array;
                    apex_json.close_object;
                    
                    l_out := apex_json.get_clob_output;
                    apex_json.free_output;
                    PRINT_CLOB(l_out);
                END;


            ELSIF l_act = 'CAT_SEARCH' THEN
                DECLARE
                    l_keywords VARCHAR2(4000) := l_p1;
                    l_domain VARCHAR2(100) := l_p2;
                BEGIN
                    l_out := AI_CORE_PKG.CATALOG_SEARCH_TABLES(
                        p_org_id       => 1,
                        p_schema_owner => l_current_schema,
                        p_keywords     => l_keywords,
                        p_domain       => l_domain,
                        p_max_results  => 20
                    );
                    PRINT_CLOB(NVL(l_out, '{"results":[]}'));
                EXCEPTION WHEN OTHERS THEN
                    htp.p('{"status":"error","message":"' || REPLACE(SQLERRM,'"','`') || '"}');
                END;

            ELSIF l_act = 'CAT_CONTEXT' THEN
                DECLARE
                    l_domain VARCHAR2(100) := l_p1;
                    l_max NUMBER := NVL(TO_NUMBER(l_p2), 30);
                BEGIN
                    l_out := AI_CORE_PKG.CATALOG_GET_SEMANTIC_CONTEXT(
                        p_org_id       => 1,
                        p_schema_owner => l_current_schema,
                        p_domain       => l_domain,
                        p_max_tables   => l_max
                    );
                    PRINT_CLOB(NVL(l_out, '{"tables":[]}'));
                EXCEPTION WHEN OTHERS THEN
                    htp.p('{"status":"error","message":"' || REPLACE(SQLERRM,'"','`') || '"}');
                END;


            ELSIF l_act = 'CAT_STATS' THEN
                BEGIN
                    l_out := AI_CORE_PKG.CATALOG_GET_STATS(
                        p_org_id       => 1,
                        p_schema_owner => l_current_schema
                    );
                    PRINT_CLOB(NVL(l_out, '{"error":"No stats"}'));
                EXCEPTION WHEN OTHERS THEN
                    htp.p('{"status":"error","message":"' || REPLACE(SQLERRM,'"','`') || '"}');
                END;

            ELSIF l_act = 'CAT_APPLY' THEN
                DECLARE
                    l_org_id NUMBER := 1;
                    l_owner VARCHAR2(128) := l_current_schema;
                    -- ... variables ...
                    l_dummy CLOB; l_refresh CLOB; l_ai CLOB;
                    l_cnt NUMBER; l_name VARCHAR2(4000); 
                    TYPE t_set IS TABLE OF VARCHAR2(1) INDEX BY VARCHAR2(4000); l_sel t_set;
                BEGIN
                    IF l_p2 IS NOT NULL THEN
                         apex_json.parse(l_p2);
                         l_cnt := apex_json.get_count('selected');
                         FOR i IN 1..l_cnt LOOP
                             l_name := apex_json.get_varchar2('selected[%d]', i);
                             IF l_name IS NOT NULL THEN l_sel(UPPER(TRIM(l_name))) := 'Y'; END IF;
                         END LOOP;
                    END IF;
                    
                    FOR r IN (SELECT t.object_name, t.object_type FROM asklyze_catalog_tables t JOIN asklyze_catalog_schemas s ON s.id=t.schema_id WHERE s.org_id=l_org_id AND UPPER(s.schema_owner)=UPPER(l_owner)) LOOP
                        AI_CORE_PKG.CATALOG_SET_WHITELIST(l_org_id, l_owner, r.object_name, r.object_type, CASE WHEN l_sel.EXISTS(UPPER(r.object_name)) THEN 'Y' ELSE 'N' END, 'Y', NULL, l_dummy);
                    END LOOP;
                    
                    AI_CORE_PKG.CATALOG_REFRESH_SCHEMA(l_org_id, l_owner, 'INCR', NULL, l_refresh);
                    AI_CORE_PKG.CATALOG_AI_DESCRIBE_SCHEMA(l_org_id, l_owner, 'Y', 50, 'N', l_ai);
                    
                    apex_json.initialize_clob_output;
                    apex_json.open_object;
                    apex_json.write('status', 'success');
                    apex_json.write_raw('refresh', NVL(l_refresh,'{}'));
                    apex_json.write_raw('ai', NVL(l_ai,'{}'));
                    apex_json.close_object;
                    l_out := apex_json.get_clob_output;
                    apex_json.free_output;
                    PRINT_CLOB(l_out);
                EXCEPTION WHEN OTHERS THEN
                    htp.p('{"status":"error","message":"' || REPLACE(SQLERRM,'"','`') || '"}');
                END;

            ELSIF l_act = 'CHART_TYPES' THEN
                AI_CORE_PKG.GET_CHART_TYPES(l_out);
                PRINT_CLOB(NVL(l_out,'{"status":"error"}'));
                
            ELSIF l_act = 'TEST_SQL' THEN
                -- ... implementation similar to before, ensure using PRINT_CLOB ...
                DECLARE
                    l_cursor SYS_REFCURSOR;
                    l_sql CLOB := AI_CORE_PKG.CLEAN_AI_SQL(l_p2); -- p2 has sql
                BEGIN
                    -- ... (logic to execute sql and output json via apex_json) ...
                    -- l_out := apex_json.get_clob_output;
                    -- PRINT_CLOB(l_out);
                    
                    -- Quick implementation wrapper:
                    l_out := AI_CORE_PKG.EXECUTE_SQL_TO_JSON(l_sql); -- Reuse the function we fixed in CORE
                    PRINT_CLOB('{"status":"success","data":' || NVL(l_out,'[]') || '}');
                EXCEPTION WHEN OTHERS THEN
                     htp.p('{"status":"error","message":"' || REPLACE(SQLERRM,'"','`') || '"}');
                END;
                
            ELSIF l_act = 'UPDATE_CHART' THEN
                DECLARE
                     l_query_id NUMBER := TO_NUMBER(l_p1);
                     l_idx NUMBER; l_nsql CLOB; l_type VARCHAR2(100); l_title VARCHAR2(500);
                BEGIN
                     apex_json.parse(l_p2);
                     l_idx := apex_json.get_number('chart_index');
                     l_nsql := apex_json.get_clob('sql');
                     l_type := apex_json.get_varchar2('chart_type');
                     l_title := apex_json.get_varchar2('title');
                     AI_CORE_PKG.UPDATE_DASHBOARD_CHART(l_query_id, l_idx, l_nsql, l_type, l_title, l_out);
                     PRINT_CLOB(l_out);
                END;
            
            ELSIF l_act = 'DELETE_CHART' THEN
                AI_CORE_PKG.DELETE_DASHBOARD_CHART(
                    p_query_id    => TO_NUMBER(l_p1),
                    p_chart_index => TO_NUMBER(l_p2),
                    p_result_json => l_out
                );
                PRINT_CLOB(NVL(l_out,'{"status":"error"}'));

            ELSE
                htp.p('{"status":"error","message":"Unknown action: ' || l_act || '"}');
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
             htp.p('{"status":"error","message":"Global Error: ' || REPLACE(SQLERRM,'"','`') || '"}');
        END;
    END ajax_handler;

END AI_UI_PKG;
/
