# WeCare Insights (Agregador)

App Rails **separado** (repo próprio) que unifica os dados de todos os ambientes do
monólito WeCare para o time interno, via **dashboard** e **MCP**.

> Não confundir com a **API dos Clientes** (`/api/v2`, no monólito) que as empresas
> consomem. Aqui é a **nossa** camada interna.

## Como as peças se encaixam

```
Monólito (cada deploy) ── expõe ──►  API Interna de Insights  (/insights/v1, read-only, token por ambiente)
                                             ▲
        Agregador Insights (ESTE app) ───────┘  guarda 1 token por ambiente, chama cada um,
             │  cache Redis (lazy loading)        agrega. Os dados já vêm anonimizados do monólito.
             ├── Dashboard (admins, OAuth Google)
             └── MCP (Claude/ChatGPT)
```

- **API Interna de Insights**: vive **no monólito** (repo `wecare`), namespace `/insights/v1`.
  Deployada junto com o monólito em cada ambiente. Autentica por `INSIGHTS_API_TOKEN` (ENV) —
  **uma credencial read-only por ambiente/db**. Retorna métricas + listas **anonimizadas**
  (colaboradores viram pseudônimo estável).
- **Agregador** (este app): registra os ambientes (base_url + token) e as empresas
  (ativa/inativa), chama a API Interna de cada um, cacheia no Redis e serve dashboard + MCP.

## Setup

```bash
cp .env.example .env      # ajuste REDIS_URL, GOOGLE_* (OAuth), INSIGHTS_MASTER_KEY
bundle install
bin/rails db:create db:migrate
bin/rails s                # http://localhost:3000
```

> Sem `GOOGLE_CLIENT_ID` em development, o dashboard libera como usuário `dev`.

## Cadastrar ambientes e sincronizar empresas

```bash
# 1) cadastra um ambiente com o token read-only daquele deploy
curl -X POST http://localhost:3000/environments \
  -d 'name=danone' -d 'base_url=https://danone.wecare.com.br' \
  -d 'db_type=dedicated' -d 'token=<INSIGHTS_API_TOKEN do ambiente>'

# 2) descobre as empresas de cada ambiente ativo (popula o registro)
curl -X POST http://localhost:3000/environments/sync
```

O token de cada ambiente é o valor de `INSIGHTS_API_TOKEN` configurado naquele deploy do monólito.

## Endpoints (exigem sessão OAuth)

- `GET /api/overview?start_date&end_date&fields` — agregado de todos os clientes ativos.
- `GET /api/companies/:name?sections&fields&start_date&end_date&limit` — analytics de um cliente.
- `GET /environments` / `POST /environments` / `POST /environments/sync`.
- `GET /client_companies` / `POST /client_companies/:id/toggle` — ativa/inativa por empresa.

## MCP

```bash
bin/mcp    # servidor stdio (Claude Desktop / dev)
```

Tools: `list_clients`, `get_overview`, `get_analytics_by_client_name`.

Config exemplo (claude_desktop_config.json):

```json
{
  "mcpServers": {
    "wecare-insights": { "command": "bin/mcp", "cwd": "/caminho/wecare-insights" }
  }
}
```

Em produção, expor as tools via HTTP (Streamable HTTP) atrás do mesmo OAuth do dashboard.

## Anonimização / LGPD

Os dados **já chegam anonimizados** do monólito (a API Interna nunca envia nome/CPF/e-mail;
colaboradores são pseudônimos estáveis). Este app só agrega e cacheia — nunca vê PII.
