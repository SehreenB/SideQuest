# SideQuest
## Inspiration

For the last 15 years, the mapping industry has been obsessed with a single metric: ETA. Every major navigation app optimizes strictly for speed, rushing us through concrete highways and gray intersections just to shave off a few seconds. In the race to get from Point A to Point B, we realized society was optimizing the joy out of the journey.

SideQuest was inspired by a desire to challenge the assumption that optimization always means speed. We wanted to reframe inefficiency as intentional design. What if a map prioritized discovery, mood, and memory over sheer velocity? We set out to build an interactive exploration engine that doesn't just guide you through a city, but connects you to it.

---

## What It Does

SideQuest is a native iOS app that generates scenic, discovery-focused routes instead of the fastest path. Users choose a **Navigator Mode** — Adventure, Foodie, Nature, Culture, Social, or Mystery — each tailored to a different mood and intention. The app then builds a real, live route around the user's current location using Gemini AI with Google Search grounding, narrated stop-by-stop by an AI voice guide powered by ElevenLabs.

- **Walking mode** prioritizes murals, cafés, parks, and hidden neighborhood gems
- **Driving mode** emphasizes scenic roads, waterfront drives, and parking-accessible stops
- **Detour levels** — Light, Moderate, Bold — let users control how adventurous the route gets
- **Memory Vault** lets users capture geo-tagged photos at each stop, stored privately or shared publicly on a community map
- **Challenges** offer a scavenger-style Find It mode where users receive clues and must explore to locate and check in
- **Points and badges** reward exploration — Mural Hunter, Café Crawler, Park Hopper, Neighborhood Nomad, Community Curator, and more — with streak tracking and leaderboards

---

## How We Built It

**Frontend — Native iOS (SwiftUI)**

The app is built entirely in SwiftUI with a five-tab shell covering Home, Explore, Vault, Challenges, and Profile. Key components include:

- `ScenicRoutePlanner` — the core route engine that resolves destinations, queries scenic waypoints via Gemini AI and Google Places, builds polylines through Google Directions API with MapKit as a fallback, and calculates detour budgets per travel mode and duration
- `DiscoveryEngine` — a multi-source place discovery system that queries Gemini first, falls back to Google Places, then MapKit, then seeded local data — ensuring Explore never renders empty regardless of API availability
- `ElevenLabsService` — calls the ElevenLabs TTS API directly from iOS via `URLSession`, caches audio by text key, and plays it through `AVAudioPlayer` with `AVAudioSession` configured for spoken audio playback. Gemini generates the spoken script before ElevenLabs voices it
- `GeminiService` — handles all Gemini 2.0/2.5 Flash calls: themed waypoint generation with Google Search grounding, photo analysis via vision, audio guide script generation, place curation, and learning insights for stop descriptions
- `RouteBuilder` — builds navigation polylines through Google Directions API with MapKit segment-by-segment fallback
- `GoogleMapsService` — wraps the Places API, Directions API, and Geocoding API with typed Swift models
- `LocationManager` — wraps `CLLocationManager` with async/await for live GPS coordinates
- `PointsEngine` — awards points for check-ins (80pts), public memories (60pts), and route completions, and evaluates badge unlock conditions against memory content, category visit counts, and streak data
- `AppState` — a single `@MainActor ObservableObject` managing all user state, active route, memories, challenges, badge progress, and streak logic across the app

**Backend — Node.js + Express**

A modular JavaScript backend handles the heavier AI workloads:

- `POST /api/voice` — ElevenLabs streaming audio with 6 mode-matched voice personalities and emotional tone tags
- `POST /api/routes` — Gemini 2.5 Flash waypoint generation with Google Search grounding
- `POST /vault/sign` — Supabase presigned upload URLs for memory storage
- `POST /rewards/mint` — Solana Devnet cNFT badge minting via Metaplex Bubblegum

**Authentication — Auth0**

Auth0 native iOS SDK handles Google Sign-In and guest sessions, with `AuthViewModel` managing credential state and profile hydration.

---

## Challenges We Ran Into

**Multi-source discovery with graceful degradation** was the hardest engineering problem. `DiscoveryEngine` chains Gemini → Google Places → MapKit → seed data, and getting each fallback to produce usable results — with proper deduplication, distance normalization, and mode-relevant filtering — required significant iteration.

**Scenic route geometry** needed to respect real detour budgets. `ScenicRoutePlanner` computes a hard detour budget in meters per travel mode, filters candidate stops by corridor offset, scores them by rating vs. detour penalty, and only falls back to Gemini or seed stops when the Places API comes up empty. Getting this to feel natural across walking and driving modes at different durations took many tuning passes.

**ElevenLabs + Gemini audio pipeline** required chaining two async AI calls — Gemini generates a warm, story-driven script under 40 words, then ElevenLabs voices it — while keeping latency low enough to feel live. Audio caching by text key prevented redundant API calls on revisited stops.

**Gemini JSON reliability** was an ongoing challenge. The `decodeLenientJSON` fallback was added specifically to handle cases where Gemini wraps valid JSON in markdown fences or extra prose, extracting the JSON substring by brace detection before attempting decode.

**Backend and iOS working in parallel** across two teammates required agreeing on API contracts (`POST /api/voice`, `POST /api/routes`) before writing any code, then merging two independently developed modules with no conflicts.

---

## Accomplishments That We're Proud Of

- A fully working scenic route engine that generates real, geocoded, mode-matched routes anywhere in the world, with live polylines, turn-by-turn instructions, and detour time calculations
- A multi-source discovery system that never renders empty — it always has something to show, regardless of which APIs are available
- An end-to-end AI voice guide that chains Gemini script generation with ElevenLabs narration, cached and played natively on iOS
- Gemini vision integration that analyzes photos taken during exploration and auto-generates captions and tags for memories
- A complete points, badge, streak, and challenge system with real unlock logic tied to user behavior
- A modular full-stack architecture across SwiftUI, Node.js, Supabase, Solana, and Auth0 built and shipped in a single weekend

---

## What We Learned

**Define the data contract before writing a single line.** Both teammates built independently against the same API shape — `RoutePlan`, `Spot`, `MemoryItem`, `NavigatorMode` — and the merge was seamless because the types were agreed on first.

**AI responses need defensive parsing.** Gemini is powerful but inconsistent in output format. The `decodeLenientJSON` pattern — try strict decode, fall back to brace-extraction, then throw — is the right approach for any production Gemini integration.

**Fallback chains make or break real-world apps.** The multi-source discovery architecture meant SideQuest worked on demo day even when Google Places rate limits kicked in mid-presentation.

**Streaming audio changes the feel of an app.** The difference between a button that loads and a voice that speaks before you expect it is the difference between a utility and an experience.
