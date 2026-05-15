if (!globalThis.crypto) globalThis.crypto = require("crypto").webcrypto;
const { TableClient } = require("@azure/data-tables");

module.exports = async function (context, req) {
  try {
    const client = TableClient.fromConnectionString(
      process.env.STORAGE_CONNECTION_STRING, "BatchHistory"
    );
    const entities = [];
    for await (const entity of client.listEntities()) {
      entities.push(entity);
    }
    context.res = { status: 200, headers: {"Content-Type":"application/json"}, body: entities };
  } catch (err) {
    context.res = { status: 500, body: "Error reading BatchHistory: " + err.message };
  }
};
