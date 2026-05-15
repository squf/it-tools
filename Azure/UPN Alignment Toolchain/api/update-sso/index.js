if (!globalThis.crypto) globalThis.crypto = require("crypto").webcrypto;
const { TableClient } = require("@azure/data-tables");

module.exports = async function (context, req) {
  try {
    const body = req.body;
    if (!body || !body.RowKey) {
      context.res = { status: 400, body: "Missing RowKey" };
      return;
    }
    const client = TableClient.fromConnectionString(
      process.env.STORAGE_CONNECTION_STRING, "SSOAppStatus"
    );
    await client.upsertEntity({
      partitionKey: body.PartitionKey || "app",
      rowKey: body.RowKey,
      ...body
    }, "Merge");
    context.res = { status: 200, headers: {"Content-Type":"application/json"}, body: { ok: true } };
  } catch (err) {
    context.res = { status: 500, body: "Error updating SSOAppStatus: " + err.message };
  }
};
