/* Rekorra progressive enhancement: native GET forms and links work without JS. */
(() => {
  function markBusy(panel) {
    if (!panel || panel.dataset.loading === "true") return;
    panel.dataset.loading = "true";
    const results = panel.querySelector(".rk-index-results");
    if (results) results.setAttribute("aria-busy", "true");
  }

  function clearBusy() {
    document.querySelectorAll("[data-rk-index][data-loading]").forEach((panel) => {
      delete panel.dataset.loading;
      const results = panel.querySelector(".rk-index-results");
      if (results) results.removeAttribute("aria-busy");
    });
  }

  document.addEventListener("submit", (event) => {
    if (!event.target.matches("[data-rk-index-form]") || event.defaultPrevented) return;
    markBusy(event.target.closest("[data-rk-index]"));
  });

  document.addEventListener("click", (event) => {
    if (event.defaultPrevented || event.button !== 0 ||
        event.ctrlKey || event.metaKey || event.altKey || event.shiftKey) return;
    const link = event.target.closest("a[data-rk-index-nav]");
    if (!link || link.hasAttribute("download") || link.target && link.target !== "_self") return;
    if (link.origin !== location.origin) return;
    markBusy(link.closest("[data-rk-index]"));
  });

  // Browsers may restore the previous document through back/forward cache.
  window.addEventListener("pageshow", clearBusy);
})();
