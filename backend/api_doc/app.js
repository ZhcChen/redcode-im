// RedCode IM API 文档应用主脚本

// 初始化应用
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

function initializeApp() {
    // 渲染API内容
    renderAPIs();
    renderCatalog();

    // 初始化导航
    initializeNavigation();

    // 初始化搜索功能
    initializeSearch();

    // 显示默认页面
    showSection('overview');
}

// 渲染API内容
function renderAPIs() {
    renderAuthAPIs();
    renderSystemAPIs();
    renderMessagesAPIs();
    renderWebSocketAPIs();
}

// 渲染认证API
function renderAuthAPIs() {
    const container = document.getElementById('auth-apis');
    if (!container) return;

    container.innerHTML = API_DATA.auth.map(api => createAPICard(api)).join('');
}

// 渲染系统API
function renderSystemAPIs() {
    const container = document.getElementById('system-apis');
    if (!container) return;

    container.innerHTML = API_DATA.system.map(api => createAPICard(api)).join('');
}

// 渲染WebSocket API
function renderWebSocketAPIs() {
    const container = document.getElementById('websocket-apis');
    if (!container) return;

    container.innerHTML = API_DATA.websocket.map(api => createAPICard(api)).join('');
}

// 渲染消息API
function renderMessagesAPIs() {
    const container = document.getElementById('messages-apis');
    if (!container || !API_DATA.messages) return;

    container.innerHTML = API_DATA.messages.map(api => createAPICard(api)).join('');
}

// 渲染接口总览（目录）
function renderCatalog() {
    const container = document.getElementById('catalog-list');
    if (!container) return;

    const groups = [
        { key: 'system', title: '系统接口', items: API_DATA.system || [] },
        { key: 'auth', title: '用户认证', items: API_DATA.auth || [] },
        { key: 'messages', title: '消息接口', items: API_DATA.messages || [] },
        { key: 'websocket', title: 'WebSocket 实时通信', items: API_DATA.websocket || [] },
    ];

    let html = '';
    groups.forEach(g => {
        if (!g.items.length) return;
        html += `
            <div class="api-section">
                <h4><i class="fas fa-folder"></i> ${g.title}</h4>
                <ul class="catalog-list">
                    ${g.items.map(api => `
                        <li class="catalog-item" data-module="${g.key}" data-api-id="${api.id}">
                            <span class="api-method method-${api.method.toLowerCase()}">${api.method}</span>
                            <code class="api-path">${API_DATA.baseUrl}${api.path}</code>
                            <span class="api-title">${api.title}</span>
                        </li>
                    `).join('')}
                </ul>
            </div>
        `;
    });

    container.innerHTML = html;
    setupCatalogNavigation();
}

function setupCatalogNavigation() {
    const list = document.getElementById('catalog-list');
    if (!list) return;
    list.addEventListener('click', function(e) {
        const item = e.target.closest('.catalog-item');
        if (!item) return;
        const module = item.getAttribute('data-module');
        const apiId = item.getAttribute('data-api-id');
        showSection(module);
        setTimeout(() => {
            const targetCard = document.querySelector(`#${module} .api-card[data-api-id="${apiId}"]`);
            if (targetCard) targetCard.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }, 0);
    });
}

// 创建API卡片HTML
function createAPICard(api) {
    return `
        <div class="api-card" data-api-id="${api.id}">
            <div class="api-header">
                <div class="api-title">
                    <h3>${api.title}</h3>
                    <span class="api-method method-${api.method.toLowerCase()}">${api.method}</span>
                </div>
                <div class="api-path"><code>${API_DATA.baseUrl}${api.path}</code></div>
                <div class="api-description">${api.description}</div>
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

// 创建请求体部分
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

// 创建参数表格
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

    tableHTML += `
            </tbody>
        </table>
    `;

    return tableHTML;
}

// 创建响应部分
function createResponsesSection(responses) {
    return `
        <div class="api-section">
            <h4><i class="fas fa-arrow-down"></i> 响应</h4>
            ${responses.map(response => `
                <div style="margin-bottom: 1rem;">
                    <div style="margin-bottom: 0.5rem;">
                        <strong>HTTP ${response.status}:</strong> ${response.description}
                    </div>
                    ${response.example ? `
                        <div class="response-example">
                            <pre>${typeof response.example === 'string' ?
                                response.example :
                                JSON.stringify(response.example, null, 2)
                            }</pre>
                        </div>
                    ` : ''}
                </div>
            `).join('')}
        </div>
    `;
}

// 创建消息类型部分（WebSocket专用）
function createMessageTypesSection(messageTypes) {
    if (!messageTypes || messageTypes.length === 0) return '';

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

// 初始化导航
function initializeNavigation() {
    const navLinks = document.querySelectorAll('.nav-link');

    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();

            const targetId = this.getAttribute('href').substring(1);
            showSection(targetId);

            // 更新导航状态
            navLinks.forEach(l => l.classList.remove('active'));
            this.classList.add('active');
        });
    });
}

// 显示指定部分
function showSection(sectionId) {
    const sections = document.querySelectorAll('.section');

    sections.forEach(section => {
        section.classList.remove('active');
    });

    const targetSection = document.getElementById(sectionId);
    if (targetSection) {
        targetSection.classList.add('active');
    }
}

// 初始化搜索功能
function initializeSearch() {
    const searchInput = document.getElementById('searchInput');
    if (!searchInput) return;

    searchInput.addEventListener('input', function() {
        const query = this.value.toLowerCase().trim();

        if (query === '') {
            // 显示所有API
            document.querySelectorAll('.api-card').forEach(card => {
                card.style.display = 'block';
            });
        } else {
            // 搜索过滤
            document.querySelectorAll('.api-card').forEach(card => {
                const title = card.querySelector('h3').textContent.toLowerCase();
                const description = card.querySelector('.api-description').textContent.toLowerCase();
                const path = card.querySelector('.api-path').textContent.toLowerCase();

                if (title.includes(query) || description.includes(query) || path.includes(query)) {
                    card.style.display = 'block';
                } else {
                    card.style.display = 'none';
                }
            });
        }
    });
}

// 工具函数：格式化JSON
function formatJSON(obj) {
    return JSON.stringify(obj, null, 2);
}

// 工具函数：复制到剪贴板
function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        return navigator.clipboard.writeText(text);
    }

    // 降级方案
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

// 添加键盘快捷键
document.addEventListener('keydown', function(e) {
    // Ctrl/Cmd + K 聚焦搜索框
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.focus();
            searchInput.select();
        }
    }

    // ESC 清空搜索
    if (e.key === 'Escape') {
        const searchInput = document.getElementById('searchInput');
        if (searchInput && document.activeElement === searchInput) {
            searchInput.value = '';
            searchInput.dispatchEvent(new Event('input'));
            searchInput.blur();
        }
    }
});

// 添加复制代码功能
document.addEventListener('click', function(e) {
    if (e.target.closest('.response-example')) {
        const example = e.target.closest('.response-example');
        const code = example.querySelector('pre').textContent;

        copyToClipboard(code).then(() => {
            // 显示复制成功的视觉反馈
            const originalBg = example.style.backgroundColor;
            example.style.backgroundColor = '#10b981';
            example.style.color = 'white';

            setTimeout(() => {
                example.style.backgroundColor = originalBg;
                example.style.color = '';
            }, 300);
        }).catch(err => {
            console.error('复制失败:', err);
        });
    }
});

// 导出函数供其他脚本使用
window.APIViewer = {
    showSection,
    copyToClipboard,
    formatJSON
};