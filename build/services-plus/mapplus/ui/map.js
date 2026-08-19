class MapPlusRenderer {
    constructor(container, options = {}) {
        this.container = container;
        this.style = options.style || 'styleAtlas';
        
        // Calibrated GTA V CRS transformation with exact road alignment
        this.GtaCRS = Object.assign({}, L.CRS.Simple, {
            projection: L.Projection.LonLat,
            scale: (zoom) => Math.pow(2, zoom),
            zoom: (sc) => Math.log(sc) / Math.LN2,
            distance: (pos1, pos2) => Math.hypot(pos2.lng - pos1.lng, pos2.lat - pos1.lat),
            transformation: new L.Transformation(0.02075, 118.65, -0.0205, 173.0),
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
            attributionControl: false
        });

        const ext = this.style === 'styleGrid' ? 'png' : 'jpg';

        // Seamless tile layer subclass that forces 258x258 dimensions and -1px margin
        const SeamlessTileLayer = L.TileLayer.extend({
            createTile: function(coords, done) {
                const tile = L.TileLayer.prototype.createTile.call(this, coords, done);
                tile.style.width = '258px';
                tile.style.height = '258px';
                tile.style.margin = '-1px';
                return tile;
            }
        });

        this.tileLayer = new SeamlessTileLayer(`https://raw.githubusercontent.com/Trusted-Studios/mapStyles/main/${this.style}/{z}/{x}/{y}.${ext}`, {
            minZoom: 0,
            maxZoom: 5,
            noWrap: true,
            keepBuffer: 6
        }).addTo(this.map);

        this.routeLine = null;
        this.markers = {};
        this._lastFramedCenter = null;
        this._lastFramedSpan = null;

        this.setupObservers();
        this.refreshLayout();
    }

    refreshLayout() {
        if (!this.map || typeof this.map.invalidateSize !== 'function') return;
        const invalidate = () => this.map?.invalidateSize(false);
        invalidate();
        setTimeout(invalidate, 60);
        setTimeout(invalidate, 150);
        setTimeout(invalidate, 300);
        setTimeout(invalidate, 600);
    }

    setupObservers() {
        if (typeof ResizeObserver !== 'undefined' && this.container) {
            this._resizeObserver = new ResizeObserver(() => {
                this.refreshLayout();
            });
            this._resizeObserver.observe(this.container);
        }
    }

    setCenter(x, y, zoom = 3) {
        if (!this.map) return;
        this.map.setView([y, x], zoom);
        this.refreshLayout();
    }

    setPlayer(x, y, heading) {
        if (!this.map || typeof x !== 'number' || typeof y !== 'number') return;
        if (!this.markers['player']) {
            const iconHtml = `<div style="background:#fff;width:12px;height:12px;border-radius:50%;border:2px solid #a742ff;box-shadow:0 0 8px rgba(167,66,255,0.9);"></div>`;
            const icon = L.divIcon({ html: iconHtml, className: 'mapplus-player-marker', iconSize: [12, 12], iconAnchor: [6, 6] });
            this.markers['player'] = L.marker([y, x], { icon, zIndexOffset: 1000 }).addTo(this.map);
        } else {
            this.markers['player'].setLatLng([y, x]);
        }
    }

    setDestination(x, y) {
        if (!this.map || typeof x !== 'number' || typeof y !== 'number') return;
        if (!this.markers['destination']) {
            const iconHtml = `<div style="background:#f4b914;width:15px;height:15px;border-radius:50%;border:2px solid #101114;box-shadow:0 2px 8px rgba(0,0,0,0.85);"></div>`;
            const icon = L.divIcon({ html: iconHtml, className: 'mapplus-dest-marker', iconSize: [15, 15], iconAnchor: [7.5, 7.5] });
            this.markers['destination'] = L.marker([y, x], { icon, zIndexOffset: 900 }).addTo(this.map);
        } else {
            this.markers['destination'].setLatLng([y, x]);
        }
    }

    setRoute(points, destination, player) {
        if (!this.map) return;

        if (player) {
            this.setPlayer(player.x, player.y, player.heading);
        }

        if (destination) {
            this.setDestination(destination.x, destination.y);
        } else if (this.markers['destination']) {
            this.map.removeLayer(this.markers['destination']);
            delete this.markers['destination'];
        }

        if (!points || points.length === 0) {
            if (this.routeLine) {
                this.map.removeLayer(this.routeLine);
                this.routeLine = null;
            }
            // When no active route (e.g. arrived at destination), follow the player smoothly
            if (player && typeof player.x === 'number') {
                const currentCenter = this.map.getCenter();
                if (Math.hypot(player.y - currentCenter.lat, player.x - currentCenter.lng) > 30.0) {
                    this.map.panTo([player.y, player.x], { animate: true, duration: 0.5 });
                }
            }
            return;
        }

        // Points in GTA coords: [Y, X]
        const latLngs = points.map(p => [p.y, p.x]);

        // Zero-flicker live SVG polyline update
        if (!this.routeLine) {
            this.routeLine = L.polyline(latLngs, {
                color: '#a742ff',
                weight: 7,
                opacity: 0.95,
                lineCap: 'round',
                lineJoin: 'round'
            }).addTo(this.map);
        } else {
            this.routeLine.setLatLngs(latLngs);
        }

        // Buttery smooth dynamic auto-zoom and framing as you drive
        try {
            const bounds = L.latLngBounds(latLngs);
            if (player && typeof player.x === 'number') bounds.extend([player.y, player.x]);
            if (destination && typeof destination.x === 'number') bounds.extend([destination.y, destination.x]);

            if (bounds.isValid()) {
                const center = bounds.getCenter();
                const span = Math.hypot(bounds.getNorth() - bounds.getSouth(), bounds.getEast() - bounds.getWest());

                // Refit smoothly when moving or when zoom scale changes
                const shouldRefit = !this._lastFramedCenter 
                    || Math.hypot(center.lat - this._lastFramedCenter.lat, center.lng - this._lastFramedCenter.lng) > 25.0
                    || !this._lastFramedSpan
                    || Math.abs(span - this._lastFramedSpan) / this._lastFramedSpan > 0.10;

                if (shouldRefit) {
                    this._lastFramedCenter = center;
                    this._lastFramedSpan = span;
                    this.map.flyToBounds(bounds, {
                        paddingTopLeft: [75, 50],     // 75px clearance from left header, 50px from top
                        paddingBottomRight: [35, 85], // 35px from right, 85px clearance above buttons
                        minZoom: 1.5,
                        maxZoom: 4,
                        duration: 0.6,
                        easeLinearity: 0.3
                    });
                }
            }
        } catch (e) {}
    }

    addMarker(id, x, y, type = 'destination') {
        if (!this.map) return;
        if (type === 'destination') {
            this.setDestination(x, y);
            return;
        }
        if (this.markers[id]) {
            this.map.removeLayer(this.markers[id]);
        }
        const iconColor = type === 'destination' ? '#f4b914' : '#ffffff';
        const iconHtml = `<div style="background-color: ${iconColor}; width: 15px; height: 15px; border-radius: 50%; border: 2px solid #101114; box-shadow: 0 1px 4px rgba(0,0,0,0.8);"></div>`;
        const icon = L.divIcon({ html: iconHtml, className: 'mapplus-marker', iconSize: [15, 15], iconAnchor: [7.5, 7.5] });
        this.markers[id] = L.marker([y, x], { icon }).addTo(this.map);
    }

    clear() {
        if (this.routeLine) {
            this.map.removeLayer(this.routeLine);
            this.routeLine = null;
        }
        Object.values(this.markers).forEach(m => this.map.removeLayer(m));
        this.markers = {};
        this._lastFramedCenter = null;
        this._lastFramedSpan = null;
    }

    destroy() {
        if (this._resizeObserver) {
            this._resizeObserver.disconnect();
        }
        this.clear();
        if (this.map) {
            this.map.remove();
            this.map = null;
        }
    }
}
window.MapPlusRenderer = MapPlusRenderer;
