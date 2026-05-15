// =============================================================================
// API Client + Auth Helper
// =============================================================================
const API = {
  async get(path) {
    const res = await fetch('/api/' + path);
    if (!res.ok) throw new Error(await res.text());
    return res.json();
  },
  async post(path, body) {
    const res = await fetch('/api/' + path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!res.ok) {
      const err = await res.text();
      throw new Error(err);
    }
    return res.json();
  },
  async put(path, body) {
    const res = await fetch('/api/' + path, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!res.ok) throw new Error(await res.text());
    return res.json();
  },
  async getUserInfo() {
    try {
      const res = await fetch('/.auth/me');
      const data = await res.json();
      return data.clientPrincipal;
    } catch { return null; }
  }
};

function badge(status) {
  const map = {
    success: 'badge-success', completed: 'badge-success',
    pending: 'badge-warning', running: 'badge-warning',
    failed: 'badge-danger', 'job-failed': 'badge-danger',
    dryrun: 'badge-info', 'dryrun-complete': 'badge-info',
    skipped: 'badge-gray', partial: 'badge-warning',
    HIGH: 'badge-high', LOW: 'badge-low', MEDIUM: 'badge-warning'
  };
  return `<span class="badge ${map[status] || 'badge-gray'}">${status || 'unknown'}</span>`;
}

function timeAgo(ts) {
  if (!ts) return '—';
  const d = new Date(ts);
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return 'just now';
  if (diff < 3600) return Math.floor(diff/60) + 'm ago';
  if (diff < 86400) return Math.floor(diff/3600) + 'h ago';
  return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'});
}

function escapeHtml(s) {
  if (!s) return '';
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}
