(async function() {
  let allTargets = [];
  try {
    allTargets = await API.get('get-targets');
  } catch(err) {
    document.getElementById('users-tbody').innerHTML =
      '<tr><td colspan="6" class="empty">Error: '+escapeHtml(err.message)+'</td></tr>';
    return;
  }

  const search = document.getElementById('user-search');
  const filter = document.getElementById('user-filter');
  const countEl = document.getElementById('user-count');

  function render() {
    const q = (search.value||'').toLowerCase();
    const f = filter.value;
    const filtered = allTargets.filter(t => {
      if (f && t.status !== f) return false;
      if (q && !(
        (t.displayName||'').toLowerCase().includes(q) ||
        (t.sam||'').toLowerCase().includes(q) ||
        (t.currentUPN||'').toLowerCase().includes(q) ||
        (t.targetUPN||'').toLowerCase().includes(q)
      )) return false;
      return true;
    });
    countEl.textContent = filtered.length + ' user' + (filtered.length!==1?'s':'');
    const tbody = document.getElementById('users-tbody');
    if (filtered.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="empty">No users match filters</td></tr>';
    } else {
      tbody.innerHTML = filtered.map(t => `<tr>
        <td>${escapeHtml(t.displayName)}</td>
        <td><code>${escapeHtml(t.sam)}</code></td>
        <td>${escapeHtml(t.currentUPN)}</td>
        <td>${escapeHtml(t.targetUPN)}</td>
        <td>${badge(t.status)}</td>
        <td class="text-muted text-sm">${timeAgo(t.lastUpdated)}</td>
      </tr>`).join('');
    }
  }
  search.addEventListener('input', render);
  filter.addEventListener('change', render);
  render();
})();
