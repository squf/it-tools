(async function() {
  const search = document.getElementById('audit-search');
  const dateFilter = document.getElementById('audit-date');
  const tbody = document.getElementById('audit-tbody');
  let allLogs = [];

  async function loadLogs() {
    try {
      const dateVal = dateFilter.value || '';
      const url = dateVal ? 'get-audit?date=' + dateVal : 'get-audit';
      allLogs = await API.get(url);
      renderLogs();
    } catch(err) {
      tbody.innerHTML = '<tr><td colspan="8" class="empty">Error: '+escapeHtml(err.message)+'</td></tr>';
    }
  }

  function renderLogs() {
    const q = (search.value||'').toLowerCase();
    const filtered = allLogs.filter(l => {
      if (!q) return true;
      return (l.Target||'').toLowerCase().includes(q) ||
             (l.Actor||'').toLowerCase().includes(q) ||
             (l.OldValue||'').toLowerCase().includes(q) ||
             (l.NewValue||'').toLowerCase().includes(q) ||
             (l.BatchId||'').toLowerCase().includes(q);
    }).sort((a,b) => (b.RowKey||'').localeCompare(a.RowKey||''));

    if (filtered.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" class="empty">No audit entries found</td></tr>';
    } else {
      tbody.innerHTML = filtered.map(l => `<tr>
        <td class="text-sm text-muted">${timeAgo(l.RowKey?.split('-upn-')[0])}</td>
        <td>${escapeHtml(l.Actor)}</td>
        <td>${escapeHtml(l.Action)}</td>
        <td><code>${escapeHtml(l.Target)}</code></td>
        <td class="text-sm">${escapeHtml(l.OldValue)}</td>
        <td class="text-sm">${escapeHtml(l.NewValue)}</td>
        <td>${badge(l.Status)}</td>
        <td class="text-sm text-muted" title="${escapeHtml(l.BatchId)}">${(l.BatchId||'').substring(0,8)}…</td>
      </tr>`).join('');
    }
  }

  search.addEventListener('input', renderLogs);
  dateFilter.addEventListener('change', loadLogs);
  loadLogs();
})();
