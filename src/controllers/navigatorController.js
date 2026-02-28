/**
 * navigatorController.js
 * Uses Gemini with Google Search grounding to return waypoints
 * based on coordinates, theme, travel mode, and number of stops.
 */

"use strict";

const { GoogleGenerativeAI } = require("@google/generative-ai");

const RADIUS_BY_MODE = {
  walk:  2,
  car:   15,
  cycle: 7,
};

// ─── Core function ────────────────────────────────────────────────────────────

async function findWaypoints(lat, lng, theme, travelMode = "walk", stops = 3) {
  const genAI  = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const radius = RADIUS_BY_MODE[travelMode.toLowerCase()] ?? 2;

  const model = genAI.getGenerativeModel({
    model: "gemini-2.5-flash",
    tools: [{ googleSearch: {} }],
  });

  const prompt = `
You are a local tour guide AI for the SideQuest exploration app.
A user is standing at latitude ${lat}, longitude ${lng}.
Travel mode: "${travelMode}" — only suggest places within ${radius} km.
Theme: "${theme}"
Number of stops requested: ${stops}

Return EXACTLY ${stops} waypoints that fit the theme, are reachable within ${radius} km,
and make sense as a sequential route (ordered by logical walking/driving path).

Respond ONLY with valid JSON — no markdown, no prose, no code fences.

Schema:
{
  "waypoints": [
    {
      "name": "Place Name",
      "address": "Full street address",
      "lat": 0.0,
      "lng": 0.0,
      "description": "One sentence about why this fits the theme and is worth visiting."
    }
  ]
}
`.trim();

  const result = await model.generateContent(prompt);
  const text   = result.response.text().trim();
  const clean  = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();

  let parsed;
  try {
    parsed = JSON.parse(clean);
  } catch (err) {
    throw new Error(`Gemini returned non-JSON response:\n${text}`);
  }

  if (!Array.isArray(parsed.waypoints) || parsed.waypoints.length === 0) {
    throw new Error("No waypoints returned by Gemini.");
  }

  return parsed;
}

// ─── Express handler ──────────────────────────────────────────────────────────

const navigate = async (req, res) => {
  const { lat, lng, theme, travelMode = "walk", stops = 3 } = req.body;

  if (lat === undefined || lng === undefined || !theme) {
    return res.status(400).json({ error: "lat, lng, and theme are required." });
  }

  try {
    const result = await findWaypoints(
      Number(lat), Number(lng), theme, travelMode, Number(stops)
    );
    res.json(result);
  } catch (error) {
    console.error("[/api/routes]", error.message);
    res.status(500).json({ error: error.message });
  }
};

// ─── Demo page ────────────────────────────────────────────────────────────────

const demo = (_req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <title>SideQuest</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=DM+Sans:wght@300;400;500&display=swap" rel="stylesheet">
  <style>
    :root { --green: #39ff14; --green-dim: #1a7a00; --bg: #080808; --surface: #111111; --surface2: #1a1a1a; --border: #2a2a2a; --text: #f0f0f0; --muted: #666; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'DM Sans', sans-serif; background: var(--bg); color: var(--text); height: 100dvh; display: flex; flex-direction: column; overflow: hidden; }
    #map { flex: 1; width: 100%; min-height: 0; }
    #header { position: absolute; top: 0; left: 0; right: 0; padding: 16px 16px 0; pointer-events: none; z-index: 10; }
    #logo { font-family: 'Syne', sans-serif; font-weight: 800; font-size: 22px; color: var(--green); background: rgba(8,8,8,0.85); display: inline-block; padding: 6px 14px; border-radius: 20px; border: 1px solid rgba(57,255,20,0.2); backdrop-filter: blur(10px); }
    #status-pill { position: absolute; top: 60px; left: 50%; transform: translateX(-50%); background: rgba(8,8,8,0.9); border: 1px solid var(--border); color: var(--muted); padding: 8px 16px; border-radius: 20px; font-size: 12px; z-index: 10; backdrop-filter: blur(10px); white-space: nowrap; transition: all 0.3s ease; max-width: 90vw; overflow: hidden; text-overflow: ellipsis; }
    #status-pill.active { color: var(--green); border-color: var(--green-dim); }
    #status-pill.error { color: #ff4444; border-color: #440000; }
    #panel { background: var(--surface); border-top: 1px solid var(--border); display: flex; flex-direction: column; max-height: 55dvh; position: relative; z-index: 20; }
    #panel::before { content: ''; display: block; width: 36px; height: 4px; background: var(--border); border-radius: 2px; margin: 10px auto 0; }
    #controls { padding: 12px 16px 14px; border-bottom: 1px solid var(--border); }
    #mode-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; margin-bottom: 12px; }
    .mode-btn { background: var(--surface2); border: 1px solid var(--border); color: var(--muted); padding: 9px 4px 7px; border-radius: 10px; font-size: 10px; font-family: 'DM Sans', sans-serif; font-weight: 500; cursor: pointer; text-align: center; transition: all 0.15s; line-height: 1.5; }
    .mode-btn .icon { display: block; font-size: 18px; margin-bottom: 2px; }
    .mode-btn.active { background: rgba(57,255,20,0.12); border-color: var(--green); color: var(--green); font-weight: 600; }
    #bottom-row { display: flex; gap: 8px; align-items: stretch; }
    #travel-toggle { display: flex; gap: 4px; background: var(--surface2); border: 1px solid var(--border); border-radius: 10px; padding: 3px; }
    .travel-btn { padding: 7px 10px; border-radius: 7px; border: none; background: transparent; color: var(--muted); font-size: 18px; cursor: pointer; transition: all 0.15s; }
    .travel-btn.active { background: rgba(57,255,20,0.15); color: var(--green); }
    #time-select { flex: 1; background: var(--surface2); border: 1px solid var(--border); color: var(--text); border-radius: 10px; padding: 0 12px; font-size: 13px; cursor: pointer; appearance: none; }
    #find-btn { background: var(--green); color: #000; border: none; border-radius: 10px; padding: 0 18px; font-size: 13px; font-family: 'Syne', sans-serif; font-weight: 700; cursor: pointer; white-space: nowrap; }
    #find-btn:disabled { background: var(--surface2); color: var(--muted); cursor: not-allowed; }
    #waypoints { overflow-y: auto; padding: 12px 16px 20px; flex: 1; }
    .wp-card { background: var(--surface2); border: 1px solid var(--border); border-radius: 12px; padding: 12px 14px; margin-bottom: 8px; display: flex; gap: 12px; align-items: flex-start; cursor: pointer; }
    .wp-num { width: 26px; height: 26px; min-width: 26px; background: var(--green); color: #000; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-family: 'Syne', sans-serif; font-weight: 800; font-size: 12px; }
    .wp-info h3 { font-family: 'Syne', sans-serif; font-weight: 600; font-size: 13px; color: var(--text); margin-bottom: 3px; }
    .wp-info p { font-size: 11px; color: var(--muted); line-height: 1.5; }
    .wp-address { font-size: 10px; color: #444; margin-top: 4px; }
    .shimmer { background: linear-gradient(90deg, var(--surface2) 25%, #222 50%, var(--surface2) 75%); background-size: 200% 100%; animation: shimmer 1.2s infinite; border-radius: 8px; height: 70px; margin-bottom: 8px; }
    @keyframes shimmer { 0%{background-position:200% 0} 100%{background-position:-200% 0} }
  </style>
</head>
<body>
<div id="map"></div>
<div id="header"><div id="logo">⚔️ SideQuest</div></div>
<div id="status-pill">📍 Locating you...</div>
<div id="panel">
  <div id="controls">
    <div id="mode-grid">
      <button class="mode-btn active" data-mode="Adventure Mode: murals, street art, scenic viewpoints, unexpected landmarks" onclick="selectMode(this)"><span class="icon">🗺️</span>Adventure</button>
      <button class="mode-btn" data-mode="Foodie Mode: hidden cafés, dessert spots, food markets, local restaurant favourites" onclick="selectMode(this)"><span class="icon">🍜</span>Foodie</button>
      <button class="mode-btn" data-mode="Nature Mode: parks, waterfront paths, tree-lined streets, green spaces" onclick="selectMode(this)"><span class="icon">🌿</span>Nature</button>
      <button class="mode-btn" data-mode="Culture Mode: galleries, bookstores, historic corners, live music venues" onclick="selectMode(this)"><span class="icon">🎨</span>Culture</button>
      <button class="mode-btn" data-mode="Social Mode: lively areas, patios, event spaces, popular hangout spots" onclick="selectMode(this)"><span class="icon">🎉</span>Social</button>
      <button class="mode-btn" data-mode="Mystery Mode: completely random but highly rated hidden gems, surprises" onclick="selectMode(this)"><span class="icon">🎲</span>Mystery</button>
    </div>
    <div id="bottom-row">
      <div id="travel-toggle">
        <button class="travel-btn active" data-mode="walk" onclick="selectTravel(this)">🚶</button>
        <button class="travel-btn" data-mode="car" onclick="selectTravel(this)">🚗</button>
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
  let map, directionsService, directionsRenderer, userMarker;
  let waypointMarkers = [];
  let selectedMode = 'Adventure Mode: murals, street art, scenic viewpoints, unexpected landmarks';
  let selectedTravel = 'walk';
  let userLat = null, userLng = null;

  function calcStops(minutes, travelMode) {
    if (travelMode === 'car') { if (minutes <= 30) return 2; if (minutes <= 60) return 3; if (minutes <= 120) return 4; return 5; }
    else { if (minutes <= 30) return 2; if (minutes <= 45) return 3; if (minutes <= 90) return 4; if (minutes <= 150) return 5; return 6; }
  }
  function setStatus(msg, type = '') { const el = document.getElementById('status-pill'); el.innerText = msg; el.className = type; }
  function selectMode(btn) { document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active')); btn.classList.add('active'); selectedMode = btn.dataset.mode; }
  function selectTravel(btn) { document.querySelectorAll('.travel-btn').forEach(b => b.classList.remove('active')); btn.classList.add('active'); selectedTravel = btn.dataset.mode; }

  function initMap() {
    map = new google.maps.Map(document.getElementById('map'), {
      center: { lat: 51.5074, lng: -0.1278 }, zoom: 14, disableDefaultUI: true,
      styles: [
        { elementType: 'geometry', stylers: [{ color: '#0f0f0f' }] },
        { elementType: 'labels.text.fill', stylers: [{ color: '#555' }] },
        { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#1c1c1c' }] },
        { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#0a1628' }] },
        { featureType: 'poi', elementType: 'geometry', stylers: [{ color: '#141414' }] },
        { featureType: 'poi.park', elementType: 'geometry', stylers: [{ color: '#0d1f0d' }] },
      ]
    });
    directionsService = new google.maps.DirectionsService();
    directionsRenderer = new google.maps.DirectionsRenderer({ map, suppressMarkers: true, polylineOptions: { strokeColor: '#39ff14', strokeWeight: 3, strokeOpacity: 0.8 } });
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        userLat = pos.coords.latitude; userLng = pos.coords.longitude;
        map.setCenter({ lat: userLat, lng: userLng });
        userMarker = new google.maps.Marker({ position: { lat: userLat, lng: userLng }, map, icon: { path: google.maps.SymbolPath.CIRCLE, scale: 9, fillColor: '#39ff14', fillOpacity: 1, strokeColor: '#fff', strokeWeight: 2 }, zIndex: 999 });
        setStatus('✅ Ready — pick a mode and hit GO', 'active');
        document.getElementById('find-btn').disabled = false;
      },
      (err) => setStatus('❌ Location blocked: ' + err.message, 'error'),
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }

  async function findQuest() {
    if (!userLat || !userLng) { setStatus('❌ Location not ready yet', 'error'); return; }
    const btn = document.getElementById('find-btn');
    const minutes = parseInt(document.getElementById('time-select').value);
    const stops = calcStops(minutes, selectedTravel);
    btn.disabled = true; btn.innerText = '...';
    setStatus('🤖 Gemini is building your quest...', 'active');
    waypointMarkers.forEach(m => m.setMap(null)); waypointMarkers = [];
    directionsRenderer.setDirections({ routes: [] });
    const wpContainer = document.getElementById('waypoints');
    wpContainer.innerHTML = Array(stops).fill('<div class="shimmer"></div>').join('');
    try {
      const res = await fetch('/api/routes', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ lat: userLat, lng: userLng, theme: selectedMode, travelMode: selectedTravel, stops }) });
      const data = await res.json();
      if (!data.waypoints || data.waypoints.length === 0) throw new Error(data.error || 'No waypoints returned');
      const wps = data.waypoints;
      setStatus('🗺️ ' + wps.length + ' stops — ' + minutes + ' min ' + (selectedTravel === 'walk' ? 'walk' : 'drive'), 'active');
      wps.forEach((wp, i) => {
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="40" viewBox="0 0 32 40"><path d="M16 0C7.16 0 0 7.16 0 16c0 10 16 24 16 24s16-14 16-24C32 7.16 24.84 0 16 0z" fill="#39ff14"/><circle cx="16" cy="16" r="10" fill="#000"/><text x="16" y="20.5" text-anchor="middle" font-family="Arial Black,sans-serif" font-weight="900" font-size="11" fill="#39ff14">' + (i + 1) + '</text></svg>';
        const marker = new google.maps.Marker({ position: { lat: wp.lat, lng: wp.lng }, map, title: wp.name, icon: { url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg), scaledSize: new google.maps.Size(32, 40), anchor: new google.maps.Point(16, 40) }, zIndex: 100 + i });
        waypointMarkers.push(marker);
      });
      const origin = { lat: userLat, lng: userLng };
      const destination = { lat: wps[wps.length - 1].lat, lng: wps[wps.length - 1].lng };
      const waypoints = wps.slice(0, -1).map(wp => ({ location: { lat: wp.lat, lng: wp.lng }, stopover: true }));
      const travelMode = selectedTravel === 'car' ? google.maps.TravelMode.DRIVING : google.maps.TravelMode.WALKING;
      directionsService.route({ origin, destination, waypoints, travelMode, optimizeWaypoints: false }, (result, status) => { if (status === 'OK') directionsRenderer.setDirections(result); });
      const bounds = new google.maps.LatLngBounds();
      bounds.extend(origin); wps.forEach(wp => bounds.extend({ lat: wp.lat, lng: wp.lng }));
      map.fitBounds(bounds, { top: 80, bottom: 20, left: 20, right: 20 });
      wpContainer.innerHTML = '';
      wps.forEach((wp, i) => {
        const card = document.createElement('div'); card.className = 'wp-card';
        card.innerHTML = '<div class="wp-num">' + (i + 1) + '</div><div class="wp-info"><h3>' + wp.name + '</h3><p>' + wp.description + '</p><p class="wp-address">📍 ' + wp.address + '</p></div>';
        card.onclick = () => { map.panTo({ lat: wp.lat, lng: wp.lng }); map.setZoom(16); };
        wpContainer.appendChild(card);
      });
    } catch (err) { setStatus('❌ ' + err.message, 'error'); wpContainer.innerHTML = ''; }
    btn.disabled = false; btn.innerText = 'GO';
  }
</script>
<script src="https://maps.googleapis.com/maps/api/js?key=${process.env.GOOGLE_MAPS_API_KEY}&libraries=places&callback=initMap" async defer></script>
</body>
</html>`);
};

module.exports = { navigate, demo, findWaypoints };
