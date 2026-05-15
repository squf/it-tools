(async function() {
  const TOTAL_SCOPE = [1000]; // [insert total number of users in scope, e.g. 4500]
  const ALREADY_ALIGNED = [250]; // [insert number of already aligned users]
  const TOTAL_TARGETS = [750]; // [insert total number of migration targets]

  try {
    const [targets, batches] = await Promise.all([
      API.get('get-targets'),
      API.get('get-batches')
    ]);

    // Count statuses
    const migrated = targets.filter(t => t.status === 'success').length;
    const pending = TOTAL_TARGETS - migrated - targets.filter(t => t.status === 'failed').length - targets.filter(t => t.status === 'skipped').length;
    const failed = targets.filter(t => t.status === 'failed').length;
    const dryrun = targets.filter(t => t.status === 'dryrun').length;

    // Progress
    const percent = TOTAL_TARGETS > 0 ? Math.round((migrated / TOTAL_TARGETS) * 100) : 0;
    document.getElementById('progress-fill').style.width = percent + '%';
    document.getElementById('progress-fill').textContent = percent + '%';
    document.getElementById('progress-label-left').textContent = migrated + ' of ' + TOTAL_TARGETS + ' migrated';
    document.getElementById('progress-label-right').textContent = ALREADY_ALIGNED + ' pre-aligned';

    // Stats
    document.getElementById('stat-scope').textContent = TOTAL_SCOPE;
    document.getElementById('stat-migrated').textContent = migrated;
    document.getElementById('stat-pending').textContent = pending > 0 ? pending : TOTAL_TARGETS - migrated;
    document.getElementById('stat-failed').textContent = failed;
    document.getElementById('stat-dryrun').textContent = dryrun;

    // Recent batches
    const sorted = batches.sort((a,b) => (b.StartTime||'').localeCompare(a.StartTime||'')).slice(0, 10);
    const tbody = document.getElementById('batches-tbody');
    if (sorted.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="empty">No batches yet</td></tr>';
    } else {
      tbody.innerHTML = sorted.map(b => `<tr>
        <td class="text-sm" title="${escapeHtml(b.RowKey)}">${escapeHtml((b.RowKey||'').substring(0,8))}…</td>
        <td>${escapeHtml(b.Initiator)}</td>
        <td>${b.UserCount || 0}</td>
        <td>${badge(b.Status)}</td>
        <td>${b.DryRun === true || b.DryRun === 'true' ? '✅' : '—'}</td>
        <td class="text-muted text-sm">${timeAgo(b.StartTime)}</td>
      </tr>`).join('');
    }
  } catch (err) {
    console.error('Dashboard load error:', err);
    document.getElementById('batches-tbody').innerHTML =
      '<tr><td colspan="6" class="empty">Error loading data: ' + escapeHtml(err.message) + '</td></tr>';
  }
})();
