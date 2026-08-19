;(function () {
    const root = document.getElementById('taxi-request')
    const { el, icon, badge, row, button, detail, onMessage } = Dispatch

    Dispatch.registerIcons({
        car: ['M5 11l1.4-4.3A2 2 0 0 1 8.3 5.3h7.4a2 2 0 0 1 1.9 1.4L19 11', 'M3 11h18v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z', 'M7 18v1', 'M17 18v1'],
        price: ['M12 1v22', 'M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6'],
    })

    // PROTOTYPE ONLY. Real distance updates already exist server-side
    // (client/services/requests.lua's startDistanceUpdates, every 2s) but
    // this dev preview has no live game position to draw from, so the
    // "approach" below is entirely faked: progress just climbs from 0 to 1
    // on a timer and drives both the dot position and the displayed
    // distance number.
    // The "inner box" from the reference mockup: a fixed rectangle,
    // always in the same place, that's the only area allowed to show the
    // actual route/pin/unit. Everything outside it still shows the same
    // map texture (roads/grid) at the same clarity - that outer area
    // carries no real route data, it's purely there so the whole
    // notification reads as "this is a map" instead of a small boxed-in
    // widget.
    //
    // Sized to the actual gap between the other content, not just picked
    // to look reasonable in isolation - measured live in the browser:
    // header bottom ~47px, pickup top ~145px (viewBox y ~= real px here,
    // card height and viewBox height are both 224). A box that ignores
    // this just draws the route underneath the header/pickup/footer text
    // instead of in open space - which is exactly what happened before
    // this fix. ROUTE_D's points must stay inside BOX.
    const BOX = { x: 16, y: 52, width: 288, height: 88 } // y 52-140, clear of header (ends ~47) and pickup (starts ~145)
    const ROUTE_D = 'M 30 128 C 70 136, 100 108, 140 98 S 220 68, 290 64'
    const START_MI = 2.6

    // Icon-then-value, unlike Dispatch.headerStats() (value-then-icon) -
    // kept local to this prototype rather than changed in the shared
    // dispatch.js, which real templates still use as-is.
    function iconValue(className, iconName, value) {
        const wrap = el('div', className)
        wrap.appendChild(icon(iconName))
        wrap.appendChild(el('span', null, value))
        return wrap
    }

    function buildMapBg() {
        const bg = el('div', 'dispatch-map-bg')
        bg.innerHTML = `
            <svg viewBox="0 0 320 224" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <clipPath id="dispatch-map-route-box">
                        <rect x="${BOX.x}" y="${BOX.y}" width="${BOX.width}" height="${BOX.height}"/>
                    </clipPath>
                </defs>
                <path class="dispatch-map-road" d="M0 60H320 M0 150H320"/>
                <path class="dispatch-map-road cross" d="M55 0V224 M160 0V224 M255 0V224"/>
                <g clip-path="url(#dispatch-map-route-box)">
                    <path class="dispatch-map-route-dim" d="${ROUTE_D}"/>
                    <path class="dispatch-map-route-done" d="${ROUTE_D}" pathLength="1" stroke-dasharray="1" stroke-dashoffset="1"/>
                    <g class="dispatch-map-pin" transform="translate(290 64)">
                        <circle class="dispatch-map-pin-ring" r="9"/>
                        <circle class="dispatch-map-pin-dot" r="4"/>
                    </g>
                    <g class="dispatch-map-unit" transform="translate(30 128)">
                        <circle class="dispatch-map-unit-pulse" r="6"/>
                        <circle class="dispatch-map-unit-dot" r="5"/>
                    </g>
                </g>
            </svg>
        `
        return bg
    }

    // Moves the unit dot along ROUTE_D and the "done" stroke to match,
    // using the path's own geometry so the dot always sits exactly on the
    // line regardless of its curvature - the clipPath means it's simply
    // never drawn once it would fall outside BOX, no extra bounds check
    // needed here. setInterval rather than requestAnimationFrame on
    // purpose: this is a slow ambient drift, not a 60fps animation, and
    // rAF never fires at all while the card isn't actively composited
    // (verified while building this), which would mean the whole thing
    // silently never starts. Called directly, not deferred to a frame -
    // getTotalLength() only needs the path in the document, not a
    // layout/paint pass.
    function startApproach(bgEl, distanceValue) {
        const routeDone = bgEl.querySelector('.dispatch-map-route-done')
        const routeDim = bgEl.querySelector('.dispatch-map-route-dim')
        const unit = bgEl.querySelector('.dispatch-map-unit')
        const length = routeDim.getTotalLength()

        const durationMs = 14000 // full approach over 14s, looping - demo pacing only
        const startedAt = Date.now()

        function tick() {
            const progress = ((Date.now() - startedAt) % durationMs) / durationMs
            const point = routeDim.getPointAtLength(progress * length)
            unit.setAttribute('transform', `translate(${point.x} ${point.y})`)
            routeDone.setAttribute('stroke-dashoffset', String(1 - progress))
            distanceValue.textContent = `${Math.max(0, START_MI * (1 - progress)).toFixed(1)} mi`
        }
        tick()
        window.setInterval(tick, 250)
    }

    function renderActive(card, payload) {
        const surface = el('article', 'dispatch-card has-map')
        surface.setAttribute('aria-label', `${card.title}: active ride`)

        const bg = buildMapBg()
        const scrim = el('div', 'dispatch-map-scrim')

        const header = el('div', 'dispatch-header')
        const badgeEl = el('div')
        badge(badgeEl, 'car', card.iconUrl)
        const heading = el('div', 'dispatch-heading')
        heading.append(el('div', 'dispatch-title', card.title), el('div', 'dispatch-subtitle', card.subtitle))
        header.append(badgeEl, heading)

        // Plain text over the map, top-right - no chip/border, same
        // treatment as the pickup line below.
        const distanceChip = el('div', 'dispatch-map-distance')
        distanceChip.innerHTML = '<span>Distance</span>'
        const distanceValue = el('strong')
        distanceValue.textContent = `${START_MI.toFixed(1)} mi`
        distanceChip.appendChild(distanceValue)

        const pickup = el('div', 'dispatch-map-pickup')
        pickup.append(icon('location'), el('span', null, detail(card, 'location', 'Marked location')))

        const footer = el('div', 'dispatch-footer')
        const buttons = el('div', 'dispatch-buttons')
        card.actions.forEach((action) => buttons.appendChild(button(payload, action)))
        // Passenger count rides along in the same row as Cancel/Complete
        // instead of its own chip over the map - pushed to the row's far
        // end so it doesn't crowd the two real buttons.
        const peopleValue = detail(card, 'people', null)
        if (peopleValue) buttons.appendChild(iconValue('dispatch-map-people', 'people', String(peopleValue)))
        footer.appendChild(buttons)
        footer.appendChild(el('div', 'dispatch-map-note', 'Prototype - simulated approach, not live position'))

        const content = el('div', 'dispatch-map-content')
        content.append(header, distanceChip, pickup, footer)

        surface.append(bg, scrim, content)
        startApproach(bg, distanceValue)
        return surface
    }

    function renderPending(card, payload) {
        const surface = el('article', 'dispatch-card')
        surface.setAttribute('aria-label', `${card.title}: incoming request`)

        const header = el('div', 'dispatch-header')
        const badgeEl = el('div')
        badge(badgeEl, 'car', card.iconUrl)
        const heading = el('div', 'dispatch-heading')
        heading.append(
            el('div', 'dispatch-eyebrow', 'New request'),
            el('div', 'dispatch-title', card.title),
            el('div', 'dispatch-subtitle', card.subtitle),
        )
        header.append(badgeEl, heading, Dispatch.headerStats([
            { value: detail(card, 'distance', null), icon: 'distance' },
            { value: String(detail(card, 'people', '--')), icon: 'people' },
            { value: detail(card, 'price', null), icon: 'price', highlight: true },
        ]))

        const body = el('div', 'dispatch-body')
        body.appendChild(row({ icon: 'location', label: 'Pickup', value: detail(card, 'location', 'Marked location') }))

        const footer = el('div', 'dispatch-footer')
        const buttons = el('div', 'dispatch-buttons')
        card.actions.forEach((action) => buttons.appendChild(button(payload, action)))
        footer.appendChild(buttons)

        surface.append(header, body, footer)
        return surface
    }

    function render(payload) {
        const card = payload.card
        const surface = card.state === 'active' ? renderActive(card, payload) : renderPending(card, payload)
        root.replaceChildren(surface)
    }

    onMessage(render)
})()
