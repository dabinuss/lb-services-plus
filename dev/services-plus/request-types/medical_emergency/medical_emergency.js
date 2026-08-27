;(function () {
    const root = document.getElementById('dispatch-request')
    const { el, icon, badge, row, headerStats, button, detail, onMessage, startCountdown } = Dispatch
    let stopCountdown = null

    Dispatch.registerIcons({
        medical: ['M3 12h4l2-5 4 10 2-5h6', 'M12 21C5 17 2 13 3 8a5 5 0 0 1 9-2 5 5 0 0 1 9 2'],
    })

    // Decorative location thumbnail - no live map/routing data source exists
    // inside this NUI, so this is a stylized incident-pin graphic, not a map.
    function miniMap() {
        const wrap = el('div', 'dispatch-map')
        wrap.innerHTML = '<svg viewBox="0 0 46 46" xmlns="http://www.w3.org/2000/svg">'
            + '<rect width="46" height="46" fill="#14161a"/>'
            + '<path d="M0 16H46M0 30H46M16 0V46M30 0V46" stroke="#242730" stroke-width="1.5"/>'
            + '<path d="M23 15v16M15 23h16" stroke="var(--dispatch-accent)" stroke-width="2.5" stroke-linecap="round"/>'
            + '</svg>'
        return wrap
    }

    function render(payload) {
        const card = payload.card
        const active = card.state === 'active'
        if (stopCountdown) { stopCountdown(); stopCountdown = null }

        const surface = el('article', 'dispatch-card')
        surface.setAttribute('aria-label', `${card.title}: ${active ? 'active dispatch' : 'incoming dispatch'}`)

        const header = el('div', 'dispatch-header')
        const badgeEl = el('div')
        badge(badgeEl, 'medical', card.iconUrl)
        const heading = el('div', 'dispatch-heading')
        heading.append(
            el('div', 'dispatch-eyebrow', active ? 'Active dispatch' : 'Medics dispatch'),
            el('div', 'dispatch-title', card.title),
            el('div', 'dispatch-subtitle', card.subtitle),
        )
        // Distance first, then patient count - a real number every dispatch
        // has, not a decorative "Priority: Medium" that never changed with
        // the actual incident (this codebase has no triage data model yet).
        header.append(badgeEl, heading, headerStats([
            { value: detail(card, 'distance', null), icon: 'distance' },
            { value: String(detail(card, 'people', '--')), icon: 'people' },
        ]))

        const body = el('div', 'dispatch-body')
        body.appendChild(row({
            icon: 'location', label: 'Address', value: detail(card, 'location', 'Marked location'), trailing: miniMap(),
        }))

        if (card.description) {
            const note = el('div', 'dispatch-note')
            note.append(el('div', 'dispatch-row-label', 'Notes'), el('div', 'dispatch-note-text', card.description))
            body.appendChild(note)
        }

        const footer = el('div', 'dispatch-footer')
        const visibleActions = card.actions.filter((action) => action.presentation !== 'tap')
        if (visibleActions.length > 0) {
            const buttons = el('div', 'dispatch-buttons')
            visibleActions.forEach((action) => buttons.appendChild(button(payload, action)))
            footer.appendChild(buttons)
        }

        if (!active) {
            const info = el('div', 'dispatch-info')
            footer.appendChild(info)
            stopCountdown = startCountdown(card.remainingMs, (seconds) => {
                info.replaceChildren()
                if (seconds < 0) return
                info.classList.toggle('warn', seconds <= 5)
                info.append(icon('clock'), document.createTextNode('Auto-decline in '), el('strong', null, `${seconds}s`))
            })
        }

        surface.append(header, body, footer)
        root.replaceChildren(surface)
    }

    onMessage(render)
})()
