// PeekPlus Sibling-NUI controller. It renders into LB Phone's real
// .full-phone tree and owns LB's native .phoneVisbility peek position. It
// does not enqueue an LB notification or edit any LB Phone files.
;(function () {
    const CONTROLLER_VERSION = 'peekplus-1.3.0'
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
    let cardTimerInterval = null
    let timerAnchorCardId = null
    let timerAnchorKey = null
    let timerAnchorStartedAt = 0
    let motionSequence = 0
    const reportedCapabilities = new Set()
    const ICON_PATHS = {
        request: ['M5 5h14v14H5z', 'M8 9h8', 'M8 13h5'],
        people: ['M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2', 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8', 'M22 21v-2a4 4 0 0 0-3-3.87', 'M16 3.13a4 4 0 0 1 0 7.75'],
        location: ['M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0', 'M12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6'],
        distance: ['M6 19V5', 'M18 19V5', 'M9 8h6', 'M9 16h6', 'M4 5h4', 'M16 19h4'],
        taxi: ['M5 17h14l-1.5-7h-11z', 'M7 10l1-3h8l1 3', 'M7 17v2', 'M17 17v2', 'M7.5 14h.01', 'M16.5 14h.01', 'M9 7V5h6v2'],
        police: ['M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10', 'M9 12l2 2 4-4'],
        medical: ['M3 12h4l2-5 4 10 2-5h6', 'M12 21C5 17 2 13 3 8a5 5 0 0 1 9-2 5 5 0 0 1 9 2'],
        wrench: ['M14.7 6.3a4 4 0 0 0-5-5l2.1 2.1-2.4 2.4-2.1-2.1a4 4 0 0 0 5 5L4 17a2.1 2.1 0 1 0 3 3l7.7-8.3a4 4 0 0 0 5-5l-2.1 2.1-2.4-2.4z'],
        'tow-truck': ['M3 17V8h10v9', 'M13 11h4l4 4v2h-8', 'M6 17a2 2 0 1 0 0 4 2 2 0 0 0 0-4', 'M18 17a2 2 0 1 0 0 4 2 2 0 0 0 0-4', 'M3 5h7'],
        government: ['M3 10h18', 'M5 10v8', 'M9 10v8', 'M15 10v8', 'M19 10v8', 'M2 21h20', 'M12 3l9 5H3z'],
        news: ['M4 5h16v14H4z', 'M8 9h8', 'M8 13h8', 'M8 17h5'],
        law: ['M12 3v18', 'M5 7h14', 'M5 7l-3 6a3 3 0 0 0 6 0z', 'M19 7l-3 6a3 3 0 0 0 6 0z', 'M8 21h8'],
        'car-dealer': ['M4 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0', 'M12 12h9', 'M17 12v4', 'M20 12v3'],
        'car-wash': ['M5 16h14v-5a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2z', 'M7.5 18h.01', 'M16.5 18h.01', 'M7 2l-1 2l2 2l-1 2', 'M12 1l-1 2l2 2l-1 2', 'M17 2l-1 2l2 2l-1 2'],
        restaurant: ['M6 2v6a2 2 0 0 0 4 0V2', 'M8 2v4', 'M8 8v14', 'M15 2l2 7v13'],
        bar: ['M4 4h16l-8 9z', 'M12 13v8', 'M8 21h8'],
        barber: ['M3.5 6a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0', 'M3.5 18a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0', 'M8 7.5L20 20', 'M8 16.5L20 4'],
        tattoo: ['M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 21 12 17.77 5.82 21 7 14.14 2 9.27l6.91-1.01L12 2z'],
        music: ['M9 18V5l12-2v13', 'M3 18a3 3 0 1 0 6 0a3 3 0 1 0 -6 0', 'M15 16a3 3 0 1 0 6 0a3 3 0 1 0 -6 0'],
        shop: ['M6 8h12l-1 12a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2z', 'M9 8V6a3 3 0 0 1 6 0v2'],
        funeral: ['M12 3v18', 'M7 8h10'],
    }
    const ICON_ALIASES = {
        'taxi-ride': 'taxi',
        emergency_backup: 'police',
        'emergency-backup': 'police',
        medical_emergency: 'medical',
        'medical-emergency': 'medical',
        tow_truck: 'tow-truck',
        breaking_news: 'news',
        'breaking-news': 'news',
        bank: 'government',
        'car_dealer': 'car-dealer',
        car_wash: 'car-wash',
    }

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

    function isNativeBannerActive() {
        const wrapper = lbDocument?.querySelector('.phoneVisbility')
        return wrapper && wrapper.style.marginTop === '45rem'
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
        /* Only a bounded slice of the phone is visible while it is peeking.
           Keep actions in that slice and let optional content yield first. */
        #${OVERLAY_ID}[data-host='phone'] .sp-card {
            display: flex;
            flex-direction: column;
            width: 100%;
            max-width: 100%;
            max-height: 11.25rem;
            overflow: hidden;
            padding: .72rem .82rem;
            border-radius: 1rem;
        }
        #${OVERLAY_ID}[data-host='phone'] .sp-title,
        #${OVERLAY_ID}[data-host='phone'] .sp-sub,
        #${OVERLAY_ID}[data-host='phone'] .sp-meta,
        #${OVERLAY_ID}[data-host='phone'] .sp-detail-label,
        #${OVERLAY_ID}[data-host='phone'] .sp-detail-value {
            min-width: 0;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        #${OVERLAY_ID}[data-host='phone'] .sp-title { font-size: .94rem; line-height: 1.08; }
        #${OVERLAY_ID}[data-host='phone'] .sp-sub { font-size: .74rem; line-height: 1.08; }
        #${OVERLAY_ID}[data-host='phone'] .sp-header { gap: .62rem; }
        #${OVERLAY_ID}[data-host='phone'] .sp-card-icon { width: 2.35rem; height: 2.35rem; border-radius: .68rem; }
        #${OVERLAY_ID}[data-host='phone'] .sp-card-icon .sp-icon { width: 1.48rem; height: 1.48rem; }
        #${OVERLAY_ID}[data-host='phone'] .sp-status { padding: .28rem .46rem; font-size: .64rem; }
        #${OVERLAY_ID}[data-host='phone'] .sp-meta {
            flex: 0 0 auto;
            margin-top: .34rem;
            font-size: .73rem;
            line-height: 1.2;
        }
        #${OVERLAY_ID}[data-host='phone'] .sp-details {
            min-height: 0;
            overflow: hidden;
            margin-top: .58rem;
            gap: .3rem;
        }
        #${OVERLAY_ID}[data-host='phone'] .sp-detail {
            min-height: 0;
            gap: .42rem;
            font-size: .75rem;
            line-height: 1.15;
        }
        #${OVERLAY_ID}[data-host='phone'] .sp-detail-label { flex: 1 1 auto; }
        #${OVERLAY_ID}[data-host='phone'] .sp-detail-value {
            flex: 0 1 58%;
            max-width: 58%;
        }
        #${OVERLAY_ID}[data-host='phone'] .sp-details.iconic { gap: .34rem; }
        #${OVERLAY_ID}[data-host='phone'] .sp-details.iconic[data-count='3'] { grid-template-columns: .62fr minmax(0, 2.3fr) .82fr; }
        #${OVERLAY_ID}[data-host='phone'] .sp-details.iconic[data-count='2'] { grid-template-columns: minmax(0, 2.5fr) .85fr; }
        #${OVERLAY_ID}[data-host='phone'] .sp-details.iconic .sp-detail-value { flex: 1 1 auto; max-width: 100%; }
        #${OVERLAY_ID}[data-host='phone'] .sp-detail-icon { width: 1.22rem; height: 1.22rem; }
        #${OVERLAY_ID}[data-host='phone'] .sp-progress,
        #${OVERLAY_ID}[data-host='phone'] .sp-timer,
        #${OVERLAY_ID}[data-host='phone'] .sp-template-frame { min-height: 0; overflow: hidden; }
        #${OVERLAY_ID}[data-host='phone'] .sp-buttons {
            flex: 0 0 auto;
            margin-top: .62rem;
            gap: .46rem;
        }
        #${OVERLAY_ID}[data-host='phone'] .sp-btn {
            min-width: 0;
            overflow: hidden;
            padding: .5rem .25rem;
            font-size: .72rem;
            line-height: 1;
            text-overflow: ellipsis;
            white-space: nowrap;
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
        #${OVERLAY_ID}[data-host='lockscreen'] .sp-card { width: 100%; max-width: 100%; }
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
            position: relative;
            will-change: transform, opacity;
            box-sizing: border-box;
            width: 24rem;
            max-width: 90vw;
            border-radius: 1.125rem;
            padding: .9rem 1rem;
            box-shadow: 0 .4rem 1rem rgba(0, 0, 0, .24);
            border-left: .24rem solid #8e8e93;
        }
        #${OVERLAY_ID} .sp-card[data-variant='info'] { border-left-color: #0a84ff; }
        #${OVERLAY_ID} .sp-card[data-variant='success'] { border-left-color: #30d158; }
        #${OVERLAY_ID} .sp-card[data-variant='warning'] { border-left-color: #ff9f0a; }
        #${OVERLAY_ID} .sp-card[data-variant='error'] { border-left-color: #ff453a; }
        #${OVERLAY_ID}[data-theme] .sp-card[data-state='active'] {
            color: #f5f7fa;
            background: linear-gradient(145deg, rgba(22,27,33,.985), rgba(10,13,17,.99));
            border-top: 1px solid rgba(255,255,255,.09);
            border-right: 1px solid rgba(255,255,255,.06);
            border-bottom: 1px solid rgba(255,255,255,.06);
            box-shadow: 0 .75rem 1.8rem rgba(0,0,0,.42), inset 0 1px 0 rgba(255,255,255,.025);
        }
        #${OVERLAY_ID} .sp-card[data-template='compact'] { padding: .65rem .8rem; border-radius: .85rem; }
        #${OVERLAY_ID} .sp-card[data-template='compact'] .sp-title { font-size: .86rem; }
        #${OVERLAY_ID} .sp-card[data-template='compact'] .sp-meta { margin-top: .2rem; }
        #${OVERLAY_ID}[data-theme='light'] .sp-card {
            background: rgb(245, 245, 250);
            color: #000;
        }
        #${OVERLAY_ID}[data-theme='dark'] .sp-card {
            background: rgb(28, 28, 30);
            color: #f2f2f7;
        }
        /* Full-card consumers own their visual surface. PeekPlus only
           supplies a bounded display slot and the trusted action bridge. */
        #${OVERLAY_ID}[data-theme] .sp-card[data-full-card='true'] {
            width: 100%; max-width: 100%; padding: 0; border: 0; border-radius: 0;
            color: inherit; background: transparent; box-shadow: none;
        }
        #${OVERLAY_ID} .sp-header { display: flex; align-items: center; gap: .65rem; min-width: 0; }
        #${OVERLAY_ID} .sp-card-icon {
            position: relative; display: grid; place-items: center; flex: 0 0 auto; overflow: hidden;
            width: 2.35rem; height: 2.35rem; border-radius: .7rem;
            background: linear-gradient(145deg, rgba(255,255,255,.14), rgba(255,255,255,.045));
            border: 1px solid rgba(255,255,255,.12); box-shadow: inset 0 1px 0 rgba(255,255,255,.06);
        }
        #${OVERLAY_ID} .sp-card-icon .sp-icon { width: 1.55rem; height: 1.55rem; }
        #${OVERLAY_ID} .sp-card-icon-fallback { display: grid; place-items: center; width: 100%; height: 100%; }
        #${OVERLAY_ID} .sp-card-icon-image { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; opacity: 0; transition: opacity .16s ease; }
        #${OVERLAY_ID} .sp-card-icon.has-image .sp-card-icon-image { opacity: 1; }
        #${OVERLAY_ID} .sp-heading { min-width: 0; flex: 1 1 auto; }
        #${OVERLAY_ID} .sp-status {
            flex: 0 0 auto; display: flex; align-items: center; gap: .32rem;
            padding: .3rem .48rem; border-radius: .55rem; font-size: .66rem; font-weight: 700;
            color: #30d158; background: rgba(48,209,88,.13); border: 1px solid rgba(48,209,88,.22);
        }
        #${OVERLAY_ID} .sp-status::before { content: ''; width: .38rem; height: .38rem; border-radius: 50%; background: currentColor; }
        #${OVERLAY_ID} .sp-icon { display: block; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
        #${OVERLAY_ID} .sp-title { font-size: .95rem; font-weight: 700; }
        #${OVERLAY_ID} .sp-sub { font-size: .78rem; opacity: .7; margin-top: .1rem; }
        #${OVERLAY_ID} .sp-meta { font-size: .78rem; opacity: .85; margin-top: .35rem; }
        #${OVERLAY_ID} .sp-details { margin-top: .55rem; display: grid; gap: .25rem; }
        #${OVERLAY_ID} .sp-detail { display: flex; justify-content: space-between; gap: .75rem; min-width: 0; font-size: .73rem; }
        #${OVERLAY_ID} .sp-detail-label { opacity: .65; }
        #${OVERLAY_ID} .sp-detail-value { min-width: 0; font-weight: 650; text-align: right; }
        #${OVERLAY_ID} .sp-details.iconic { grid-template-columns: repeat(var(--detail-count), minmax(0, 1fr)); gap: .45rem; }
        #${OVERLAY_ID} .sp-details.iconic .sp-detail { align-items: center; justify-content: flex-start; gap: .38rem; }
        #${OVERLAY_ID} .sp-details.iconic .sp-detail + .sp-detail { border-left: 1px solid rgba(127,127,127,.22); padding-left: .45rem; }
        #${OVERLAY_ID} .sp-details.iconic .sp-detail-value { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; text-align: left; }
        #${OVERLAY_ID} .sp-detail-icon { display: grid; place-items: center; flex: 0 0 auto; width: 1.2rem; height: 1.2rem; opacity: .78; }
        #${OVERLAY_ID} .sp-detail-icon .sp-icon { width: 100%; height: 100%; }
        #${OVERLAY_ID} .sp-progress { margin-top: .6rem; }
        #${OVERLAY_ID} .sp-progress-label { display: flex; justify-content: space-between; font-size: .7rem; opacity: .75; margin-bottom: .28rem; }
        #${OVERLAY_ID} .sp-progress-track { height: .32rem; border-radius: 999px; overflow: hidden; background: rgba(127,127,127,.25); }
        #${OVERLAY_ID} .sp-progress-fill { display: block; height: 100%; border-radius: inherit; background: #0a84ff; }
        #${OVERLAY_ID} .sp-timer { margin-top: .55rem; font-size: 1.25rem; font-variant-numeric: tabular-nums; font-weight: 700; }
        #${OVERLAY_ID} .sp-timer-label { font-size: .68rem; opacity: .65; margin-top: .08rem; }
        #${OVERLAY_ID} .sp-template-frame { display: block; width: 100%; margin-top: .55rem; border: 0; overflow: hidden; pointer-events: none; background: transparent; }
        #${OVERLAY_ID} .sp-template-frame[data-full-card='true'] { margin-top: 0; pointer-events: auto; }
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
        #${OVERLAY_ID} .sp-btn.success { background: linear-gradient(180deg, #35df65, #22b94e); color: #fff; box-shadow: 0 .18rem .5rem rgba(48,209,88,.2); }
        #${OVERLAY_ID} .sp-btn.decline,
        #${OVERLAY_ID} .sp-btn.cancel { background: #ff453a; color: #fff; }
        #${OVERLAY_ID} .sp-btn.danger { background: linear-gradient(180deg, #ff5a52, #e63b34); color: #fff; box-shadow: 0 .18rem .5rem rgba(255,69,58,.16); }
        #${OVERLAY_ID} .sp-btn.primary { background: #0a84ff; color: #fff; }
        #${OVERLAY_ID} .sp-btn.default { background: rgba(127, 127, 127, .25); color: inherit; }
        #${OVERLAY_ID} .sp-btn:disabled { cursor: default; opacity: .55; }
        #${OVERLAY_ID} .sp-btn:active:not(:disabled) { transform: scale(.96); filter: brightness(1.08); }
        #${OVERLAY_ID} .sp-motion-result {
            position: absolute; inset: 0; z-index: 3; display: grid; place-items: center;
            border-radius: inherit; pointer-events: none; color: #fff;
            background: rgba(18, 22, 27, .42); font-size: 2.1rem; font-weight: 800;
        }
        #${OVERLAY_ID}[data-host='phone'] .sp-card[data-full-card='true'] { max-height: 20rem; }
        /* LB Phone itself uses this (misspelled) wrapper to move the complete
           device: closed = 60rem, notification = 45rem. Owning this single
           native property avoids iframe crops and preserves LB's animation. */
        .phoneVisbility[${LOCK_ATTRIBUTE}] {
            visibility: visible !important;
            margin-top: calc(42rem - var(--peekplus-card-lift, 0px)) !important;
            transition: margin-top .5s ease-out !important;
        }
        /* A call banner occupies the top of the phone. Lift the same native
           wrapper a little further so the request remains fully visible below
           it while LB Phone keeps the higher input/visual priority. */
        .phoneVisbility[${LOCK_ATTRIBUTE}='active']:not([${CALL_PRIORITY_ATTRIBUTE}]) .lockscreen-notification-container {
            opacity: 0 !important;
            pointer-events: none !important;
            transition: opacity .3s ease;
        }
        .phoneVisbility[${LOCK_ATTRIBUTE}='active'][${CALL_PRIORITY_ATTRIBUTE}] .lockscreen-notification-container {
            opacity: 1 !important;
            transition: opacity .3s ease;
        }
        .phoneVisbility[${LOCK_ATTRIBUTE}='active'][${CALL_PRIORITY_ATTRIBUTE}] {
            margin-top: calc(39rem - var(--peekplus-card-lift, 0px)) !important;
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
        const displaySurface = fullPhone?.querySelector('.phone-container') || null
        const visibilityWrapper = lbDocument?.querySelector('.phoneVisbility') || null
        const phoneCompatible = Boolean(fullPhone && displaySurface && visibilityWrapper)
        const domFallback = Boolean(lastState && !lastState.forceFallback && !phoneCompatible)
        const lockscreenHost = phoneIsOpen && phoneCompatible && !lastState?.forceFallback
            ? lbDocument?.querySelector('.lockscreen-notification-container')
            : null
        const phoneHost = !phoneIsOpen && phoneCompatible && !lastState?.forceFallback
            ? displaySurface
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
        container.dataset.callPriority = (callHasPriority || isNativeBannerActive()) ? 'true' : 'false'
        return container
    }

    function addText(targetDocument, parent, className, value) {
        if (!value) return
        const element = targetDocument.createElement('div')
        element.className = className
        element.textContent = String(value)
        parent.appendChild(element)
    }

    function addIcon(targetDocument, parent, name, className) {
        const normalized = String(name || 'request').toLowerCase()
        const key = ICON_ALIASES[normalized] || normalized
        const paths = ICON_PATHS[key] || ICON_PATHS.request
        const wrapper = targetDocument.createElement('span')
        wrapper.className = className
        const svg = targetDocument.createElementNS('http://www.w3.org/2000/svg', 'svg')
        svg.classList.add('sp-icon')
        svg.setAttribute('viewBox', '0 0 24 24')
        svg.setAttribute('aria-hidden', 'true')
        paths.forEach((definition) => {
            const path = targetDocument.createElementNS('http://www.w3.org/2000/svg', 'path')
            path.setAttribute('d', definition)
            svg.appendChild(path)
        })
        wrapper.appendChild(svg)
        parent.appendChild(wrapper)
    }

    function addCardIcon(targetDocument, parent, name, imageUrl) {
        const wrapper = targetDocument.createElement('span')
        wrapper.className = 'sp-card-icon'
        addIcon(targetDocument, wrapper, name, 'sp-card-icon-fallback')
        if (imageUrl) {
            const image = targetDocument.createElement('img')
            image.className = 'sp-card-icon-image'
            image.alt = ''
            image.referrerPolicy = 'no-referrer'
            image.onload = () => wrapper.classList.add('has-image')
            image.onerror = () => image.remove()
            image.src = imageUrl
            wrapper.appendChild(image)
        }
        parent.appendChild(wrapper)
    }

    function formatDuration(milliseconds) {
        const total = Math.max(0, Math.floor(milliseconds / 1000))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const seconds = total % 60
        return hours > 0
            ? `${hours}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
            : `${minutes}:${String(seconds).padStart(2, '0')}`
    }

    function clearRenderedTimer() {
        window.clearInterval(cardTimerInterval)
        cardTimerInterval = null
    }

    function clearTimerAnchor() {
        timerAnchorCardId = null
        timerAnchorKey = null
        timerAnchorStartedAt = 0
    }

    function renderDetails(targetDocument, element, details) {
        if (!Array.isArray(details) || details.length === 0) return
        const rows = targetDocument.createElement('div')
        rows.className = 'sp-details'
        const iconic = details.every((detail) => detail?.icon)
        if (iconic) {
            rows.classList.add('iconic')
            rows.style.setProperty('--detail-count', String(details.length))
            rows.dataset.count = String(details.length)
        }
        details.forEach((detail) => {
            const row = targetDocument.createElement('div')
            row.className = 'sp-detail'
            row.setAttribute('aria-label', `${detail.label}: ${detail.value}`)
            row.title = detail.label
            if (detail.icon) addIcon(targetDocument, row, detail.icon, 'sp-detail-icon')
            if (!iconic) addText(targetDocument, row, 'sp-detail-label', detail.label)
            addText(targetDocument, row, 'sp-detail-value', detail.value)
            rows.appendChild(row)
        })
        element.appendChild(rows)
    }

    function renderProgress(targetDocument, element, progress) {
        if (!progress || !Number.isFinite(Number(progress.value)) || !Number.isFinite(Number(progress.max))) return
        const percent = Math.max(0, Math.min(100, Number(progress.value) / Number(progress.max) * 100))
        const wrapper = targetDocument.createElement('div')
        wrapper.className = 'sp-progress'
        const label = targetDocument.createElement('div')
        label.className = 'sp-progress-label'
        addText(targetDocument, label, '', progress.label || 'Progress')
        addText(targetDocument, label, '', `${Math.round(percent)}%`)
        const track = targetDocument.createElement('div')
        track.className = 'sp-progress-track'
        const fill = targetDocument.createElement('span')
        fill.className = 'sp-progress-fill'
        fill.style.width = `${percent}%`
        track.appendChild(fill)
        wrapper.append(label, track)
        element.appendChild(wrapper)
    }

    function renderTimer(targetDocument, element, timer, cardId) {
        if (!timer) return
        const display = targetDocument.createElement('div')
        display.className = 'sp-timer'
        const timerKey = JSON.stringify(timer)
        if (timerAnchorCardId !== cardId || timerAnchorKey !== timerKey) {
            timerAnchorCardId = cardId
            timerAnchorKey = timerKey
            timerAnchorStartedAt = Date.now()
        }
        const startedAt = timerAnchorStartedAt
        const update = () => {
            const advanced = Math.max(0, Date.now() - startedAt)
            const value = timer.countdown
                ? Math.max(0, Number(timer.duration) - Number(timer.elapsed) - advanced)
                : Number(timer.elapsed) + advanced
            display.textContent = formatDuration(value)
        }
        update()
        cardTimerInterval = window.setInterval(update, 250)
        element.appendChild(display)
        addText(targetDocument, element, 'sp-timer-label', timer.label)
    }

    function remainingPeekMs() {
        if (!lastState || typeof lastState.peekDuration !== 'number' || lastState.peekDuration < 0) return -1
        return Math.max(0, lastState.peekDuration - (Date.now() - lastState.receivedAt))
    }

    function postTemplateFrame(frame, payload) {
        frame.contentWindow?.postMessage({
            type: 'peekplus:template',
            template: payload.template,
            data: payload.templateData || {},
            actionEndpoint: `https://${resourceName}/peekplusAction`,
            presentation: {
                host: frame.closest(`#${OVERLAY_ID}`)?.dataset.host || 'fallback',
                theme: getPhoneTheme(),
                callPriority: callHasPriority || isNativeBannerActive(),
            },
            card: {
                id: payload.id,
                revision: payload.revision,
                state: payload.state,
                title: payload.title,
                subtitle: payload.subtitle,
                description: payload.description,
                variant: payload.variant,
                icon: payload.icon,
                iconUrl: payload.iconUrl,
                details: payload.details || [],
                actions: payload.actions || [],
                actionInFlight: payload.actionInFlight === true,
                confirmAction: payload.confirmAction,
                // Milliseconds left before this card auto-expires, measured
                // against the iframe's own clock (-1 = held/no expiry). Lets
                // a full-card template show a live "auto-decline" countdown
                // without needing to trust the host's GetGameTimer() clock.
                remainingMs: remainingPeekMs(),
            },
        }, '*')
    }

    function renderCustomTemplate(targetDocument, element, payload, reusableFrame) {
        const definition = payload.templateDefinition
        if (!definition?.ui) return
        const canReuse = reusableFrame
            && reusableFrame.dataset.cardId === String(payload.id)
            && reusableFrame.dataset.template === String(payload.template)
        if (canReuse) {
            // Move the live iframe into a newly built standard card before
            // the old wrapper is replaced. Without this, non-fullCard custom
            // templates disappear on their first update.
            if (reusableFrame.parentElement !== element) element.appendChild(reusableFrame)
            postTemplateFrame(reusableFrame, payload)
            return
        }
        const frame = targetDocument.createElement('iframe')
        frame.className = 'sp-template-frame'
        frame.src = definition.ui + '?v=' + Date.now()
        frame.sandbox = 'allow-scripts allow-same-origin allow-popups'
        frame.dataset.cardId = String(payload.id)
        frame.dataset.template = String(payload.template)
        frame.dataset.fullCard = definition.fullCard === true ? 'true' : 'false'
        frame.style.height = `${Number(definition.height) || 160}px`
        frame.onload = () => {
            const current = lastState?.card
            if (current && frame.dataset.cardId === String(current.id)
                && frame.dataset.template === String(current.template)) {
                postTemplateFrame(frame, current)
            }
        }
        element.appendChild(frame)
    }

    function renderCard(targetDocument, element, payload, reusableFrame) {
        if (payload.layout === 'custom' && payload.templateDefinition?.fullCard === true) {
            renderCustomTemplate(targetDocument, element, payload, reusableFrame)
            return
        }
        if (payload.icon || payload.state === 'active') {
            const header = targetDocument.createElement('div')
            header.className = 'sp-header'
            addCardIcon(targetDocument, header, payload.icon, payload.iconUrl)
            const heading = targetDocument.createElement('div')
            heading.className = 'sp-heading'
            addText(targetDocument, heading, 'sp-title', payload.title)
            addText(targetDocument, heading, 'sp-sub', payload.subtitle)
            header.appendChild(heading)
            if (payload.state === 'active') addText(targetDocument, header, 'sp-status', 'Active request')
            element.appendChild(header)
        } else {
            addText(targetDocument, element, 'sp-title', payload.title)
            addText(targetDocument, element, 'sp-sub', payload.subtitle)
        }
        addText(targetDocument, element, 'sp-meta', payload.description)
        if (payload.layout === 'details') renderDetails(targetDocument, element, payload.details)
        if (payload.layout === 'progress') renderProgress(targetDocument, element, payload.progress)
        if (payload.layout === 'timer') renderTimer(targetDocument, element, payload.timer, payload.id)
        if (payload.layout === 'custom') renderCustomTemplate(targetDocument, element, payload, reusableFrame)
        if (!Array.isArray(payload.actions) || payload.actions.length === 0) return

        const buttons = targetDocument.createElement('div')
        buttons.className = 'sp-buttons'
        payload.actions.forEach((action) => {
            const button = targetDocument.createElement('button')
            button.className = `sp-btn ${action.color || 'default'}`
            button.textContent = payload.confirmAction === action.id
                ? action.confirm?.label || 'Confirm?'
                : action.label
            button.disabled = payload.actionInFlight === true || callHasPriority || isNativeBannerActive()
            button.onclick = () => {
                if (button.disabled) return
                button.disabled = true
                button.animate?.([
                    { transform: 'scale(1)' },
                    { transform: 'scale(.94)', offset: .42 },
                    { transform: 'scale(1)' },
                ], { duration: 150, easing: 'ease-out' })
                post('peekplusAction', {
                    id: payload.id,
                    revision: payload.revision,
                    action: action.id,
                }).then((accepted) => {
                    if (accepted !== true && button.isConnected) button.disabled = false
                })
            }
            buttons.appendChild(button)
        })
        element.appendChild(buttons)
    }

    function prefersReducedMotion(element) {
        return element?.ownerDocument?.defaultView?.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true
    }

    function runAnimation(element, keyframes, options) {
        if (!element?.animate || prefersReducedMotion(element)) return Promise.resolve()
        try {
            const animation = element.animate(keyframes, { fill: 'both', ...options })
            return Promise.resolve(animation.finished).catch(() => {}).finally(() => animation.cancel?.())
        } catch {
            // Older CEF builds may expose Web Animations only partially.
            // Rendering must still complete synchronously in that case.
            return Promise.resolve()
        }
    }

    function cancelAnimations(element) {
        if (!element?.getAnimations) return
        let animations
        try {
            animations = element.getAnimations({ subtree: true })
        } catch {
            try {
                animations = element.getAnimations()
            } catch {
                return
            }
        }
        for (const animation of animations) animation.cancel?.()
    }

    function verticalOffset(container, fallback, lockscreen) {
        return container?.dataset.host === 'lockscreen' ? lockscreen : fallback
    }

    function animateResult(card, motion) {
        if (motion !== 'action-success' && motion !== 'action-failed') return Promise.resolve()
        const result = card.ownerDocument.createElement('span')
        result.className = 'sp-motion-result'
        result.textContent = motion === 'action-success' ? '✓' : '×'
        card.appendChild(result)
        const success = motion === 'action-success'
        const cardFrames = success
            ? [
                { transform: 'scale(1)', filter: 'brightness(1)' },
                { transform: 'scale(1.025)', filter: 'brightness(1.12)', offset: .5 },
                { transform: 'scale(1)', filter: 'brightness(1)' },
            ]
            : [
                { transform: 'translateX(0)' },
                { transform: 'translateX(-5px)', offset: .3 },
                { transform: 'translateX(5px)', offset: .6 },
                { transform: 'translateX(0)' },
            ]
        const resultAnimation = runAnimation(result, [
            { opacity: 0, transform: 'scale(.7)' },
            { opacity: 1, transform: 'scale(1)', offset: .42 },
            { opacity: 0, transform: 'scale(1.08)' },
        ], { duration: success ? 320 : 280, easing: 'ease-out' })
        return Promise.all([
            resultAnimation,
            runAnimation(card, cardFrames, { duration: success ? 300 : 260, easing: 'ease-out' }),
        ]).finally(() => result.remove())
    }

    function animateCardIn(card, container, motion) {
        if (!motion) return Promise.resolve()
        if (motion === 'update') {
            return runAnimation(card, [
                { opacity: .82, transform: 'translateY(-3px) scale(.985)' },
                { opacity: 1, transform: 'translateY(0) scale(1)' },
            ], { duration: 220, easing: 'cubic-bezier(.2,.8,.2,1)' })
        }
        if (motion === 'action-success' || motion === 'action-failed') return animateResult(card, motion)
        const distance = motion === 'resume'
            ? verticalOffset(container, -24, -20)
            : verticalOffset(container, -50, -40)
        return runAnimation(card, [
            { opacity: 0, transform: `translateY(${distance}px)` },
            { opacity: 1, transform: 'translateY(0)' },
        ], {
            duration: motion === 'resume' ? 260 : 300,
            easing: 'cubic-bezier(.18,.82,.25,1)',
        })
    }

    function animateCardOut(card, container, motion) {
        const distance = motion === 'interrupt'
            ? verticalOffset(container, -58, -68)
            : verticalOffset(container, -72, -84)
        return runAnimation(card, [
            { opacity: 1, transform: 'translateY(0)' },
            { opacity: 0, transform: `translateY(${distance}px)` },
        ], { duration: 210, easing: 'cubic-bezier(.4,0,1,1)' })
    }

    function animateCardUpdate(card, container, previousHeight) {
        const nextHeight = card.getBoundingClientRect().height
        const cardMotion = animateCardIn(card, container, 'update')
        if (!previousHeight || !nextHeight || Math.abs(previousHeight - nextHeight) < 1) return cardMotion
        return Promise.all([
            cardMotion,
            runAnimation(container, [
                { height: `${previousHeight}px`, overflow: 'hidden' },
                { height: `${nextHeight}px`, overflow: 'hidden' },
            ], { duration: 240, easing: 'cubic-bezier(.2,.8,.2,1)' }),
        ])
    }

    async function replaceCard(container, card, existingCard, motion, outgoingMotion, sequence) {
        const sameCard = existingCard?.dataset.cardId === card.dataset.cardId
        const previousHeight = sameCard ? existingCard.getBoundingClientRect().height : 0
        if (existingCard && !sameCard) {
            await animateResult(existingCard, outgoingMotion)
            await animateCardOut(existingCard, container, outgoingMotion)
            if (sequence !== motionSequence) return
        }
        container.replaceChildren(card)
        const attachedFrame = card.querySelector('.sp-template-frame')
        if (attachedFrame && lastState?.card
            && attachedFrame.dataset.cardId === String(lastState.card.id)
            && attachedFrame.dataset.template === String(lastState.card.template)) {
            // The iframe may have loaded while the outgoing card was still
            // animating. Re-post now that resize messages can target it.
            postTemplateFrame(attachedFrame, lastState.card)
        }
        if (sameCard && motion === 'update') await animateCardUpdate(card, container, previousHeight)
        else if (sameCard && motion === 'action-success') {
            await Promise.all([
                animateCardUpdate(card, container, previousHeight),
                animateResult(card, motion),
            ])
        }
        else await animateCardIn(card, container, motion)
    }

    function render() {
        const container = ensureContainer()
        if (!container) {
            clearRenderedTimer()
            return
        }
        const renderKey = JSON.stringify({
            card: lastState?.card || null,
            host: container.dataset.host,
            theme: container.dataset.theme,
            call: callHasPriority || isNativeBannerActive(),
        })
        if (renderKey === lastRenderKey && container.firstElementChild) return
        lastRenderKey = renderKey
        const motion = lastState?.motion || null
        const outgoingMotion = lastState?.outgoingMotion || 'exit'
        if (lastState) {
            lastState.motion = null
            lastState.outgoingMotion = null
        }
        const existingCard = container.querySelector('.sp-card')
        const reusableFrame = container.querySelector('.sp-template-frame')
        clearRenderedTimer()
        if (!lastState) {
            container.replaceChildren()
            return
        }
        if (lastState.card.layout !== 'timer') clearTimerAnchor()

        const reusableFullCard = reusableFrame && existingCard
            && lastState.card.layout === 'custom'
            && lastState.card.templateDefinition?.fullCard === true
            && reusableFrame.dataset.cardId === String(lastState.card.id)
            && reusableFrame.dataset.template === String(lastState.card.template)
        if (reusableFullCard) {
            motionSequence += 1
            cancelAnimations(container)
            existingCard.dataset.variant = lastState.card.variant || 'neutral'
            existingCard.dataset.state = lastState.card.state || 'pending'
            existingCard.dataset.template = lastState.card.template || 'default'
            existingCard.dataset.fullCard = 'true'
            renderCard(container.ownerDocument, existingCard, lastState.card, reusableFrame)
            animateCardIn(existingCard, container, motion)
            return
        }

        const card = container.ownerDocument.createElement('div')
        card.className = 'sp-card'
        card.dataset.variant = lastState.card.variant || 'neutral'
        card.dataset.state = lastState.card.state || 'pending'
        card.dataset.template = lastState.card.template || 'default'
        card.dataset.cardId = String(lastState.card.id)
        card.dataset.fullCard = lastState.card.templateDefinition?.fullCard === true ? 'true' : 'false'
        renderCard(container.ownerDocument, card, lastState.card, reusableFrame)
        const sequence = ++motionSequence
        cancelAnimations(container)
        replaceCard(container, card, existingCard, motion, outgoingMotion, sequence)
    }

    function capturePeek() {
        peekCaptureTimer = null
        if (!lbDocument || !lbFrame || Date.now() >= peekUntil) return
        const wrapper = lbDocument.querySelector('.phoneVisbility')
        if (!wrapper) return

        syncPeekHeightLift(wrapper)
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

    function syncPeekHeightLift(wrapper) {
        const definition = lastState?.card?.templateDefinition
        let requestedHeight = 0
        if (definition?.fullCard === true) {
            // Prefer the live, content-reported height (see
            // handleTemplateResize) over the registered ceiling, so the
            // phone only lifts as far as the current card actually needs.
            // Falls back to the ceiling before the first resize report
            // arrives (e.g. the very first frame of a new card).
            const frame = lbDocument?.querySelector('.sp-template-frame') || rootDocument?.querySelector('.sp-template-frame')
            const liveHeight = frame ? Number.parseFloat(frame.style.height) : NaN
            requestedHeight = Number.isFinite(liveHeight) ? liveHeight : (Number(definition.height) || 0)
        }
        const lift = Math.max(0, Math.min(320, requestedHeight) - 180)
        const value = `${lift}px`
        if (wrapper.style.getPropertyValue('--peekplus-card-lift') !== value) {
            wrapper.style.setProperty('--peekplus-card-lift', value)
        }
    }

    function applyPeekLock() {
        if (applyingLock || !lockSnapshot || Date.now() >= peekUntil || !lbDocument || !lbFrame) return
        applyingLock = true
        const wrapper = lbDocument.querySelector('.phoneVisbility')
        if (wrapper && !peekAnimating && wrapper.getAttribute(LOCK_ATTRIBUTE) !== 'active') {
            wrapper.setAttribute(LOCK_ATTRIBUTE, 'active')
        }
        if (wrapper) {
            syncPeekHeightLift(wrapper)
            if ((callHasPriority || isNativeBannerActive()) && wrapper.getAttribute(LOCK_ATTRIBUTE) === 'active') {
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
            element.style.removeProperty('--peekplus-card-lift')
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
                wrapper.style.removeProperty('--peekplus-card-lift')
            }, 520)
        } else {
            removeLockFromDocument(rootDocument)
            removeLockFromDocument(lbDocument)
        }
    }

    async function clearOverlay(motion, immediate) {
        const sequence = ++motionSequence
        const container = lbDocument?.getElementById(OVERLAY_ID) || rootDocument?.getElementById(OVERLAY_ID)
        const card = container?.querySelector('.sp-card')
        cancelAnimations(container)
        if (!immediate && card) {
            await animateResult(card, motion)
            await animateCardOut(card, container, motion)
        }
        if (sequence !== motionSequence) return
        releasePeek(immediate === true)
        rootDocument?.getElementById(OVERLAY_ID)?.remove()
        lbDocument?.getElementById(OVERLAY_ID)?.remove()
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
        peekTimer = null
        peekReleaseTimer = null

        peekUntil = indefinite ? Number.MAX_SAFE_INTEGER : Date.now() + milliseconds
        if (!indefinite) {
            const deadline = peekUntil
            const expireLocally = () => {
                if (peekUntil !== deadline) return
                const remaining = deadline - Date.now()
                if (remaining > 0) {
                    peekTimer = window.setTimeout(expireLocally, remaining)
                    return
                }
                peekTimer = null
                clearRenderedTimer()
                clearTimerAnchor()
                lastState = null
                lastRenderKey = null
                clearOverlay('exit')
            }
            peekTimer = window.setTimeout(expireLocally, milliseconds)
        }
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
        reconnectTimer = null
        clearRenderedTimer()
        clearTimerAnchor()
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

    function setReconnectPolling(required) {
        if (required && reconnectTimer === null) {
            reconnectTimer = window.setInterval(connect, 1000)
        } else if (!required && reconnectTimer !== null) {
            window.clearInterval(reconnectTimer)
            reconnectTimer = null
        }
    }

    function isRelevantLbMutation(mutation) {
        const target = mutation.target?.nodeType === 1
            ? mutation.target
            : mutation.target?.parentElement
        if (target?.closest?.(`#${OVERLAY_ID}`)) return false
        if (mutation.type === 'attributes') {
            return target === lbDocument?.documentElement || target?.matches?.('.phoneVisbility')
        }
        const selector = '.full-phone, .phoneVisbility, .lockscreen-notification-container'
        return [...mutation.addedNodes, ...mutation.removedNodes].some((node) =>
            node?.nodeType === 1 && (node.matches?.(selector) || node.querySelector?.(selector))
        )
    }

    function connect() {
        const nextRoot = findRootDocument()
        const phone = findLbPhone(nextRoot)
        const nextLbDocument = phone?.document || null
        const nextLbFrame = phone?.frame || null
        const nextRootBody = nextRoot?.body || null
        const nextLbObservedRoot = nextLbDocument?.documentElement || null
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
                lbObserver = new MutationObserver((mutations) => {
                    if (mutations.some(isRelevantLbMutation)) scheduleDomRefresh()
                })
                lbObserver.observe(lbObservedRoot, {
                    attributes: true,
                    childList: true,
                    subtree: true,
                    attributeFilter: ['class', 'style', 'data-theme'],
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
        setReconnectPolling(!nextRoot || !phone)
    }

    // A full-card template reports its own natural content height after
    // every render (see dispatch.js's reportHeight). Size the real iframe
    // to match, clamped to at most the template's registered height - that
    // registration is a ceiling now, not a fixed size, so the notification
    // is only ever as tall as its current content actually needs.
    function handleTemplateResize(event) {
        const frame = lbDocument?.querySelector('.sp-template-frame') || rootDocument?.querySelector('.sp-template-frame')
        if (!frame || frame.contentWindow !== event.source) return
        if (frame.dataset.cardId !== String(lastState?.card?.id)) return
        const definition = lastState?.card?.templateDefinition
        const maxHeight = Number(definition?.height) || 320
        const clamped = Math.max(40, Math.min(maxHeight, Math.ceil(event.data.height)))
        if (frame.style.height === `${clamped}px`) return
        frame.style.height = `${clamped}px`
        const wrapper = lbDocument?.querySelector('.phoneVisbility')
        if (wrapper && peekUntil > Date.now()) syncPeekHeightLift(wrapper)
    }

    window.addEventListener('message', (event) => {
        const data = event.data
        if (data?.type === 'peekplus:template:resize' && typeof data.height === 'number') {
            handleTemplateResize(event)
            return
        }
        if (!data?.action) return

        if (data.action === 'peekplus:render') {
            phoneIsOpen = data.phoneOpen === true
            callHasPriority = data.callActive === true
            if (data.hidden === true) {
                clearRenderedTimer()
                clearTimerAnchor()
                lastState = null
                lastRenderKey = null
                clearOverlay(null, true)
                return
            }
            lastState = {
                card: data.card,
                forceFallback: data.forceFallback === true,
                peekDuration: typeof data.peekDuration === 'number' ? data.peekDuration : -1,
                receivedAt: Date.now(),
                reason: data.reason || null,
                motion: data.motion || null,
                outgoingMotion: data.outgoingMotion || null,
                outgoingReason: data.outgoingReason || null,
            }
            if (data.playSound === true) playNotificationSound(data.soundName)
            beginPeek(data.peekDuration, data.holdPeek === true)
        } else if (data.action === 'peekplus:clear') {
            clearRenderedTimer()
            clearTimerAnchor()
            lastState = null
            lastRenderKey = null
            clearOverlay(data.motion || 'exit')
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
                if ((callHasPriority || isNativeBannerActive()) && wrapper.getAttribute(LOCK_ATTRIBUTE) === 'active') {
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
    post('peekplusReady', { controllerVersion: CONTROLLER_VERSION })
    window.addEventListener('pagehide', cleanup)
    window.addEventListener('beforeunload', cleanup)
})()
