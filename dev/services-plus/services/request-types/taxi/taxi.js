;(function () {
    const root = document.getElementById('taxi-request')
    const paths = {
        people: ['M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2', 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8'],
        distance: ['M5 3v18', 'M19 3v18', 'M9 7h6', 'M9 17h6'],
        location: ['M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0', 'M12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5'],
        time: ['M12 20a7 7 0 1 0 0-14 7 7 0 0 0 0 14', 'M12 13V9', 'M12 13l3 2', 'M9 2h6', 'M12 2v4'],
        back: ['M20 5H9l-5 7 5 7h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2Z', 'm16 9-4 4m0-4 4 4'],
        enter: ['M20 4v7a4 4 0 0 1-4 4H5', 'm9 11-4 4 4 4'],
    }
    let current = null
    let sending = false
    let activeCardId = null
    let activeStartedAt = 0
    let clockInterval = null

    function svg(name) {
        const element = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
        element.classList.add('sp-icon')
        element.setAttribute('viewBox', '0 0 24 24')
        element.setAttribute('aria-hidden', 'true')
        paths[name].forEach((definition) => {
            const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
            path.setAttribute('d', definition)
            element.appendChild(path)
        })
        return element
    }

    function detail(card, icon, fallback) {
        return card.details?.find((item) => item.icon === icon)?.value || fallback
    }

    function formatPassenger(value) {
        const number = Number.parseInt(value, 10)
        return Number.isFinite(number) ? String(number).padStart(2, '0') : String(value || '--')
    }

    function distanceParts(value) {
        const match = String(value || '--').trim().match(/^(.+?)\s*([a-zA-Z]+)$/)
        return match ? { value: match[1], unit: match[2].toUpperCase() } : { value: String(value || '--'), unit: '' }
    }

    function elapsed() {
        const seconds = Math.max(0, Math.floor((Date.now() - activeStartedAt) / 1000))
        return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`
    }

    function cell(label, iconName, className, value, unit) {
        const wrapper = document.createElement('div')
        wrapper.className = 'cell'
        const heading = document.createElement('div')
        heading.className = 'label'
        heading.append(svg(iconName), document.createTextNode(label))
        const output = document.createElement('div')
        output.className = `digital ${className}`
        output.textContent = value
        if (unit) {
            const suffix = document.createElement('span')
            suffix.className = 'unit'
            suffix.textContent = unit
            output.appendChild(suffix)
        }
        wrapper.append(heading, output)
        return wrapper
    }

    function button(action, active) {
        const primary = action.id === 'accept' || action.id === 'complete'
        const armed = current.card.confirmAction === action.id
        const element = document.createElement('button')
        element.type = 'button'
        element.className = `btn ${primary ? (active ? 'green' : 'yellow') : 'dark'}${armed ? ' confirm' : ''}`
        element.disabled = sending || current.card.actionInFlight || current.presentation.callPriority
        element.title = action.label
        const icon = document.createElement('span')
        icon.className = 'icon'
        icon.appendChild(svg(primary ? 'enter' : 'back'))
        const divider = document.createElement('span')
        divider.className = 'divider'
        const label = document.createElement('span')
        label.className = 'text'
        label.textContent = armed
            ? action.confirm?.label || 'Confirm?'
            : ({ decline: 'Decline', accept: 'Accept Request', cancel: 'Cancel Ride', complete: 'Complete Ride' }[action.id] || action.label)
        element.append(icon, divider, label)
        element.addEventListener('click', () => runAction(action.id))
        return element
    }

    async function runAction(actionId) {
        if (!current || sending || current.card.actionInFlight || current.presentation.callPriority) return
        if (!current.card.actions.some((action) => action.id === actionId)) return
        sending = true
        render(current)
        try {
            await fetch(current.actionEndpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ id: current.card.id, revision: current.card.revision, action: actionId }),
            })
        } finally {
            sending = false
            if (current) render(current)
        }
    }

    function render(payload) {
        current = payload
        const card = payload.card
        const active = card.state === 'active'
        if (active && activeCardId !== card.id) {
            activeCardId = card.id
            activeStartedAt = Date.now()
        } else if (!active) {
            activeCardId = null
            activeStartedAt = 0
        }

        const surface = document.createElement('article')
        surface.className = `taxometer ${active ? 'active' : 'pending'}`
        surface.setAttribute('aria-label', `${card.title}: ${active ? 'Active ride' : 'Incoming request'}`)

        const inner = document.createElement('div')
        inner.className = 'inner'
        const screen = document.createElement('section')
        screen.className = 'screen'
        const top = document.createElement('div')
        top.className = 'row top'
        const distance = distanceParts(detail(card, 'distance', '--'))
        top.append(
            cell('Pax', 'people', 'big passenger-value', formatPassenger(detail(card, 'people', '--'))),
            cell('Ride Time', 'time', 'time time-value', active ? elapsed() : '--:--'),
            cell('Distance', 'distance', 'big distance-value', distance.value, distance.unit)
        )
        const separator = document.createElement('div')
        separator.className = 'sep'
        const bottom = document.createElement('div')
        bottom.className = 'row bottom'
        bottom.appendChild(cell('Pickup', 'location', 'pickup pickup-value', detail(card, 'location', 'Marked location')))
        screen.append(top, separator, bottom)

        const leds = document.createElement('div')
        leds.className = 'leds'
        ;[['On Duty', 'on-duty'], ['Incoming Request', 'request-led'], ['Active Ride', 'active-led']].forEach(([label, className]) => {
            const item = document.createElement('div')
            item.className = 'led-item'
            const light = document.createElement('span')
            light.className = `led ${className}`
            item.append(document.createTextNode(label), light)
            leds.appendChild(item)
        })

        const actions = document.createElement('footer')
        actions.className = 'action-row'
        card.actions.forEach((action) => actions.appendChild(button(action, active)))
        inner.append(screen, leds, actions)
        surface.appendChild(inner)
        root.replaceChildren(surface)

        window.clearInterval(clockInterval)
        clockInterval = active ? window.setInterval(() => {
            const clock = root.querySelector('.time-value')
            if (clock) clock.textContent = elapsed()
        }, 1000) : null
    }

    window.addEventListener('message', ({ data }) => {
        if (data?.type !== 'peekplus:template' || !data.card || !data.actionEndpoint) return
        render(data)
    })
})()
