// Services+ Sibling-NUI request controller. It renders into LB Phone's real
// .full-phone tree and owns LB's native .phoneVisbility peek position. It
// does not enqueue an LB notification or edit any LB Phone files.
;(function () {
    const CONTROLLER_VERSION = 'peek-20260812-14'
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'services-plus'
    const OVERLAY_ID = 'services-plus-overlay'
    const STYLE_ID = 'services-plus-overlay-styles'
    const LOCK_ATTRIBUTE = 'data-services-plus-peek-lock'
    const CALL_PRIORITY_ATTRIBUTE = 'data-services-plus-call-priority'

    let lastState = null // { type: 'notification' | 'active', payload } | null
    let rootDocument = null
    let lbDocument = null
    let lbFrame = null
    let rootObserver = null
    let lbObserver = null
    let reconnectTimer = null
    let peekTimer = null
    let peekCaptureTimer = null
    let peekUntil = 0
    let peekReleaseTimer = null
    let lockSnapshot = null
    let applyingLock = false
    let peekAnimating = false
    let peekAnimationToken = 0
    let lastNotificationSoundAt = 0
    let callHasPriority = false
    let phoneIsOpen = false
    let cancelConfirmActive = false

    function post(action, data) {
        return fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((response) => response.json()).catch(() => null)
    }

    function playNotificationSound(soundName) {
        const now = Date.now()
        if (now - lastNotificationSoundAt < 1200) return
        lastNotificationSoundAt = now
        fetch('https://lb-phone/playSound', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ soundType: 'notification', soundName: soundName || 'default' }),
        }).catch(() => null)
    }

    function findRootDocument() {
        try {
            const document = window.parent.document
            return document?.body ? document : null
        } catch {
            return null
        }
    }

    function findLbPhone(root) {
        try {
            const frame = Array.from(root?.querySelectorAll('iframe') || []).find((entry) => entry.name === 'lb-phone')
            const document = frame?.contentDocument
            return document?.body ? { frame, document } : null
        } catch {
            return null
        }
    }

    function escapeHtml(text) {
        const div = document.createElement('div')
        div.textContent = text == null ? '' : String(text)
        return div.innerHTML
    }

    function getPhoneTheme() {
        return lbDocument?.documentElement?.getAttribute('data-theme') || 'dark'
    }

    const STYLES = `
        #${OVERLAY_ID} {
            z-index: 2147483646;
            pointer-events: none;
            display: flex;
            justify-content: center;
            font-family: -apple-system, 'Segoe UI', sans-serif;
        }
        #${OVERLAY_ID}[data-host='phone'] {
            position: absolute;
            top: 4.45rem;
            left: 0;
            right: 0;
        }
        #${OVERLAY_ID}[data-host='phone'][data-call-priority='true'] {
            top: 10.75rem;
            z-index: 97;
        }
        #${OVERLAY_ID}[data-host='lockscreen'] {
            position: relative;
            z-index: 2;
            flex: 0 0 auto;
            width: 100%;
        }
        #${OVERLAY_ID}[data-call-priority='true'] .sp-card {
            pointer-events: none;
        }
        #${OVERLAY_ID}[data-host='fallback'] {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            padding-top: 3.2rem;
        }
        #${OVERLAY_ID} .sp-card {
            pointer-events: auto;
            box-sizing: border-box;
            width: 24rem;
            max-width: 90vw;
            border-radius: 1.125rem;
            padding: .9rem 1rem;
            box-shadow: 0 .4rem 1rem rgba(0, 0, 0, .24);
        }
        #${OVERLAY_ID}[data-theme='light'] .sp-card {
            background: rgb(245, 245, 250);
            color: #000;
        }
        #${OVERLAY_ID}[data-theme='dark'] .sp-card {
            background: rgb(28, 28, 30);
            color: #f2f2f7;
        }
        #${OVERLAY_ID} .sp-title { font-size: .95rem; font-weight: 700; }
        #${OVERLAY_ID} .sp-sub { font-size: .78rem; opacity: .7; margin-top: .1rem; }
        #${OVERLAY_ID} .sp-meta { font-size: .78rem; opacity: .85; margin-top: .35rem; }
        #${OVERLAY_ID} .sp-buttons { display: flex; gap: .5rem; margin-top: .7rem; }
        #${OVERLAY_ID} .sp-btn {
            flex: 1;
            border: 0;
            border-radius: .6rem;
            padding: .55rem 0;
            font-size: .78rem;
            font-weight: 700;
            cursor: pointer;
        }
        #${OVERLAY_ID} .sp-btn.accept,
        #${OVERLAY_ID} .sp-btn.complete { background: #30d158; color: #fff; }
        #${OVERLAY_ID} .sp-btn.decline,
        #${OVERLAY_ID} .sp-btn.cancel { background: #ff453a; color: #fff; }
        /* LB Phone itself uses this (misspelled) wrapper to move the complete
           device: closed = 60rem, notification = 45rem. Owning this single
           native property avoids iframe crops and preserves LB's animation. */
        .phoneVisbility[${LOCK_ATTRIBUTE}] {
            visibility: visible !important;
            margin-top: 45rem !important;
            transition: margin-top .5s ease-out !important;
        }
        /* A call banner occupies the top of the phone. Lift the same native
           wrapper a little further so the request remains fully visible below
           it while LB Phone keeps the higher input/visual priority. */
        .phoneVisbility[${LOCK_ATTRIBUTE}='active'][${CALL_PRIORITY_ATTRIBUTE}] {
            margin-top: 39rem !important;
        }
        .phoneVisbility[${LOCK_ATTRIBUTE}='arming'],
        .phoneVisbility[${LOCK_ATTRIBUTE}='closing'] {
            margin-top: 60rem !important;
        }
    `

    function ensureStyles(targetDocument) {
        if (!targetDocument?.head || targetDocument.getElementById(STYLE_ID)) return
        const style = targetDocument.createElement('style')
        style.id = STYLE_ID
        style.textContent = STYLES
        targetDocument.head.appendChild(style)
    }

    function removeContainersExcept(targetDocument) {
        for (const doc of [rootDocument, lbDocument]) {
            if (doc && doc !== targetDocument) doc.getElementById(OVERLAY_ID)?.remove()
        }
    }

    function ensureContainer() {
        const lockscreenHost = phoneIsOpen && !lastState?.forceFallback
            ? lbDocument?.querySelector('.lockscreen-notification-container')
            : null
        const phoneHost = !phoneIsOpen && !lastState?.forceFallback
            ? lbDocument?.querySelector('.full-phone')
            : null
        const targetDocument = lockscreenHost || phoneHost ? lbDocument : phoneIsOpen ? null : rootDocument
        const host = lockscreenHost || phoneHost || (!phoneIsOpen ? rootDocument?.body : null)
        if (!targetDocument || !host) return null

        ensureStyles(targetDocument)
        removeContainersExcept(targetDocument)

        let container = targetDocument.getElementById(OVERLAY_ID)
        if (!container) {
            container = targetDocument.createElement('div')
            container.id = OVERLAY_ID
        }
        if (lockscreenHost && (container.parentElement !== host || host.firstElementChild !== container)) {
            host.prepend(container)
        } else if (!lockscreenHost && container.parentElement !== host) {
            host.appendChild(container)
        }
        container.dataset.host = lockscreenHost ? 'lockscreen' : phoneHost ? 'phone' : 'fallback'
        container.dataset.theme = getPhoneTheme()
        container.dataset.callPriority = callHasPriority ? 'true' : 'false'
        return container
    }

    function formatDistance(meters) {
        if (typeof meters !== 'number') return ''
        return `${(meters / 1609.34).toFixed(1)} mi`
    }

    function renderNotification(targetDocument, card, payload) {
        card.innerHTML = `
            <div class="sp-title">${escapeHtml(payload.typeName)}</div>
            <div class="sp-sub">${escapeHtml(payload.companyName)}</div>
            ${payload.passengerCount ? `<div class="sp-meta">${escapeHtml(payload.countLabel || 'Passenger count')}: ${escapeHtml(payload.passengerCount)}</div>` : ''}
            ${payload.description ? `<div class="sp-meta">${escapeHtml(payload.description)}</div>` : ''}
            <div class="sp-buttons">
                <button class="sp-btn decline">Delete · Decline</button>
                <button class="sp-btn accept">Enter · Accept</button>
            </div>
        `
        card.querySelector('.decline').onclick = () => {
            post('overlayAction', { action: 'decline', requestId: payload.requestId })
        }
        card.querySelector('.accept').onclick = () => {
            post('overlayAction', { action: 'accept', requestId: payload.requestId })
        }
    }

    function renderActive(targetDocument, card, payload) {
        if (payload.test) {
            card.innerHTML = `
                <div class="sp-title">${escapeHtml(payload.typeName)} · Accepted</div>
                <div class="sp-sub">${escapeHtml(payload.companyName)}</div>
                <div class="sp-meta">${escapeHtml(payload.description)}</div>
                <div class="sp-buttons">
                    <button class="sp-btn cancel">${cancelConfirmActive ? 'Confirm?' : 'Cancel test request'}</button>
                </div>
            `
            card.querySelector('.cancel').onclick = () => post('overlayAction', {
                action: 'testCancel',
                requestId: payload.requestId,
            })
            return
        }

        card.innerHTML = `
            <div class="sp-title">${escapeHtml(payload.typeName)}</div>
            <div class="sp-sub">${escapeHtml(payload.companyName)}</div>
            <div class="sp-meta">
                ${payload.passengerCount ? `${escapeHtml(payload.countLabel || 'Passenger count')}: ${escapeHtml(payload.passengerCount)} · ` : ''}
                <span class="sp-distance">${formatDistance(payload.distance)}</span>
            </div>
            <div class="sp-buttons">
                <button class="sp-btn cancel">${cancelConfirmActive ? 'Confirm?' : 'Cancel'}</button>
                <button class="sp-btn complete">Complete</button>
            </div>
        `
        card.querySelector('.cancel').onclick = () => post('overlayAction', { action: 'cancel', requestId: payload.requestId })
        card.querySelector('.complete').onclick = () => post('overlayAction', { action: 'complete', requestId: payload.requestId })
    }

    function render() {
        const container = ensureContainer()
        if (!container) return
        container.innerHTML = ''
        if (!lastState) return

        const card = container.ownerDocument.createElement('div')
        card.className = 'sp-card'
        if (lastState.type === 'notification') renderNotification(container.ownerDocument, card, lastState.payload)
        else renderActive(container.ownerDocument, card, lastState.payload)
        container.appendChild(card)
    }

    function capturePeek() {
        peekCaptureTimer = null
        if (!lbDocument || !lbFrame || Date.now() >= peekUntil) return
        const wrapper = lbDocument.querySelector('.phoneVisbility')
        if (!wrapper) return

        lockSnapshot = true
        peekAnimationToken += 1
        const animationToken = peekAnimationToken
        peekAnimating = true
        wrapper.setAttribute(LOCK_ATTRIBUTE, 'arming')
        void wrapper.offsetHeight
        window.requestAnimationFrame(() => window.requestAnimationFrame(() => {
            if (peekAnimationToken !== animationToken || Date.now() >= peekUntil) return
            peekAnimating = false
            wrapper.setAttribute(LOCK_ATTRIBUTE, 'active')
            applyPeekLock()
        }))
    }

    function applyPeekLock() {
        if (applyingLock || !lockSnapshot || Date.now() >= peekUntil || !lbDocument || !lbFrame) return
        applyingLock = true
        const wrapper = lbDocument.querySelector('.phoneVisbility')
        if (wrapper && !peekAnimating && wrapper.getAttribute(LOCK_ATTRIBUTE) !== 'active') {
            wrapper.setAttribute(LOCK_ATTRIBUTE, 'active')
        }
        if (wrapper) {
            if (callHasPriority && wrapper.getAttribute(LOCK_ATTRIBUTE) === 'active') {
                wrapper.setAttribute(CALL_PRIORITY_ATTRIBUTE, '')
            } else {
                wrapper.removeAttribute(CALL_PRIORITY_ATTRIBUTE)
            }
        }
        applyingLock = false
    }

    function removeLockFromDocument(targetDocument) {
        if (!targetDocument) return
        for (const element of targetDocument.querySelectorAll(`[${LOCK_ATTRIBUTE}]`)) {
            element.removeAttribute(LOCK_ATTRIBUTE)
            element.removeAttribute(CALL_PRIORITY_ATTRIBUTE)
        }
    }

    function releasePeek(immediate) {
        peekUntil = 0
        lockSnapshot = null
        peekAnimating = false
        peekAnimationToken += 1
        window.clearTimeout(peekTimer)
        window.clearTimeout(peekCaptureTimer)
        window.clearTimeout(peekReleaseTimer)
        peekTimer = null
        peekCaptureTimer = null
        peekReleaseTimer = null
        const wrapper = lbDocument?.querySelector('.phoneVisbility')
        if (!immediate && wrapper?.hasAttribute(LOCK_ATTRIBUTE)) {
            wrapper.removeAttribute(CALL_PRIORITY_ATTRIBUTE)
            wrapper.setAttribute(LOCK_ATTRIBUTE, 'closing')
            peekReleaseTimer = window.setTimeout(() => {
                wrapper.removeAttribute(LOCK_ATTRIBUTE)
                wrapper.removeAttribute(CALL_PRIORITY_ATTRIBUTE)
            }, 520)
        } else {
            removeLockFromDocument(rootDocument)
            removeLockFromDocument(lbDocument)
        }
    }

    function beginPeek(duration, holdPeek) {
        const milliseconds = Number(duration) || 0
        const indefinite = milliseconds < 0
        if (!holdPeek || milliseconds === 0) {
            releasePeek()
            return
        }

        window.clearTimeout(peekTimer)
        window.clearTimeout(peekCaptureTimer)
        window.clearTimeout(peekReleaseTimer)
        peekReleaseTimer = null

        peekUntil = indefinite ? Number.MAX_SAFE_INTEGER : Date.now() + milliseconds
        if (lockSnapshot) {
            applyPeekLock()
            return
        }

        // Own the geometry immediately. Waiting for LB Phone's animation made
        // its short native lifetime visible before our requested duration.
        capturePeek()
    }

    function cleanup() {
        releasePeek(true)
        rootObserver?.disconnect()
        lbObserver?.disconnect()
        window.clearInterval(reconnectTimer)
        for (const doc of [rootDocument, lbDocument]) {
            try {
                doc?.getElementById(OVERLAY_ID)?.remove()
                doc?.getElementById(STYLE_ID)?.remove()
            } catch {
                // A sibling frame may already be gone during resource stop.
            }
        }
    }

    function connect() {
        const nextRoot = findRootDocument()
        const phone = findLbPhone(nextRoot)
        const nextLbDocument = phone?.document || null
        const nextLbFrame = phone?.frame || null
        const rootChanged = nextRoot !== rootDocument
        const phoneChanged = nextLbDocument !== lbDocument || nextLbFrame !== lbFrame

        if (rootChanged) {
            rootObserver?.disconnect()
            rootDocument = nextRoot
            if (rootDocument) {
                ensureStyles(rootDocument)
                rootObserver = new MutationObserver(() => {
                    connect()
                    if (peekUntil > Date.now()) applyPeekLock()
                })
                rootObserver.observe(rootDocument.body, {
                    attributes: true,
                    childList: true,
                    subtree: true,
                    attributeFilter: ['class', 'style'],
                })
            }
        }

        if (phoneChanged) {
            lbObserver?.disconnect()
            lbDocument = nextLbDocument
            lbFrame = nextLbFrame
            if (lbDocument) {
                lbObserver = new MutationObserver(() => {
                    if (peekUntil > Date.now()) applyPeekLock()
                    if (lastState && !lbDocument.getElementById(OVERLAY_ID)) render()
                })
                lbObserver.observe(lbDocument.documentElement, {
                    attributes: true,
                    childList: true,
                    subtree: true,
                    attributeFilter: ['class', 'style'],
                })
            }
        }

        if (rootChanged || phoneChanged) {
            render()
            if (peekUntil > Date.now() && lockSnapshot) applyPeekLock()
            else if (peekUntil > Date.now() && lbDocument && !peekCaptureTimer) {
                peekCaptureTimer = window.setTimeout(capturePeek, 150)
            }
        }
    }

    window.addEventListener('message', (event) => {
        const data = event.data
        if (!data?.action) return

        if (data.action === 'requestNotification') {
            lastState = { type: 'notification', payload: data.payload, forceFallback: data.forceFallback === true }
            if (data.playSound === true) playNotificationSound(data.soundName)
            beginPeek(data.peekDuration, data.holdPeek === true)
        } else if (data.action === 'dismiss') {
            if (lastState?.type === 'notification' && lastState.payload.requestId === data.requestId) {
                lastState = null
                releasePeek()
            }
        } else if (data.action === 'showActive') {
            cancelConfirmActive = false
            lastState = { type: 'active', payload: data.payload, forceFallback: data.forceFallback === true }
            beginPeek(data.peekDuration, data.holdPeek === true)
        } else if (data.action === 'updateDistance') {
            if (lastState?.type === 'active') lastState.payload.distance = data.distance
        } else if (data.action === 'clearActive') {
            if (lastState?.type === 'active') {
                lastState = null
                cancelConfirmActive = false
                releasePeek()
            }
        } else if (data.action === 'clearTest') {
            if (lastState?.payload?.test) lastState = null
            releasePeek()
        } else if (data.action === 'releasePeek') {
            releasePeek()
        } else if (data.action === 'setPhoneOpen') {
            // On the open lockscreen the card participates in LB Phone's
            // native notification stack. On apps/home screens no lockscreen
            // host exists, so it remains hidden instead of covering the UI.
            phoneIsOpen = data.open === true
            if (phoneIsOpen) {
                lbDocument?.getElementById(OVERLAY_ID)?.remove()
            }
            releasePeek(true)
        } else if (data.action === 'setCancelConfirm') {
            cancelConfirmActive = data.active === true
        } else if (data.action === 'setCallPriority') {
            callHasPriority = data.active === true
            const wrapper = lbDocument?.querySelector('.phoneVisbility')
            if (wrapper) {
                if (callHasPriority && wrapper.getAttribute(LOCK_ATTRIBUTE) === 'active') {
                    wrapper.setAttribute(CALL_PRIORITY_ATTRIBUTE, '')
                } else {
                    wrapper.removeAttribute(CALL_PRIORITY_ATTRIBUTE)
                }
            }
        } else if (data.action === 'destroy') {
            cleanup()
            return
        } else {
            return
        }

        render()
    })

    connect()
    reconnectTimer = window.setInterval(connect, 1000)
    post('ready', { controllerVersion: CONTROLLER_VERSION })
    window.addEventListener('unload', cleanup)
})()
