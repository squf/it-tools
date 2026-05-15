if (!globalThis.crypto) globalThis.crypto = require("crypto").webcrypto;
const { TableClient } = require("@azure/data-tables");

module.exports = async function (context, req) {
  try {
    const client = TableClient.fromConnectionString(
      process.env.STORAGE_CONNECTION_STRING, "AuditLog"
    );
    const dateFilter = req.query.date || '';
    const entities = [];
    const options = dateFilter ? { queryOptions: { filter: `PartitionKey eq '${dateFilter}'` } } : {};
    for await (const entity of client.listEntities(options)) {
      entities.push(entity);
    }
    context.res = { status: 200, headers: {"Content-Type":"application/json"}, body: entities };
  } catch (err) {
    context.res = { status: 500, body: "Error reading AuditLog: " + err.message };
  }
};
