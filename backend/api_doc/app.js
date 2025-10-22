let API_MODULES = {};

document.addEventListener('DOMContentLoaded', () => {
    buildModuleIndex();
    renderNavigationTree();
    renderCatalog();
    initializeNavigation();
    initializeSearch();
    showSection('overview');
});

function buildModuleIndex() {
    API_MODULES = {
        auth: API_DATA.auth || [],
        system: API_DATA.system || [],
        messages: API_DATA.messages || [],
        chats: API_DATA.chats || [],
        friends: API_DATA.friends || [],
        websocket: API_DATA.websocket || [],
        models: API_DATA.models || [],
    };
}

// 渲染导航树
function renderNavigationTree() {
    const container = document.getElementById('apiTree');
    if (!container) return;

    const groups = [
        {
            key: 'overview',
            title: '文档概览',
            icon: 'fas fa-home',
            items: [
                {
                    id: 'overview',
                    title: 'API 概览',
                    method: 'INFO',
                    path: '/',
                    description: '文档简介'
                }
            ],
        },
        {
            key: 'models',
            title: '模型定义',
            icon: 'fas fa-database',
            items: API_MODULES.models,
        },
        {
            key: 'catalog',
            title: '接口索引',
            icon: 'fas fa-list',
            items: [
                {
                    id: 'catalog',
                    title: '接口目录',
                    method: 'INFO',
                    path: '/',
                    description: '所有接口的快速入口'
                }
            ],
        },
        {
            key: 'auth',
            title: '用户认证',
            icon: 'fas fa-shield-alt',
            items: API_MODULES.auth,
        },
        {
            key: 'system',
            title: '系统接口',
            icon: 'fas fa-cogs',
            items: API_MODULES.system,
        },
        {
            key: 'messages',
            title: '消息接口',
            icon: 'fas fa-envelope',
            items: API_MODULES.messages,
        },
        {
            key: 'chats',
            title: '会话接口',
            icon: 'fas fa-comments',
            items: API_MODULES.chats,
        },
        {
            key: 'friends',
            title: '好友接口',
            icon: 'fas fa-user-friends',
            items: API_MODULES.friends,
        },
        {
            key: 'websocket',
            title: '实时通信',
            icon: 'fas fa-plug',
            items: API_MODULES.websocket,
        },
    ];

    let html = '<ul class="tree-list">';
    groups.forEach(group => {
        const hasChildren = Array.isArray(group.items) && group.items.length > 0;
        const classes = ['tree-group'];
        if (hasChildren) {
            classes.push('open');
        }

        html += `
            <li class="${classes.join(' ')}" data-module="${group.key}">
                <div class="tree-item" data-target="${group.key}">
                    <span class="tree-icon"><i class="${group.icon}"></i></span>
                    <span class="tree-title">${group.title}</span>
                    ${hasChildren ? '<span class="tree-toggle"><i class="fas fa-chevron-down"></i></span>' : ''}
                </div>
                ${hasChildren ? `
                    <ul class="tree-children">
                        ${group.items.map(api => createTreeLeaf(group.key, api)).join('')}
                    </ul>
                ` : ''}
            </li>
        `;
    });
    html += '</ul>';

    container.innerHTML = html;
}

function createTreeLeaf(module, api) {
    const method = (api.method || 'GET').toUpperCase();
    const searchText = [
        api.title || '',
        api.path || '',
        method,
        api.description || ''
    ].join(' ').toLowerCase();

    const badgeClass = methodBadgeClass(method);
    return `
        <li class="tree-leaf" data-module="${module}" data-api-id="${api.id}" data-search="${escapeHtml(searchText)}">
            <span class="method-badge ${badgeClass}">${method}</span>
            <span class="leaf-title">${api.title || api.id}</span>
        </li>
    `;
}

function methodBadgeClass(method) {
    switch (method) {
        case 'GET':
            return 'method-get';
        case 'POST':
            return 'method-post';
        case 'PUT':
        case 'PATCH':
            return 'method-put';
        case 'DELETE':
            return 'method-delete';
        default:
            return 'method-info';
    }
}

function renderCatalog() {
    const container = document.getElementById('catalog-list');
    if (!container) return;

    const catalogGroups = [
        { key: 'system', title: '系统接口', items: API_MODULES.system },
        { key: 'auth', title: '用户认证', items: API_MODULES.auth },
        { key: 'models', title: '模型定义', items: API_MODULES.models },
        { key: 'messages', title: '消息接口', items: API_MODULES.messages },
        { key: 'chats', title: '会话接口', items: API_MODULES.chats },
        { key: 'friends', title: '好友接口', items: API_MODULES.friends },
        { key: 'websocket', title: '实时通信', items: API_MODULES.websocket },
    ];

    let html = '';
    catalogGroups.forEach(group => {
        if (!group.items || !group.items.length) return;
        html += `
            <div class="api-section">
                <h4><i class="fas fa-folder"></i> ${group.title}</h4>
                <ul class="catalog-list">
                    ${group.items.map(api => `
                        <li class="catalog-item" data-module="${group.key}" data-api-id="${api.id}">
                            <span class="api-method method-${(api.method || 'GET').toLowerCase()}">${api.method || 'GET'}</span>
                            <code class="api-path">${API_DATA.baseUrl}${api.path || ''}</code>
                            <span class="api-title">${api.title}</span>
                        </li>
                    `).join('')}
                </ul>
            </div>
        `;
    });

    container.innerHTML = html;

    container.addEventListener('click', function(e) {
        const item = e.target.closest('.catalog-item');
        if (!item) return;
        const module = item.getAttribute('data-module');
        const apiId = item.getAttribute('data-api-id');
        showSection('api-detail', module, apiId);
        setTimeout(() => {
            const card = document.querySelector(`#api-detail .api-card[data-api-id="${apiId}"]`);
            if (card) {
                card.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }, 0);
    });
}

function initializeNavigation() {
    const treeContainer = document.getElementById('apiTree');
    if (!treeContainer) return;

    treeContainer.addEventListener('click', function(event) {
        const toggle = event.target.closest('.tree-toggle');
        if (toggle) {
            const group = toggle.closest('.tree-group');
            if (group) {
                group.classList.toggle('collapsed');
                group.classList.toggle('open');
            }
            return;
        }

        const item = event.target.closest('.tree-item');
        if (item) {
            const group = item.closest('.tree-group');
            if (group) {
                group.classList.toggle('collapsed');
                group.classList.toggle('open');
            }
            return;
        }

        const leaf = event.target.closest('.tree-leaf');
        if (!leaf) return;

        const module = leaf.getAttribute('data-module');
        const apiId = leaf.getAttribute('data-api-id');

        if (module === 'overview' || module === 'catalog') {
            showSection(module);
        } else {
            showSection('api-detail', module, apiId);
        }
    });
}

function showSection(sectionId, moduleKey, apiId) {
    const sections = document.querySelectorAll('.section');
    sections.forEach(section => section.classList.remove('active'));

    const targetSection = document.getElementById(sectionId);
    if (targetSection) {
        targetSection.classList.add('active');
    }

    if (sectionId === 'api-detail' && moduleKey && apiId) {
        renderApiDetail(moduleKey, apiId);
    }

    setActiveTree(sectionId === 'api-detail' ? moduleKey : sectionId, apiId);
}

function setActiveTree(sectionId, apiId) {
    const treeContainer = document.getElementById('apiTree');
    if (!treeContainer) return;

    const groups = treeContainer.querySelectorAll('.tree-group');
    groups.forEach(group => {
        const module = group.getAttribute('data-module');
        const item = group.querySelector('.tree-item');
        if (module === sectionId) {
            if (item) item.classList.add('active');
            group.classList.remove('collapsed');
            group.classList.add('open');
        } else {
            if (item) item.classList.remove('active');
        }
    });

    const leaves = treeContainer.querySelectorAll('.tree-leaf');
    leaves.forEach(leaf => leaf.classList.remove('active'));

    if (sectionId && apiId) {
        const target = treeContainer.querySelector(`.tree-leaf[data-module="${sectionId}"][data-api-id="${apiId}"]`);
        if (target) {
            target.classList.add('active');
            const group = target.closest('.tree-group');
            if (group) {
                group.classList.remove('collapsed');
                group.classList.add('open');
                const item = group.querySelector('.tree-item');
                if (item) item.classList.add('active');
            }
        }
    }
}

function renderApiDetail(moduleKey, apiId) {
    const container = document.getElementById('api-detail');
    if (!container) return;

    const moduleApis = API_MODULES[moduleKey] || [];
    const api = moduleApis.find(item => item.id === apiId);

    if (!api) {
        container.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-info-circle"></i>
                <p>未找到接口详情，请重新选择。</p>
            </div>
        `;
        return;
    }

    container.innerHTML = `
        <div class="section-header">
            <h2><i class="fas fa-code"></i> ${api.title}</h2>
            <p>${api.description || ''}</p>
        </div>
        ${createAPICard(api)}
    `;
}

function initializeSearch() {
    const searchInput = document.getElementById('searchInput');
    const treeContainer = document.getElementById('apiTree');
    if (!searchInput || !treeContainer) return;

    searchInput.addEventListener('input', function() {
        const query = this.value.toLowerCase().trim();
        const groups = treeContainer.querySelectorAll('.tree-group');

        groups.forEach(group => {
            const leaves = group.querySelectorAll('.tree-leaf');
            let visibleLeaves = 0;

            leaves.forEach(leaf => {
                const haystack = leaf.getAttribute('data-search') || '';
                const match = !query || haystack.includes(query);
                leaf.style.display = match ? 'flex' : 'none';
                if (match) visibleLeaves += 1;
            });

            group.style.display = visibleLeaves > 0 || !leaves.length ? '' : 'none';
            if (query && visibleLeaves > 0) {
                group.classList.remove('collapsed');
                group.classList.add('open');
            }
        });
    });
}

// --- 生成接口卡片和辅助函数 ---
function createAPICard(api) {
    return `
        <div class="api-card" data-api-id="${api.id}">
            <div class="api-header">
                <div class="api-title">
                    <h3>${api.title}</h3>
                    <span class="api-method method-${(api.method || 'GET').toLowerCase()}">${api.method || 'GET'}</span>
                </div>
                <div class="api-path"><code>${API_DATA.baseUrl}${api.path || ''}</code></div>
                <div class="api-description">${api.description || ''}</div>
            </div>
            <div class="api-body">
                ${api.authentication ?
                    '<div class="api-section"><span class="auth-required"><i class="fas fa-lock"></i> 需要认证</span></div>' :
                    '<div class="api-section"><span class="auth-not-required"><i class="fas fa-unlock"></i> 公开接口</span></div>'
                }

                ${api.requestBody ? createRequestBodySection(api.requestBody) : ''}

                ${createResponsesSection(api.responses)}

                ${api.messageTypes ? createMessageTypesSection(api.messageTypes) : ''}
            </div>
        </div>
    `;
}

function createRequestBodySection(requestBody) {
    if (!requestBody) return '';

    return `
        <div class="api-section">
            <h4><i class="fas fa-arrow-up"></i> 请求体</h4>
            <div><strong>Content-Type:</strong> ${requestBody.contentType}</div>

            ${requestBody.schema ? `
                <div style="margin-top: 1rem;">
                    <strong>请求参数:</strong>
                    ${createParameterTable(requestBody.schema)}
                </div>
            ` : ''}

            ${requestBody.example ? `
                <div style="margin-top: 1rem;">
                    <strong>示例:</strong>
                    <div class="response-example">
                        <pre>${JSON.stringify(requestBody.example, null, 2)}</pre>
                    </div>
                </div>
            ` : ''}
        </div>
    `;
}

function createResponsesSection(responses) {
    if (!responses || !responses.length) return '';

    return `
        <div class="api-section">
            <h4><i class="fas fa-arrow-down"></i> 响应示例</h4>
            ${responses.map(response => `
                <div class="response-item">
                    <div class="response-meta">
                        <span class="status-badge status-${Math.floor(response.status / 100)}xx">${response.status}</span>
                        <span>${response.description || '响应'}</span>
                    </div>
                    <div class="response-example">
                        <pre>${JSON.stringify(response.example ?? response.body, null, 2)}</pre>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

function createMessageTypesSection(messageTypes) {
    if (!messageTypes || !messageTypes.length) return '';

    return `
        <div class="api-section">
            <h4><i class="fas fa-exchange-alt"></i> 消息类型</h4>
            ${messageTypes.map(type => `
                <div style="margin-bottom: 0.75rem;">
                    <div><strong>${type.type}:</strong> ${type.description}</div>
                    ${type.example ? `<div style="margin-left: 1rem; font-family: monospace; color: #6b7280;">示例: ${type.example}</div>` : ''}
                </div>
            `).join('')}
        </div>
    `;
}

function createParameterTable(schema) {
    if (!schema.properties) return '';

    let tableHTML = `
        <table class="parameter-table">
            <thead>
                <tr>
                    <th>参数名</th>
                    <th>类型</th>
                    <th>必需</th>
                    <th>描述</th>
                    <th>示例</th>
                </tr>
            </thead>
            <tbody>
    `;

    Object.keys(schema.properties).forEach(key => {
        const prop = schema.properties[key];
        const required = schema.required && schema.required.includes(key);

        tableHTML += `
            <tr>
                <td><code>${key}</code></td>
                <td>${prop.type}${prop.format ? ` (${prop.format})` : ''}</td>
                <td><span class="${required ? 'required' : 'optional'}">${required ? '必需' : '可选'}</span></td>
                <td>${prop.description || '-'}</td>
                <td>${prop.example ? `<code>${prop.example}</code>` : '-'}</td>
            </tr>
        `;
    });

    tableHTML += '</tbody></table>';
    return tableHTML;
}

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// 复制工具
function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        return navigator.clipboard.writeText(text);
    }

    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    textArea.style.top = '-999999px';
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
        return new Promise((resolve, reject) => {
            document.execCommand('copy') ? resolve() : reject();
            textArea.remove();
        });
    } catch (err) {
        textArea.remove();
        return Promise.reject(err);
    }
}
