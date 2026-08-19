;(function () {
    const root = document.getElementById('taxi-request')
    const { el, badge, row, headerStats, button, detail, onMessage } = Dispatch

    Dispatch.registerIcons({
        car: ['M5 11l1.4-4.3A2 2 0 0 1 8.3 5.3h7.4a2 2 0 0 1 1.9 1.4L19 11', 'M3 11h18v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z', 'M7 18v1', 'M17 18v1'],
        price: ['M12 1v22', 'M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6'],
    })

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

    let currentMapRenderer = null;
    let activeCardMounted = false;
    let currentActiveElements = null;

    function renderPending(payload, card) {
        activeCardMounted = false;
        currentActiveElements = null;
        if (currentMapRenderer) {
            currentMapRenderer.destroy();
            currentMapRenderer = null;
        }

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
        header.append(badgeEl, heading, headerStats([
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
        root.replaceChildren(surface)
    }

    function updateActive(payload, card) {
        if (!currentActiveElements) return;
        const { distanceEl, peopleEl, heading } = currentActiveElements;
        if (distanceEl) distanceEl.textContent = detail(card, 'distance', '');
        if (heading) {
            const titleEl = heading.querySelector('.dispatch-title');
            const subEl = heading.querySelector('.dispatch-subtitle');
            if (titleEl) titleEl.textContent = card.title;
            if (subEl) subEl.textContent = card.subtitle;
        }
        if (peopleEl) {
            peopleEl.innerHTML = `<svg class="dispatch-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg> ${detail(card, 'people', '--')}`;
        }
    }

    function renderActive(payload, card) {
        if (activeCardMounted && currentActiveElements) {
            updateActive(payload, card);
            return;
        }

        activeCardMounted = true;
        const surface = el('article', 'dispatch-card has-map')
        surface.setAttribute('aria-label', `${card.title}: active ride`)

        const mapContainer = el('div', 'dispatch-map-bg mapplus-container')
        const scrim = el('div', 'dispatch-map-scrim')
        const content = el('div', 'dispatch-map-content')

        const header = el('div', 'dispatch-header')
        const badgeEl = el('div')
        badge(badgeEl, 'car', card.iconUrl)
        const heading = el('div', 'dispatch-heading')
        heading.append(
            el('div', 'dispatch-eyebrow', 'Active ride'),
            el('div', 'dispatch-title', card.title),
            el('div', 'dispatch-subtitle', card.subtitle),
        )
        const distanceEl = el('div', 'dispatch-map-distance', detail(card, 'distance', ''))
        
        header.append(badgeEl, heading, distanceEl)

        const footer = el('div', 'dispatch-footer')
        const buttons = el('div', 'dispatch-buttons')
        card.actions.forEach((action) => buttons.appendChild(button(payload, action)))
        
        const peopleEl = el('div', 'dispatch-map-people')
        peopleEl.innerHTML = `<svg class="dispatch-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg> ${detail(card, 'people', '--')}`
        
        footer.append(buttons, peopleEl)

        content.append(header, footer)
        surface.append(mapContainer, scrim, content)
        root.replaceChildren(surface)

        currentActiveElements = { distanceEl, peopleEl, heading };

        // Initialize MapPlus
        if (currentMapRenderer) {
            currentMapRenderer.destroy();
            currentMapRenderer = null;
        }
        setTimeout(() => {
            currentMapRenderer = new window.MapPlusRenderer(mapContainer);
            if (card.templateData?.pos) {
                currentMapRenderer.setCenter(card.templateData.pos.x, card.templateData.pos.y, 3);
                currentMapRenderer.addMarker('pickup', card.templateData.pos.x, card.templateData.pos.y, 'destination');
            } else {
                currentMapRenderer.setCenter(0, 0, 3);
            }
        }, 20);
    }

    function render(payload) {
        if (payload.action === 'mapplus:routeUpdate') {
            if (currentMapRenderer) {
                currentMapRenderer.setRoute(payload.points, payload.destination, payload.player);
            }
            return;
        }

        if (payload.action === 'mapplus:playerUpdate') {
            if (currentMapRenderer) {
                currentMapRenderer.updatePlayer(payload.player);
            }
            return;
        }

        const card = payload.card
        if (!card) return;

        if (card.state === 'active') {
            renderActive(payload, card)
        } else {
            renderPending(payload, card)
        }
    }

    window.addEventListener('message', (event) => {
        if (event.data?.action === 'mapplus:routeUpdate' || event.data?.action === 'mapplus:playerUpdate') {
            render(event.data);
        }
    });

    onMessage(render)
})()
