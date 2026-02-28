/**
 * navigator.js
 * Uses Gemini with Google Search grounding to return waypoints
 * based on coordinates, theme, travel mode, and number of stops.
 */

"use strict";
require("dotenv").config();

const { GoogleGenerativeAI } = require("@google/generative-ai");

const RADIUS_BY_MODE = {
  walk: 2,
  car: 15,
  cycle: 7,
};

/**
 * Find waypoints near a given location.
 *
 * @param {number} lat
 * @param {number} lng
 * @param {string} theme
 * @param {string} travelMode - "walk" | "car"
 * @param {number} stops      - how many waypoints to return
 */
async function findWaypoints(lat, lng, theme, travelMode = "walk", stops = 3) {
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
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
  const response = result.response;
  const text = response.text().trim();

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