;(function () {
    const root = document.getElementById('active-request')
    const iconPaths = {
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
    }
    const aliases = {
        'taxi-ride': 'taxi', emergency_backup: 'police', 'emergency-backup': 'police',
        medical_emergency: 'medical', 'medical-emergency': 'medical', tow_truck: 'tow-truck',
        breaking_news: 'news', 'breaking-news': 'news',
    }
    let current = null
    let sending = false

    function text(parent, className, value) {
        if (value === undefined || value === null || value === '') return null
        const element = document.createElement('div')
        element.className = className
        element.textContent = String(value)
        parent.appendChild(element)
        return element
    }

    function icon(name) {
        const normalized = String(name || 'request').toLowerCase()
        const paths = iconPaths[aliases[normalized] || normalized] || iconPaths.request
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
        svg.classList.add('sp-icon')
        svg.setAttribute('viewBox', '0 0 24 24')
        svg.setAttribute('aria-hidden', 'true')
        paths.forEach((definition) => {
            const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
            path.setAttribute('d', definition)
            svg.appendChild(path)
        })
        return svg
    }

    function companyIcon(card) {
        const wrapper = document.createElement('div')
        wrapper.className = 'company-icon'
        wrapper.appendChild(icon(card.icon))
        if (card.iconUrl) {
            const image = document.createElement('img')
            image.alt = ''
            image.referrerPolicy = 'no-referrer'
            image.onerror = () => image.remove()
            image.src = card.iconUrl
            wrapper.appendChild(image)
        }
        return wrapper
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
                body: JSON.stringify({
                    id: current.card.id,
                    revision: current.card.revision,
                    action: actionId,
                }),
            })
        } finally {
            sending = false
            if (current) render(current)
        }
    }

    function render(payload) {
        current = payload
        const card = payload.card
        const surface = document.createElement('article')
        surface.className = 'request-card'

        const header = document.createElement('header')
        header.className = 'request-header'
        header.appendChild(companyIcon(card))
        const heading = document.createElement('div')
        heading.className = 'heading'
        text(heading, 'title', card.title)
        text(heading, 'subtitle', card.subtitle)
        header.appendChild(heading)
        text(header, 'status', payload.data.statusLabel || 'Active request')
        surface.appendChild(header)
        text(surface, 'note', card.description)

        if (Array.isArray(card.details) && card.details.length > 0) {
            const details = document.createElement('section')
            details.className = 'details'
            details.dataset.count = String(card.details.length)
            card.details.forEach((item) => {
                const detail = document.createElement('div')
                detail.className = 'detail'
                detail.setAttribute('aria-label', `${item.label}: ${item.value}`)
                const detailIcon = document.createElement('span')
                detailIcon.className = 'detail-icon'
                detailIcon.appendChild(icon(item.icon))
                detail.appendChild(detailIcon)
                text(detail, 'detail-value', item.value)
                details.appendChild(detail)
            })
            surface.appendChild(details)
        }

        const actions = document.createElement('footer')
        actions.className = 'actions'
        card.actions.forEach((action) => {
            const button = document.createElement('button')
            button.type = 'button'
            button.className = `action ${action.color || 'default'}`
            button.textContent = card.confirmAction === action.id
                ? action.confirm?.label || 'Confirm?'
                : action.label
            button.disabled = sending || card.actionInFlight || payload.presentation.callPriority
            button.addEventListener('click', () => runAction(action.id))
            actions.appendChild(button)
        })
        surface.appendChild(actions)
        root.replaceChildren(surface)
    }

    window.addEventListener('message', ({ data }) => {
        if (data?.type !== 'peekplus:template' || !data.card || !data.actionEndpoint) return
        render(data)
    })
})()
