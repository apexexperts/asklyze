(function () {
  if (window.mqDashNavInit) { return; }
  window.mqDashNavInit = true;

  // --- دوال HTML ---
  function liHeader(title) {
    return $(`
      <li class="nav-header" role="presentation" style="padding: 12px 16px; font-weight: bold; color: #555; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px;">
        <span>${title}</span>
      </li>
    `);
  }
  
  function liLink(item) {
    const isCur = (item.is_current === "YES");
    const activeClass = isCur ? "is-selected" : ""; 
    const activeStyle = isCur ? "background-color: rgba(0,0,0,0.05); font-weight: bold;" : "";
    
    return $(`
      <li id="menu_${item.id}" class="a-TreeView-node a-TreeView-node--leaf ${activeClass}">
        <div class="a-TreeView-content ${activeClass}" style="${activeStyle}">
          ${item.icon ? `<span class="${item.icon}" style="margin-right:8px;"></span>` : ""}
          <a class="a-TreeView-label" href="${item.target || "#"}" data-id="${item.id}" style="text-decoration:none; color:inherit; flex-grow:1;">
            ${item.title}
          </a>
        </div>
      </li>
    `);
  }

  // --- دالة تحديث القائمة (AJAX) ---
  window.refreshDashMenu = function() {
    try { $("#t_TreeNav").off(); } catch (e) { }

    // هام جداً: نرسل P0_DATABASE_SCHEMA ليتم استخدامه في الفلترة
    apex.server.process("GET_DASH_NAV", {
      pageItems: "#P3_DASH_ID,#P0_DATABASE_SCHEMA" 
    }, {
      success: function (data) {
        const $navContainer = $("#t_TreeNav");
        let $menu = $navContainer.find("ul").first();
        
        if ($menu.length === 0) {
            if ($navContainer.length === 0) return; 
            $navContainer.html('<ul class="a-TreeView-list" role="tree"></ul>');
            $menu = $navContainer.find("ul").first();
        } else {
            $menu.empty();
        }

        if (!Array.isArray(data) || data.length === 0) {
             $menu.html('<li style="padding:10px; color:#777;">No items found.</li>');
             return;
        }

        const historyHeader = data.find(x => x.is_header === "YES" && x.title === "Dashboard History");
        const rootItems = data.filter(x => x.parent_id == null && x.is_header !== "YES");
        
        // 1. العناصر الأساسية
        rootItems.forEach(item => {
            $menu.append(liLink(item));
        });

        $menu.append('<li style="border-bottom: 1px solid #e0e0e0; margin: 8px 0;"></li>');

        // 2. الهيستوري (سيتغير الآن بناءً على السكيما)
        if (historyHeader) {
            $menu.append(liHeader(historyHeader.title));
            const timeGroups = data.filter(x => x.parent_id === historyHeader.id && x.is_header === "YES");
            
            let hasChildren = false;
            timeGroups.forEach(group => {
                const children = data.filter(x => x.parent_id === group.id);
                if(children.length > 0) {
                    hasChildren = true;
                    $menu.append(liHeader(group.title));
                    children.forEach(child => {
                        $menu.append(liLink(child));
                    });
                }
            });
            
            if (!hasChildren) {
                 $menu.append('<li style="padding:8px 16px; font-size:12px; color:#999;">No history for this schema</li>');
            }
        }
      },
      error: function(jqXHR, textStatus) {
          console.error("Menu Load Error:", textStatus);
      }
    });
  };

  // --- التعامل مع النقرات (بدون ريلود) ---
  $("body").off("click", "#t_TreeNav a, #t_TreeNav .a-TreeView-label");
  $("body").on("click", "#t_TreeNav a, #t_TreeNav .a-TreeView-label", async function (e) {
    e.preventDefault();
    e.stopImmediatePropagation(); 

    const $el = $(this);
    const href = $el.attr("href");

    $("#t_TreeNav .a-TreeView-content").removeClass("is-selected").css("font-weight", "normal").css("background-color", "transparent");
    $el.closest(".a-TreeView-content").addClass("is-selected").css("font-weight", "bold").css("background-color", "rgba(0,0,0,0.05)");

    const saveSession = async (items) => {
        try {
            await apex.server.process("SET_SESSION_STATE", { 
                pageItems: items 
            }, { dataType: "json" }); 
        } catch (err) { console.warn("Session save warning:", err); }
    };

    // 1. New Dashboard
    if (href === "#new") {
      apex.item("P3_DASH_ID").setValue("");
      apex.item("P3_QUESTION").setValue("");
      if(apex.item("P3_PLAN_JSON")) apex.item("P3_PLAN_JSON").setValue("");
      
      await saveSession("#P3_DASH_ID,#P3_QUESTION,#P3_PLAN_JSON");

      $("#mq_dash, #mqDashboard, .mq-dashboard-region").empty();
      $("#mq_chart, #mqKpiSection, #mqOverview").hide();
      $("#P3_QUESTION_CONTAINER").show();
      if(window.apex && apex.item("P3_QUESTION")) apex.item("P3_QUESTION").setFocus();
      
      window.refreshDashMenu();
      return;
    }

    // 2. History Item (AJAX Load)
    if (href && href.startsWith("#dash-")) {
      const dashId = href.split("-")[1];
      apex.item("P3_DASH_ID").setValue(dashId);
      
      await saveSession("#P3_DASH_ID");
      
      if (typeof window.renderHeaderAndOverview === "function") {
         $("#mqPlaceholder").remove();
         // إخفاء السؤال عند فتح داشبورد سابق (اختياري)
         // $("#P3_QUESTION_CONTAINER").hide();
         await window.renderHeaderAndOverview();
      } else {
         // فقط إذا فشل كل شيء نلجأ للريلود
         window.location.reload();
      }
      return;
    }
    
    if (href && href.startsWith("f?p=")) {
        window.location.assign(href);
    }
  });

  // *** الجزء الأهم: الاستماع لتغيير السكيما ***
  // بمجرد تغيير القيمة، يتم تحديث القائمة فوراً بدون ريلود
  $(document).on("change", "#P0_DATABASE_SCHEMA", function() {
      window.refreshDashMenu();
  });

  // التحميل الأولي
  $(function() {
      window.refreshDashMenu();
  });

})();
