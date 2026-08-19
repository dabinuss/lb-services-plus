// =============================================================================
// MapPlus – GTA V Navigation Renderer (v55)
// Endpoint-Fit Navigation Camera: Player and Destination are ALWAYS fully visible
// with asymmetric UI safe-insets, representative route extrema, and zoom safety margin.
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
        this.cameraPadding = Object.assign({
            top: 48,
            right: 18,
            bottom: 54,
            left: 18,
        }, options.cameraPadding);

        this._layoutTimers = [];
        this._lastPlayer = null;
        this._lastDestination = null;
        this._routeLatLngs = [];
        this._initialFramed = false;

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
            minZoom: 0,
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
                this._frameCurrentNavigation({ animate: false });
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
     * Builds unified camera bounds containing Player + Destination + Sampled Route Extrema.
     */
    _buildNavigationBounds() {
        const bounds = L.latLngBounds([]);

        if (this._lastPlayer && typeof this._lastPlayer.x === 'number') {
            bounds.extend([this._lastPlayer.y, this._lastPlayer.x]);
        }

        if (this._lastDestination && typeof this._lastDestination.x === 'number') {
            bounds.extend([this._lastDestination.y, this._lastDestination.x]);
        }

        const pts = this._routeLatLngs;
        if (pts && pts.length > 0) {
            const ROUTE_BOUND_SAMPLES = 32;
            const stride = Math.max(1, Math.floor(pts.length / ROUTE_BOUND_SAMPLES));
            for (let i = 0; i < pts.length; i += stride) {
                bounds.extend(pts[i]);
            }
            bounds.extend(pts[pts.length - 1]);
        }

        return bounds.isValid() ? bounds : null;
    }

    /**
     * Checks if both player and destination are comfortably visible within safe UI insets.
     */
    _isNavigationVisible() {
        if (!this.map) return true;
        const size = this.map.getSize();
        if (!size || size.x === 0 || size.y === 0) return true;

        const pad = this.cameraPadding;
        const isPointVisible = (lat, lng) => {
            const p = this.map.latLngToContainerPoint([lat, lng]);
            return p.x >= pad.left && p.x <= (size.x - pad.right)
                && p.y >= pad.top && p.y <= (size.y - pad.bottom);
        };

        if (this._lastPlayer && !isPointVisible(this._lastPlayer.y, this._lastPlayer.x)) {
            return false;
        }
        if (this._lastDestination && !isPointVisible(this._lastDestination.y, this._lastDestination.x)) {
            return false;
        }
        return true;
    }

    /**
     * Re-frames the camera to guarantee full visibility of both endpoints with safety margin.
     */
    _frameCurrentNavigation(opts = {}) {
        const bounds = this._buildNavigationBounds();
        if (!this.map || !bounds) return;

        this.map.stop();
        const pad = this.cameraPadding;
        const totalPad = L.point(pad.left + pad.right, pad.top + pad.bottom);

        // Determine zoom so entire geometry fits within the padded area
        let targetZoom = this.map.getBoundsZoom(bounds, false, totalPad);
        // Safety margin of 0.25 zoom levels so markers never sit right against the border
        targetZoom = Math.max(0, Math.min(4.25, targetZoom - 0.25));

        const size = this.map.getSize();
        const width = (size && size.x > 50) ? size.x : (this.container?.offsetWidth || 320);
        const height = (size && size.y > 50) ? size.y : (this.container?.offsetHeight || 224);

        // Center of the open usable area on screen
        const usableCenterX = pad.left + (width - pad.left - pad.right) / 2;
        const usableCenterY = pad.top + (height - pad.top - pad.bottom) / 2;

        const screenCenterX = width / 2;
        const screenCenterY = height / 2;

        const shiftX = usableCenterX - screenCenterX;
        const shiftY = usableCenterY - screenCenterY;

        const routeCenter = bounds.getCenter();
        const routeCenterProj = this.map.project(routeCenter, targetZoom);

        const targetCenterPixel = L.point(routeCenterProj.x - shiftX, routeCenterProj.y - shiftY);
        const targetCenter = this.map.unproject(targetCenterPixel, targetZoom);

        this.map.setView(targetCenter, targetZoom, {
            animate: opts.animate !== false,
            duration: opts.duration || 0.5,
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
                    border-left: 5px solid transparent;
                    border-right: 5px solid transparent;
                    border-bottom: 12px solid #ffffff;
                    filter: drop-shadow(0 0 4px rgba(167,66,255,0.9));
                    transform: rotate(${rotateDeg}deg);
                    transform-origin: 50% 65%;
                "></div>`;
            const icon = L.divIcon({
                html: iconHtml,
                className: 'mapplus-player-marker',
                iconSize: [10, 12],
                iconAnchor: [5, 8],
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
                display: flex; align-items: center; justify-content: center;
            "><div style="width: 4px; height: 4px; border-radius: 50%; background: #101114;"></div></div>`;
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
     * Main update – sets the route and frames both endpoints.
     * reason: 'new' | 'reroute' | 'trim' | 'clear'
     */
    setRoute(points, destination, player, reason = 'new') {
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
            this._routeLatLngs = [];
            this._initialFramed = false;
            return;
        }

        const latLngs = points.map(p => [p.y, p.x]);
        this._routeLatLngs = latLngs;

        const polyOpts = { smoothFactor: 0, noClip: true, interactive: false, pane: 'mapplusRoute' };

        if (!this.routeOutline) {
            this.routeOutline = L.polyline(latLngs, {
                color: '#2a0f40', weight: 8, opacity: 0.85,
                lineCap: 'round', lineJoin: 'round', ...polyOpts,
            }).addTo(this.map);
        } else {
            this.routeOutline.setLatLngs(latLngs);
        }

        if (!this.routeLine) {
            this.routeLine = L.polyline(latLngs, {
                color: '#a742ff', weight: 5.5, opacity: 1.0,
                lineCap: 'round', lineJoin: 'round', ...polyOpts,
            }).addTo(this.map);
        } else {
            this.routeLine.setLatLngs(latLngs);
        }

        // Re-frame on new route, reroute, initial mount, or if endpoints drifted outside safe insets
        if (reason === 'new' || reason === 'reroute' || !this._initialFramed) {
            this._initialFramed = true;
            this._frameCurrentNavigation({ animate: true });
        } else if (reason === 'trim') {
            if (!this._isNavigationVisible()) {
                this._frameCurrentNavigation({ animate: true });
            }
        }
    }

    /**
     * Lightweight player-only update – every 300ms tick.
     * Ensures player and destination remain clearly within the visible safe insets.
     */
    updatePlayer(player) {
        if (!this.map || !player || typeof player.x !== 'number') return;
        this.setPlayer(player.x, player.y, player.heading);

        if (window.MapPlusDebug && this._debugState) this._debugState.lastPlayerAt = Date.now();

        // Never blind panTo that could hide the destination; reframe endpoints if visibility is violated
        if (!this._isNavigationVisible()) {
            this._frameCurrentNavigation({ animate: true });
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
        this._routeLatLngs = [];
        this._initialFramed = false;
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
