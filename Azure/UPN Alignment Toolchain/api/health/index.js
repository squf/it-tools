module.exports = async function (context) {
  let tableStatus = "not loaded";
  try {
    const { TableClient } = require("@azure/data-tables");
    tableStatus = "loaded OK - " + typeof TableClient;
  } catch (err) {
    tableStatus = "FAILED: " + err.message;
  }
  context.res = {
    status: 200,
    headers: { "Content-Type": "application/json" },
    body: { ok: true, tableStatus, time: new Date().toISOString() }
  };
};
