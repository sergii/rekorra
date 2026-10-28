/* Optional association search: preserve unsaved draft fields with same-origin HTML. */
(() => {
  const active = new WeakMap();

  async function search(form) {
    const field = form.dataset.rkField;
    const recordForm = document.querySelector("form.rk-form");
    if (!recordForm || !/^[a-z][a-z0-9_]*$/.test(field || "")) return;

    const select = [...recordForm.querySelectorAll("select")].find(
      (element) => element.name === "record[" + field + "]"
    );
    if (!select) return;

    const status = form.querySelector(".rk-association-lookup__status");
    const previous = active.get(form);
    if (previous) previous.abort();
    const controller = new AbortController();
    active.set(form, controller);
    const currentValue = select.value;
    const previousOption = [...select.options].find((o) => o.value === currentValue)?.cloneNode(true);
    const url = new URL(form.action, window.location.href);
    url.search = new URLSearchParams(new FormData(form)).toString();

    if (status) status.textContent = "Searching related records…";
    form.setAttribute("aria-busy", "true");
    try {
      const response = await fetch(url, {
        method: "GET", credentials: "same-origin",
        headers: { "Accept": "text/html" }, signal: controller.signal
      });
      if (!response.ok || response.redirected) throw new Error("Unable to search related records");
      const doc = new DOMParser().parseFromString(await response.text(), "text/html");
      const updated = [...doc.querySelectorAll("form.rk-form select")].find(
        (element) => element.name === "record[" + field + "]"
      );
      if (!updated) throw new Error("Invalid association lookup response");
      const options = [...updated.options].map((o) => o.cloneNode(true));
      if (currentValue && previousOption && !options.some((o) => o.value === currentValue)) {
        options.push(previousOption);
      }
      select.replaceChildren(...options);
      if (currentValue && options.some((o) => o.value === currentValue)) select.value = currentValue;
      if (status) status.textContent = String(options.filter((o) => o.value).length) + " options available";
    } catch (error) {
      if (error.name !== "AbortError" && status) {
        status.textContent = "Search failed. Your unsaved changes are preserved; try again.";
      }
    } finally {
      if (active.get(form) === controller) {
        form.removeAttribute("aria-busy");
        active.delete(form);
      }
    }
  }

  document.addEventListener("submit", (event) => {
    const form = event.target;
    if (!form.matches("form[data-rk-association-lookup]") || event.defaultPrevented) return;
    const recordForm = document.querySelector("form.rk-form");
    if (!recordForm || typeof window.fetch !== "function" || typeof window.DOMParser !== "function") return;
    event.preventDefault();
    search(form);
  });

  document.addEventListener("click", (event) => {
    const link = event.target.closest("a[data-rk-association-clear]");
    if (!link || event.defaultPrevented || event.metaKey || event.ctrlKey ||
        event.altKey || event.shiftKey || event.button !== 0) return;
    const form = link.closest("form[data-rk-association-lookup]");
    if (!form || typeof window.fetch !== "function") return;
    event.preventDefault();
    const input = form.querySelector('input[type="search"]');
    if (input) input.value = "";
    form.requestSubmit();
  });
})();
