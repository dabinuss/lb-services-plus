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
        });

        const ext = this.style === 'styleGrid' ? 'png' : 'jpg';
        this.tileLayer = L.tileLayer(
            `https://raw.githubusercontent.com/Trusted-Studios/mapStyles/main/${this.style}/{z}/{x}/{y}.${ext}`,
            {
                minZoom: 0,
                maxZoom: 5,
                noWrap: true,
                keepBuffer: 2,  // Small buffer sufficient for a fixed-size notification panel
            }
        ).addTo(this.map);

        this.routeOutline = null;
        this.routeLine = null;
        this.markers = {};
        this._lastFramedSpan = null;

        this._setupObservers();
        this._refreshLayout();
    }

    _refreshLayout() {
        // Cancel any pending layout timers before scheduling new ones
        for (const id of this._layoutTimers) clearTimeout(id);
        this._layoutTimers = [];

        const invalidate = () => {
            if (this.map) this.map.invalidateSize(false);
        };
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
            // Arrow shape pointing up; inner div is rotated for heading
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
                background: #f4b914;
                border: 2px solid #101114;
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
     * Main update entry point for full route+player state.
     * Called only when route changes (not on every player tick).
     */
    setRoute(points, destination, player) {
        if (!this.map) return;

        if (destination) {
            this.setDestination(destination.x, destination.y);
        } else if (this.markers['destination']) {
            this.map.removeLayer(this.markers['destination']);
            delete this.markers['destination'];
        }

        if (player) {
            this.setPlayer(player.x, player.y, player.heading);
        }

        if (!points || points.length === 0) {
            if (this.routeOutline) { this.map.removeLayer(this.routeOutline); this.routeOutline = null; }
            if (this.routeLine) { this.map.removeLayer(this.routeLine); this.routeLine = null; }
            this._overviewDone = false;
            this._lastFramedSpan = null;
            return;
        }

        const latLngs = points.map(p => [p.y, p.x]);

        // Outline layer beneath for contrast (dark halo)
        if (!this.routeOutline) {
            this.routeOutline = L.polyline(latLngs, {
                color: '#2a0f40',
                weight: 9,
                opacity: 0.85,
                lineCap: 'round',
                lineJoin: 'round',
                interactive: false,
            }).addTo(this.map);
        } else {
            this.routeOutline.setLatLngs(latLngs);
        }

        // Foreground lila line
        if (!this.routeLine) {
            this.routeLine = L.polyline(latLngs, {
                color: '#a742ff',
                weight: 6,
                opacity: 1.0,
                lineCap: 'round',
                lineJoin: 'round',
                interactive: false,
            }).addTo(this.map);
        } else {
            this.routeLine.setLatLngs(latLngs);
        }

        // --- Framing logic ---
        try {
            const bounds = L.latLngBounds(latLngs);
            if (player && typeof player.x === 'number') bounds.extend([player.y, player.x]);
            if (destination && typeof destination.x === 'number') bounds.extend([destination.y, destination.x]);
            if (!bounds.isValid()) return;

            if (!this._overviewDone) {
                // OVERVIEW MODE: First render – fit entire route so nothing is cropped
                this._overviewDone = true;
                this._lastFramedSpan = Math.hypot(
                    bounds.getNorth() - bounds.getSouth(),
                    bounds.getEast() - bounds.getWest()
                );
                this.map.fitBounds(bounds, {
                    paddingTopLeft: [75, 50],
                    paddingBottomRight: [35, 90],
                    maxZoom: 4,
                    animate: true,
                    duration: 0.5,
                });
            } else {
                // NAVIGATION MODE: Only re-zoom when span changes significantly (>15%)
                const span = Math.hypot(
                    bounds.getNorth() - bounds.getSouth(),
                    bounds.getEast() - bounds.getWest()
                );
                const spanChange = this._lastFramedSpan
                    ? Math.abs(span - this._lastFramedSpan) / this._lastFramedSpan
                    : 1;

                if (spanChange > 0.15) {
                    this._lastFramedSpan = span;
                    this.map.fitBounds(bounds, {
                        paddingTopLeft: [75, 50],
                        paddingBottomRight: [35, 90],
                        maxZoom: 4,
                        animate: true,
                        duration: 0.5,
                    });
                }
                // Player position update is handled separately by updatePlayer()
            }
        } catch (error) {
            if (window.MapPlusDebug) console.warn('[MapPlus] framing error', error);
        }
    }

    /**
     * Lightweight player-only update (no route redraw, no framing).
     * Called on every 300ms tick from Lua.
     */
    updatePlayer(player) {
        if (!this.map || !player || typeof player.x !== 'number') return;
        this.setPlayer(player.x, player.y, player.heading);

        // In navigation mode (after first overview fit), pan to keep player in view
        if (!this._overviewDone) return;
        try {
            const center = this.map.getCenter();
            const drift = Math.hypot(player.y - center.lat, player.x - center.lng);
            if (drift > 40) {
                this.map.panTo([player.y, player.x], { animate: true, duration: 0.4, easeLinearity: 0.5 });
            }
        } catch (e) {
            if (window.MapPlusDebug) console.warn('[MapPlus] pan error', e);
        }
    }

    addMarker(id, x, y, type = 'destination') {
        if (type === 'destination') {
            this.setDestination(x, y);
            return;
        }
        if (this.markers[id]) this.map.removeLayer(this.markers[id]);
        const iconHtml = `<div style="background:#fff;width:12px;height:12px;border-radius:50%;border:2px solid #101114;box-shadow:0 1px 4px rgba(0,0,0,0.8);"></div>`;
        const icon = L.divIcon({ html: iconHtml, className: 'mapplus-marker', iconSize: [12, 12], iconAnchor: [6, 6] });
        this.markers[id] = L.marker([y, x], { icon }).addTo(this.map);
    }

    clear() {
        if (this.routeOutline) { this.map.removeLayer(this.routeOutline); this.routeOutline = null; }
        if (this.routeLine) { this.map.removeLayer(this.routeLine); this.routeLine = null; }
        Object.values(this.markers).forEach(m => this.map.removeLayer(m));
        this.markers = {};
        this._overviewDone = false;
        this._lastFramedSpan = null;
    }

    destroy() {
        for (const id of this._layoutTimers) clearTimeout(id);
        this._layoutTimers = [];
        if (this._resizeObserver) this._resizeObserver.disconnect();
        this.clear();
        if (this.map) {
            this.map.remove();
            this.map = null;
        }
    }
}

window.MapPlusRenderer = MapPlusRenderer;
