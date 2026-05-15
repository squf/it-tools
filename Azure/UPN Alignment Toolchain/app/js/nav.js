// =============================================================================
// Sidebar Navigation — injected into every page
// =============================================================================
(async function() {
  const pages = [
    { href: '/', icon: '📊', label: 'Dashboard' },
    { href: '/users.html', icon: '👥', label: 'Users' },
    { href: '/batch.html', icon: '🔧', label: 'Batch Builder' },
    { href: '/audit.html', icon: '📜', label: 'Audit Log' },
    { href: '/sso.html', icon: '🔌', label: 'SSO Apps' },
  ];
  const current = location.pathname === '/index.html' ? '/' : location.pathname;
  const nav = pages.map(p =>
    `<a href="${p.href}" class="${p.href===current||(current==='/'&&p.href==='/')?'active':''}">
      <span class="icon">${p.icon}</span>${p.label}
    </a>`
  ).join('');

  const user = await API.getUserInfo();
  const username = user ? user.userDetails : 'Not signed in';
  const roles = user && user.userRoles ? user.userRoles.filter(r=>r!=='anonymous'&&r!=='authenticated').join(', ') : '';

  document.getElementById('sidebar').innerHTML = `
    <div class="sidebar-brand">
      UPN Control Center
      <small>IT Department</small>
    </div>
    <nav class="sidebar-nav">${nav}</nav>
    <div class="sidebar-user">
      <strong>${escapeHtml(username)}</strong>
      ${roles ? '<span>'+escapeHtml(roles)+'</span><br>' : ''}
      <a href="/.auth/logout" style="font-size:11px">Sign out</a>
    </div>`;
})();
