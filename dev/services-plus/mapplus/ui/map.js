class MapPlusRenderer {
    constructor(container, options = {}) {
        this.container = container;
        this.style = options.style || 'styleAtlas';
        
        // Fine-tuned GTA V CRS with native Transformation matrix
        this.GtaCRS = Object.assign({}, L.CRS.Simple, {
            projection: L.Projection.LonLat,
            scale: (zoom) => Math.pow(2, zoom),
            zoom: (sc) => Math.log(sc) / Math.LN2,
            distance: (pos1, pos2) => Math.hypot(pos2.lng - pos1.lng, pos2.lat - pos1.lat),
            transformation: new L.Transformation(0.02072, 117.15, -0.0205, 172.5),
            infinite: true,
        });

        this.map = L.map(container, {
            crs: this.GtaCRS,
            minZoom: 2,
            maxZoom: 5,
            zoomSnap: 1,
            zoomDelta: 1,
            center: [-1000, 150],
            zoom: 3,
            zoomControl: false,
            attributionControl: false
        });

        const ext = this.style === 'styleGrid' ? 'png' : 'jpg';
        this.tileLayer = L.tileLayer(`https://raw.githubusercontent.com/Trusted-Studios/mapStyles/main/${this.style}/{z}/{x}/{y}.${ext}`, {
            minZoom: 0,
            maxZoom: 5,
            noWrap: true
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
        this.map.setView([y, x], Math.round(zoom));
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
        }

        if (!points || points.length === 0) {
            if (this.routeLine) {
                this.map.removeLayer(this.routeLine);
                this.routeLine = null;
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

        // Dynamic auto-zoom and framing as the player drives closer or further away
        try {
            const bounds = L.latLngBounds(latLngs);
            if (player && typeof player.x === 'number') bounds.extend([player.y, player.x]);
            if (destination && typeof destination.x === 'number') bounds.extend([destination.y, destination.x]);

            if (bounds.isValid()) {
                const center = bounds.getCenter();
                const span = Math.hypot(bounds.getNorth() - bounds.getSouth(), bounds.getEast() - bounds.getWest());

                // Refit when moving noticeably (20m) or when distance span changes by 10%
                const shouldRefit = !this._lastFramedCenter 
                    || Math.hypot(center.lat - this._lastFramedCenter.lat, center.lng - this._lastFramedCenter.lng) > 20.0
                    || !this._lastFramedSpan
                    || Math.abs(span - this._lastFramedSpan) / this._lastFramedSpan > 0.10;

                if (shouldRefit) {
                    this._lastFramedCenter = center;
                    this._lastFramedSpan = span;
                    this.map.fitBounds(bounds, {
                        paddingTopLeft: [55, 35],     // Header / distance clearance
                        paddingBottomRight: [25, 75], // 75px bottom clearance above buttons
                        minZoom: 2,
                        maxZoom: 4,
                        animate: false
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
