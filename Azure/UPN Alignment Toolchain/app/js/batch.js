(async function() {
  let allTargets = [];
  let selected = new Set();

  try {
    allTargets = await API.get('get-targets');
  } catch(err) {
    document.getElementById('batch-tbody').innerHTML =
      '<tr><td colspan="6" class="empty">Error: '+escapeHtml(err.message)+'</td></tr>';
    return;
  }

  const search = document.getElementById('batch-search');
  const filter = document.getElementById('batch-filter');
  const countEl = document.getElementById('selected-count');
  const submitBtn = document.getElementById('submit-batch');
  const selectAll = document.getElementById('select-all');
  const resultsPanel = document.getElementById('results-panel');
  const resultsSummary = document.getElementById('results-summary');
  const resultsBody = document.getElementById('results-tbody');

  function getFiltered() {
    const q = (search.value||'').toLowerCase();
    const f = filter.value;
    return allTargets.filter(t => {
      if (f && t.status !== f) return false;
      if (q && !(
        (t.displayName||'').toLowerCase().includes(q) ||
        (t.sam||'').toLowerCase().includes(q) ||
        (t.currentUPN||'').toLowerCase().includes(q)
      )) return false;
      return true;
    });
  }

  function updateCount() {
    countEl.textContent = selected.size + ' selected';
    submitBtn.disabled = selected.size === 0;
  }

  function render() {
    const filtered = getFiltered();
    const tbody = document.getElementById('batch-tbody');
    if (filtered.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="empty">No users match filters</td></tr>';
    } else {
      tbody.innerHTML = filtered.map(t => `<tr>
        <td><input type="checkbox" data-sam="${escapeHtml(t.sam)}" ${selected.has(t.sam)?'checked':''}></td>
        <td>${escapeHtml(t.displayName)}</td>
        <td><code>${escapeHtml(t.sam)}</code></td>
        <td>${escapeHtml(t.currentUPN)}</td>
        <td>${escapeHtml(t.targetUPN)}</td>
        <td>${badge(t.status)}</td>
      </tr>`).join('');

      tbody.querySelectorAll('input[type=checkbox]').forEach(cb => {
        cb.addEventListener('change', () => {
          if (cb.checked) selected.add(cb.dataset.sam);
          else selected.delete(cb.dataset.sam);
          updateCount();
        });
      });
    }
    updateCount();
  }

  search.addEventListener('input', render);
  filter.addEventListener('change', render);
  selectAll.addEventListener('change', () => {
    const filtered = getFiltered();
    if (selectAll.checked) filtered.forEach(t => selected.add(t.sam));
    else filtered.forEach(t => selected.delete(t.sam));
    render();
  });

  // ── Display a full synchronous result (original behavior) ──────────
  async function displayResult(result) {
    const r = result.result || result;
    resultsSummary.innerHTML = `
      <div class="stats" style="margin-top:12px">
        <div class="stat-card accent"><div class="value">${r.totalTargeted||0}</div><div class="label">Targeted</div></div>
        <div class="stat-card success"><div class="value">${r.success||0}</div><div class="label">Success</div></div>
        <div class="stat-card info"><div class="value">${r.dryRunCount||0}</div><div class="label">Dry Run</div></div>
        <div class="stat-card warning"><div class="value">${r.skipped||0}</div><div class="label">Skipped</div></div>
        <div class="stat-card danger"><div class="value">${r.failed||0}</div><div class="label">Failed</div></div>
      </div>
      <p class="text-sm text-muted mt">Batch ID: ${escapeHtml(r.batchId)} | Status: ${badge(result.status||r.status)}</p>`;

    const users = r.users || [];
    if (users.length > 0) {
      resultsBody.innerHTML = users.map(u => `<tr>
        <td>${escapeHtml(u.displayName)}</td>
        <td><code>${escapeHtml(u.sam)}</code></td>
        <td>${escapeHtml(u.oldUPN)}</td>
        <td>${escapeHtml(u.newUPN)}</td>
        <td>${badge(u.status)}</td>
        <td class="text-sm">${escapeHtml(u.skipReason||u.errors?.join(', ')||'—')}</td>
      </tr>`).join('');
    } else {
      resultsBody.innerHTML = '<tr><td colspan="6" class="empty">No user details returned</td></tr>';
    }
    resultsPanel.classList.add('visible');

    allTargets = await API.get('get-targets');
    selected.clear();
    render();
  }

  // ── Poll get-batches + get-audit for async result ──────────────────
  function pollForResult(submittedAt) {
    return new Promise((resolve) => {
      const cutoff = new Date(submittedAt.getTime() - 10000); // 10s grace window

      const poll = setInterval(async () => {
        try {
          const batches = await API.get('get-batches');

          // Find newest batch that started after our submission
          const match = batches
            .filter(b => new Date(b.StartTime || b.Timestamp) >= cutoff)
            .sort((a, b) => (b.StartTime||b.Timestamp||'').localeCompare(a.StartTime||a.Timestamp||''))
            [0];

          if (!match) {
            resultsSummary.innerHTML = '<p>⏳ Waiting for pipeline to initialize…</p>';
            return; // keep polling
          }

          const status = (match.Status || match.status || '').toLowerCase();

          // Still running — update UI and keep polling
          if (status === 'running' || status === 'submitted') {
            resultsSummary.innerHTML = `<p>⏳ Batch <code>${(match.RowKey||'').substring(0,8)}…</code> — ${badge(status)} — polling every 5 s…</p>`;
            return;
          }

          // ── Terminal state — render results ──
          clearInterval(poll);
          const batchId = match.RowKey;

          resultsSummary.innerHTML = `
            <div class="stats" style="margin-top:12px">
              <div class="stat-card accent"><div class="value">${match.UserCount||0}</div><div class="label">Targeted</div></div>
              <div class="stat-card success"><div class="value">${match.SuccessCount||match.successCount||0}</div><div class="label">Success</div></div>
              <div class="stat-card info"><div class="value">${match.DryRunCount||match.dryRunCount||0}</div><div class="label">Dry Run</div></div>
              <div class="stat-card warning"><div class="value">${match.SkipCount||match.skipCount||0}</div><div class="label">Skipped</div></div>
              <div class="stat-card danger"><div class="value">${match.FailCount||match.failCount||0}</div><div class="label">Failed</div></div>
            </div>
            <p class="text-sm text-muted mt">Batch ID: ${escapeHtml(batchId)} | Status: ${badge(status)}</p>`;

          // Fetch audit entries to show per-user detail
          try {
            const today = new Date().toISOString().slice(0, 10);
            const auditLogs = await API.get('get-audit?date=' + today);
            const batchLogs = auditLogs.filter(l => l.BatchId === batchId);

            if (batchLogs.length > 0) {
              resultsBody.innerHTML = batchLogs.map(l => `<tr>
                <td>${escapeHtml(l.Target||'')}</td>
                <td><code>${escapeHtml(l.Target||'')}</code></td>
                <td>${escapeHtml(l.OldValue||'')}</td>
                <td>${escapeHtml(l.NewValue||'')}</td>
                <td>${badge(l.Status)}</td>
                <td class="text-sm">—</td>
              </tr>`).join('');
            } else {
              resultsBody.innerHTML = '<tr><td colspan="6" class="empty">No user details in audit log yet</td></tr>';
            }
          } catch (_) {
            resultsBody.innerHTML = '<tr><td colspan="6" class="empty">Could not fetch audit details</td></tr>';
          }

          resultsPanel.classList.add('visible');
          allTargets = await API.get('get-targets');
          selected.clear();
          render();
          resolve();

        } catch (e) {
          resultsSummary.innerHTML = `<p>⚠️ Poll error — retrying… (${escapeHtml(e.message)})</p>`;
        }
      }, 5000); // poll every 5 seconds

      // Safety valve — stop after 5 minutes
      setTimeout(() => {
        clearInterval(poll);
        resultsSummary.innerHTML += '<p class="text-sm text-muted">Polling timed out after 5 min. Check the Audit Log tab for results.</p>';
        submitBtn.disabled = false;
        submitBtn.innerHTML = '🚀 Submit Batch';
        resolve();
      }, 300000);
    });
  }

  // ── Submit handler ─────────────────────────────────────────────────
  submitBtn.addEventListener('click', async () => {
    if (selected.size === 0) return;
    const dryRun = document.getElementById('dryrun-toggle').checked;
    const user = await API.getUserInfo();
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<span class="spinner"></span> Running…';

    const submittedAt = new Date();

    try {
      const result = await API.post('trigger-batch', {
        targetUsers: Array.from(selected),
        dryRun: dryRun,
        initiator: user ? user.userDetails : 'unknown'
      });

      // If Logic App responded within 10s, we get the full result immediately
      if (result.result) {
        await displayResult(result);
        return;
      }

      // Async path — 202 received, pipeline is running, start polling
      resultsSummary.innerHTML = '<p>⏳ Job submitted — pipeline is running. Polling for results…</p>';
      resultsBody.innerHTML = '<tr><td colspan="6" class="empty">Waiting…</td></tr>';
      resultsPanel.classList.add('visible');
      submitBtn.innerHTML = '<span class="spinner"></span> Polling…';

      await pollForResult(submittedAt);

    } catch(err) {
      resultsSummary.innerHTML = '<p style="color:var(--danger)">Error: '+escapeHtml(err.message)+'</p>';
      resultsPanel.classList.add('visible');
    } finally {
      submitBtn.disabled = false;
      submitBtn.innerHTML = '🚀 Submit Batch';
    }
  });

  render();
})();
