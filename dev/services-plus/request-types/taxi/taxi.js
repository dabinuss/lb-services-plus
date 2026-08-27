;(function () {
    const root = document.getElementById('taxi-request')
    const { el, badge, row, headerStats, button, detail, onMessage } = Dispatch

    Dispatch.registerIcons({
        car: ['M5 11l1.4-4.3A2 2 0 0 1 8.3 5.3h7.4a2 2 0 0 1 1.9 1.4L19 11', 'M3 11h18v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z', 'M7 18v1', 'M17 18v1'],
        price: ['M12 1v22', 'M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6'],
    })

    // Decorative location thumbnail only - this NUI has no live map/routing
    // data source, so it's a stylized road pattern, not a real map render.
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

    function render(payload) {
        const card = payload.card
        const active = card.state === 'active'

        const surface = el('article', 'dispatch-card')
        surface.setAttribute('aria-label', `${card.title}: ${active ? 'active ride' : 'incoming request'}`)

        const header = el('div', 'dispatch-header')
        const badgeEl = el('div')
        badge(badgeEl, 'car', card.iconUrl)
        const heading = el('div', 'dispatch-heading')
        heading.append(
            el('div', 'dispatch-eyebrow', active ? 'Active ride' : 'New request'),
            el('div', 'dispatch-title', card.title),
            el('div', 'dispatch-subtitle', card.subtitle),
        )
        // The dispatch card intentionally shows no fare estimate: the real
        // meter begins only when the driver reaches the pickup point.
        header.append(badgeEl, heading, headerStats([
            { value: detail(card, 'distance', null), icon: 'distance' },
            { value: String(detail(card, 'people', '--')), icon: 'people' },
        ]))

        const body = el('div', 'dispatch-body')
        body.appendChild(row({ icon: 'location', label: 'Pickup', value: detail(card, 'location', 'Marked location'), trailing: miniMap() }))

        const footer = el('div', 'dispatch-footer')
        const visibleActions = card.actions.filter((action) => action.presentation !== 'tap')
        if (visibleActions.length > 0) {
            const buttons = el('div', 'dispatch-buttons')
            visibleActions.forEach((action) => buttons.appendChild(button(payload, action)))
            footer.appendChild(buttons)
        }

        surface.append(header, body, footer)
        root.replaceChildren(surface)
    }

    onMessage(render)
})()
