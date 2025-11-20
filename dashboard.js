--Function and Global Variable Declaration
(function () {
  const ITEM_Q           = "P3_QUESTION";
  const ITEM_PLAN_JSON   = "P3_PLAN_JSON";
  const ITEM_DASH_ID     = "P3_DASH_ID";
  const REGION_STATIC_ID = "mq_dash";
  const $d = document;
  const sel = (q, el = $d) => el.querySelector(q);
  const escapeHTML = txt =>
    txt == null
      ? ""
      : String(txt)
          .replace(/&/g, "&amp;")
          .replace(/</g, "&lt;")
          .replace(/>/g, "&gt;");
  function normalizeItemToken(token) {
    if (!token) { return null; }
    let t = token.trim();
    if (!t) { return null; }
    if (!t.startsWith("#")) { t = `#${t}`; }
    if (!t.endsWith("#")) { t = `${t}#`; }
    return t;
  }
  function callProcess(name, opts) {
    const options = {};
    const payload = { ...(opts || {}) };

    if (payload.dataType) {
      options.dataType = payload.dataType;
      delete payload.dataType;
    } else {
      options.dataType = "json";
    }
    if (payload.pageItems) {
      const pageItems = Array.isArray(payload.pageItems)
        ? payload.pageItems
        : String(payload.pageItems).split(",");
      const formatted = pageItems
        .map(normalizeItemToken)
        .filter(Boolean)
        .join(",");
      if (formatted) {
        options.pageItems = formatted;
      }
      delete payload.pageItems;
    }
    return apex.server.process(name, payload, options);
  }
  const sectionReady = { overview: false, kpis: false, charts: false };
  const LOADING_PLACEHOLDER_ID = "mqLoadingPlaceholder";
  let loadingStylesInjected = false;
  const STEPS = [
    { key: "plan",    label: "Planning" },
    { key: "create",  label: "Creating dashboard" },
    { key: "overview",label: "Generating overview" },
    { key: "kpis",    label: "Generating KPIs" },
    { key: "chart",   label: "Creating charts" },
    { key: "final",   label: "Finalizing" }
  ];
  function ensureProgress() {
    let wrap = sel("#mqBuildProgress");
    if (wrap) return wrap;
    wrap = $d.createElement("div");
    wrap.id = "mqBuildProgress";
    wrap.style.cssText = "position:static;margin:16px auto 12px;background:#e83d8e;color:#fff;border:1px solid #2d2d2d;border-radius:16px;box-shadow:0 16px 32px rgba(0,0,0,.35);padding:16px 20px;width:min(775px,calc(100% - 32px));font:14px/1.4 system-ui,Segoe UI,Roboto,Arial;";
    wrap.innerHTML = `
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px">
        <strong style="font-size:14px">AI Dashboard Builder</strong>
        <span id="mqBuildStatus" style="color:#bbb"></span>
        <span id="mqBuildPct" style="margin-inline-start:auto;color:#bbb">0%</span>
      </div>
      <div id="mqBuildSteps" style="display:flex;gap:8px;margin-bottom:10px;flex-wrap:nowrap;justify-content:space-between"></div>
      <div style="height:6px;background:#222;border-radius:999px;overflow:hidden">
        <div id="mqBuildBar" style="height:100%;width:0%;background:#2563eb;transition:width .25s ease"></div>
      </div>`;
    const steps = sel("#mqBuildSteps", wrap);
    STEPS.forEach(s => {
      const chip = $d.createElement("div");
      chip.className = "mq-step"; chip.dataset.key = s.key;
      chip.style.cssText = "flex:1;min-width:0;text-align:center;padding:4px 8px;border-radius:999px;border:1px solid #333;color:#000;background:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis";
      chip.textContent = s.label; steps.appendChild(chip);
    });
    const placeholder = sel(`#${LOADING_PLACEHOLDER_ID}`);
    if (placeholder && placeholder.parentElement) {
      placeholder.parentElement.insertBefore(wrap, placeholder.nextSibling);
    } else {
      $d.body.appendChild(wrap);
    }
    return wrap;
  }
  function setStepActive(key, sub = "") {
    ensureProgress();
    const status = sel("#mqBuildStatus");
    const chipEls = Array.from($d.querySelectorAll(".mq-step"));
    chipEls.forEach(c => {
      if (c.dataset.key === key) {
        c.style.borderColor = "#2563eb"; c.style.background = "#111a2b"; c.style.color = "#e5e5e5"; c.style.fontWeight = "600";
      } else if (STEPS.findIndex(s => s.key === c.dataset.key) < STEPS.findIndex(s => s.key === key)) {
        c.style.borderColor = "#16a34a"; c.style.background = "#0a2c22"; c.style.color = "#baf7d0";
      }
    });
    if (status) status.textContent = sub ? `— ${sub}` : "";
    const pct = Math.round((STEPS.findIndex(s => s.key === key) / (STEPS.length - 1)) * 100);
    const bar = sel("#mqBuildBar"); const pctEl = sel("#mqBuildPct");
    if (bar) bar.style.width = Math.max(1, pct) + "%";
    if (pctEl) pctEl.textContent = Math.max(1, pct) + "%";
  }
  function finishProgress(ok, msg = "") {
    const bar = sel("#mqBuildBar"); const status = sel("#mqBuildStatus"); const pctEl = sel("#mqBuildPct");
    if (bar) bar.style.width = "100%"; if (pctEl) pctEl.textContent = "100%";
    if (status) status.textContent = msg ? `— ${msg}` : (ok ? "Done" : "Error");
    setTimeout(() => { const wrap = sel("#mqBuildProgress"); if (wrap) wrap.remove(); }, 1800);
  }
  function setElementDisplay(el, show) {
    if (!el) return;
    if (show) {
      if (Object.prototype.hasOwnProperty.call(el.dataset, "mqPrevDisplay")) {
        el.style.display = el.dataset.mqPrevDisplay || "";
      } else {
        el.style.removeProperty("display");
      }
    } else {
      if (!Object.prototype.hasOwnProperty.call(el.dataset, "mqPrevDisplay")) {
        el.dataset.mqPrevDisplay = el.style.display || "";
      }
      el.style.display = "none";
    }
  }
  function toggleQuestionArea(show) {
    const apexItem = typeof apex !== "undefined" && apex.item ? apex.item(ITEM_Q) : null;
    const apexNode = apexItem && (apexItem.node || apexItem.element || (apexItem.getElement && apexItem.getElement()));
    const inputEl = apexNode || sel(`#${ITEM_Q}`);
    const container =
      sel(`#${ITEM_Q}_CONTAINER`) ||
      (inputEl && inputEl.closest ? inputEl.closest(".t-Form-fieldContainer") : null);
    const region =
      (container && container.closest ? container.closest(".t-Region") : null) ||
      (inputEl && inputEl.closest ? inputEl.closest(".t-Region") : null);
    const chatCard = sel(".mq-chat-card") || sel(".mq-chat-box");
    const placeholder = sel("#mqPlaceholder");

    const targets = [inputEl, container, region, chatCard, placeholder];
    const seen = new Set();
    targets.forEach(el => {
      if (!el || seen.has(el)) return;
      seen.add(el);
      setElementDisplay(el, show);
    });
  }
  function fadeIn(el) {
    if (!el) return;
    el.style.transition = "none";
    el.style.opacity = "0";
    el.style.transform = "translateY(14px)";
    requestAnimationFrame(() => {
      el.style.transition = "opacity .45s ease, transform .45s ease";
      el.style.opacity = "1";
      el.style.transform = "translateY(0)";
    });
  }

  function ensurePlaceholderStyles() {
    if (loadingStylesInjected) return;
    loadingStylesInjected = true;
    const style = document.createElement("style");
    style.textContent = `
      @keyframes mqSkeletonSlide {
        0% { background-position: -200px 0; }
        100% { background-position: calc(200px + 100%) 0; }
      }
      .mq-skeleton {
        display:block;
        background: linear-gradient(90deg, #f3f3f3 25%, #e5e5e5 37%, #f3f3f3 63%);
        background-size: 400% 100%;
        animation: mqSkeletonSlide 1.4s ease infinite;
        border-radius: 999px;
        margin: 8px 0;
      }
      .mq-placeholder-card {
        border: 1px solid #ececec;
        border-radius: 12px;
        padding: 20px;
        margin-bottom: 16px;
        background: #fff;
        box-shadow: 0 8px 20px rgba(15,23,42,0.05);
      }
      .mq-placeholder-card + .mq-placeholder-card {
        margin-top: 18px;
      }
      .mq-placeholder-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 12px;
        font: 600 15px/1.4 system-ui,Segoe UI,Roboto,Arial;
        color: #0f172a;
      }
      .mq-placeholder-subtext {
        font: 500 12px/1.4 system-ui,Segoe UI,Roboto,Arial;
        color: #94a3b8;
      }
      .mq-placeholder-kpis {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
        gap: 12px;
      }
      .mq-placeholder-kpi {
        border: 1px solid #ececec;
        border-radius: 12px;
        padding: 12px;
        background: #fff;
        box-shadow: 0 6px 16px rgba(15,23,42,0.08);
      }
      .mq-placeholder-kpi .mq-skeleton:first-child {
        width: 60%;
        height: 12px;
      }
      .mq-placeholder-kpi .mq-skeleton:last-child {
        width: 50%;
        height: 24px;
        margin-top: 12px;
        border-radius: 12px;
      }
      .mq-placeholder-chart-grid {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 16px;
      }
      @media (max-width: 1024px) {
        .mq-placeholder-chart-grid {
          grid-template-columns: repeat(2, minmax(0, 1fr));
        }
      }
      @media (max-width: 640px) {
        .mq-placeholder-chart-grid {
          grid-template-columns: repeat(1, minmax(0, 1fr));
        }
      }
      .mq-chart-placeholder {
        border: 1px solid #e8eaed;
        border-radius: 16px;
        padding: 16px;
        min-height: 220px;
        background: #fff;
        box-shadow: 0 10px 25px rgba(15,23,42,0.08);
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      .mq-chart-placeholder-type {
        font: 600 13px/1.3 system-ui,Segoe UI,Roboto,Arial;
        color: #475569;
      }
      .mq-placeholder-bars,
      .mq-placeholder-line,
      .mq-placeholder-area {
        flex: 1;
        display: flex;
        align-items: flex-end;
        gap: 6px;
        height: 120px;
      }
      .mq-placeholder-line {
        align-items: center;
      }
      .mq-placeholder-bars .mq-skeleton,
      .mq-placeholder-area .mq-skeleton {
        flex: 1;
      }
      .mq-placeholder-pie,
      .mq-placeholder-donut {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .mq-placeholder-pie span,
      .mq-placeholder-donut .mq-donut-ring {
        width: 110px;
        height: 110px;
        border-radius: 50%;
      }
      .mq-placeholder-donut .mq-donut {
        position: relative;
      }
      .mq-placeholder-donut .mq-donut-hole {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        width: 48px;
        height: 48px;
        border-radius: 50%;
        background: #fff;
        box-shadow: inset 0 4px 12px rgba(15,23,42,0.08);
      }
      .mq-placeholder-table {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 10px;
      }
      .mq-placeholder-table span {
        height: 12px;
      }
    `;
    document.head.appendChild(style);
  }

  function showBuildPlaceholders() {
    ensurePlaceholderStyles();
    const region =
      document.getElementById(REGION_STATIC_ID) ||
      sel("#mqDashboard") ||
      sel(".t-Region") ||
      $d.body;
    if (!region || !region.parentElement) return;
    removeBuildPlaceholders();

    const placeholder = $d.createElement("div");
    placeholder.id = LOADING_PLACEHOLDER_ID;
    placeholder.style.margin = "20px 0";
    placeholder.innerHTML = `
      <div class="mq-placeholder-card">
        <div class="mq-placeholder-header">
          <span></span>
          <span class="mq-placeholder-subtext"></span>
        </div>
        <span class="mq-skeleton" style="width:180px;height:16px;"></span>
        <span class="mq-skeleton" style="width:100%;height:12px;"></span>
        <span class="mq-skeleton" style="width:95%;height:12px;"></span>
        <span class="mq-skeleton" style="width:88%;height:12px;"></span>
        <span class="mq-skeleton" style="width:70%;height:12px;"></span>
      </div>
      <div class="mq-placeholder-card">
        <div class="mq-placeholder-header">
          <span></span>
          <span class="mq-placeholder-subtext"></span>
        </div>
        <div class="mq-placeholder-kpis">
          ${Array.from({ length: 4 })
            .map(
              () => `
            <div class="mq-placeholder-kpi">
              <span class="mq-skeleton"></span>
              <span class="mq-skeleton"></span>
            </div>`
            )
            .join("")}
        </div>
      </div>
      <div class="mq-placeholder-card">
        <div class="mq-placeholder-header">
          <span></span>
          <span class="mq-placeholder-subtext"></span>
        </div>
        <div class="mq-placeholder-chart-grid">
          <div class="mq-chart-placeholder">
            <div class="mq-chart-placeholder-type"></div>
            <div class="mq-placeholder-bars">
              <span class="mq-skeleton" style="height:30%;"></span>
              <span class="mq-skeleton" style="height:55%;"></span>
              <span class="mq-skeleton" style="height:80%;"></span>
              <span class="mq-skeleton" style="height:45%;"></span>
            </div>
          </div>
          <div class="mq-chart-placeholder">
            <div class="mq-chart-placeholder-type"></div>
            <div class="mq-placeholder-line" style="gap:10px;">
              <span class="mq-skeleton" style="width:12%;height:4px;"></span>
              <span class="mq-skeleton" style="width:18%;height:4px;"></span>
              <span class="mq-skeleton" style="width:10%;height:4px;"></span>
              <span class="mq-skeleton" style="width:20%;height:4px;"></span>
              <span class="mq-skeleton" style="width:14%;height:4px;"></span>
            </div>
          </div>
          <div class="mq-chart-placeholder">
            <div class="mq-chart-placeholder-type"></div>
            <div class="mq-placeholder-area">
              <span class="mq-skeleton" style="height:20%;"></span>
              <span class="mq-skeleton" style="height:45%;"></span>
              <span class="mq-skeleton" style="height:70%;"></span>
              <span class="mq-skeleton" style="height:90%;"></span>
              <span class="mq-skeleton" style="height:60%;"></span>
            </div>
          </div>
          <div class="mq-chart-placeholder">
            <div class="mq-chart-placeholder-type"></div>
            <div class="mq-placeholder-pie">
              <span class="mq-skeleton"></span>
            </div>
          </div>
          <div class="mq-chart-placeholder">
            <div class="mq-chart-placeholder-type"></div>
            <div class="mq-placeholder-donut">
              <div class="mq-donut">
                <span class="mq-skeleton mq-donut-ring"></span>
                <span class="mq-donut-hole"></span>
              </div>
            </div>
          </div>
          <div class="mq-chart-placeholder">
            <div class="mq-chart-placeholder-type"></div>
            <div class="mq-placeholder-table">
              <span class="mq-skeleton" style="width:80%;"></span>
              <span class="mq-skeleton" style="width:65%;"></span>
              <span class="mq-skeleton" style="width:90%;"></span>
              <span class="mq-skeleton" style="width:55%;"></span>
              <span class="mq-skeleton" style="width:70%;"></span>
            </div>
          </div>
        </div>
      </div>
    `;
    region.parentElement.insertBefore(placeholder, region);
    const progress = sel("#mqBuildProgress");
    if (progress) {
      placeholder.parentElement.insertBefore(progress, placeholder.nextSibling);
    }
  }

  function removeBuildPlaceholders() {
    const existing = document.getElementById(LOADING_PLACEHOLDER_ID);
    if (existing) existing.remove();
  }
  function ensureQuestionActionButton() {
    const apexItem = typeof apex !== "undefined" && apex.item ? apex.item(ITEM_Q) : null;
    const inputEl =
      apexItem && (apexItem.node || apexItem.element || (apexItem.getElement && apexItem.getElement()));
    if (!inputEl || inputEl.dataset.mqHasButton) {
      return;
    }
    const container =
      sel(`#${ITEM_Q}_CONTAINER`) ||
      (inputEl.closest ? inputEl.closest(".t-Form-fieldContainer") : null) ||
      inputEl.parentElement;
    if (!container) {
      return;
    }
    const label = container.querySelector("label");
    if (label) {
      label.style.display = "none";
    }
    const inputWrapper =
      inputEl.closest(".t-Form-inputContainer") ||
      inputEl.closest(".t-Form-itemWrapper") ||
      inputEl.parentElement;
    if (!inputWrapper) {
      return;
    }
    const shell = $d.createElement("div");
    shell.className = "mq-question-shell";
    shell.style.cssText =
      "width:100%;max-width:880px;margin:60px auto 30px;padding:0 8px;";
    const inputShell = $d.createElement("div");
    inputShell.className = "mq-question-wrap";
    inputShell.style.cssText =
      "position:relative;display:flex;align-items:center;background:#fff;border-radius:24px;box-shadow:0 20px 55px rgba(15,23,42,.18);padding:16px 22px;";
    container.style.display = "block";
    container.style.border = "none";
    container.style.padding = "0";
    container.style.background = "transparent";
    container.appendChild(shell);
    shell.appendChild(inputShell);
    inputWrapper.style.margin = "0";
    inputWrapper.style.flex = "1";
    inputWrapper.style.width = "100%";
    inputShell.appendChild(inputWrapper);
    inputEl.style.width = "100%";
    inputEl.style.minHeight = "64px";
    inputEl.style.border = "none";
    inputEl.style.background = "transparent";
    inputEl.style.outline = "none";
    inputEl.style.font = "500 18px/1.5 system-ui,Segoe UI,Roboto,Arial";
    inputEl.style.color = "#0f172a";
    inputEl.style.resize = "none";
    inputEl.style.padding = "0";
    inputEl.style.paddingRight = "60px";
    if (!inputEl.placeholder) {
      inputEl.placeholder = "Ask your question…";
    }
    const triggerBuild = () => {
      if (typeof window.runDashboardBuilder === "function") {
        window.runDashboardBuilder();
      }
    };
    const actionBtn = $d.createElement("button");
    actionBtn.type = "button";
    actionBtn.className = "mq-question-action";
    actionBtn.innerHTML =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 2L11 13"></path><path d="M22 2L15 22 11 13 2 9z"></path></svg>';
    actionBtn.style.cssText =
      "position:absolute;right:18px;top:50%;transform:translateY(-50%);width:35px;height:35px;border:none;border-radius:6px;background:#e83d8e;color:#fff;display:flex;align-items:center;justify-content:center;box-shadow:0 18px 30px rgba(37,99,235,.3);cursor:pointer;transition:transform .2s,box-shadow .2s;z-index:2;";
    actionBtn.addEventListener("mouseenter", () => {
      actionBtn.style.transform = "translateY(calc(-50% - 1px))";
      actionBtn.style.boxShadow = "0 22px 34px rgba(37,99,235,.35)";
    });
    actionBtn.addEventListener("mouseleave", () => {
      actionBtn.style.transform = "translateY(-50%)";
      actionBtn.style.boxShadow = "0 18px 30px rgba(37,99,235,.3)";
    });
    actionBtn.addEventListener("click", evt => {
      evt.preventDefault();
      evt.stopPropagation();
      triggerBuild();
    });
    inputShell.appendChild(actionBtn);
    inputEl.addEventListener("keydown", evt => {
      if (evt.key === "Enter" && !evt.shiftKey) {
        evt.preventDefault();
        triggerBuild();
      }
    });
    const helper = container.querySelector(".t-Form-itemHelp");
    if (helper) helper.style.display = "none";
    inputEl.dataset.mqHasButton = "1";
  }
async function renderHeaderAndOverview() {
  const region =
    document.getElementById(REGION_STATIC_ID) ||
    sel("#mqDashboard") ||
    sel(".t-Region") ||
    $d.body;
  if (!region) return;
  let meta = null;
  try {
    const res = await callProcess("GET_DASH_META", {
      pageItems: [ITEM_DASH_ID, ITEM_Q, "P0_DATABASE_SCHEMA"]
    });
    if (res && res.ok) {
      meta = res;
      const userQuestion =
        apex.item(ITEM_Q) && apex.item(ITEM_Q).getValue
          ? apex.item(ITEM_Q).getValue()
          : null;

      if (!meta.title && userQuestion) {
        meta.title = userQuestion;
      }
    }
  } catch (e) {
    console.error("GET_DASH_META failed:", e);
    return;
  }
  if (!meta) {
    console.error("No meta data available");
    return;
  }
  if (region) {
    const existingCards = region.parentElement
      ? region.parentElement.querySelectorAll(".mq-card")
      : [];
    existingCards.forEach(function (card) {
      card.remove();
    });
  }
  const header = sel("#mqHeader");
  if (header) header.remove();
  const titleBlock = sel("#mqTitleBlock");
  if (titleBlock) titleBlock.remove();
  const insightsSection = sel("#mqInsights");
  if (insightsSection) insightsSection.remove();
  let kpisData = [];
  try {
    if (meta.kpis) {
      const kpisJson =
        typeof meta.kpis === "string" ? JSON.parse(meta.kpis) : meta.kpis;
      kpisData = (kpisJson && kpisJson.kpis) || [];
    } else if (meta.visual_options && meta.chart_type === "KPI") {
      const visualOpts =
        typeof meta.visual_options === "string"
          ? JSON.parse(meta.visual_options)
          : meta.visual_options;
      if (visualOpts && Array.isArray(visualOpts.kpis)) {
        kpisData = visualOpts.kpis;
      }
    }
  } catch (e) {
    console.warn("KPI parsing error:", e);
  }
  function formatKpiValue(kpi) {
    const raw = kpi.value != null ? String(kpi.value) : "";
    const unit = (kpi.unit || "").toLowerCase();
    if (!unit) return raw;
    if (unit === "currency") return raw;
    if (unit === "%") return raw + "%";
    if (unit === "tasks") return raw;
    return raw + " " + kpi.unit;
  }
  function getKpiIconClass(kpi) {
    var icon = (kpi && kpi.icon) ? String(kpi.icon).trim() : "";
    if (!icon) {
      return "fa-chart-line";
    }
    if (icon.indexOf(" ") >= 0) {
      var parts = icon.split(/\s+/).filter(function (p) {
        return p.indexOf("fa-") === 0;
      });
      if (parts.length) {
        icon = parts[0];
      }
    }
    if (!/^fa-/.test(icon)) {
      icon = "fa-" + icon.replace(/^fa[-\s]*/i, "");
    }
    return icon;
  }
  const parent = region.parentElement || $d.body;
  let kpiHtml = "";
  if (kpisData.length > 0) {
    const kpiCards = kpisData
      .map(function (kpi) {
        var color = kpi.color || "#2563eb";
        var iconClass = getKpiIconClass(kpi);
        return `
      <div class="mq-kpi" style="
        flex: 1;
        min-width: 220px;
        padding: 20px 24px;
        border: 1px solid #e5e7eb;
        border-radius: 12px;
        background: #ffffff;
        text-align: center;
        transition: all 0.3s ease;
        cursor: pointer;
        position: relative;
        overflow: hidden;
      " onmouseover="this.style.transform='translateY(-4px)'; this.style.boxShadow='0 8px 25px rgba(0,0,0,0.15)'; this.style.borderColor='${color}';"
        onmouseout="this.style.transform='translateY(0)'; this.style.boxShadow='0 2px 8px rgba(0,0,0,0.1)'; this.style.borderColor='#e5e7eb';">
        <div class="mq-kpi-inner" style="
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 6px;
        ">
          <div class="mq-kpi-icon" style="
            font-size: 32px;
            line-height: 1;
            color: ${color};
          ">
            <span class="t-Icon fa ${iconClass}" aria-hidden="true"></span>
          </div>
          <div class="mq-kpi-value" style="
            font: 600 26px/1.25 system-ui,Segoe UI,Roboto,Arial;
            color: ${color};
          ">
            ${formatKpiValue(kpi)}
          </div>
          <div class="mq-kpi-label" style="
            font: 500 13px/1.4 system-ui,Segoe UI,Roboto,Arial;
            color: #6b7280;
          ">
            ${kpi.title || ""}
          </div>
        </div>
        <div class="mq-kpi-accent" style="
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          height: 3px;
          background: ${color};
          opacity: 0;
          transition: opacity 0.3s ease;
        "></div>
      </div>`;
      })
      .join("");
    kpiHtml =
    //   '<h4 style="margin:16px 0 12px;font:600 16px/1.4 system-ui,Segoe UI,Roboto,Arial;">Key Metrics</h4>' +
      '<div style="display:flex;gap:16px;flex-wrap:wrap;margin-bottom:16px;">' +
      kpiCards +
      "</div>";
  }
  let ov = sel("#mqOverview");
  if (!ov) {
    ov = $d.createElement("section");
    ov.id = "mqOverview";
    ov.className = "mq-card";
    ov.style.cssText =
      "margin:6px 0 16px;padding:16px;border:1px solid #f5f4f2;border-radius:12px;background:#fff;";
    if (parent) parent.insertBefore(ov, region);
  }
  if (!sectionReady.overview) {
    ov.style.display = "none";
    delete ov.dataset.mqShown;
  } else {
    ov.style.display = "";
    const ovHtml =
      '<div style="font:600 16px/1.4 system-ui;">Overview</div>' +
      '<div style="margin-top:6px;font:14px/1.6 system-ui;color:#000;">' +
      (meta.overview || meta.subtitle || "") +
      "</div>";
    if (ov.dataset.mqContent !== ovHtml) {
      ov.innerHTML = ovHtml;
      ov.dataset.mqContent = ovHtml;
      if (!ov.dataset.mqShown) {
        fadeIn(ov);
        ov.dataset.mqShown = "1";
      }
    } else if (!ov.dataset.mqShown) {
      fadeIn(ov);
      ov.dataset.mqShown = "1";
    }
  }

  let kpiSection = sel("#mqKpiSection");
  if (!kpiSection) {
    kpiSection = $d.createElement("section");
    kpiSection.id = "mqKpiSection";
    kpiSection.className = "mq-card";
    // kpiSection.style.cssText =
    //   "margin:0 0 20px;padding:16px;border:1px solid #f5f4f2;border-radius:12px;background:#fbf9f8;";
    if (parent) parent.insertBefore(kpiSection, region);
  }
  if (!sectionReady.kpis) {
    kpiSection.style.display = "none";
    delete kpiSection.dataset.mqShown;
  } else {
    kpiSection.style.display = "";
    const kpiContent = kpiHtml || '<div style="font:14px/1.5 system-ui;">No KPIs available yet.</div>';
    if (kpiSection.dataset.mqContent !== kpiContent) {
      kpiSection.innerHTML = kpiContent;
      kpiSection.dataset.mqContent = kpiContent;
      kpiSection.dataset.mqShown = "1";
      fadeIn(kpiSection);
    } else if (!kpiSection.dataset.mqShown) {
      fadeIn(kpiSection);
      kpiSection.dataset.mqShown = "1";
    }
    if (kpisData.length > 0) {
      kpiSection.querySelectorAll(".mq-kpi").forEach(function (kpi) {
        const accent = kpi.querySelector(".mq-kpi-accent");
        kpi.addEventListener("mouseenter", function () {
          if (accent) accent.style.opacity = "1";
        });
        kpi.addEventListener("mouseleave", function () {
          if (accent) accent.style.opacity = "0";
        });
      });
    }
  }

  let chartContainer = sel("#mq_chart");
  if (!chartContainer) {
    chartContainer = $d.createElement("div");
    chartContainer.id = "mq_chart";
    chartContainer.className = "mq-card mq-chart-section";
    // chartContainer.style.cssText =
    //   "margin:0 0 20px;padding:16px;border:1px solid #f5f4f2;border-radius:12px;background:#fff;";
    if (parent) parent.insertBefore(chartContainer, region);
  }
  if (!sectionReady.charts) {
    chartContainer.style.display = "none";
    chartContainer.innerHTML = "";
    delete chartContainer.dataset.mqShown;
  } else {
    chartContainer.style.display = "";
    await renderChartSection(meta);
    if (!chartContainer.dataset.mqShown) {
      fadeIn(chartContainer);
      chartContainer.dataset.mqShown = "1";
    }
  }
}
  window.runDashboardBuilder = async function () {
    apex.message.clearErrors();
    ensureProgress();
    toggleQuestionArea(false);
    sectionReady.overview = false;
    sectionReady.kpis = false;
    sectionReady.charts = false;
    ["#mqOverview", "#mqKpiSection", "#mq_chart"].forEach(id => {
      const el = sel(id);
      if (el) {
        el.style.display = "none";
        delete el.dataset.mqShown;
      }
    });
    showBuildPlaceholders();
    try {
      setStepActive("plan", "Planning layout and blocks…");
      const rawPlan = await callProcess("DASH_PLAN", {
        pageItems: [ITEM_Q, "P0_DATABASE_SCHEMA"],
        dataType: "text"
      });
      let planRes = rawPlan;
      if (typeof rawPlan === "string") {
        try {
          planRes = JSON.parse(rawPlan);
        } catch (err) {
          throw new Error("Invalid JSON from server (PLAN).");
        }
      }
      if (!planRes || planRes.ok !== true) {
        throw new Error((planRes && (planRes.error || planRes.title)) || "Planner failed.");
      }
      if (planRes.plan) apex.item(ITEM_PLAN_JSON).setValue(planRes.plan);
    } catch (e) {
      apex.message.showErrors([{ type: "error", location: "page", message: e.message }]);
      finishProgress(false, "Failed at Planning");
      removeBuildPlaceholders();
      toggleQuestionArea(true);
      return;
    }
    let dashId = null;
    try {
      setStepActive("create", "Creating dashboard and widgets…");
      const createRes = await callProcess("DASH_CREATE_BLOCKS", {
        pageItems: [ITEM_PLAN_JSON, ITEM_Q]
      });
      if (!createRes || createRes.ok !== true) {
        throw new Error((createRes && createRes.error) || "Create failed.");
      }
      dashId = createRes.dashboardId || apex.item(ITEM_DASH_ID).getValue();
      if (!dashId) throw new Error("No dashboardId returned.");
      apex.item(ITEM_DASH_ID).setValue(String(dashId));
    } catch (e) {
      apex.message.showErrors([{ type: "error", location: "page", message: e.message }]);
      finishProgress(false, "Failed at Creating");
      removeBuildPlaceholders();
      toggleQuestionArea(true);
      return;
    }
    try {
      setStepActive("overview", "AI generating overview…");
      await callProcess("DASH_GEN_OVERVIEW", { pageItems: [ITEM_DASH_ID, "P0_DATABASE_SCHEMA"] });
      sectionReady.overview = true;
    } catch (e) {
      console.warn("OVERVIEW warn", e);
    }
    try {
      setStepActive("kpis", "AI generating KPI metrics…");
      await callProcess("DASH_GEN_KPIS", { pageItems: [ITEM_DASH_ID, "P0_DATABASE_SCHEMA"] });
      sectionReady.kpis = true;
    } catch (e) {
      console.warn("KPIS warn", e);
    }
    try {
      setStepActive("chart", "AI creating chart with insights…");
      await callProcess("DASH_GEN_CHART", {
        pageItems: [ITEM_DASH_ID, "P0_DATABASE_SCHEMA", ITEM_Q]
      });
      sectionReady.charts = true;
    } catch (e) {
      console.warn("CHART warn", e);
    }
    try {
      setStepActive("final", "Finalizing dashboard…");
      await callProcess("DASH_FINALIZE", { pageItems: [ITEM_DASH_ID, "P0_DATABASE_SCHEMA"] });
    } catch (e) {
      console.warn("FINAL warn", e);
    }
    const placeholder = sel("#mqPlaceholder");
    if (placeholder) placeholder.remove();

    setStepActive("final", "Rendering AI-generated content…");
    sectionReady.overview = true;
    sectionReady.kpis = true;
    sectionReady.charts = true;
    await renderHeaderAndOverview();
    removeBuildPlaceholders();
    finishProgress(true, "Dashboard ready");
    apex.message.showPageSuccess("Dashboard ready with AI-generated content.");
    toggleQuestionArea(true);
  };
  document.addEventListener("DOMContentLoaded", async () => {
    ensureQuestionActionButton();
    const dashId = apex.item(ITEM_DASH_ID).getValue();
    if (dashId) {
      sectionReady.overview = true;
      sectionReady.kpis = true;
      sectionReady.charts = true;
      await renderHeaderAndOverview();
    } else {
      const region = sel("#mqDashboard") || sel("#" + REGION_STATIC_ID) || sel(".t-Region") || $d.body;
      if (region && region.parentElement) {
        const existingCards = region.parentElement.querySelectorAll(".mq-card");
        existingCards.forEach(card => card.remove());

        const placeholder = $d.createElement("div");
        placeholder.id = "mqPlaceholder";
        placeholder.style.cssText =
          "margin:130px auto 12px;padding-right:140px;text-align:center;color:#475569;font:15px/1.6 system-ui;max-width:640px;";
        placeholder.innerHTML = `
          <p style="margin:0 0 8px;font-size:18px;font-weight:600;">Ready to create your AI-powered dashboard</p>
          <p style="margin:0;font-size:15px;">Enter your question and click "Generate Dashboard" to begin</p>
        `;
        region.parentElement.insertBefore(placeholder, region);
      }
    }
  });
})();
(function (apex, $) {
  let mqChartInstances = [];
  let leafletLoader = null;

  const escapeHTML = txt =>
    txt == null
      ? ""
      : String(txt)
          .replace(/&/g, "&amp;")
          .replace(/</g, "&lt;")
          .replace(/>/g, "&gt;");

  function ensureLeaflet() {
    if (window.L && typeof window.L.map === "function") {
      return Promise.resolve();
    }
    if (leafletLoader) {
      return leafletLoader;
    }
    leafletLoader = new Promise((resolve, reject) => {
      const css = document.createElement("link");
      css.rel = "stylesheet";
      css.href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css";
      document.head.appendChild(css);

      const script = document.createElement("script");
      script.src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js";
      script.onload = () => {
        if (window.L && typeof window.L.map === "function") {
          resolve();
        } else {
          reject(new Error("Leaflet failed to load"));
        }
      };
      script.onerror = reject;
      document.head.appendChild(script);
    });
    return leafletLoader;
  }

  function destroyExistingCharts() {
    mqChartInstances.forEach(function (chart) {
      try {
        if (chart && typeof chart.destroy === "function") {
          chart.destroy();
        } else if (chart && typeof chart.remove === "function") {
          chart.remove();
        }
      } catch (e) {
        console.warn("Error destroying chart instance", e);
      }
    });
    mqChartInstances = [];
  }
  function toNumberArray(values) {
    if (!Array.isArray(values)) {
      return [];
    }
    return values.map(function (val) {
      if (val === null || val === undefined) {
        return null;
      }
      const cleaned = String(val).replace(/,/g, "");
      const num = Number(cleaned);
      return Number.isFinite(num) ? num : null;
    });
  }
  function normalizeSeriesData(series) {
    if (!Array.isArray(series)) {
      return [];
    }
    return series.map(function (entry) {
      const normalized = { ...(entry || {}) };
      normalized.data = toNumberArray(entry.data);
      return normalized;
    });
  }
  const PALETTE_BANK = [
    ["#2563eb"],
    ["#16a34a"],
    ["#f97316"],
    ["#dc2626"],
    ["#9333ea"],
    ["#0ea5e9"],
    ["#14b8a6"],
    ["#f59e0b"],
    ["#475569"],
    ["#d946ef"]
  ];

  function resolvePalette(chart, idx) {
    if (Array.isArray(chart.colors) && chart.colors.length) {
      return chart.colors;
    }
    if (typeof chart.colors === "string" && chart.colors.trim() !== "") {
      try {
        var parsed = JSON.parse(chart.colors);
        if (Array.isArray(parsed) && parsed.length) {
          return parsed;
        }
      } catch (_) {}
    }
    if (Array.isArray(chart.color) && chart.color.length) {
      return chart.color;
    }
    if (typeof chart.color === "string" && chart.color.trim() !== "") {
      return [chart.color];
    }
    return PALETTE_BANK[idx % PALETTE_BANK.length];
  }
window.renderChartSection = function (meta) {
  var container =
    document.getElementById("mq_chart") ||
    document.querySelector("#mq_dash .mq-chart-section") ||
    document.getElementById("mq_dash");
  if (!container) {
    console.warn("Chart container not found (mq_chart / mq_dash).");
    return;
  }
  destroyExistingCharts();
  container.innerHTML = "";
  if (typeof ApexCharts === "undefined") {
    var msg = document.createElement("p");
    msg.textContent = "Chart library is not available.";
    container.appendChild(msg);
    return;
  }
  var chartDataRaw =
    meta.chartData || meta.chart_data || meta.charts || null;
  if (!chartDataRaw) {
    var noCfg = document.createElement("p");
    noCfg.textContent = "No chart configuration returned from AI.";
    container.appendChild(noCfg);
    return;
  }
  var chartConfig;
  try {
    if (typeof chartDataRaw === "string") {
      chartConfig = JSON.parse(chartDataRaw);
    } else {
      chartConfig = chartDataRaw;
    }
  } catch (e) {
    console.error("Invalid chartData JSON", e, chartDataRaw);
    var invalid = document.createElement("p");
    invalid.textContent = "Chart configuration is invalid.";
    container.appendChild(invalid);
    return;
  }
  var chartsArray = [];
  if (Array.isArray(chartConfig)) {
    chartsArray = chartConfig;
  } else if (Array.isArray(chartConfig.charts)) {
    chartsArray = chartConfig.charts;
  }
  if (!chartsArray.length) {
    var empty = document.createElement("p");
    empty.textContent = "No chart data available.";
    container.appendChild(empty);
    return;
  }
  chartsArray = chartsArray.slice(0, 6);
  var header = document.createElement("h3");
//   header.textContent = "Chart";
  header.className = "mq-section-title";
  container.appendChild(header);
  var grid = document.createElement("div");
  grid.className = "mq-chart-grid";
  grid.style.display = "grid";
  grid.style.gridTemplateColumns = "repeat(2, minmax(0, 1fr))";
  grid.style.gap = "16px";
  grid.style.marginTop = "8px";
  container.appendChild(grid);
  chartsArray.forEach(function (chart, idx) {

    var card = document.createElement("div");
    card.className = "mq-chart-card";
    grid.appendChild(card);
    var titleEl = document.createElement("div");
    titleEl.className = "mq-chart-title";
    titleEl.textContent = chart.title || "Chart " + (idx + 1);
    card.appendChild(titleEl);
    if (chart.subtitle) {
      var subEl = document.createElement("div");
      subEl.className = "mq-chart-subtitle";
      subEl.textContent = chart.subtitle;
      card.appendChild(subEl);
    }
    var chartDiv = document.createElement("div");
    chartDiv.id = "mq_chart_" + (idx + 1);
    card.appendChild(chartDiv);
    var hasLabels = Array.isArray(chart.labels);
    var hasSeriesArray =
      Array.isArray(chart.series) && chart.series.length > 0;
    var hasSimpleData =
      hasLabels &&
      (Array.isArray(chart.data) ||
        (hasSeriesArray && Array.isArray(chart.series[0].data)));
    var isMapChart =
      (chart.chartType || chart.type || "").toString().toLowerCase() === "map";
    var hasMapData =
      isMapChart &&
      Array.isArray(chart.latitudes) &&
      chart.latitudes.length &&
      Array.isArray(chart.longitudes) &&
      chart.longitudes.length;
    var hasData = hasSeriesArray || hasSimpleData || hasMapData;

        var hasSqlOnly =
      !isMapChart &&
      !hasData &&
      typeof chart.sql === "string" &&
      chart.sql.trim() !== "";
    if (hasSqlOnly) {
      console.warn(
        "Chart has SQL only, fetching data via RUN_CHART_SQL.",
        chart
      );
      chartDiv.innerHTML =
        '<div class="mq-chart-loading" style="margin-top:8px;font:12px/1.5 system-ui;color:#6b7280;">Running query and loading chart…</div>';
      apex.server.process(
        "RUN_CHART_SQL",
        {
          x01: chart.sql
        },
        {
          dataType: "json",
          success: function (res) {
            if (!res || res.ok === false) {
              console.error("RUN_CHART_SQL error", res && res.error);
              var errHtml =
                '<div class="mq-chart-error">' +
                escapeHTML(res && res.error ? res.error : 'Error loading chart data.') +
                '</div>';
              chartDiv.innerHTML = errHtml;
              return;
            }
            var labels = Array.isArray(res.labels) ? res.labels : [];
            var data = Array.isArray(res.data) ? res.data : [];

            if (!labels.length || !data.length) {
              chartDiv.innerHTML =
                '<div class="mq-chart-error">No data returned for this chart.</div>';
              return;
            }
            var chartKind = (
              chart.chartType ||
              chart.type ||
              "bar"
            )
              .toString()
              .toLowerCase();
            var type;
            if (chartKind === "line") {
              type = "line";
            } else if (chartKind === "area") {
              type = "area";
            } else if (chartKind === "pie") {
              type = "pie";
            } else if (chartKind === "donut") {
              type = "donut";
            } else if (
              chartKind === "radialbar" ||
              chartKind === "radial_bar"
            ) {
              type = "radialBar";
            } else {
              type = "bar";
            }
            var isPieLike =
              type === "pie" ||
              type === "donut" ||
              type === "radialBar";
            var palette = resolvePalette(chart, idx);
            var apexSeries;
            if (isPieLike) {
              apexSeries = toNumberArray(data);
            } else {
              apexSeries = [
                {
                  name:
                    chart.series_name ||
                    chart.y_axis_title ||
                    "Value",
                  data: toNumberArray(data)
                }
              ];
            }
            var xaxisConfig = !isPieLike
              ? {
                  categories: labels
                }
              : undefined;
            if (xaxisConfig && chart.x_axis_title) {
              xaxisConfig.title = { text: chart.x_axis_title };
            }
            var yaxisConfig = !isPieLike ? {} : undefined;
            if (yaxisConfig && chart.y_axis_title) {
              yaxisConfig.title = { text: chart.y_axis_title };
            }
            var options = {
              chart: {
                type: type,
                height: 320,
                toolbar: { show: false }
              },
              series: apexSeries,
              xaxis: xaxisConfig,
              yaxis: yaxisConfig,
              dataLabels: {
                enabled: chart.show_values === false ? false : true
              },
              colors: palette,
              tooltip: {
                shared: !isPieLike,
                intersect: false
              },
              legend: {
                show: true
              }
            };

            if (isPieLike) {
              options.labels = labels;
            }
            var apexChart = new ApexCharts(chartDiv, options);
            mqChartInstances.push(apexChart);
            apexChart.render().catch(function (err) {
              chartDiv.innerHTML =
                '<div class="mq-chart-error">Unable to render chart.</div>';
            });
          },
          error: function (jqXHR, textStatus, errorThrown) {
            var serverMsg =
              (jqXHR && jqXHR.responseJSON && jqXHR.responseJSON.error) ||
              (jqXHR && jqXHR.responseText) ||
              errorThrown ||
              textStatus;

            chartDiv.innerHTML =
              '<div class="mq-chart-error">Error calling RUN_CHART_SQL: ' +
              escapeHTML(serverMsg) +
              '</div>';
          }
        }
      );
      return;
    }
    if (!hasData) {

      chartDiv.innerHTML =
        '<div class="mq-chart-error">No data available for this chart.</div>';
      return;
    }
    if (isMapChart) {
      var mapLabels = hasLabels ? chart.labels : [];
      var latitudes = Array.isArray(chart.latitudes) ? chart.latitudes : [];
      var longitudes = Array.isArray(chart.longitudes) ? chart.longitudes : [];
      var mapValues = Array.isArray(chart.data) ? chart.data : [];

      if (!latitudes.length || latitudes.length !== longitudes.length) {
        chartDiv.innerHTML =
          '<div class="mq-chart-error">No coordinates available for this map.</div>';
        return;
      }

      var mapPoints = latitudes.map(function (lat, idx) {
        return {
          lat: Number(lat),
          lon: Number(longitudes[idx]),
          label: mapLabels && mapLabels[idx] != null ? mapLabels[idx] : "Location",
          value: mapValues && mapValues[idx] != null ? mapValues[idx] : null
        };
      }).filter(function (pt) {
        return Number.isFinite(pt.lat) && Number.isFinite(pt.lon);
      });

      if (!mapPoints.length) {
        chartDiv.innerHTML =
          '<div class="mq-chart-error">No valid latitude/longitude pairs for this map.</div>';
        return;
      }

      chartDiv.style.height = "360px";
      chartDiv.style.position = "relative";
      chartDiv.innerHTML = '<div class="mq-chart-loading">Loading map…</div>';

      ensureLeaflet()
        .then(function () {
          if (!window.L || typeof window.L.map !== "function") {
            chartDiv.innerHTML =
              '<div class="mq-chart-error">Map library is unavailable.</div>';
            return;
          }

          chartDiv.innerHTML = "";
          var map = L.map(chartDiv);
          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 18,
            attribution: '&copy; OpenStreetMap contributors'
          }).addTo(map);

          var bounds = [];
          mapPoints.forEach(function (pt) {
            bounds.push([pt.lat, pt.lon]);
            var popupHtml =
              '<strong>' + escapeHTML(pt.label) + '</strong>' +
              (pt.value != null
                ? '<br/>Value: ' + escapeHTML(pt.value)
                : "");
            L.circleMarker([pt.lat, pt.lon], {
              radius: 6,
              fillColor: "#2563eb",
              color: "#1d4ed8",
              weight: 1,
              fillOpacity: 0.8
            })
              .addTo(map)
              .bindPopup(popupHtml);
          });

          if (bounds.length === 1) {
            map.setView(bounds[0], 6);
          } else {
            map.fitBounds(bounds, { padding: [20, 20] });
          }

          mqChartInstances.push(map);
        })
        .catch(function () {
          chartDiv.innerHTML =
            '<div class="mq-chart-error">Unable to load map tiles.</div>';
        });

      return;
    }

    var sanitizedLabels = hasLabels
      ? chart.labels.map(function (l) {
          return l === null || l === undefined ? "" : String(l);
        })
      : [];
    var chartKind = (
      chart.chartType ||
      chart.type ||
      "bar"
    )
      .toString()
      .toLowerCase();
    var type;
    if (chartKind === "line") {
      type = "line";
    } else if (chartKind === "area") {
      type = "area";
    } else if (chartKind === "pie") {
      type = "pie";
    } else if (chartKind === "donut") {
      type = "donut";
    } else if (chartKind === "radialbar" || chartKind === "radial_bar") {
      type = "radialBar";
    } else {
      type = "bar";
    }
    var isPieLike =
      type === "pie" || type === "donut" || type === "radialBar";
    var apexSeries;
    if (isPieLike) {
      if (Array.isArray(chart.series) && !Array.isArray(chart.series[0])) {
        apexSeries = toNumberArray(chart.series);
      } else if (Array.isArray(chart.data)) {
        apexSeries = toNumberArray(chart.data);
      } else {

        chartDiv.innerHTML =
          '<div class="mq-chart-error">No numeric data for pie/donut chart.</div>';
        return;
      }
    } else {
      if (
        Array.isArray(chart.series) &&
        Array.isArray(chart.series[0].data)
      ) {
        apexSeries = normalizeSeriesData(chart.series);
      } else if (Array.isArray(chart.data)) {
        apexSeries = [
          {
            name:
              chart.series_name ||
              chart.y_axis_title ||
              "Value",
            data: toNumberArray(chart.data)
          }
        ];
      } else {
        console.warn("Invalid series data, skipping chart", chart);
        chartDiv.innerHTML =
          '<div class="mq-chart-error">No numeric data for this chart.</div>';
        return;
      }
    }
    var palette = resolvePalette(chart, idx);
    var xaxisConfig = !isPieLike
      ? {
          categories: sanitizedLabels
        }
      : undefined;
    if (xaxisConfig && chart.x_axis_title) {
      xaxisConfig.title = { text: chart.x_axis_title };
    }
    var yaxisConfig = !isPieLike ? {} : undefined;
    if (yaxisConfig && chart.y_axis_title) {
      yaxisConfig.title = { text: chart.y_axis_title };
    }
    var options = {
      chart: {
        type: type,
        height: 320,
        toolbar: { show: false }
      },
      series: apexSeries,
      xaxis: xaxisConfig,
      yaxis: yaxisConfig,
      dataLabels: {
        enabled: chart.show_values === false ? false : true
      },
      colors: palette,
      tooltip: {
        shared: !isPieLike,
        intersect: false
      },
      legend: {
        show: true
      }
    };
    if (isPieLike && Array.isArray(chart.labels)) {
      options.labels = chart.labels;
    }
    if (
      !apexSeries ||
      !Array.isArray(apexSeries) ||
      apexSeries.length === 0
    ) {

      chartDiv.innerHTML =
        '<div class="mq-chart-error">No series data for this chart.</div>';
      return;
    }

    var apexChart = new ApexCharts(chartDiv, options);
    mqChartInstances.push(apexChart);
    apexChart.render().catch(function (err) {
      chartDiv.innerHTML =
        '<div class="mq-chart-error">Unable to render chart.</div>';
    });
  });
};
})(apex, apex.jQuery);
