;(function () {
    const root = document.getElementById('taxi-request')
    const { el, icon, badge, row, button, detail, onMessage } = Dispatch

    Dispatch.registerIcons({
        car: ['M5 11l1.4-4.3A2 2 0 0 1 8.3 5.3h7.4a2 2 0 0 1 1.9 1.4L19 11', 'M3 11h18v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z', 'M7 18v1', 'M17 18v1'],
        price: ['M12 1v22', 'M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6'],
    })

    // Decorative location thumbnail only, pending state only - this has no
    // live position to show yet (the request isn't accepted), so it stays
    // a stylized road pattern rather than a real map. See renderActive()
    // for the real one.
    function miniMap() {
        const wrap = el('div', 'dispatch-map')
        wrap.innerHTML = '<svg viewBox="0 0 46 46" xmlns="http://www.w3.org/2000/svg">'
            + '<rect width="46" height="46" fill="#14161a"/>'
            + '<path d="M0 14H46M0 30H46M14 0V46M30 0V46" stroke="#242730" stroke-width="1.5"/>'
            + '<path d="M4 40 20 22 30 26 42 8" stroke="var(--dispatch-accent)" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
            + '<circle cx="4" cy="40" r="3" fill="var(--dispatch-accent)"/>'
            + '</svg>'
        return wrap
    }

    // Icon-then-value, unlike Dispatch.headerStats() (value-then-icon) -
    // used for the passenger count in the active/map footer row, where it
    // sits over map art rather than the flat card background.
    function iconValue(className, iconName, value) {
        const wrap = el('div', className)
        wrap.appendChild(icon(iconName))
        wrap.appendChild(el('span', null, value))
        return wrap
    }

    // Real lb-phone GameMap instance (docs.lbscripts.com/phone/custom-apps),
    // kept alive across re-renders instead of recreated - see comment on
    // renderActive() for why that matters. `components` is injected by
    // lb-phone into pages it loads as a custom app; whether it's also
    // present in a PeekPlus Sibling-NUI full-card iframe (this file) is
    // NOT yet confirmed in a live client - if it's missing, this
    // degrades to a plain gradient background instead of throwing.
    let map = null // { key, container, instance }

    function destroyMap() {
        if (map?.instance) {
            try { map.instance.destroy() } catch { /* best-effort cleanup */ }
        }
        map = null
    }

    // Builds (or reuses, if this is still the same request) the map
    // container + GameMap instance. Reuse matters: the server pushes a
    // fresh details update roughly every 2s while a ride is active
    // (client/services/requests.lua's startDistanceUpdates), which
    // triggers a fresh render() call here every time - recreating the
    // GameMap that often would reload/flicker it constantly instead of
    // it just quietly tracking the player's live position on its own via
    // setShowSelf().
    function startGameMap(container, pos) {
        if (!pos || !window.components?.GameMap || !map) return
        // defaultZoom is a guess (the lb-phone docs example uses 3 for a
        // different, full-screen map context) - needs live tuning once
        // this actually renders in-game.
        const instance = new window.components.GameMap(container, {
            allowMoving: false,
            center: pos,
            defaultZoom: 15,
        })
        map.instance = instance
        instance.ready
            .then(() => {
                instance.addLocation({ title: 'Pickup', coords: pos })
                return instance.setShowSelf(true)
            })
            .catch(() => { /* GameMap failed to load - container just stays empty over the scrim */ })
    }

    function mapContainer(key, pos) {
        if (map && map.key === key) {
            // components can plausibly become available after the first
            // render already ran without it - retry on a later render
            // (there's always one coming, every ~2s while active) instead
            // of staying empty forever once it does.
            if (!map.instance) startGameMap(map.container, pos)
            return map.container
        }

        destroyMap()
        const container = el('div', 'dispatch-map-bg')
        map = { key, container, instance: null }
        startGameMap(container, pos)
        return container
    }

    function renderActive(card, payload) {
        const surface = el('article', 'dispatch-card has-map')
        surface.setAttribute('aria-label', `${card.title}: active ride`)

        const bg = mapContainer(card.key, payload.data?.pos)
        const scrim = el('div', 'dispatch-map-scrim')

        const header = el('div', 'dispatch-header')
        const badgeEl = el('div')
        badge(badgeEl, 'car', card.iconUrl)
        const heading = el('div', 'dispatch-heading')
        heading.append(el('div', 'dispatch-title', card.title), el('div', 'dispatch-subtitle', card.subtitle))
        header.append(badgeEl, heading)

        const distanceChip = el('div', 'dispatch-map-distance')
        distanceChip.innerHTML = '<span>Distance</span>'
        const distanceText = detail(card, 'distance', null)
        distanceChip.appendChild(el('strong', null, distanceText || '—'))

        const pickup = el('div', 'dispatch-map-pickup')
        pickup.append(icon('location'), el('span', null, detail(card, 'location', 'Marked location')))

        const footer = el('div', 'dispatch-footer')
        const buttons = el('div', 'dispatch-buttons')
        card.actions.forEach((action) => buttons.appendChild(button(payload, action)))
        const peopleValue = detail(card, 'people', null)
        if (peopleValue) buttons.appendChild(iconValue('dispatch-map-people', 'people', String(peopleValue)))
        footer.appendChild(buttons)

        const content = el('div', 'dispatch-map-content')
        content.append(header, distanceChip, pickup, footer)

        surface.append(bg, scrim, content)
        return surface
    }

    function renderPending(card, payload) {
        destroyMap() // leftover from a previous active render of a different request

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
        body.appendChild(row({ icon: 'location', label: 'Pickup', value: detail(card, 'location', 'Marked location'), trailing: miniMap() }))

        const footer = el('div', 'dispatch-footer')
        const buttons = el('div', 'dispatch-buttons')
        card.actions.forEach((action) => buttons.appendChild(button(payload, action)))
        footer.appendChild(buttons)

        surface.append(header, body, footer)
        return surface
    }

    function render(payload) {
        const card = payload.card
        const active = card.state === 'active'
        const surface = active ? renderActive(card, payload) : renderPending(card, payload)
        root.replaceChildren(surface)
    }

    onMessage(render)
})()
