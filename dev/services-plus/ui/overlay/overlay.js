// Sibling-NUI controller for request notifications (see SIBLING-NUI.md and
// client/overlay.lua). Deliberately vanilla JS/no build step - this file is
// the entire "hack", keeping it in one auditable place.
//
// Renders directly into the CitizenFX root NUI document (not into lb-phone's
// own iframe) so the notification card works even when the phone is closed
// or only shown at peek (plan §44) - unlike lb-phone-damage's overlay, this
// one deliberately does NOT live inside `.phone-container`.

;(function () {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'services-plus'

    let observedDocument = null
    let observer = null
    let reconnectTimer = null

    // { type: 'notification' | 'active', payload } | null
    let lastState = null

    function post(action, data) {
        return fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        })
            .then((r) => r.json())
            .catch(() => null)
    }

    function getRootDocument() {
        try {
            const doc = window.parent.document
            return doc && doc.body ? doc : null
        } catch {
            return null
        }
    }

    function getPhoneTheme(rootDocument) {
        try {
            const frame = Array.from(rootDocument.querySelectorAll('iframe')).find((f) => f.name === 'lb-phone')
            return frame?.contentDocument?.documentElement?.getAttribute('data-theme') || 'dark'
        } catch {
            return 'dark'
        }
    }

    function escapeHtml(text) {
        const div = document.createElement('div')
        div.textContent = text == null ? '' : String(text)
        return div.innerHTML
    }

    const STYLES = `
        #services-plus-overlay {
            position: fixed;
            top: 0; left: 0; right: 0;
            display: flex;
            justify-content: center;
            padding-top: 3.2rem;
            z-index: 2147483647;
            pointer-events: none;
            font-family: -apple-system, 'Segoe UI', sans-serif;
        }
        #services-plus-overlay .sp-card {
            pointer-events: auto;
            width: 21rem;
            max-width: 90vw;
            border-radius: 1rem;
            padding: 0.9rem 1rem;
            box-shadow: 0 0.6rem 1.8rem rgba(0, 0, 0, 0.35);
            backdrop-filter: blur(12px);
            animation: sp-drop-in 0.25s ease-out;
        }
        #services-plus-overlay[data-theme='light'] .sp-card {
            background: rgba(245, 245, 250, 0.92);
            color: #000;
        }
        #services-plus-overlay[data-theme='dark'] .sp-card {
            background: rgba(28, 28, 30, 0.92);
            color: #f2f2f7;
        }
        #services-plus-overlay .sp-title { font-size: 0.95rem; font-weight: 700; }
        #services-plus-overlay .sp-sub { font-size: 0.78rem; opacity: 0.7; margin-top: 0.1rem; }
        #services-plus-overlay .sp-meta { font-size: 0.78rem; opacity: 0.85; margin-top: 0.35rem; }
        #services-plus-overlay .sp-buttons { display: flex; gap: 0.5rem; margin-top: 0.7rem; }
        #services-plus-overlay .sp-btn {
            flex: 1;
            border: none;
            border-radius: 0.6rem;
            padding: 0.55rem 0;
            font-size: 0.78rem;
            font-weight: 700;
            cursor: pointer;
        }
        #services-plus-overlay .sp-btn.accept, #services-plus-overlay .sp-btn.complete { background: #30d158; color: #fff; }
        #services-plus-overlay .sp-btn.decline, #services-plus-overlay .sp-btn.cancel { background: #ff453a; color: #fff; }
        @keyframes sp-drop-in {
            from { transform: translateY(-0.6rem); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
    `

    function ensureStyles(rootDocument) {
        if (rootDocument.getElementById('services-plus-overlay-styles')) return
        const style = rootDocument.createElement('style')
        style.id = 'services-plus-overlay-styles'
        style.textContent = STYLES
        rootDocument.head.appendChild(style)
    }

    function ensureContainer(rootDocument) {
        let el = rootDocument.getElementById('services-plus-overlay')
        if (!el) {
            el = rootDocument.createElement('div')
            el.id = 'services-plus-overlay'
            rootDocument.body.appendChild(el)
        }
        return el
    }

    function formatDistance(meters) {
        if (typeof meters !== 'number') return ''
        const miles = meters / 1609.34
        return `${miles.toFixed(1)} mi`
    }

    function renderNotification(rootDocument, card, payload) {
        card.innerHTML = `
            <div class="sp-title">${escapeHtml(payload.typeName)}</div>
            <div class="sp-sub">${escapeHtml(payload.companyName)}</div>
            ${payload.passengerCount ? `<div class="sp-meta">${escapeHtml(payload.passengerCount)} passengers</div>` : ''}
            ${payload.description ? `<div class="sp-meta">${escapeHtml(payload.description)}</div>` : ''}
            <div class="sp-buttons">
                <button class="sp-btn decline">Decline</button>
                <button class="sp-btn accept">Accept</button>
            </div>
        `

        card.querySelector('.decline').onclick = () => {
            post('overlayAction', { action: 'decline', requestId: payload.requestId })
            lastState = null
            render(rootDocument)
        }

        card.querySelector('.accept').onclick = () => {
            post('overlayAction', { action: 'accept', requestId: payload.requestId })
            // The client Lua replies with its own showActive/dismiss message
            // once the server responds - no optimistic state change here.
        }
    }

    function renderActive(rootDocument, card, payload) {
        card.innerHTML = `
            <div class="sp-title">${escapeHtml(payload.typeName)}</div>
            <div class="sp-sub">${escapeHtml(payload.companyName)}</div>
            <div class="sp-meta">
                ${payload.passengerCount ? `${escapeHtml(payload.passengerCount)} passengers · ` : ''}
                <span class="sp-distance">${formatDistance(payload.distance)}</span>
            </div>
            <div class="sp-buttons">
                <button class="sp-btn cancel">Cancel</button>
                <button class="sp-btn complete">Complete</button>
            </div>
        `

        card.querySelector('.cancel').onclick = () => post('overlayAction', { action: 'cancel', requestId: payload.requestId })
        card.querySelector('.complete').onclick = () => post('overlayAction', { action: 'complete', requestId: payload.requestId })
    }

    function render(rootDocument) {
        if (!rootDocument || !rootDocument.body) return

        ensureStyles(rootDocument)
        const container = ensureContainer(rootDocument)
        container.setAttribute('data-theme', getPhoneTheme(rootDocument))
        container.innerHTML = ''

        if (!lastState) return

        const card = rootDocument.createElement('div')
        card.className = 'sp-card'

        if (lastState.type === 'notification') renderNotification(rootDocument, card, lastState.payload)
        else if (lastState.type === 'active') renderActive(rootDocument, card, lastState.payload)

        container.appendChild(card)
    }

    function connect() {
        const rootDocument = getRootDocument()
        if (!rootDocument) return

        if (rootDocument === observedDocument) return

        observer?.disconnect()
        observedDocument = rootDocument

        observer = new MutationObserver(() => {
            if (lastState && !rootDocument.getElementById('services-plus-overlay')) render(rootDocument)
        })
        observer.observe(rootDocument.body, { childList: true })

        render(rootDocument)
    }

    window.addEventListener('message', (event) => {
        const data = event.data
        if (!data || !data.action) return

        if (data.action === 'requestNotification') {
            lastState = { type: 'notification', payload: data.payload }
        } else if (data.action === 'dismiss') {
            if (lastState?.type === 'notification' && lastState.payload.requestId === data.requestId) lastState = null
        } else if (data.action === 'showActive') {
            lastState = { type: 'active', payload: data.payload }
        } else if (data.action === 'updateDistance') {
            if (lastState?.type === 'active') lastState.payload.distance = data.distance
        } else if (data.action === 'clearActive') {
            if (lastState?.type === 'active') lastState = null
        } else {
            return
        }

        render(observedDocument || getRootDocument())
    })

    connect()
    reconnectTimer = window.setInterval(connect, 2000)

    post('ready', {})

    window.addEventListener('unload', () => {
        window.clearInterval(reconnectTimer)
        try {
            observedDocument?.getElementById('services-plus-overlay')?.remove()
            observedDocument?.getElementById('services-plus-overlay-styles')?.remove()
        } catch {
            // root document may already be gone during a restart
        }
    })
})()
