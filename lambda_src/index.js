// lambda_src/index.js
const AWS = require("aws-sdk");

const secrets = new AWS.SecretsManager();
const STORE = process.env.SHOPIFY_STORE_DOMAIN;       // e.g., unfitware.myshopify.com
const API_VERSION = process.env.SHOPIFY_API_VERSION || "2025-07";
const SECRET_ID = process.env.SECRET_ID;              // e.g., "shopify/admin"
const MCP_BEARER = process.env.MCP_BEARER;

// --- Helpers ---
async function getAdminToken() {
  const out = await secrets.getSecretValue({ SecretId: SECRET_ID }).promise();
  if (out.SecretString) {
    try {
      // If user stored JSON like {"SHOPIFY_ADMIN_TOKEN":"..."}
      const asJson = JSON.parse(out.SecretString);
      return asJson.SHOPIFY_ADMIN_TOKEN || out.SecretString;
    } catch (_) {
      // Plain string token
      return out.SecretString;
    }
  }
  if (out.SecretBinary) {
    return Buffer.from(out.SecretBinary, "base64").toString("utf8");
  }
  throw new Error("Secret has no value. Set your Admin token in Secrets Manager.");
}

async function shopifyGraphQL(query, variables = {}) {
  const token = await getAdminToken();
  const endpoint = `https://${STORE}/admin/api/${API_VERSION}/graphql.json`;
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Shopify-Access-Token": token
    },
    body: JSON.stringify({ query, variables })
  });
  const json = await res.json();
  if (!res.ok || json.errors) {
    throw new Error("Shopify error: " + JSON.stringify(json.errors || json));
  }
  return json.data;
}

// --- MCP tool registry ---
function listTools() {
  return {
    tools: [
      {
        name: "list_products",
        description: "List first N products (id, title, status).",
        inputSchema: {
          type: "object",
          properties: { first: { type: "integer", minimum: 1, maximum: 50, default: 10 } },
          required: []
        }
      },
      {
        name: "update_variant_price",
        description: "Update a variant's price by variant GID (gid://shopify/ProductVariant/...).",
        inputSchema: {
          type: "object",
          properties: {
            variantId: { type: "string" },
            price: { type: "string", pattern: "^[0-9]+(\\.[0-9]{2})?$" }
          },
          required: ["variantId", "price"]
        }
      }
    ]
  };
}

async function callTool(name, args) {
  if (name === "list_products") {
    const first = Math.max(1, Math.min(50, (args && args.first) || 10));
    const q = /* GraphQL */ `
      query($first: Int!) {
        products(first: $first, sortKey: CREATED_AT, reverse: true) {
          nodes { id title status }
        }
      }`;
    const data = await shopifyGraphQL(q, { first });
    return data.products.nodes;
  }

  if (name === "update_variant_price") {
    const { variantId, price } = args || {};
    const m = /* GraphQL */ `
      mutation($variantId: ID!, $price: Money!) {
        productVariantUpdate(input: { id: $variantId, price: $price }) {
          productVariant { id price }
          userErrors { field message }
        }
      }`;
    const data = await shopifyGraphQL(m, { variantId, price });
    const errors = data.productVariantUpdate?.userErrors;
    if (errors && errors.length) throw new Error("UserErrors: " + JSON.stringify(errors));
    return data.productVariantUpdate.productVariant;
  }

  throw new Error(`Unknown tool: ${name}`);
}

// --- Lambda handler (API Gateway v2 → JSON-RPC) ---
exports.handler = async (event) => {
  try {
    // Simple bearer protection
    const auth = event.headers?.authorization || event.headers?.Authorization || "";
    if (!auth.startsWith("Bearer ") || auth.slice(7) !== MCP_BEARER) {
      return resp(401, { error: "Unauthorized" });
    }

    if (event.requestContext?.http?.method !== "POST") {
      return resp(405, "Method not allowed");
    }

    const req = JSON.parse(event.body || "{}");
    const { id, method, params } = req;

    if (method === "tools/list") {
      return ok(id, listTools());
    }

    if (method === "tools/call") {
      const { name, arguments: toolArgs } = params || {};
      const result = await callTool(name, toolArgs || {});
      return ok(id, { content: [{ type: "json", value: result }] });
    }

    return err(id, "Method not found");
  } catch (e) {
    console.error(e);
    return err(null, e.message || "Server error");
  }
};

function ok(id, result) {
  return resp(200, { jsonrpc: "2.0", id, result });
}
function err(id, message) {
  return resp(200, { jsonrpc: "2.0", id, error: { code: -32603, message } });
}
function resp(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body)
  };
}
