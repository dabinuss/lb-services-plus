// =============================================================================
// MapPlus – GTA V Navigation Renderer (v51)
// Direct and unconditional upper-right quadrant projection.
// =============================================================================

/**
 * Single authoritative GTA V → Leaflet coordinate transform.
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
        this._lastPlayer = null;
        this._lastDestination = null;
        this._currentBounds = null;

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
            fadeAnimation: false,
            markerZoomAnimation: true,
            center: [-1000, 150],
            zoom: 3,
            zoomControl: false,
            attributionControl: false,
            dragging: false,
            scrollWheelZoom: false,
            doubleClickZoom: false,
            touchZoom: false,
            keyboard: false,
            boxZoom: false,
            maxBounds: [[-4400, -4000], [8000, 8000]],
            maxBoundsViscosity: 0.0,
        });

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

        this.tileLayer.on('tileerror', (event) => {
            if (window.MapPlusDebug) {
                console.warn('[MapPlus] tile failed:', event.tile?.src);
                if (this._debugState) this._debugState.tileErrors++;
            }
        });

        this.routeOutline = null;
        this.routeLine = null;
        this.markers = {};

        if (window.MapPlusDebug) {
            this._debugState = { routePoints: 0, lastRouteAt: 0, lastPlayerAt: 0, tileErrors: 0 };
        }

        this._setupObservers();
        this._refreshLayout();
    }

    _refreshLayout() {
        for (const id of this._layoutTimers) clearTimeout(id);
        this._layoutTimers = [];
        const invalidate = () => {
            if (this.map) {
                this.map.invalidateSize(false);
                if (this._currentBounds) {
                    this._frameRouteUpperRight(this._currentBounds, { animate: false });
                }
            }
        };
        invalidate();
        this._layoutTimers.push(setTimeout(invalidate, 50));
        this._layoutTimers.push(setTimeout(invalidate, 150));
        this._layoutTimers.push(setTimeout(invalidate, 350));
    }

    _setupObservers() {
        if (typeof ResizeObserver !== 'undefined' && this.container) {
            this._resizeObserver = new ResizeObserver(() => this._refreshLayout());
            this._resizeObserver.observe(this.container);
        }
    }

    /**
     * Mathematically projects the route bounding box (Player + Route + Destination)
     * strictly into the free upper-right quadrant of the card (clear of left header and bottom buttons).
     */
    _frameRouteUpperRight(bounds, opts = {}) {
        if (!this.map || !bounds || !bounds.isValid()) return;
        this.map.stop();

        const size = this.map.getSize();
        const width = (size && size.x > 50) ? size.x : (this.container?.offsetWidth || 320);
        const height = (size && size.y > 50) ? size.y : (this.container?.offsetHeight || 224);

        // The free upper-right window in the PeekPlus card is:
        // Left offset: 145px (completely clears the Taxi Header on the left)
        // Bottom offset: 95px (completely clears the Action Buttons at the bottom)
        const targetWidth = Math.max(90, width - 160);
        const targetHeight = Math.max(75, height - 120);

        // Compute zoom level so the full route (player to destination) fits inside the window
        const padX = width - targetWidth;
        const padY = height - targetHeight;
        let zoom = this.map.getBoundsZoom(bounds, false, [padX, padY]);
        zoom = Math.max(1.0, Math.min(4.25, zoom));

        // Center of the target window in screen pixel space
        const targetScreenX = 145 + (targetWidth / 2);  // ~225px (comfortably on the right)
        const targetScreenY = 25 + (targetHeight / 2);   // ~77px (comfortably at top)

        // Screen center
        const screenCenterX = width / 2;
        const screenCenterY = height / 2;

        // Pixel offset from screen center to target window center
        const dx = targetScreenX - screenCenterX;
        const dy = targetScreenY - screenCenterY;

        // The geographic center of the route
        const routeCenter = bounds.getCenter();
        const projectedRoute = this.map.project(routeCenter, zoom);

        // Shift camera center so the route appears at targetScreenX, targetScreenY
        const targetMapProjected = L.point(projectedRoute.x - dx, projectedRoute.y - dy);
        const targetMapCenter = this.map.unproject(targetMapProjected, zoom);

        this.map.setView(targetMapCenter, zoom, {
            animate: opts.animate !== false,
            duration: opts.duration || 0.4,
            easeLinearity: 0.3,
        });
    }

    setCenter(x, y, zoom = 3) {
        if (!this.map) return;
        this.map.setView([y, x], zoom, { animate: false });
        this._refreshLayout();
    }

    setPlayer(x, y, heading) {
        if (!this.map || typeof x !== 'number' || typeof y !== 'number') return;
        this._lastPlayer = { x, y, heading };

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
        this._lastDestination = { x, y };

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
     * Main update – sets the route polyline and projects BOTH player and destination
     * into the upper-right quadrant.
     */
    setRoute(points, destination, player) {
        if (!this.map) return;

        const effectivePlayer = player || this._lastPlayer;

        if (destination) {
            this.setDestination(destination.x, destination.y);
        } else if (this.markers['destination']) {
            this.map.removeLayer(this.markers['destination']);
            delete this.markers['destination'];
            this._lastDestination = null;
        }

        if (effectivePlayer) {
            this.setPlayer(effectivePlayer.x, effectivePlayer.y, effectivePlayer.heading);
        }

        if (window.MapPlusDebug && this._debugState) {
            this._debugState.routePoints = points ? points.length : 0;
            this._debugState.lastRouteAt = Date.now();
        }

        if (!points || points.length === 0) {
            if (this.routeOutline) { this.map.removeLayer(this.routeOutline); this.routeOutline = null; }
            if (this.routeLine)    { this.map.removeLayer(this.routeLine);    this.routeLine    = null; }
            this._currentBounds = null;
            return;
        }

        const latLngs = points.map(p => [p.y, p.x]);
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

        // --- Framing: ALWAYS project Player, Destination, and Route in upper-right ---
        try {
            const bounds = L.latLngBounds(latLngs);

            if (effectivePlayer && typeof effectivePlayer.x === 'number') {
                bounds.extend([effectivePlayer.y, effectivePlayer.x]);
            }
            if (destination && typeof destination.x === 'number') {
                bounds.extend([destination.y, destination.x]);
            }

            if (!bounds.isValid()) return;
            this._currentBounds = bounds;

            // Frame unconditionally to ensure the view updates immediately
            this._frameRouteUpperRight(bounds);
        } catch (error) {
            if (window.MapPlusDebug) console.warn('[MapPlus] framing error', error);
        }
    }

    /**
     * Lightweight player-only update – every 300ms tick.
     * Ensures player and destination remain clearly within the visible upper-right quadrant.
     */
    updatePlayer(player) {
        if (!this.map || !player || typeof player.x !== 'number') return;
        this.setPlayer(player.x, player.y, player.heading);

        if (window.MapPlusDebug && this._debugState) this._debugState.lastPlayerAt = Date.now();

        try {
            const size = this.map.getSize();
            if (!size || size.x === 0 || size.y === 0) return;

            const playerPoint = this.map.latLngToContainerPoint([player.y, player.x]);

            if (this._lastDestination && typeof this._lastDestination.x === 'number') {
                const destPoint = this.map.latLngToContainerPoint([this._lastDestination.y, this._lastDestination.x]);

                const isOutOfSafeZone = (p) => {
                    return p.x < 140 || p.x > (size.x - 15) || p.y < 20 || p.y > (size.y - 90);
                };

                if (isOutOfSafeZone(playerPoint) || isOutOfSafeZone(destPoint)) {
                    const bounds = L.latLngBounds([
                        [player.y, player.x],
                        [this._lastDestination.y, this._lastDestination.x]
                    ]);
                    if (this.routeLine) {
                        bounds.extend(this.routeLine.getBounds());
                    }
                    this._currentBounds = bounds;
                    this._frameRouteUpperRight(bounds);
                }
            } else {
                const marginX = size.x * 0.20;
                const marginY = size.y * 0.20;
                const outsideSafeZone =
                    playerPoint.x < marginX || playerPoint.x > (size.x - marginX) ||
                    playerPoint.y < marginY || playerPoint.y > (size.y - marginY);

                if (outsideSafeZone) {
                    this.map.panTo([player.y, player.x], { animate: true, duration: 0.4, easeLinearity: 0.5 });
                }
            }
        } catch (e) {
            if (window.MapPlusDebug) console.warn('[MapPlus] pan/frame error', e);
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
        this._lastDestination = null;
        this._currentBounds = null;
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
