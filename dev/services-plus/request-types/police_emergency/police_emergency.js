;(function () {
    const root = document.getElementById('dispatch-request')
    const { el, badge, row, headerStats, button, detail, onMessage } = Dispatch

    Dispatch.registerIcons({
        siren: ['M12 3a7 7 0 0 0-7 7v7h14v-7a7 7 0 0 0-7-7z', 'M12 3V1', 'M5 21h14'],
    })

    // Decorative location thumbnail - no live map/routing data source exists
    // inside this NUI, so this is a stylized incident-pin graphic, not a map.
    function miniMap() {
        const wrap = el('div', 'dispatch-map')
        wrap.innerHTML = '<svg viewBox="0 0 46 46" xmlns="http://www.w3.org/2000/svg">'
            + '<rect width="46" height="46" fill="#14161a"/>'
            + '<path d="M0 16H46M0 30H46M16 0V46M30 0V46" stroke="#242730" stroke-width="1.5"/>'
            + '<circle cx="23" cy="23" r="10" fill="none" stroke="var(--dispatch-accent)" stroke-width="1.5" opacity=".55"/>'
            + '<circle cx="23" cy="23" r="4" fill="var(--dispatch-accent)"/>'
            + '</svg>'
        return wrap
    }

    function render(payload) {
        const card = payload.card
        const active = card.state === 'active'

        const surface = el('article', 'dispatch-card')
        surface.setAttribute('aria-label', `${card.title}: ${active ? 'active dispatch' : 'incoming dispatch'}`)

        const header = el('div', 'dispatch-header')
        const badgeEl = el('div')
        badge(badgeEl, 'siren', card.iconUrl)
        const heading = el('div', 'dispatch-heading')
        heading.append(
            el('div', 'dispatch-eyebrow', active ? 'Active dispatch' : 'Dispatch'),
            el('div', 'dispatch-title', card.title),
            el('div', 'dispatch-subtitle', card.subtitle),
        )
        // Distance in the header corner - a real number every dispatch has,
        // not a decorative "Priority: High" that never changed with the
        // actual incident (this codebase has no triage data model yet).
        // Police requests carry no other per-incident number today.
        header.append(badgeEl, heading, headerStats([{ value: detail(card, 'distance', null), icon: 'distance' }]))

        const body = el('div', 'dispatch-body')
        body.appendChild(row({
            icon: 'location', label: 'Address', value: detail(card, 'location', 'Marked location'), trailing: miniMap(),
        }))

        const note = el('div', 'dispatch-note')
        note.append(el('div', 'dispatch-row-label', 'Situation'), el('div', 'dispatch-note-text', card.description || 'No further details provided.'))
        body.appendChild(note)

        const footer = el('div', 'dispatch-footer')
        const buttons = el('div', 'dispatch-buttons')
        card.actions.forEach((action) => buttons.appendChild(button(payload, action)))
        footer.appendChild(buttons)

        surface.append(header, body, footer)
        root.replaceChildren(surface)
    }

    onMessage(render)
})()
