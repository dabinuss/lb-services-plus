// PeekPlus Sibling-NUI controller. It renders into LB Phone's real
// .full-phone tree and owns LB's native .phoneVisbility peek position. It
// does not enqueue an LB notification or edit any LB Phone files.
;(function () {
    const CONTROLLER_VERSION = 'peekplus-1.0.0'
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'services-plus'
    const OVERLAY_ID = 'services-plus-overlay'
    const STYLE_ID = 'services-plus-overlay-styles'
    const LOCK_ATTRIBUTE = 'data-services-plus-peek-lock'
    const CALL_PRIORITY_ATTRIBUTE = 'data-services-plus-call-priority'

    let lastState = null // { card, forceFallback } | null
    let rootDocument = null
    let lbDocument = null
    let lbFrame = null
    let rootObserver = null
    let lbObserver = null
    let rootObservedBody = null
    let lbObservedRoot = null
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
    let domFrame = null
    let lastRenderKey = null
    const reportedCapabilities = new Set()

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

    function getPhoneTheme() {
        return lbDocument?.documentElement?.getAttribute('data-theme') || 'dark'
    }

    function reportCapability(name) {
        if (reportedCapabilities.has(name)) return
        reportedCapabilities.add(name)
        console.warn(`[services-plus][PeekPlus] LB Phone capability unavailable: ${name}; using safe fallback.`)
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
        #${OVERLAY_ID} .sp-btn.complete,
        #${OVERLAY_ID} .sp-btn.success { background: #30d158; color: #fff; }
        #${OVERLAY_ID} .sp-btn.decline,
        #${OVERLAY_ID} .sp-btn.cancel { background: #ff453a; color: #fff; }
        #${OVERLAY_ID} .sp-btn.danger { background: #ff453a; color: #fff; }
        #${OVERLAY_ID} .sp-btn.primary { background: #0a84ff; color: #fff; }
        #${OVERLAY_ID} .sp-btn.default { background: rgba(127, 127, 127, .25); color: inherit; }
        #${OVERLAY_ID} .sp-btn:disabled { cursor: default; opacity: .55; }
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
        if (!targetDocument?.head) return
        let style = targetDocument.getElementById(STYLE_ID)
        if (!style) {
            style = targetDocument.createElement('style')
            style.id = STYLE_ID
            targetDocument.head.appendChild(style)
        }
        if (style.textContent !== STYLES) style.textContent = STYLES
    }

    function removeContainersExcept(targetDocument) {
        for (const doc of [rootDocument, lbDocument]) {
            if (doc && doc !== targetDocument) doc.getElementById(OVERLAY_ID)?.remove()
        }
    }

    function ensureContainer() {
        const fullPhone = lbDocument?.querySelector('.full-phone') || null
        const visibilityWrapper = lbDocument?.querySelector('.phoneVisbility') || null
        const phoneCompatible = Boolean(fullPhone && visibilityWrapper)
        const domFallback = Boolean(lastState && !lastState.forceFallback && !phoneCompatible)
        const lockscreenHost = phoneIsOpen && phoneCompatible && !lastState?.forceFallback
            ? lbDocument?.querySelector('.lockscreen-notification-container')
            : null
        const phoneHost = !phoneIsOpen && phoneCompatible && !lastState?.forceFallback
            ? fullPhone
            : null
        const useFallback = lastState?.forceFallback || domFallback
        const targetDocument = lockscreenHost || phoneHost ? lbDocument : useFallback ? rootDocument : null
        const host = lockscreenHost || phoneHost || (useFallback ? rootDocument?.body : null)
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

    function addText(targetDocument, parent, className, value) {
        if (!value) return
        const element = targetDocument.createElement('div')
        element.className = className
        element.textContent = String(value)
        parent.appendChild(element)
    }

    function renderCard(targetDocument, element, payload) {
        addText(targetDocument, element, 'sp-title', payload.title)
        addText(targetDocument, element, 'sp-sub', payload.subtitle)
        addText(targetDocument, element, 'sp-meta', payload.description)
        if (!Array.isArray(payload.actions) || payload.actions.length === 0) return

        const buttons = targetDocument.createElement('div')
        buttons.className = 'sp-buttons'
        payload.actions.forEach((action) => {
            const button = targetDocument.createElement('button')
            button.className = `sp-btn ${action.color || 'default'}`
            button.textContent = payload.confirmAction === action.id
                ? action.confirm?.label || 'Confirm?'
                : action.label
            button.disabled = payload.actionInFlight === true || callHasPriority
            button.onclick = () => post('peekplusAction', {
                id: payload.id,
                revision: payload.revision,
                action: action.id,
            })
            buttons.appendChild(button)
        })
        element.appendChild(buttons)
    }

    function render() {
        const container = ensureContainer()
        if (!container) return
        const renderKey = JSON.stringify({
            card: lastState?.card || null,
            host: container.dataset.host,
            theme: container.dataset.theme,
            call: callHasPriority,
        })
        if (renderKey === lastRenderKey && container.firstElementChild) return
        lastRenderKey = renderKey
        container.replaceChildren()
        if (!lastState) return

        const card = container.ownerDocument.createElement('div')
        card.className = 'sp-card'
        renderCard(container.ownerDocument, card, lastState.card)
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
        window.cancelAnimationFrame(domFrame)
        domFrame = null
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

    function scheduleDomRefresh() {
        if (domFrame !== null) return
        domFrame = window.requestAnimationFrame(() => {
            domFrame = null
            connect()
            if (peekUntil > Date.now()) applyPeekLock()
            if (lastState) render()
        })
    }

    function connect() {
        const nextRoot = findRootDocument()
        const phone = findLbPhone(nextRoot)
        const nextLbDocument = phone?.document || null
        const nextLbFrame = phone?.frame || null
        const nextRootBody = nextRoot?.body || null
        const nextLbObservedRoot = nextLbDocument?.querySelector('.full-phone') || nextLbDocument?.body || null
        const rootChanged = nextRoot !== rootDocument || nextRootBody !== rootObservedBody
        const phoneChanged = nextLbDocument !== lbDocument || nextLbFrame !== lbFrame
            || nextLbObservedRoot !== lbObservedRoot

        if (!nextRoot) reportCapability('citizenfx-root')
        else if (!phone) reportCapability('lb-phone-iframe')
        else {
            if (!nextLbDocument.querySelector('.full-phone')) reportCapability('.full-phone')
            if (!nextLbDocument.querySelector('.phoneVisbility')) reportCapability('.phoneVisbility')
        }

        if (rootChanged) {
            rootObserver?.disconnect()
            rootDocument = nextRoot
            rootObservedBody = nextRootBody
            if (rootDocument) {
                ensureStyles(rootDocument)
                rootObserver = new MutationObserver(scheduleDomRefresh)
                rootObserver.observe(rootDocument.body, {
                    childList: true,
                    subtree: false,
                })
            }
        }

        if (phoneChanged) {
            lbObserver?.disconnect()
            lbDocument = nextLbDocument
            lbFrame = nextLbFrame
            lbObservedRoot = nextLbObservedRoot
            if (lbDocument) {
                lbObserver = new MutationObserver(scheduleDomRefresh)
                lbObserver.observe(lbObservedRoot, {
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

        if (data.action === 'peekplus:render') {
            phoneIsOpen = data.phoneOpen === true
            callHasPriority = data.callActive === true
            if (data.hidden === true) {
                lastState = null
                lastRenderKey = null
                releasePeek(true)
                rootDocument?.getElementById(OVERLAY_ID)?.remove()
                lbDocument?.getElementById(OVERLAY_ID)?.remove()
                return
            }
            lastState = {
                card: data.card,
                forceFallback: data.forceFallback === true,
            }
            if (data.playSound === true) playNotificationSound(data.soundName)
            beginPeek(data.peekDuration, data.holdPeek === true)
        } else if (data.action === 'peekplus:clear') {
            lastState = null
            lastRenderKey = null
            releasePeek()
            rootDocument?.getElementById(OVERLAY_ID)?.remove()
            lbDocument?.getElementById(OVERLAY_ID)?.remove()
            return
        } else if (data.action === 'peekplus:phone') {
            // On the open lockscreen the card participates in LB Phone's
            // native notification stack. On apps/home screens no lockscreen
            // host exists, so it remains hidden instead of covering the UI.
            phoneIsOpen = data.open === true
            if (phoneIsOpen) {
                lbDocument?.getElementById(OVERLAY_ID)?.remove()
            }
            releasePeek(true)
        } else if (data.action === 'peekplus:call') {
            callHasPriority = data.active === true
            const wrapper = lbDocument?.querySelector('.phoneVisbility')
            if (wrapper) {
                if (callHasPriority && wrapper.getAttribute(LOCK_ATTRIBUTE) === 'active') {
                    wrapper.setAttribute(CALL_PRIORITY_ATTRIBUTE, '')
                } else {
                    wrapper.removeAttribute(CALL_PRIORITY_ATTRIBUTE)
                }
            }
        } else if (data.action === 'peekplus:reconnect') {
            connect()
        } else if (data.action === 'peekplus:phoneUnavailable') {
            releasePeek(true)
        } else if (data.action === 'peekplus:release') {
            releasePeek()
        } else if (data.action === 'peekplus:destroy') {
            cleanup()
            return
        } else {
            return
        }

        render()
    })

    connect()
    reconnectTimer = window.setInterval(connect, 1000)
    post('peekplusReady', { controllerVersion: CONTROLLER_VERSION })
    window.addEventListener('pagehide', cleanup)
    window.addEventListener('beforeunload', cleanup)
})()
