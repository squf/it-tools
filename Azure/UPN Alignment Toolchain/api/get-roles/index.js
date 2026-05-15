module.exports = async function (context, req) {
  const principal = req.body || {};
  const claims = principal.claims || [];
  const roles = claims
    .filter(c => c.typ === "http://schemas.microsoft.com/ws/2008/06/identity/claims/role")
    .map(c => c.val);
  context.res = {
    status: 200,
    headers: { "Content-Type": "application/json" },
    body: { roles }
  };
};
