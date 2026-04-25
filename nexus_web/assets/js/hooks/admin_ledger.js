/**
 * AdminLedger Hook
 * 
 * Synchronizes the Elite Ledger Terminal UI with LiveView state, 
 * handling GSAP row animations, Lucide icon refreshment, and 
 * sophisticated transition effects for drawers and panels.
 */
const AdminLedger = {
  mounted() {
    this.initIcons();
    this.animateRows();
  },

  updated() {
    this.initIcons();
    // Only animate rows if they've changed (e.g. pagination/filter)
    // We can check a data attribute or just stagger them
    if (this.el.dataset.animateRows === "true") {
      this.animateRows();
    }
  },

  initIcons() {
    if (window.lucide) {
      window.lucide.createIcons();
    }
  },

  animateRows() {
    if (window.gsap) {
      window.gsap.fromTo(
        '.ledger-row',
        { opacity: 0, y: 8 },
        { 
          opacity: 1, 
          y: 0, 
          stagger: 0.03, 
          duration: 0.4, 
          ease: "power2.out",
          overwrite: true
        }
      );
    }
  }
};

export default AdminLedger;
