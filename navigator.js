/**
 * navigator.js
 * Uses Gemini 2.0 Flash with Google Maps grounding to return 3 waypoints
 * based on coordinates, theme, and travel mode.
 */

"use strict";
require("dotenv").config();

const { GoogleGenerativeAI } = require("@google/generative-ai");

const RADIUS_BY_MODE = {
  walk: 2,   // km
  car: 15,  // km
  cycle: 7,   // km  (sensible default; extend as needed)
};

/**
 * Find 3 waypoints near a given location.
 *
 * @param {number}  lat        - Latitude
 * @param {number}  lng        - Longitude
 * @param {string}  theme      - E.g. "street art", "historic pubs", "nature"
 * @param {string}  travelMode - "walk" | "car" | "cycle"
 * @returns {Promise<{ waypoints: Array<{name,address,lat,lng,description}> }>}
 */
async function findWaypoints(lat, lng, theme, travelMode = "walk") {
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const radius = RADIUS_BY_MODE[travelMode.toLowerCase()] ?? 2;

  const model = genAI.getGenerativeModel({
    model: "gemini-2.5-flash",
    tools: [{ googleSearch: {} }],   // Google Search grounding (Maps-aware)
  });

  const prompt = `
You are a local tour guide AI. A user is standing at latitude ${lat}, longitude ${lng}.
Their travel mode is "${travelMode}" so only suggest places within ${radius} km.
Their chosen theme is: "${theme}".

Return EXACTLY 3 waypoints that fit the theme and are reachable within ${radius} km.
Respond ONLY with valid JSON – no markdown, no prose, no code fences.

Schema:
{
  "waypoints": [
    {
      "name": "Place Name",
      "address": "Full street address",
      "lat": 0.0,
      "lng": 0.0,
      "description": "One sentence about why this fits the theme."
    }
  ]
}
`.trim();

  const result = await model.generateContent(prompt);
  const response = result.response;
  const text = response.text().trim();

  // Strip accidental markdown fences
  const clean = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();

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

module.exports = { findWaypoints };
