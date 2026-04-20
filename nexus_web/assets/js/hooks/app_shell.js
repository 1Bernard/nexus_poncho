const AppShell = {
  mounted() {
    this._applyCollapsedState();
    this._setupSidebar();
    this._setupSidebarTooltips();
    this._setupCommandPalette();
    this._setupProfileMenu();
    this._startClock();
    this._setActiveNav();
    this._animateEntry();

    // Re-sync active nav on every LiveView navigation
    window.addEventListener("phx:page-loading-stop", () => this._setActiveNav());
  },

  updated() {
    // Re-apply client state that LiveView may have reset during DOM diff
    this._applyCollapsedState();
    this._setActiveNav();
  },

  destroyed() {
    if (this._clockInterval) clearInterval(this._clockInterval);
  },

  // ── Sidebar ────────────────────────────────────────────────────────────────

  _applyCollapsedState() {
    const sidebar = this.el.querySelector("#main-sidebar");
    const icon = this.el.querySelector(".sidebar-toggle-icon");
    if (!sidebar) return;

    const collapsed = localStorage.getItem("aura-sidebar-collapsed") === "true";
    if (collapsed) {
      sidebar.classList.add("collapsed");
      sidebar.style.width = "88px";
      if (icon) icon.style.transform = "rotate(180deg)";
    } else {
      sidebar.classList.remove("collapsed");
      sidebar.style.width = "288px";
      if (icon) icon.style.transform = "rotate(0deg)";
    }
  },

  _setupSidebar() {
    const toggle = this.el.querySelector("#sidebar-toggle");
    if (!toggle || toggle._ready) return;
    toggle._ready = true;

    toggle.addEventListener("click", () => {
      const sidebar = this.el.querySelector("#main-sidebar");
      const icon = this.el.querySelector(".sidebar-toggle-icon");
      if (!sidebar) return;

      const collapsed = sidebar.classList.contains("collapsed");
      if (collapsed) {
        sidebar.classList.remove("collapsed");
        sidebar.style.width = "288px";
        if (icon) icon.style.transform = "rotate(0deg)";
        localStorage.setItem("aura-sidebar-collapsed", "false");
      } else {
        sidebar.classList.add("collapsed");
        sidebar.style.width = "88px";
        if (icon) icon.style.transform = "rotate(180deg)";
        localStorage.setItem("aura-sidebar-collapsed", "true");
      }
    });
  },

  // ── Sidebar Tooltips (fixed-position to escape overflow:hidden) ───────────

  _setupSidebarTooltips() {
    this.el.querySelectorAll(".sidebar-item").forEach((item) => {
      const tooltip = item.querySelector(".sidebar-tooltip");
      if (!tooltip || item._tooltipReady) return;
      item._tooltipReady = true;

      item.addEventListener("mouseenter", () => {
        const sidebar = this.el.querySelector("#main-sidebar");
        if (!sidebar || !sidebar.classList.contains("collapsed")) return;
        const rect = item.getBoundingClientRect();
        tooltip.style.top = `${rect.top + rect.height / 2}px`;
        tooltip.style.left = `${rect.right + 15}px`;
        tooltip.style.transform = "translateY(-50%) translateX(-6px)";
      });
    });
  },

  // ── Command Palette ────────────────────────────────────────────────────────

  _setupCommandPalette() {
    const palette = this.el.querySelector("#app-command-palette");
    const input = this.el.querySelector("#palette-search");
    const trigger = this.el.querySelector("[data-cmd-palette]");
    const backdrop = palette?.querySelector("[data-backdrop]");
    if (!palette) return;

    const open = () => {
      palette.style.opacity = "0";
      palette.classList.remove("hidden");
      requestAnimationFrame(() => {
        palette.style.transition = "opacity 0.2s ease";
        palette.style.opacity = "1";
      });
      if (input) setTimeout(() => input.focus(), 60);
    };

    const close = () => {
      palette.style.transition = "opacity 0.2s ease";
      palette.style.opacity = "0";
      setTimeout(() => {
        palette.classList.add("hidden");
        if (input) input.value = "";
      }, 200);
    };

    if (trigger) trigger.addEventListener("click", open);
    if (backdrop) backdrop.addEventListener("click", close);

    document.addEventListener("keydown", (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        palette.classList.contains("hidden") ? open() : close();
      }
      if (e.key === "Escape" && !palette.classList.contains("hidden")) close();
    });
  },

  // ── Profile Menu ───────────────────────────────────────────────────────────

  _setupProfileMenu() {
    const menu = this.el.querySelector("#app-profile-menu");
    const trigger = this.el.querySelector("[data-profile-toggle]");
    if (!menu || !trigger || trigger._profileReady) return;
    trigger._profileReady = true;

    const open = () => {
      menu.classList.remove("hidden");
      menu.style.opacity = "0";
      menu.style.transform = "translateY(-8px)";
      menu.style.transition = "opacity 0.2s ease, transform 0.2s ease";
      requestAnimationFrame(() => {
        menu.style.opacity = "1";
        menu.style.transform = "translateY(0)";
      });
    };

    const close = () => {
      menu.style.transition = "opacity 0.2s ease, transform 0.2s ease";
      menu.style.opacity = "0";
      menu.style.transform = "translateY(-8px)";
      setTimeout(() => menu.classList.add("hidden"), 200);
    };

    trigger.addEventListener("click", (e) => {
      e.stopPropagation();
      menu.classList.contains("hidden") ? open() : close();
    });

    document.addEventListener("click", (e) => {
      if (!menu.classList.contains("hidden") && !e.target.closest("#app-profile-menu")) {
        close();
      }
    });
  },

  // ── Live Clock ─────────────────────────────────────────────────────────────

  _startClock() {
    const el = this.el.querySelector("#app-live-time");
    if (!el) return;

    const tick = () => {
      const now = new Date();
      const h = String(now.getUTCHours()).padStart(2, "0");
      const m = String(now.getUTCMinutes()).padStart(2, "0");
      const s = String(now.getUTCSeconds()).padStart(2, "0");
      el.textContent = `${h}:${m}:${s}_UTC`;
    };

    tick();
    this._clockInterval = setInterval(tick, 1000);
  },

  // ── Active Nav ─────────────────────────────────────────────────────────────

  _setActiveNav() {
    const path = window.location.pathname;
    this.el.querySelectorAll("[data-nav-path]").forEach((item) => {
      const navPath = item.getAttribute("data-nav-path");
      item.classList.toggle("active", Boolean(navPath && path.startsWith(navPath)));
    });
  },

  // ── Entry Animations ───────────────────────────────────────────────────────

  _animateEntry() {
    const sidebar = this.el.querySelector("#main-sidebar");
    const topbar = this.el.querySelector("#app-topbar");

    if (sidebar && !sidebar._animated) {
      sidebar._animated = true;
      sidebar.classList.add("aura-entry-sidebar");
    }
    if (topbar && !topbar._animated) {
      topbar._animated = true;
      topbar.classList.add("aura-entry-topbar");
    }
  },
};

export default AppShell;
