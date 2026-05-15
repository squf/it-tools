module.exports = async function (context, req) {
  const triggerUrl = process.env.LOGIC_APP_TRIGGER_URL;
  if (!triggerUrl) {
    context.res = { status: 500, body: { error: "LOGIC_APP_TRIGGER_URL not configured" } };
    return;
  }

  try {
    // Fire Logic App with 10s abort — if it responds fast (gate failure etc.), return that.
    // Otherwise return 202 and let the frontend poll batchhistory via get-batches.
    const ac = new AbortController();
    const timer = setTimeout(() => ac.abort(), 10000);

    try {
      const response = await fetch(triggerUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(req.body),
        signal: ac.signal
      });
      clearTimeout(timer);

      // Logic App responded within 10s — return full result as before
      const data = await response.text();
      let parsed;
      try { parsed = JSON.parse(data); } catch { parsed = { raw: data }; }

      context.res = {
        status: response.status,
        headers: { "Content-Type": "application/json" },
        body: parsed
      };
    } catch (_) {
      clearTimeout(timer);
      // Expected — Logic App still running. Return 202 so frontend can poll.
      context.res = {
        status: 202,
        headers: { "Content-Type": "application/json" },
        body: { status: "submitted", message: "Job submitted — pipeline is running." }
      };
    }
  } catch (err) {
    context.res = { status: 500, body: { error: "Error calling Logic App: " + err.message } };
  }
};
