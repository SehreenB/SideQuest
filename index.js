/**
 * index.js
 * Express server for SideQuest.
 *
 * Routes
 * ──────
 * GET  /health         – health check
 * GET  /config         – returns Google Maps API key for frontend
 * GET  /test-maps      – basic map test page
 * GET  /demo           – full SideQuest demo with time, modes, routing
 * POST /navigate       – returns waypoints via Gemini (count based on time)
 * POST /vault/sign     – returns a presigned Supabase upload URL
 * POST /rewards/mint   – mints a cNFT badge on Solana Devnet
 */

"use strict";
require("dotenv").config();

const express = require("express");
const { findWaypoints } = require("./navigator");
const { createPresignedUploadUrl } = require("./vault");
const { mintBadge } = require("./rewards");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// ── Health check ─────────────────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

// ── Config ────────────────────────────────────────────────────────────────────
app.get("/config", (_req, res) => {
  res.json({ googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY });
});

// ── Test Maps ─────────────────────────────────────────────────────────────────
app.get("/test-maps", (_req, res) => {
  res.send(`<!DOCTYPE html><html><head><title>Maps Test</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>body{margin:0}#map{height:100vh;width:100%}#status{position:fixed;top:10px;left:50%;transform:translateX(-50%);background:#000;color:lime;padding:10px 20px;border-radius:20px;font-size:14px;z-index:999;font-family:sans-serif}</style>
  </head><body>
  <div id="status">📍 Getting location...</div><div id="map"></div>
  <script>function initMap(){navigator.geolocation.getCurrentPosition(p=>{const lat=p.coords.latitude,lng=p.coords.longitude;document.getElementById('status').innerText='✅ '+lat.toFixed(4)+', '+lng.toFixed(4);const map=new google.maps.Map(document.getElementById('map'),{center:{lat,lng},zoom:15});new google.maps.Marker({position:{lat,lng},map})},e=>{document.getElementById('status').innerText='❌ '+e.message})}</script>
  <script src="https://maps.googleapis.com/maps/api/js?key=${process.env.GOOGLE_MAPS_API_KEY}&callback=initMap" async defer></script>
  </body></html>`);
});

// ── Full Demo Page ────────────────────────────────────────────────────────────
app.get("/demo", (_req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <title>SideQuest</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=DM+Sans:wght@300;400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --green: #39ff14;
      --green-dim: #1a7a00;
      --bg: #080808;
      --surface: #111111;
      --surface2: #1a1a1a;
      --border: #2a2a2a;
      --text: #f0f0f0;
      --muted: #666;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }

    body {
      font-family: 'DM Sans', sans-serif;
      background: var(--bg);
      color: var(--text);
      height: 100dvh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    /* ── MAP ── */
    #map {
      flex: 1;
      width: 100%;
      min-height: 0;
    }

    /* ── HEADER OVERLAY ── */
    #header {
      position: absolute;
      top: 0; left: 0; right: 0;
      padding: 16px 16px 0;
      pointer-events: none;
      z-index: 10;
    }

    #logo {
      font-family: 'Syne', sans-serif;
      font-weight: 800;
      font-size: 22px;
      color: var(--green);
      letter-spacing: -0.5px;
      text-shadow: 0 0 20px rgba(57,255,20,0.4);
      background: rgba(8,8,8,0.85);
      display: inline-block;
      padding: 6px 14px;
      border-radius: 20px;
      border: 1px solid rgba(57,255,20,0.2);
      backdrop-filter: blur(10px);
    }

    /* ── STATUS PILL ── */
    #status-pill {
      position: absolute;
      top: 60px; left: 50%;
      transform: translateX(-50%);
      background: rgba(8,8,8,0.9);
      border: 1px solid var(--border);
      color: var(--muted);
      padding: 8px 16px;
      border-radius: 20px;
      font-size: 12px;
      z-index: 10;
      backdrop-filter: blur(10px);
      white-space: nowrap;
      transition: all 0.3s ease;
      max-width: 90vw;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    #status-pill.active { color: var(--green); border-color: var(--green-dim); }
    #status-pill.error { color: #ff4444; border-color: #440000; }

    /* ── BOTTOM PANEL ── */
    #panel {
      background: var(--surface);
      border-top: 1px solid var(--border);
      padding: 0;
      display: flex;
      flex-direction: column;
      max-height: 55dvh;
      position: relative;
      z-index: 20;
    }

    /* drag handle */
    #panel::before {
      content: '';
      display: block;
      width: 36px;
      height: 4px;
      background: var(--border);
      border-radius: 2px;
      margin: 10px auto 0;
    }

    #controls {
      padding: 12px 16px 14px;
      border-bottom: 1px solid var(--border);
    }

    /* ── MODE GRID ── */
    #mode-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 6px;
      margin-bottom: 12px;
    }

    .mode-btn {
      background: var(--surface2);
      border: 1px solid var(--border);
      color: var(--muted);
      padding: 9px 4px 7px;
      border-radius: 10px;
      font-size: 10px;
      font-family: 'DM Sans', sans-serif;
      font-weight: 500;
      cursor: pointer;
      text-align: center;
      transition: all 0.15s;
      line-height: 1.5;
      letter-spacing: 0.2px;
    }
    .mode-btn .icon { display: block; font-size: 18px; margin-bottom: 2px; }
    .mode-btn:active { transform: scale(0.96); }
    .mode-btn.active {
      background: rgba(57,255,20,0.12);
      border-color: var(--green);
      color: var(--green);
      font-weight: 600;
    }

    /* ── BOTTOM ROW: travel + time + button ── */
    #bottom-row {
      display: flex;
      gap: 8px;
      align-items: stretch;
    }

    #travel-toggle {
      display: flex;
      gap: 4px;
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 3px;
    }

    .travel-btn {
      padding: 7px 10px;
      border-radius: 7px;
      border: none;
      background: transparent;
      color: var(--muted);
      font-size: 18px;
      cursor: pointer;
      transition: all 0.15s;
      line-height: 1;
    }
    .travel-btn.active {
      background: rgba(57,255,20,0.15);
      color: var(--green);
    }

    #time-select {
      flex: 1;
      background: var(--surface2);
      border: 1px solid var(--border);
      color: var(--text);
      border-radius: 10px;
      padding: 0 12px;
      font-size: 13px;
      font-family: 'DM Sans', sans-serif;
      cursor: pointer;
      appearance: none;
      -webkit-appearance: none;
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%3E%3Cpath d='M1 1l5 5 5-5' stroke='%23666' stroke-width='1.5' fill='none' stroke-linecap='round'/%3E%3C/svg%3E");
      background-repeat: no-repeat;
      background-position: right 12px center;
      padding-right: 32px;
    }
    #time-select:focus { outline: none; border-color: var(--green); }

    #find-btn {
      background: var(--green);
      color: #000;
      border: none;
      border-radius: 10px;
      padding: 0 18px;
      font-size: 13px;
      font-family: 'Syne', sans-serif;
      font-weight: 700;
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.15s;
      letter-spacing: 0.3px;
    }
    #find-btn:active { transform: scale(0.97); background: #2dd10f; }
    #find-btn:disabled {
      background: var(--surface2);
      color: var(--muted);
      cursor: not-allowed;
      transform: none;
    }

    /* ── WAYPOINT CARDS ── */
    #waypoints {
      overflow-y: auto;
      padding: 12px 16px 20px;
      -webkit-overflow-scrolling: touch;
      flex: 1;
    }

    .wp-card {
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 12px 14px;
      margin-bottom: 8px;
      display: flex;
      gap: 12px;
      align-items: flex-start;
      cursor: pointer;
      transition: border-color 0.15s;
    }
    .wp-card:active { border-color: var(--green); }

    .wp-num {
      width: 26px;
      height: 26px;
      min-width: 26px;
      background: var(--green);
      color: #000;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: 'Syne', sans-serif;
      font-weight: 800;
      font-size: 12px;
      margin-top: 1px;
    }

    .wp-info h3 {
      font-family: 'Syne', sans-serif;
      font-weight: 600;
      font-size: 13px;
      color: var(--text);
      margin-bottom: 3px;
    }
    .wp-info p {
      font-size: 11px;
      color: var(--muted);
      line-height: 1.5;
    }
    .wp-address {
      font-size: 10px;
      color: #444;
      margin-top: 4px;
    }

    /* ── LOADING SHIMMER ── */
    .shimmer {
      background: linear-gradient(90deg, var(--surface2) 25%, #222 50%, var(--surface2) 75%);
      background-size: 200% 100%;
      animation: shimmer 1.2s infinite;
      border-radius: 8px;
      height: 70px;
      margin-bottom: 8px;
    }
    @keyframes shimmer { 0%{background-position:200% 0} 100%{background-position:-200% 0} }

    /* scrollbar */
    #waypoints::-webkit-scrollbar { width: 3px; }
    #waypoints::-webkit-scrollbar-track { background: transparent; }
    #waypoints::-webkit-scrollbar-thumb { background: var(--border); border-radius: 2px; }
  </style>
</head>
<body>

<div id="map"></div>

<div id="header">
  <div id="logo">⚔️ SideQuest</div>
</div>

<div id="status-pill">📍 Locating you...</div>

<div id="panel">
  <div id="controls">
    <div id="mode-grid">
      <button class="mode-btn active" data-mode="Adventure Mode: murals, street art, scenic viewpoints, unexpected landmarks" onclick="selectMode(this)">
        <span class="icon">🗺️</span>Adventure
      </button>
      <button class="mode-btn" data-mode="Foodie Mode: hidden cafés, dessert spots, food markets, local restaurant favourites" onclick="selectMode(this)">
        <span class="icon">🍜</span>Foodie
      </button>
      <button class="mode-btn" data-mode="Nature Mode: parks, waterfront paths, tree-lined streets, green spaces" onclick="selectMode(this)">
        <span class="icon">🌿</span>Nature
      </button>
      <button class="mode-btn" data-mode="Culture Mode: galleries, bookstores, historic corners, live music venues" onclick="selectMode(this)">
        <span class="icon">🎨</span>Culture
      </button>
      <button class="mode-btn" data-mode="Social Mode: lively areas, patios, event spaces, popular hangout spots" onclick="selectMode(this)">
        <span class="icon">🎉</span>Social
      </button>
      <button class="mode-btn" data-mode="Mystery Mode: completely random but highly rated hidden gems, surprises" onclick="selectMode(this)">
        <span class="icon">🎲</span>Mystery
      </button>
    </div>

    <div id="bottom-row">
      <div id="travel-toggle">
        <button class="travel-btn active" data-mode="walk" title="Walk" onclick="selectTravel(this)">🚶</button>
        <button class="travel-btn" data-mode="car" title="Drive" onclick="selectTravel(this)">🚗</button>
      </div>

      <select id="time-select">
        <option value="30">⏱ 30 min</option>
        <option value="45">⏱ 45 min</option>
        <option value="60" selected>⏱ 1 hour</option>
        <option value="90">⏱ 1.5 hrs</option>
        <option value="120">⏱ 2 hours</option>
        <option value="180">⏱ 3 hours</option>
        <option value="240">⏱ 4 hours</option>
      </select>

      <button id="find-btn" onclick="findQuest()" disabled>GO</button>
    </div>
  </div>

  <div id="waypoints"></div>
</div>

<script>
  let map, directionsService, directionsRenderer;
  let userMarker, waypointMarkers = [];
  let selectedMode = 'Adventure Mode: murals, street art, scenic viewpoints, unexpected landmarks';
  let selectedTravel = 'walk';
  let userLat = null, userLng = null;

  // ── How many stops based on time + mode ────────────────────────────────────
  function calcStops(minutes, travelMode) {
    if (travelMode === 'car') {
      if (minutes <= 30)  return 2;
      if (minutes <= 60)  return 3;
      if (minutes <= 120) return 4;
      return 5;
    } else {
      if (minutes <= 30)  return 2;
      if (minutes <= 45)  return 3;
      if (minutes <= 90)  return 4;
      if (minutes <= 150) return 5;
      return 6;
    }
  }

  function setStatus(msg, type = '') {
    const el = document.getElementById('status-pill');
    el.innerText = msg;
    el.className = type;
  }

  function selectMode(btn) {
    document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    selectedMode = btn.dataset.mode;
  }

  function selectTravel(btn) {
    document.querySelectorAll('.travel-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    selectedTravel = btn.dataset.mode;
  }

  // ── Map Init ───────────────────────────────────────────────────────────────
  function initMap() {
    map = new google.maps.Map(document.getElementById('map'), {
      center: { lat: 51.5074, lng: -0.1278 },
      zoom: 14,
      disableDefaultUI: true,
      zoomControl: false,
      styles: [
        { elementType: 'geometry',            stylers: [{ color: '#0f0f0f' }] },
        { elementType: 'labels.text.stroke',  stylers: [{ color: '#0f0f0f' }] },
        { elementType: 'labels.text.fill',    stylers: [{ color: '#555' }] },
        { featureType: 'road',                elementType: 'geometry',           stylers: [{ color: '#1c1c1c' }] },
        { featureType: 'road',                elementType: 'geometry.stroke',    stylers: [{ color: '#111' }] },
        { featureType: 'road.highway',        elementType: 'geometry',           stylers: [{ color: '#222' }] },
        { featureType: 'road',                elementType: 'labels.text.fill',   stylers: [{ color: '#444' }] },
        { featureType: 'water',               elementType: 'geometry',           stylers: [{ color: '#0a1628' }] },
        { featureType: 'water',               elementType: 'labels.text.fill',   stylers: [{ color: '#1a3a5c' }] },
        { featureType: 'poi',                 elementType: 'geometry',           stylers: [{ color: '#141414' }] },
        { featureType: 'poi.park',            elementType: 'geometry',           stylers: [{ color: '#0d1f0d' }] },
        { featureType: 'poi.park',            elementType: 'labels.text.fill',   stylers: [{ color: '#1a4d1a' }] },
        { featureType: 'transit',             elementType: 'geometry',           stylers: [{ color: '#181818' }] },
        { featureType: 'administrative',      elementType: 'geometry.stroke',    stylers: [{ color: '#222' }] },
        { featureType: 'administrative.land_parcel', elementType: 'labels.text.fill', stylers: [{ color: '#333' }] },
      ]
    });

    directionsService  = new google.maps.DirectionsService();
    directionsRenderer = new google.maps.DirectionsRenderer({
      map,
      suppressMarkers: true,
      polylineOptions: {
        strokeColor:   '#39ff14',
        strokeWeight:  3,
        strokeOpacity: 0.8,
      }
    });

    // Get user location
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        userLat = pos.coords.latitude;
        userLng = pos.coords.longitude;
        map.setCenter({ lat: userLat, lng: userLng });

        userMarker = new google.maps.Marker({
          position: { lat: userLat, lng: userLng },
          map,
          title: 'You',
          icon: {
            path: google.maps.SymbolPath.CIRCLE,
            scale: 9,
            fillColor: '#39ff14',
            fillOpacity: 1,
            strokeColor: '#fff',
            strokeWeight: 2,
          },
          zIndex: 999,
        });

        setStatus('✅ Ready — pick a mode and hit GO', 'active');
        document.getElementById('find-btn').disabled = false;
      },
      (err) => {
        setStatus('❌ Location blocked: ' + err.message, 'error');
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }

  // ── Find Quest ─────────────────────────────────────────────────────────────
  async function findQuest() {
    if (!userLat || !userLng) {
      setStatus('❌ Location not ready yet', 'error');
      return;
    }

    const btn     = document.getElementById('find-btn');
    const minutes = parseInt(document.getElementById('time-select').value);
    const stops   = calcStops(minutes, selectedTravel);

    btn.disabled = true;
    btn.innerText = '...';
    setStatus('🤖 Gemini is building your quest...', 'active');

    // Clear previous
    waypointMarkers.forEach(m => m.setMap(null));
    waypointMarkers = [];
    directionsRenderer.setDirections({ routes: [] });

    const wpContainer = document.getElementById('waypoints');
    wpContainer.innerHTML = Array(stops).fill('<div class="shimmer"></div>').join('');

    try {
      const res = await fetch('/navigate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          lat:        userLat,
          lng:        userLng,
          theme:      selectedMode,
          travelMode: selectedTravel,
          stops,
        })
      });

      const data = await res.json();
      if (!data.waypoints || data.waypoints.length === 0) throw new Error(data.error || 'No waypoints returned');

      const wps = data.waypoints;
      setStatus('🗺️ ' + wps.length + ' stops — ' + minutes + ' min ' + (selectedTravel === 'walk' ? 'walk' : 'drive'), 'active');

      // ── Draw numbered markers ─────────────────────────────────────────────
      wps.forEach((wp, i) => {
        const svg = \`
          <svg xmlns="http://www.w3.org/2000/svg" width="32" height="40" viewBox="0 0 32 40">
            <path d="M16 0C7.16 0 0 7.16 0 16c0 10 16 24 16 24s16-14 16-24C32 7.16 24.84 0 16 0z" fill="#39ff14"/>
            <circle cx="16" cy="16" r="10" fill="#000"/>
            <text x="16" y="20.5" text-anchor="middle" font-family="Arial Black,sans-serif" font-weight="900" font-size="11" fill="#39ff14">\${i + 1}</text>
          </svg>
        \`;

        const marker = new google.maps.Marker({
          position: { lat: wp.lat, lng: wp.lng },
          map,
          title: wp.name,
          icon: {
            url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
            scaledSize: new google.maps.Size(32, 40),
            anchor:     new google.maps.Point(16, 40),
          },
          zIndex: 100 + i,
        });

        waypointMarkers.push(marker);
      });

      // ── Draw route through all waypoints ──────────────────────────────────
      const origin      = { lat: userLat, lng: userLng };
      const destination = { lat: wps[wps.length - 1].lat, lng: wps[wps.length - 1].lng };
      const waypoints   = wps.slice(0, -1).map(wp => ({
        location: { lat: wp.lat, lng: wp.lng },
        stopover: true,
      }));

      const travelMode = selectedTravel === 'car'
        ? google.maps.TravelMode.DRIVING
        : google.maps.TravelMode.WALKING;

      directionsService.route(
        { origin, destination, waypoints, travelMode, optimizeWaypoints: false },
        (result, status) => {
          if (status === 'OK') {
            directionsRenderer.setDirections(result);
          } else {
            console.warn('Directions failed:', status);
          }
        }
      );

      // Fit map to all markers
      const bounds = new google.maps.LatLngBounds();
      bounds.extend(origin);
      wps.forEach(wp => bounds.extend({ lat: wp.lat, lng: wp.lng }));
      map.fitBounds(bounds, { top: 80, bottom: 20, left: 20, right: 20 });

      // ── Render waypoint cards ─────────────────────────────────────────────
      wpContainer.innerHTML = '';
      wps.forEach((wp, i) => {
        const card = document.createElement('div');
        card.className = 'wp-card';
        card.innerHTML = \`
          <div class="wp-num">\${i + 1}</div>
          <div class="wp-info">
            <h3>\${wp.name}</h3>
            <p>\${wp.description}</p>
            <p class="wp-address">📍 \${wp.address}</p>
          </div>
        \`;
        card.onclick = () => {
          map.panTo({ lat: wp.lat, lng: wp.lng });
          map.setZoom(16);
        };
        wpContainer.appendChild(card);
      });

    } catch (err) {
      setStatus('❌ ' + err.message, 'error');
      wpContainer.innerHTML = '';
    }

    btn.disabled = false;
    btn.innerText = 'GO';
  }
</script>

<script
  src="https://maps.googleapis.com/maps/api/js?key=${process.env.GOOGLE_MAPS_API_KEY}&libraries=places&callback=initMap"
  async defer>
</script>
</body>
</html>`);
});

// ── POST /navigate ────────────────────────────────────────────────────────────
app.post("/navigate", async (req, res) => {
  const { lat, lng, theme, travelMode = "walk", stops = 3 } = req.body;

  if (lat === undefined || lng === undefined || !theme) {
    return res.status(400).json({ error: "lat, lng, and theme are required." });
  }

  try {
    const result = await findWaypoints(Number(lat), Number(lng), theme, travelMode, Number(stops));
    res.json(result);
  } catch (err) {
    console.error("[/navigate]", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /vault/sign ──────────────────────────────────────────────────────────
app.post("/vault/sign", async (req, res) => {
  const { filename, contentType = "application/octet-stream", expiresIn = 600 } = req.body;

  if (!filename) {
    return res.status(400).json({ error: "filename is required." });
  }

  try {
    const result = await createPresignedUploadUrl(filename, contentType, Number(expiresIn));
    res.json(result);
  } catch (err) {
    console.error("[/vault/sign]", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /rewards/mint ────────────────────────────────────────────────────────
app.post("/rewards/mint", async (req, res) => {
  const { recipientAddress, metadata, treeAddress } = req.body;

  if (!recipientAddress || !metadata?.name || !metadata?.uri) {
    return res.status(400).json({
      error: "recipientAddress, metadata.name, and metadata.uri are required.",
    });
  }

  try {
    const result = await mintBadge(recipientAddress, metadata, treeAddress);
    res.json(result);
  } catch (err) {
    console.error("[/rewards/mint]", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`✅  SideQuest server running on http://localhost:${PORT}`);
  console.log(`🗺️   Demo page:      http://localhost:${PORT}/demo`);
  console.log(`🧪  Maps test page: http://localhost:${PORT}/test-maps`);
});

module.exports = app;