/* Pulse admin console — no build step, no framework. */
(function () {
  'use strict';

  var TOKEN_KEY = 'pulse.admin.token';
  var token = localStorage.getItem(TOKEN_KEY);
  var state = { page: 'dashboard', records: [], search: '', editing: null, sites: [], categories: [] };

  var $ = function (id) { return document.getElementById(id); };
  var esc = function (v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  };

  // ---------------------------------------------------------------- API

  function api(path, options) {
    options = options || {};
    var headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = 'Bearer ' + token;
    return fetch('/admin/api' + path, {
      method: options.method || 'GET',
      headers: headers,
      body: options.body ? JSON.stringify(options.body) : undefined,
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (data) {
        if (r.status === 401) { signOut(); throw new Error(data.message || 'Session expired.'); }
        if (!r.ok) throw new Error(data.message || 'Request failed.');
        return data;
      });
    });
  }

  function toast(message, isError) {
    var el = $('toast');
    el.textContent = message;
    el.className = 'toast' + (isError ? ' bad' : '');
    el.hidden = false;
    clearTimeout(el._t);
    el._t = setTimeout(function () { el.hidden = true; }, 3200);
  }

  // ---------------------------------------------------------------- schema

  var DATE_HINT = 'ISO format, e.g. 2026-08-16T10:00';

  var PAGES = {
    dashboard: { title: 'Dashboard', group: 'Overview' },
    events: {
      title: 'Events', group: 'Content', resource: 'events', singular: 'event',
      columns: [
        { key: 'id', label: 'ID', width: 56 },
        { key: 'title', label: 'Title' },
        { key: 'starts_at', label: 'Starts', format: 'datetime' },
        { key: 'venue', label: 'Venue' },
        { key: 'amount', label: 'Price', format: 'money' },
        { key: 'capacity', label: 'Seats', format: 'number' },
        { key: 'status', label: 'Status', format: 'pill' },
      ],
      extraActions: [{ label: 'Registrations', action: 'registrations' }],
      fields: [
        { key: 'title', label: 'Title', wide: true, required: true },
        { key: 'description', label: 'Description', type: 'textarea', wide: true },
        { key: 'venue', label: 'Venue', wide: true },
        { key: 'cover_image', label: 'Cover image URL', wide: true, hint: 'Any public https image URL' },
        { key: 'starts_at', label: 'Starts at', type: 'datetime-local', required: true, hint: DATE_HINT },
        { key: 'ends_at', label: 'Ends at', type: 'datetime-local' },
        { key: 'site_id', label: 'Site', type: 'select', source: 'sites', required: true },
        { key: 'category_id', label: 'Category', type: 'select', source: 'categories' },
        { key: 'amount', label: 'Price (₹)', type: 'number' },
        { key: 'capacity', label: 'Capacity', type: 'number', hint: '0 means unlimited' },
        { key: 'is_paid', label: 'Paid event', type: 'checkbox' },
        { key: 'status', label: 'Status', type: 'select', options: ['published', 'draft', 'cancelled'] },
      ],
    },
    noticeboards: {
      title: 'Notices', group: 'Content', resource: 'noticeboards', singular: 'notice',
      columns: [
        { key: 'id', label: 'ID', width: 56 },
        { key: 'title', label: 'Title' },
        { key: 'category', label: 'Category' },
        { key: 'is_important', label: 'Important', format: 'bool' },
        { key: 'created_at', label: 'Posted', format: 'datetime' },
      ],
      fields: [
        { key: 'title', label: 'Title', wide: true, required: true },
        { key: 'body', label: 'Body', type: 'textarea', wide: true },
        { key: 'category', label: 'Category', hint: 'e.g. Maintenance, Security' },
        { key: 'site_id', label: 'Site', type: 'select', source: 'sites', required: true },
        { key: 'cover_image', label: 'Cover image URL', wide: true },
        { key: 'expires_at', label: 'Expires at', type: 'datetime-local' },
        { key: 'is_important', label: 'Pin as important', type: 'checkbox' },
      ],
    },
    communities: {
      title: 'Communities', group: 'Content', resource: 'communities', singular: 'community',
      columns: [
        { key: 'id', label: 'ID', width: 56 },
        { key: 'name', label: 'Name' },
        { key: 'category', label: 'Category' },
        { key: 'members_count', label: 'Members', format: 'number' },
        { key: 'trending', label: 'Trending', format: 'bool' },
      ],
      fields: [
        { key: 'name', label: 'Name', wide: true, required: true },
        { key: 'description', label: 'Description', type: 'textarea', wide: true },
        { key: 'cover_image', label: 'Cover image URL', wide: true },
        { key: 'category', label: 'Category' },
        { key: 'site_id', label: 'Site', type: 'select', source: 'sites', required: true },
        { key: 'trending', label: 'Show as trending', type: 'checkbox' },
      ],
    },
    posts: {
      title: 'Feed posts', group: 'Content', resource: 'posts', singular: 'post',
      columns: [
        { key: 'id', label: 'ID', width: 56 },
        { key: 'body', label: 'Body', truncate: true },
        { key: 'community_id', label: 'Community', format: 'number' },
        { key: 'user_id', label: 'Author', format: 'number' },
        { key: 'created_at', label: 'Posted', format: 'datetime' },
      ],
      fields: [
        { key: 'body', label: 'Body', type: 'textarea', wide: true, required: true },
        { key: 'user_id', label: 'Author user ID', type: 'number', required: true },
        { key: 'community_id', label: 'Community ID', type: 'number' },
        { key: 'image_url', label: 'Image URL', wide: true },
      ],
    },
    users: {
      title: 'Members', group: 'People', resource: 'users', singular: 'member',
      columns: [
        { key: 'id', label: 'ID', width: 56 },
        { key: 'firstname', label: 'First name' },
        { key: 'lastname', label: 'Last name' },
        { key: 'mobile', label: 'Mobile' },
        { key: 'company_name', label: 'Company' },
        { key: 'wallet_balance', label: 'Wallet', format: 'money' },
        { key: 'loyalty_points', label: 'Points', format: 'number' },
      ],
      fields: [
        { key: 'firstname', label: 'First name' },
        { key: 'lastname', label: 'Last name' },
        { key: 'mobile', label: 'Mobile', required: true, hint: '10 digits, no country code' },
        { key: 'email', label: 'Email' },
        { key: 'company_name', label: 'Company' },
        { key: 'designation', label: 'Designation' },
        { key: 'site_id', label: 'Site', type: 'select', source: 'sites', required: true },
        { key: 'gender', label: 'Gender' },
        { key: 'wallet_balance', label: 'Wallet balance (₹)', type: 'number' },
        { key: 'loyalty_points', label: 'Privilege points', type: 'number' },
        { key: 'profile_image', label: 'Profile image URL', wide: true },
      ],
    },
    sites: {
      title: 'Sites', group: 'Setup', resource: 'sites', singular: 'site',
      columns: [
        { key: 'id', label: 'ID', width: 56 },
        { key: 'name', label: 'Name' },
        { key: 'city', label: 'City' },
        { key: 'address', label: 'Address' },
        { key: 'active', label: 'Active', format: 'bool' },
      ],
      fields: [
        { key: 'name', label: 'Name', wide: true, required: true },
        { key: 'city', label: 'City' },
        { key: 'address', label: 'Address', wide: true },
        { key: 'logo_url', label: 'Logo URL', wide: true },
        { key: 'active', label: 'Active', type: 'checkbox' },
      ],
    },
    event_categories: {
      title: 'Event categories', group: 'Setup', resource: 'event_categories', singular: 'category',
      columns: [
        { key: 'id', label: 'ID', width: 56 },
        { key: 'name', label: 'Name' },
      ],
      fields: [
        { key: 'name', label: 'Name', wide: true, required: true },
        { key: 'site_id', label: 'Site', type: 'select', source: 'sites', required: true },
      ],
    },
    team: { title: 'Administrators', group: 'Setup' },
  };

  // ---------------------------------------------------------------- formatting

  function fmt(value, format) {
    if (value == null || value === '') return '<span style="color:var(--faint)">—</span>';
    if (format === 'datetime') {
      var d = new Date(String(value).replace(' ', 'T'));
      if (isNaN(d)) return esc(value);
      return d.toLocaleString('en-IN', {
        day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit',
      });
    }
    if (format === 'money') return '₹' + Number(value).toLocaleString('en-IN');
    if (format === 'number') return Number(value).toLocaleString('en-IN');
    if (format === 'bool') {
      return value
        ? '<span class="pill good">Yes</span>'
        : '<span class="pill mute">No</span>';
    }
    if (format === 'pill') {
      var cls = value === 'published' ? 'good' : value === 'cancelled' ? 'bad' : 'warn';
      return '<span class="pill ' + cls + '">' + esc(value) + '</span>';
    }
    return esc(value);
  }

  /** SQLite stores "YYYY-MM-DD HH:MM:SS"; <input type=datetime-local> wants "YYYY-MM-DDTHH:MM". */
  function toLocalInput(value) {
    if (!value) return '';
    var d = new Date(String(value).replace(' ', 'T'));
    if (isNaN(d)) return '';
    var pad = function (n) { return String(n).padStart(2, '0'); };
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
      'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
  }

  // ---------------------------------------------------------------- nav

  function buildNav() {
    var nav = $('nav');
    nav.innerHTML = '';
    var lastGroup = '';
    Object.keys(PAGES).forEach(function (key) {
      var page = PAGES[key];
      if (page.group !== lastGroup) {
        var g = document.createElement('div');
        g.className = 'group';
        g.textContent = page.group;
        nav.appendChild(g);
        lastGroup = page.group;
      }
      var b = document.createElement('button');
      b.textContent = page.title;
      b.dataset.page = key;
      if (key === state.page) b.className = 'on';
      b.onclick = function () { go(key); };
      nav.appendChild(b);
    });
  }

  function go(page) {
    state.page = page;
    state.search = '';
    buildNav();
    $('page-title').textContent = PAGES[page].title;
    render();
  }

  // ---------------------------------------------------------------- render

  function render() {
    var page = PAGES[state.page];
    var actions = $('topbar-actions');
    var content = $('content');
    actions.innerHTML = '';
    content.innerHTML = '<div class="loading">Loading…</div>';

    if (state.page === 'dashboard') return renderDashboard();
    if (state.page === 'team') return renderTeam();

    var search = document.createElement('input');
    search.className = 'search';
    search.placeholder = 'Search ' + page.title.toLowerCase() + '…';
    search.value = state.search;
    var debounce;
    search.oninput = function () {
      clearTimeout(debounce);
      state.search = search.value;
      debounce = setTimeout(loadList, 260);
    };
    actions.appendChild(search);

    var add = document.createElement('button');
    add.className = 'btn primary';
    add.textContent = 'New ' + page.singular;
    add.onclick = function () { openEditor(null); };
    actions.appendChild(add);

    loadList();
  }

  function loadList() {
    var page = PAGES[state.page];
    var query = state.search ? '?q=' + encodeURIComponent(state.search) : '';
    api('/' + page.resource + query).then(function (data) {
      state.records = data.records || [];
      renderTable();
    }).catch(function (e) {
      $('content').innerHTML = '<div class="empty"><h3>Could not load</h3><p>' + esc(e.message) + '</p></div>';
    });
  }

  function renderTable() {
    var page = PAGES[state.page];
    if (!state.records.length) {
      $('content').innerHTML =
        '<div class="card"><div class="empty"><h3>Nothing here yet</h3><p>Create your first ' +
        esc(page.singular) + ' with the button above.</p></div></div>';
      return;
    }

    var html = '<div class="card"><div class="table-wrap"><table><thead><tr>';
    page.columns.forEach(function (c) {
      html += '<th' + (c.width ? ' style="width:' + c.width + 'px"' : '') + '>' + esc(c.label) + '</th>';
    });
    html += '<th></th></tr></thead><tbody>';

    state.records.forEach(function (rec, i) {
      html += '<tr>';
      page.columns.forEach(function (c) {
        html += '<td class="' + (c.format === 'money' || c.format === 'number' ? 'num ' : '') +
          (c.truncate ? 'cell-truncate' : '') + '">' + fmt(rec[c.key], c.format) + '</td>';
      });
      html += '<td class="actions">';
      (page.extraActions || []).forEach(function (a) {
        html += '<button class="btn ghost small" data-extra="' + esc(a.action) + '" data-i="' + i + '">' +
          esc(a.label) + '</button>';
      });
      html += '<button class="btn ghost small" data-edit="' + i + '">Edit</button>' +
        '<button class="btn danger small" data-del="' + i + '">Delete</button></td></tr>';
    });

    html += '</tbody></table></div></div>';
    $('content').innerHTML = html;

    $('content').querySelectorAll('[data-edit]').forEach(function (b) {
      b.onclick = function () { openEditor(state.records[+b.dataset.edit]); };
    });
    $('content').querySelectorAll('[data-del]').forEach(function (b) {
      b.onclick = function () { confirmDelete(state.records[+b.dataset.del]); };
    });
    $('content').querySelectorAll('[data-extra]').forEach(function (b) {
      b.onclick = function () { showRegistrations(state.records[+b.dataset.i]); };
    });
  }

  function confirmDelete(rec) {
    var page = PAGES[state.page];
    var label = rec.title || rec.name || rec.firstname || ('#' + rec.id);
    if (!confirm('Delete "' + label + '"? This cannot be undone.')) return;
    api('/' + page.resource + '/' + rec.id, { method: 'DELETE' })
      .then(function () { toast('Deleted.'); loadList(); })
      .catch(function (e) { toast(e.message, true); });
  }

  // ---------------------------------------------------------------- editor

  function openEditor(rec) {
    var page = PAGES[state.page];
    state.editing = rec;
    $('modal-title').textContent = (rec ? 'Edit ' : 'New ') + page.singular;
    $('modal-error').hidden = true;

    var html = '';
    page.fields.forEach(function (f) {
      var value = rec ? rec[f.key] : '';
      html += '<div class="field' + (f.wide ? ' wide' : '') + (f.type === 'checkbox' ? ' check' : '') + '">';

      if (f.type === 'checkbox') {
        html += '<input type="checkbox" id="f_' + f.key + '"' + (value ? ' checked' : '') + '>' +
          '<label for="f_' + f.key + '">' + esc(f.label) + '</label>';
      } else {
        html += '<label for="f_' + f.key + '">' + esc(f.label) +
          (f.required ? ' <span style="color:var(--bad)">*</span>' : '') + '</label>';

        if (f.type === 'textarea') {
          html += '<textarea id="f_' + f.key + '">' + esc(value) + '</textarea>';
        } else if (f.type === 'select') {
          var opts = f.options
            ? f.options.map(function (o) { return { id: o, name: o }; })
            : (state[f.source] || []);
          // On a new record, preselect the first option for fields the database
          // will not accept as null.
          var current = value;
          if (!rec && !current && f.required && opts.length) current = opts[0].id;

          html += '<select id="f_' + f.key + '">';
          if (!f.required) html += '<option value="">—</option>';
          opts.forEach(function (o) {
            var sel = String(o.id) === String(current) ? ' selected' : '';
            html += '<option value="' + esc(o.id) + '"' + sel + '>' + esc(o.name) + '</option>';
          });
          html += '</select>';
        } else if (f.type === 'datetime-local') {
          html += '<input type="datetime-local" id="f_' + f.key + '" value="' + toLocalInput(value) + '">';
        } else {
          html += '<input type="' + (f.type || 'text') + '" id="f_' + f.key + '" value="' + esc(value) + '">';
        }
        if (f.hint) html += '<div class="hint">' + esc(f.hint) + '</div>';
      }
      html += '</div>';
    });

    $('modal-fields').innerHTML = html;
    $('modal').hidden = false;
  }

  function saveEditor() {
    var page = PAGES[state.page];
    var body = {};
    page.fields.forEach(function (f) {
      var el = $('f_' + f.key);
      if (!el) return;
      body[f.key] = f.type === 'checkbox' ? el.checked : el.value;
    });

    var btn = $('modal-save');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span>';

    var isNew = !state.editing;
    var path = '/' + page.resource + (isNew ? '' : '/' + state.editing.id);

    api(path, { method: isNew ? 'POST' : 'PATCH', body: body })
      .then(function () {
        $('modal').hidden = true;
        toast(isNew ? 'Created.' : 'Saved.');
        loadList();
      })
      .catch(function (e) {
        $('modal-error').textContent = e.message;
        $('modal-error').hidden = false;
      })
      .finally(function () {
        btn.disabled = false;
        btn.textContent = 'Save';
      });
  }

  // ---------------------------------------------------------------- registrations

  function showRegistrations(event) {
    $('page-title').textContent = 'Registrations — ' + event.title;
    $('topbar-actions').innerHTML = '';
    var back = document.createElement('button');
    back.className = 'btn ghost';
    back.textContent = '← Back to events';
    back.onclick = function () { go('events'); };
    $('topbar-actions').appendChild(back);
    $('content').innerHTML = '<div class="loading">Loading…</div>';

    api('/events/' + event.id + '/registrations').then(function (data) {
      var list = data.registrations || [];
      if (!list.length) {
        $('content').innerHTML = '<div class="card"><div class="empty"><h3>No registrations yet</h3></div></div>';
        return;
      }
      var html = '<div class="card"><div class="table-wrap"><table><thead><tr>' +
        '<th>Member</th><th>Mobile</th><th>Company</th><th>Guests</th><th>Paid</th>' +
        '<th>Ticket</th><th>Attended</th><th></th></tr></thead><tbody>';
      list.forEach(function (r, i) {
        html += '<tr>' +
          '<td>' + esc([r.firstname, r.lastname].filter(Boolean).join(' ')) + '</td>' +
          '<td>' + esc(r.mobile) + '</td>' +
          '<td>' + fmt(r.company_name) + '</td>' +
          '<td class="num">' + r.guests + '</td>' +
          '<td class="num">' + fmt(r.amount_paid, 'money') + '</td>' +
          '<td><code style="font-size:11.5px">' + esc(r.ticket_code) + '</code></td>' +
          '<td>' + (r.attended ? '<span class="pill good">Checked in</span>' : '<span class="pill mute">Not yet</span>') + '</td>' +
          '<td class="actions"><button class="btn ghost small" data-toggle="' + i + '">' +
          (r.attended ? 'Undo' : 'Check in') + '</button></td></tr>';
      });
      html += '</tbody></table></div></div>';
      $('content').innerHTML = html;

      $('content').querySelectorAll('[data-toggle]').forEach(function (b) {
        b.onclick = function () {
          var r = list[+b.dataset.toggle];
          api('/registrations/' + r.id + '/attendance', {
            method: 'PATCH', body: { attended: !r.attended },
          }).then(function () { showRegistrations(event); })
            .catch(function (e) { toast(e.message, true); });
        };
      });
    }).catch(function (e) {
      $('content').innerHTML = '<div class="empty"><h3>Could not load</h3><p>' + esc(e.message) + '</p></div>';
    });
  }

  // ---------------------------------------------------------------- dashboard

  function renderDashboard() {
    api('/dashboard').then(function (d) {
      var s = d.stats;
      var cards = [
        ['Members', s.users, true], ['Events', s.events], ['Upcoming', s.upcoming],
        ['Registrations', s.registrations], ['Checked in', s.attended],
        ['Notices', s.notices], ['Communities', s.communities], ['Feed posts', s.posts],
      ];
      var html = '<div class="stats">';
      cards.forEach(function (c) {
        html += '<div class="stat' + (c[2] ? ' accent' : '') + '"><b>' +
          Number(c[1]).toLocaleString('en-IN') + '</b><span>' + c[0] + '</span></div>';
      });
      html += '<div class="stat"><b>₹' + Number(s.revenue).toLocaleString('en-IN') +
        '</b><span>Collected</span></div></div>';

      html += '<div class="card"><h2>Recent registrations</h2>';
      var list = d.recent_registrations || [];
      if (!list.length) {
        html += '<div class="empty">No registrations yet.</div>';
      } else {
        html += '<div class="table-wrap"><table><thead><tr><th>Member</th><th>Mobile</th>' +
          '<th>Event</th><th>Paid</th><th>Status</th><th>When</th></tr></thead><tbody>';
        list.forEach(function (r) {
          html += '<tr><td>' + esc([r.firstname, r.lastname].filter(Boolean).join(' ')) + '</td>' +
            '<td>' + esc(r.mobile) + '</td>' +
            '<td class="cell-truncate">' + esc(r.event_title) + '</td>' +
            '<td class="num">' + fmt(r.amount_paid, 'money') + '</td>' +
            '<td>' + (r.attended ? '<span class="pill good">Checked in</span>' :
              '<span class="pill info">Registered</span>') + '</td>' +
            '<td>' + fmt(r.created_at, 'datetime') + '</td></tr>';
        });
        html += '</tbody></table></div>';
      }
      html += '</div>';
      $('content').innerHTML = html;
    }).catch(function (e) {
      $('content').innerHTML = '<div class="empty"><h3>Could not load</h3><p>' + esc(e.message) + '</p></div>';
    });
  }

  // ---------------------------------------------------------------- team

  function renderTeam() {
    api('/team/list').then(function (d) {
      var html = '<div class="card"><h2>Administrators</h2><div class="table-wrap"><table><thead><tr>' +
        '<th>Email</th><th>Name</th><th>Role</th><th>Last sign-in</th></tr></thead><tbody>';
      (d.admins || []).forEach(function (a) {
        html += '<tr><td>' + esc(a.email) + '</td><td>' + fmt(a.name) + '</td>' +
          '<td><span class="pill info">' + esc(a.role) + '</span></td>' +
          '<td>' + fmt(a.last_login_at, 'datetime') + '</td></tr>';
      });
      html += '</tbody></table></div></div>';

      html += '<div class="card" style="margin-top:20px"><h2>Add an administrator</h2>' +
        '<div style="padding:18px"><div class="fields">' +
        '<div class="field"><label for="t_email">Email</label><input id="t_email" type="email"></div>' +
        '<div class="field"><label for="t_name">Name</label><input id="t_name"></div>' +
        '<div class="field wide"><label for="t_pass">Password</label><input id="t_pass" type="password">' +
        '<div class="hint">At least 8 characters.</div></div></div>' +
        '<button class="btn primary" id="t_add" style="margin-top:16px">Add administrator</button></div></div>';

      html += '<div class="card" style="margin-top:20px"><h2>Change my password</h2>' +
        '<div style="padding:18px"><div class="field" style="max-width:320px">' +
        '<label for="t_new">New password</label><input id="t_new" type="password">' +
        '<div class="hint">At least 8 characters.</div></div>' +
        '<button class="btn primary" id="t_change" style="margin-top:16px">Change password</button></div></div>';

      $('content').innerHTML = html;

      $('t_add').onclick = function () {
        api('/team/invite', {
          method: 'POST',
          body: { email: $('t_email').value, name: $('t_name').value, password: $('t_pass').value },
        }).then(function () { toast('Administrator added.'); renderTeam(); })
          .catch(function (e) { toast(e.message, true); });
      };
      $('t_change').onclick = function () {
        api('/team/password', { method: 'POST', body: { password: $('t_new').value } })
          .then(function (r) { toast(r.message || 'Password changed.'); $('t_new').value = ''; })
          .catch(function (e) { toast(e.message, true); });
      };
    });
  }

  // ---------------------------------------------------------------- session

  function signOut() {
    localStorage.removeItem(TOKEN_KEY);
    token = null;
    $('app').hidden = true;
    $('login').hidden = false;
  }

  function start(admin) {
    $('login').hidden = true;
    $('app').hidden = false;
    $('who').textContent = admin.email;
    // Dropdown sources the editors depend on.
    Promise.all([api('/sites'), api('/event_categories')]).then(function (r) {
      state.sites = r[0].records || [];
      state.categories = r[1].records || [];
    }).catch(function () { /* editors fall back to blank dropdowns */ });
    buildNav();
    go('dashboard');
  }

  $('login-form').onsubmit = function (e) {
    e.preventDefault();
    var err = $('login-error');
    err.hidden = true;
    fetch('/admin/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: $('email').value, password: $('password').value }),
    }).then(function (r) { return r.json().then(function (d) { return { ok: r.ok, d: d }; }); })
      .then(function (res) {
        if (!res.ok) throw new Error(res.d.message || 'Could not sign in.');
        token = res.d.token;
        localStorage.setItem(TOKEN_KEY, token);
        start(res.d.admin);
      })
      .catch(function (e2) { err.textContent = e2.message; err.hidden = false; });
  };

  $('logout').onclick = function () {
    api('/logout', { method: 'POST' }).catch(function () {}).finally(signOut);
  };

  $('modal-save').onclick = saveEditor;
  $('modal-cancel').onclick = function () { $('modal').hidden = true; };
  $('modal-close').onclick = function () { $('modal').hidden = true; };
  $('modal-form').onsubmit = function (e) { e.preventDefault(); saveEditor(); };
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !$('modal').hidden) $('modal').hidden = true;
  });

  if (token) {
    api('/me').then(function (d) { start(d.admin); }).catch(signOut);
  }
})();
