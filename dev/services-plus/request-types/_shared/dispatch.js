// Shared helpers for full-card PeekPlus request-type templates. Each
// template (taxi/index.html, police_emergency/index.html, ...) loads this
// before its own small script and gets: an SVG icon builder, the standard
// postMessage/action-dispatch plumbing (same contract as PeekPlus' own
// built-in cards use), and a local countdown ticker for auto-decline.
window.Dispatch = (function () {
    const basePaths = {
        people: ['M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2', 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8'],
        location: ['M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0', 'M12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5'],
        distance: ['M5 3v18', 'M19 3v18', 'M9 7h6', 'M9 17h6'],
        clock: ['M12 20a7 7 0 1 0 0-14 7 7 0 0 0 0 14', 'M12 13V9', 'M12 13l3 2'],
        close: ['M6 6l12 12', 'M18 6L6 18'],
        check: ['M20 6L9 17l-5-5'],
        nav: ['M3 11l18-8-8 18-2-8-8-2z'],
        alert: ['M12 3l9 16H3z', 'M12 9v5', 'M12 17h.01'],
        note: ['M6 4h9l3 3v13H6z', 'M9 9h6', 'M9 13h6', 'M9 17h3'],
    }
    const icons = { ...basePaths }

    function registerIcons(map) {
        Object.assign(icons, map)
    }

    function icon(name, className) {
        const wrapper = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
        wrapper.setAttribute('class', `dispatch-icon${className ? ` ${className}` : ''}`)
        wrapper.setAttribute('viewBox', '0 0 24 24')
        wrapper.setAttribute('aria-hidden', 'true')
        const paths = icons[name] || icons.alert
        paths.forEach((definition) => {
            const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
            path.setAttribute('d', definition)
            wrapper.appendChild(path)
        })
        return wrapper
    }

    // Fills a .dispatch-badge element: the request type's own icon as a
    // permanent fallback, with the company's actual branding image (same
    // iconUrl the standard PeekPlus card would show, see card.iconUrl) laid
    // over it once it has loaded. Mirrors overlay.js's own addCardIcon().
    function badge(container, iconName, iconUrl) {
        container.classList.add('dispatch-badge')
        container.appendChild(icon(iconName))
        if (!iconUrl) return
        const image = document.createElement('img')
        image.className = 'dispatch-badge-image'
        image.alt = ''
        image.referrerPolicy = 'no-referrer'
        image.onload = () => container.classList.add('has-image')
        image.onerror = () => image.remove()
        image.src = iconUrl
        container.appendChild(image)
    }

    function el(tag, className, text) {
        const element = document.createElement(tag)
        if (className) element.className = className
        if (text != null) element.textContent = text
        return element
    }

    // A single content row: icon + label/value, optionally with a short
    // bold "aside" value on the right (e.g. a distance) and/or a trailing
    // element (e.g. a map thumbnail). Used for every row-shaped fact on a
    // dispatch card so they all line up and behave the same under a
    // flex-shrink parent (see .dispatch-row in dispatch.css).
    function row({ icon: iconName, label, value, aside, trailing }) {
        const wrap = el('div', 'dispatch-row')
        const iconWrap = el('div', 'dispatch-row-icon')
        iconWrap.appendChild(icon(iconName))
        const body = el('div', 'dispatch-row-body')
        body.append(el('div', 'dispatch-row-label', label), el('div', 'dispatch-row-value', value))
        wrap.append(iconWrap, body)
        if (aside) wrap.appendChild(el('div', 'dispatch-row-aside', aside))
        if (trailing) wrap.appendChild(trailing)
        return wrap
    }

    // The header's top-right corner: distance first (every card has one),
    // then whatever else is specific to this request type - a small icon
    // stands in for a text label since there's no room for both. Pass
    // { value, icon, highlight } per line; `highlight` gives one line (e.g.
    // taxi's fare) its own accent chip instead of blending into the rest.
    function headerStats(items) {
        const wrap = el('div', 'dispatch-header-stats')
        items.filter((item) => item?.value).forEach(({ value, icon: iconName, highlight }) => {
            const line = el('div', `dispatch-header-stat${highlight ? ' highlight' : ''}`)
            line.appendChild(el('span', 'dispatch-header-stat-value', value))
            if (iconName) line.appendChild(icon(iconName))
            wrap.appendChild(line)
        })
        return wrap
    }

    // Standard accept/decline (or complete/cancel) button, identical across
    // every dispatch template - only the accent color (set via CSS) and
    // which two action ids are offered differ.
    function button(payload, action) {
        const primary = action.id === 'accept' || action.id === 'complete'
        const armed = payload.card.confirmAction === action.id
        const labels = { decline: 'Decline', accept: 'Accept', cancel: 'Cancel', complete: 'Complete' }
        const b = el('button', `dispatch-btn ${primary ? 'primary' : 'secondary'}`)
        b.type = 'button'
        b.disabled = payload.card.actionInFlight || payload.presentation.callPriority
        b.append(icon(primary ? 'check' : 'close'), el('span', null, armed ? (action.confirm?.label || 'Confirm?') : (labels[action.id] || action.label)))
        b.addEventListener('click', () => {
            b.disabled = true
            runAction(payload, action.id)
        })
        return b
    }

    // Same lookup convention as PeekPlus' built-in details layout: request
    // types attach structured rows (label/value/icon) instead of the
    // template inventing its own data channel.
    function detail(card, iconName, fallback) {
        const row = card.details?.find((item) => item.icon === iconName)
        return row ? row.value : fallback
    }

    // Measures the card's own natural content height (see dispatch.css -
    // nothing forces the card to fill the iframe, so this is a true "how
    // tall does this actually need to be" number) and reports it to
    // overlay.js, which sizes the real iframe to match, clamped to at most
    // the template's registered height. Runs after every render so the
    // notification is only ever as tall as its current content needs.
    // getBoundingClientRect() forces a synchronous layout pass on its own,
    // so this reads the up-to-date size immediately - deliberately not
    // deferred to requestAnimationFrame, which can sit unfired for a while
    // when the phone/iframe isn't actively being composited (e.g. not the
    // visible screen right now), which would delay the resize for no reason.
    function reportHeight() {
        const card = document.querySelector('.dispatch-card')
        const height = card ? Math.ceil(card.getBoundingClientRect().height) : document.body.scrollHeight
        window.parent.postMessage({ type: 'peekplus:template:resize', height }, '*')
    }

    function onMessage(handler) {
        window.addEventListener('message', ({ data }) => {
            if (data?.type !== 'peekplus:template' || !data.card || !data.actionEndpoint) return
            handler(data)
            reportHeight()
        })
    }

    async function runAction(payload, actionId, onSettled) {
        try {
            await fetch(payload.actionEndpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ id: payload.card.id, revision: payload.card.revision, action: actionId }),
            })
        } finally {
            if (onSettled) onSettled()
        }
    }

    // Ticks a local countdown starting from a "remaining ms as of receipt"
    // snapshot (see overlay.js's remainingMs) rather than trusting the
    // host's clock domain. Returns a stop() function; onTick(-1) means
    // "held / no expiry", never negative-but-finite.
    function startCountdown(remainingMs, onTick) {
        let handle = null
        if (typeof remainingMs !== 'number' || remainingMs < 0) {
            onTick(-1)
            return () => {}
        }
        const startedAt = Date.now()
        const tick = () => {
            const left = Math.max(0, Math.round((remainingMs - (Date.now() - startedAt)) / 1000))
            onTick(left)
            if (left <= 0) window.clearInterval(handle)
        }
        tick()
        handle = window.setInterval(tick, 500)
        return () => window.clearInterval(handle)
    }

    return { el, icon, badge, row, headerStats, button, registerIcons, detail, onMessage, runAction, startCountdown }
})()
