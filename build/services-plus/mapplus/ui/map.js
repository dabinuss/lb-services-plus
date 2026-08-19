// =============================================================================
// MapPlus – GTA V Navigation Renderer
// Single source of truth for CRS calibration and rendering.
// =============================================================================

/**
 * Single authoritative GTA V → Leaflet coordinate transform.
 * debug.html MUST import this file and use window.GTA_MAP_TRANSFORM instead
 * of defining its own CRS, to guarantee zero drift between debug and production.
 *
 * How to re-calibrate:
 *   1. Open debug.html with calibration mode enabled
 *   2. Place 10 markers across the full map (LSIA to Paleto Bay)
 *   3. Adjust scaleX/offsetX until ALL markers match their GTA coordinates
 *   4. If only LS fits but Paleto drifts → adjust scaleX (scale error)
 *   5. If all drift uniformly → adjust offsetX / offsetY (offset error)
 */
window.GTA_MAP_TRANSFORM = {
    scaleX:  0.02072,
    offsetX: 117.3,
    scaleY:  -0.0205,
    offsetY: 172.8,
};

class MapPlusRenderer {
    constructor(container, options = {}) {
        this.container = container;
        this.style = options.style || 'styleAtlas';
        this._layoutTimers = [];
        this._overviewDone = false;
        this._isFraming = false;  // true while fitBounds animation is running

        const t = window.GTA_MAP_TRANSFORM;
        this.GtaCRS = Object.assign({}, L.CRS.Simple, {
            projection: L.Projection.LonLat,
            scale: (zoom) => Math.pow(2, zoom),
            zoom: (sc) => Math.log(sc) / Math.LN2,
            distance: (p1, p2) => Math.hypot(p2.lng - p1.lng, p2.lat - p1.lat),
            transformation: new L.Transformation(t.scaleX, t.offsetX, t.scaleY, t.offsetY),
            infinite: true,
        });

        this.map = L.map(container, {
            crs: this.GtaCRS,
            minZoom: 1,
            maxZoom: 5,
            zoomSnap: 0.25,
            zoomDelta: 0.5,
            zoomAnimation: true,
            fadeAnimation: true,
            markerZoomAnimation: true,
            center: [-1000, 150],
            zoom: 3,
            zoomControl: false,
            attributionControl: false,
            // Non-interactive: this is a navigation display, not an explorable map
            dragging: false,
            scrollWheelZoom: false,
            doubleClickZoom: false,
            touchZoom: false,
            keyboard: false,
            boxZoom: false,
            // GTA V world bounds – prevents Leaflet from requesting tiles outside coverage
            // South/West corner ≈ (-4000, -4400), North/East corner ≈ (8000, 8000) in GTA coords
            maxBounds: [[-4400, -4000], [8000, 8000]],
            maxBoundsViscosity: 0.0, // don't rubber-band – map is non-interactive anyway
        });

        // Custom pane for route layers – guarantees draw order: tiles → route outline → route → markers
        this.map.createPane('mapplusRoute');
        this.map.getPane('mapplusRoute').style.zIndex = 450;

        const ext = this.style === 'styleGrid' ? 'png' : 'jpg';
        this.tileLayer = L.tileLayer(
            `https://raw.githubusercontent.com/Trusted-Studios/mapStyles/main/${this.style}/{z}/{x}/{y}.${ext}`,
            {
                minZoom: 0,
                maxZoom: 5,
                noWrap: true,
                keepBuffer: 2,
            }
        ).addTo(this.map);

        // Debug: log tile failures so we can distinguish "no route" from "no tiles"
        this.tileLayer.on('tileerror', (event) => {
            if (window.MapPlusDebug) {
                console.warn('[MapPlus] tile failed:', event.tile?.src);
                if (this._debugState) this._debugState.tileErrors++;
            }
        });

        this.routeOutline = null;
        this.routeLine = null;
        this.markers = {};
        this._lastFramedSpan = null;

        // Debug health state – populated only when MapPlusDebug is set
        if (window.MapPlusDebug) {
            this._debugState = { routePoints: 0, lastRouteAt: 0, lastPlayerAt: 0, tileErrors: 0 };
        }

        // Release _isFraming guard after every map movement ends
        this.map.on('moveend', () => { this._isFraming = false; });

        this._setupObservers();
        this._refreshLayout();
    }

    _refreshLayout() {
        for (const id of this._layoutTimers) clearTimeout(id);
        this._layoutTimers = [];
        const invalidate = () => { if (this.map) this.map.invalidateSize(false); };
        invalidate();
        this._layoutTimers.push(setTimeout(invalidate, 80));
        this._layoutTimers.push(setTimeout(invalidate, 250));
    }

    _setupObservers() {
        if (typeof ResizeObserver !== 'undefined' && this.container) {
            this._resizeObserver = new ResizeObserver(() => this._refreshLayout());
            this._resizeObserver.observe(this.container);
        }
    }

    _fitBounds(bounds, opts = {}) {
        // Stop any ongoing pan/zoom before starting a new fitBounds
        this.map.stop();
        this._isFraming = true;
        this.map.fitBounds(bounds, {
            paddingTopLeft: [75, 50],
            paddingBottomRight: [35, 90],
            maxZoom: 4,
            animate: true,
            duration: 0.5,
            ...opts,
        });
    }

    setCenter(x, y, zoom = 3) {
        if (!this.map) return;
        this.map.setView([y, x], zoom, { animate: false });
        this._refreshLayout();
    }

    setPlayer(x, y, heading) {
        if (!this.map || typeof x !== 'number' || typeof y !== 'number') return;

        // GTA V heading: 0=North, counter-clockwise (90=West, 270=East).
        // CSS rotation: clockwise from up. Conversion: (360 - gtaHeading) % 360
        const rotateDeg = (heading == null) ? 0 : (360 - heading) % 360;

        if (!this.markers['player']) {
            const iconHtml = `
                <div class="mapplus-arrow-inner" style="
                    width: 0; height: 0;
                    border-left: 6px solid transparent;
                    border-right: 6px solid transparent;
                    border-bottom: 14px solid #ffffff;
                    filter: drop-shadow(0 0 5px rgba(167,66,255,0.9));
                    transform: rotate(${rotateDeg}deg);
                    transform-origin: 50% 65%;
                "></div>`;
            const icon = L.divIcon({
                html: iconHtml,
                className: 'mapplus-player-marker',
                iconSize: [12, 14],
                iconAnchor: [6, 9],
            });
            this.markers['player'] = L.marker([y, x], { icon, zIndexOffset: 1000 }).addTo(this.map);
        } else {
            this.markers['player'].setLatLng([y, x]);
            const inner = this.markers['player'].getElement()?.querySelector('.mapplus-arrow-inner');
            if (inner) inner.style.transform = `rotate(${rotateDeg}deg)`;
        }
    }

    setDestination(x, y) {
        if (!this.map || typeof x !== 'number' || typeof y !== 'number') return;
        if (!this.markers['destination']) {
            const iconHtml = `<div style="
                width: 14px; height: 14px; border-radius: 50%;
                background: #f4b914; border: 2px solid #101114;
                box-shadow: 0 2px 8px rgba(0,0,0,0.85);
            "></div>`;
            const icon = L.divIcon({
                html: iconHtml,
                className: 'mapplus-dest-marker',
                iconSize: [14, 14],
                iconAnchor: [7, 7],
            });
            this.markers['destination'] = L.marker([y, x], { icon, zIndexOffset: 900 }).addTo(this.map);
        } else {
            this.markers['destination'].setLatLng([y, x]);
        }
    }

    /**
     * Main update – called when the route actually changes.
     * Player position is embedded in the first call; subsequent player ticks use updatePlayer().
     */
    setRoute(points, destination, player) {
        if (!this.map) return;

        if (destination) {
            this.setDestination(destination.x, destination.y);
        } else if (this.markers['destination']) {
            this.map.removeLayer(this.markers['destination']);
            delete this.markers['destination'];
        }

        if (player) this.setPlayer(player.x, player.y, player.heading);

        if (window.MapPlusDebug && this._debugState) {
            this._debugState.routePoints = points ? points.length : 0;
            this._debugState.lastRouteAt = Date.now();
            console.debug('[MapPlus] setRoute', this._debugState);
        }

        if (!points || points.length === 0) {
            if (this.routeOutline) { this.map.removeLayer(this.routeOutline); this.routeOutline = null; }
            if (this.routeLine)    { this.map.removeLayer(this.routeLine);    this.routeLine    = null; }
            this._overviewDone = false;
            this._lastFramedSpan = null;
            return;
        }

        const latLngs = points.map(p => [p.y, p.x]);

        // smoothFactor: 0  – no geometry simplification at any zoom level
        // noClip: true     – never clip segments outside the current viewport
        // pane: 'mapplusRoute' – guaranteed draw order above tiles, below markers
        const polyOpts = { smoothFactor: 0, noClip: true, interactive: false, pane: 'mapplusRoute' };

        if (!this.routeOutline) {
            this.routeOutline = L.polyline(latLngs, {
                color: '#2a0f40', weight: 9, opacity: 0.85,
                lineCap: 'round', lineJoin: 'round', ...polyOpts,
            }).addTo(this.map);
        } else {
            this.routeOutline.setLatLngs(latLngs);
        }

        if (!this.routeLine) {
            this.routeLine = L.polyline(latLngs, {
                color: '#a742ff', weight: 6, opacity: 1.0,
                lineCap: 'round', lineJoin: 'round', ...polyOpts,
            }).addTo(this.map);
        } else {
            this.routeLine.setLatLngs(latLngs);
        }

        // --- Framing ---
        try {
            if (!this._overviewDone) {
                this._overviewDone = true;

                // OVERVIEW MODE: show player + first ~500m of route (not entire long route)
                const OVERVIEW_POINTS = Math.min(points.length, 63); // 63 × 8m ≈ 500m
                const overviewLatLngs = latLngs.slice(0, OVERVIEW_POINTS);
                const bounds = L.latLngBounds(overviewLatLngs);
                if (player && typeof player.x === 'number') bounds.extend([player.y, player.x]);
                if (destination && typeof destination.x === 'number') bounds.extend([destination.y, destination.x]);

                if (bounds.isValid()) {
                    this._lastFramedSpan = Math.hypot(
                        bounds.getNorth() - bounds.getSouth(),
                        bounds.getEast() - bounds.getWest()
                    );
                    this._fitBounds(bounds);
                }
            } else {
                // NAVIGATION MODE: re-fit only when horizon span changes significantly.
                // Use the same forward-horizon as overview (first ~640m) so the map
                // never zooms out to show a 5km route in a tiny notification panel.
                const NAV_POINTS = Math.min(latLngs.length, 80); // 80 × 8m ≈ 640m
                const navLatLngs = latLngs.slice(0, NAV_POINTS);
                const bounds = L.latLngBounds(navLatLngs);
                if (player && typeof player.x === 'number') bounds.extend([player.y, player.x]);
                if (!bounds.isValid()) return;

                const span = Math.hypot(bounds.getNorth() - bounds.getSouth(), bounds.getEast() - bounds.getWest());
                const spanChange = this._lastFramedSpan
                    ? Math.abs(span - this._lastFramedSpan) / this._lastFramedSpan : 1;

                if (spanChange > 0.15) {
                    this._lastFramedSpan = span;
                    this._fitBounds(bounds);
                }
            }
        } catch (error) {
            if (window.MapPlusDebug) console.warn('[MapPlus] framing error', error);
        }
    }

    /**
     * Lightweight player-only update – every 300ms tick.
     * Pans the map smoothly using pixel-space drift check (zoom-aware).
     */
    updatePlayer(player) {
        if (!this.map || !player || typeof player.x !== 'number') return;
        this.setPlayer(player.x, player.y, player.heading);

        if (window.MapPlusDebug && this._debugState) this._debugState.lastPlayerAt = Date.now();

        // Don't pan while a fitBounds animation is running – they would conflict
        if (!this._overviewDone || this._isFraming) return;

        try {
            // Pixel-space drift: zoom-aware, uses actual rendered container size
            const playerPoint = this.map.latLngToContainerPoint([player.y, player.x]);
            const size = this.map.getSize();

            // Safe zone: central 60% of the map panel
            const marginX = size.x * 0.20;
            const marginY = size.y * 0.20;
            const outsideSafeZone =
                playerPoint.x < marginX || playerPoint.x > (size.x - marginX) ||
                playerPoint.y < marginY || playerPoint.y > (size.y - marginY);

            if (outsideSafeZone) {
                this.map.panTo([player.y, player.x], { animate: true, duration: 0.4, easeLinearity: 0.5 });
            }
        } catch (e) {
            if (window.MapPlusDebug) console.warn('[MapPlus] pan error', e);
        }
    }

    addMarker(id, x, y, type = 'destination') {
        if (type === 'destination') { this.setDestination(x, y); return; }
        if (this.markers[id]) this.map.removeLayer(this.markers[id]);
        const iconHtml = `<div style="background:#fff;width:12px;height:12px;border-radius:50%;border:2px solid #101114;box-shadow:0 1px 4px rgba(0,0,0,0.8);"></div>`;
        const icon = L.divIcon({ html: iconHtml, className: 'mapplus-marker', iconSize: [12, 12], iconAnchor: [6, 6] });
        this.markers[id] = L.marker([y, x], { icon }).addTo(this.map);
    }

    clear() {
        if (this.routeOutline) { this.map.removeLayer(this.routeOutline); this.routeOutline = null; }
        if (this.routeLine)    { this.map.removeLayer(this.routeLine);    this.routeLine    = null; }
        Object.values(this.markers).forEach(m => this.map.removeLayer(m));
        this.markers = {};
        this._overviewDone = false;
        this._isFraming = false;
        this._lastFramedSpan = null;
    }

    destroy() {
        for (const id of this._layoutTimers) clearTimeout(id);
        this._layoutTimers = [];
        if (this._resizeObserver) this._resizeObserver.disconnect();
        this.clear();
        if (this.map) { this.map.remove(); this.map = null; }
    }
}

window.MapPlusRenderer = MapPlusRenderer;
