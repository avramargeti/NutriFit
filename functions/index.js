const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";

const SYSTEM_INSTRUCTIONS = `
Είσαι ο NutriFit Assistant, βοηθός ευεξίας, διατροφής και γυμναστικής.
Απάντησε πάντα στα ελληνικά.

Κανόνες:
- Μείνε μόνο σε θέματα διατροφής, ευεξίας, fitness,
  προπόνησης και υγιεινών συνηθειών.
- Δώσε πρακτική, σύντομη και ασφαλή απάντηση.
- Αν η ερώτηση ζητά συνταγή, δώσε υλικά, σύντομα βήματα
  και ενδεικτικές θερμίδες/macros όπου γίνεται.
- Αν η ερώτηση ζητά άσκηση, δώσε ασκήσεις, σετ, επαναλήψεις,
  ξεκούραση και βασική τεχνική.
- Μην κάνεις ιατρική διάγνωση.
- Για παθήσεις, πόνο, φάρμακα ή τραυματισμούς, πρότεινε επικοινωνία με ειδικό.
- Μην ισχυρίζεσαι ότι βρήκες δεδομένα στην τοπική βάση του NutriFit.
- Η απάντηση δίνεται επειδή δεν υπήρχαν επαρκή τοπικά δεδομένα.
`;

exports.askNutriFitAi = onRequest(
    {
      region: "us-central1",
      timeoutSeconds: 30,
      cors: true,
    },
    async (req, res) => {
      try {
        if (req.method !== "POST") {
          return res.status(405).json({
            error: "Μη επιτρεπτή μέθοδος αιτήματος.",
            errorCode: "method_not_allowed",
          });
        }

        const query =
        req.body && typeof req.body.query === "string" ?
          req.body.query.trim() :
          "";

        logger.info("Received chatbot query", {length: query.length});

        if (!query) {
          return res.status(400).json({
            error: "Το ερώτημα είναι κενό.",
            errorCode: "empty_query",
          });
        }

        const apiKey = process.env.GEMINI_API_KEY;

        if (!apiKey) {
          logger.error("GEMINI_API_KEY is missing.");
          return res.status(500).json({
            error: "Η εξωτερική υπηρεσία AI δεν έχει ρυθμιστεί σωστά.",
            errorCode: "provider_config_missing",
            provider: "gemini",
          });
        }

        const model = process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL;

        const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

        const geminiResponse = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: JSON.stringify({
            systemInstruction: {
              parts: [
                {
                  text: SYSTEM_INSTRUCTIONS,
                },
              ],
            },
            contents: [
              {
                role: "user",
                parts: [
                  {
                    text: query,
                  },
                ],
              },
            ],
            generationConfig: {
              maxOutputTokens: 700,
              temperature: 0.6,
            },
          }),
        });

        const responseText = await geminiResponse.text();

        if (!geminiResponse.ok) {
          const providerError = parseProviderError(responseText);

          logger.error("Gemini API error", {
            status: geminiResponse.status,
            code: providerError.code,
            statusText: providerError.status,
            message: providerError.message,
          });

          return sendGeminiError(res, geminiResponse.status, providerError);
        }

        let data;

        try {
          data = JSON.parse(responseText);
        } catch (error) {
          logger.error("Invalid JSON from Gemini", error);
          return res.status(502).json({
            error: "Η εξωτερική υπηρεσία AI επέστρεψε μη έγκυρη απάντηση.",
            errorCode: "invalid_provider_response",
            provider: "gemini",
          });
        }

        const answer = extractGeminiText(data);

        if (!answer) {
          logger.error("Empty Gemini answer", data);
          return res.status(502).json({
            error: "Η εξωτερική υπηρεσία AI επέστρεψε κενή απάντηση.",
            errorCode: "empty_provider_response",
            provider: "gemini",
          });
        }

        return res.status(200).json({
          answer,
          provider: "gemini",
          model,
        });
      } catch (error) {
        logger.error("askNutriFitAi failed", error);

        return res.status(500).json({
          error: "Υπήρξε πρόβλημα σύνδεσης με την εξωτερική υπηρεσία AI.",
          errorCode: "proxy_connection_error",
          provider: "gemini",
        });
      }
    },
);

/**
 * Extracts all text parts from a Gemini generateContent response.
 * @param {object} data Parsed Gemini response payload.
 * @return {?string} Combined answer text, or null when empty.
 */
function extractGeminiText(data) {
  if (!data || typeof data !== "object") return null;
  if (!Array.isArray(data.candidates)) return null;

  const parts = [];

  for (const candidate of data.candidates) {
    const content = candidate && candidate.content;
    if (!content || !Array.isArray(content.parts)) continue;

    for (const part of content.parts) {
      if (part && typeof part.text === "string" && part.text.trim()) {
        parts.push(part.text.trim());
      }
    }
  }

  return parts.length > 0 ? parts.join("\n\n") : null;
}

/**
 * Reads the Gemini error payload without leaking provider details to clients.
 * @param {string} responseText Raw Gemini response body.
 * @return {{code: ?string, status: ?string, message: ?string}} Error details.
 */
function parseProviderError(responseText) {
  try {
    const parsed = JSON.parse(responseText);
    const error = parsed && parsed.error;

    return {
      code: error && typeof error.code !== "undefined" ?
        String(error.code) :
        undefined,
      status: error && typeof error.status === "string" ?
        error.status :
        undefined,
      message: error && typeof error.message === "string" ?
        error.message :
        undefined,
    };
  } catch (_) {
    return {
      code: undefined,
      status: undefined,
      message: responseText,
    };
  }
}

/**
 * Converts Gemini provider failures to stable client-facing error codes.
 * @param {object} res Express response object.
 * @param {number} providerStatus HTTP status returned by Gemini.
 * @param {object} providerError Parsed provider error details.
 * @return {object} Express JSON response.
 */
function sendGeminiError(res, providerStatus, providerError) {
  const errorCode = normalizeGeminiErrorCode(providerError);

  let clientStatus = 502;
  if (errorCode === "invalid_api_key") clientStatus = 401;
  if (errorCode === "resource_exhausted") clientStatus = 429;
  if (errorCode === "invalid_request") clientStatus = 400;

  let error = "Η εξωτερική υπηρεσία AI δεν μπόρεσε να επιστρέψει απάντηση.";

  if (errorCode === "invalid_api_key") {
    error = "Το Gemini API key δεν είναι έγκυρο ή δεν έχει δικαίωμα πρόσβασης.";
  } else if (errorCode === "resource_exhausted") {
    error = "Το Gemini API έφτασε το διαθέσιμο free quota ή rate limit.";
  } else if (errorCode === "invalid_request") {
    error =
      "Το αίτημα προς το Gemini API δεν έγινε δεκτό. " +
      "Έλεγξε το GEMINI_MODEL.";
  } else if (errorCode === "provider_unavailable") {
    error = "Το Gemini API είναι προσωρινά μη διαθέσιμο.";
  }

  return res.status(clientStatus).json({
    error,
    errorCode,
    provider: "gemini",
    providerStatus,
  });
}

/**
 * Normalizes Gemini status strings into app-level error codes.
 * @param {object} providerError Parsed provider error details.
 * @return {string} Stable error code for the Flutter client.
 */
function normalizeGeminiErrorCode(providerError) {
  const raw = providerError.status || providerError.code || "provider_error";

  if (raw === "UNAUTHENTICATED") return "invalid_api_key";
  if (raw === "PERMISSION_DENIED") return "invalid_api_key";
  if (raw === "RESOURCE_EXHAUSTED") return "resource_exhausted";
  if (raw === "INVALID_ARGUMENT") return "invalid_request";
  if (raw === "UNAVAILABLE") return "provider_unavailable";

  return "provider_error";
}
