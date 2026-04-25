/**
 * AdminSearch Hook
 * 
 * Handles institutional keyboard shortcuts for the Sovereign Ledger Terminal.
 * Supports ⌘K / Ctrl+K for focus and Escape for clearing focus.
 */
const AdminSearch = {
  mounted() {
    this.handleShortcuts = (e) => {
      // ⌘K or Ctrl+K to focus search
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        this.el.focus();
        this.el.select();
      }
      
      // Escape to blur
      if (e.key === 'Escape' && document.activeElement === this.el) {
        this.el.blur();
      }
    };
    
    window.addEventListener('keydown', this.handleShortcuts);
  },

  destroyed() {
    window.removeEventListener('keydown', this.handleShortcuts);
  }
};

export default AdminSearch;
