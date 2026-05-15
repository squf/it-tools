(async function() {
  const grid = document.getElementById('sso-grid');
  let apps = [];

  try {
    apps = await API.get('get-sso');
  } catch(err) {
    grid.innerHTML = '<div class="empty">Error: '+escapeHtml(err.message)+'</div>';
    return;
  }

  function renderCards() {
    if (apps.length === 0) {
      grid.innerHTML = '<div class="empty">No SSO apps tracked yet</div>';
      return;
    }
    grid.innerHTML = apps.map((app, i) => `
      <div class="sso-card">
        <h3>${badge(app.RiskLevel||'HIGH')} ${escapeHtml(app.AppName||app.RowKey)}</h3>
        <div class="text-sm text-muted">${escapeHtml(app.AuthMethod||'saml')} · ${escapeHtml(app.UserAccountBasis||'user.userprincipalname')}</div>
        <div class="toggles">
          <div class="toggle-row">
            <span>Vendor Contacted</span>
            <label class="toggle"><input type="checkbox" data-idx="${i}" data-field="VendorContacted"
              ${app.VendorContacted==='true'||app.VendorContacted===true?'checked':''}><span class="slider"></span></label>
          </div>
          <div class="toggle-row">
            <span>Pre-Rename Done</span>
            <label class="toggle"><input type="checkbox" data-idx="${i}" data-field="PreRenameDone"
              ${app.PreRenameDone==='true'||app.PreRenameDone===true?'checked':''}><span class="slider"></span></label>
          </div>
          <div class="toggle-row">
            <span>Cleared for Cutover</span>
            <label class="toggle"><input type="checkbox" data-idx="${i}" data-field="ClearedForCutover"
              ${app.ClearedForCutover==='true'||app.ClearedForCutover===true?'checked':''}><span class="slider"></span></label>
          </div>
        </div>
      </div>`).join('');

    grid.querySelectorAll('input[type=checkbox]').forEach(cb => {
      cb.addEventListener('change', async () => {
        const idx = parseInt(cb.dataset.idx);
        const field = cb.dataset.field;
        const app = apps[idx];
        app[field] = cb.checked;
        try {
          await API.put('update-sso', {
            PartitionKey: app.PartitionKey || 'app',
            RowKey: app.RowKey,
            [field]: cb.checked
          });
        } catch(err) {
          alert('Failed to save: ' + err.message);
          cb.checked = !cb.checked;
        }
      });
    });
  }
  renderCards();
})();
