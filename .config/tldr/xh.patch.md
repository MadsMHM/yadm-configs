> Items: `==` query, `=` JSON string, `:=` raw JSON (numbers/bools/nested), `:` header, `@` file.
> Keep secrets in env vars (`$TOKEN`) or start the line with a space, so they stay out of shell history.

- Query param vs header vs body: `purge==true` is `?purge=true`, `Purge-Cache:true` a header, `purge=true` a JSON body:

`xh :3535/v1/articles/{{article-uuid}} purge==true`

- Only response headers, following redirects and showing each hop:

`xh -h -F --all :3535/v1/articles/{{article-uuid}} purge==true`

- POST JSON with nested keys and numbers (last 24h of most-read):

`xh post :3000/list "timeframe[from]:=$(date -v-1d +%s)" "timeframe[to]:=$(date +%s)" limit:={{5}} brand={{hf}}`

- Form-encoded POST instead of JSON (`-f`):

`xh -f post :5175/v2/api/users/{{boromir}} uid={{uid}} apiKey="$API_KEY"`

- Save the response to a file:

`xh :4545/debug/article histId=={{MIJU-1234567}} -o {{article.xml}}`

- Local `*.login.local` HTTPS (mkcert-signed) via my alias:

`xhl https://{{sh}}.login.local:5175/v2/api/shop/paywall brand=={{hf}}`

- Skip TLS verification entirely (`--no-verify` does not exist):

`xh --verify=no https://{{app.lab.internal}}/healthz`

- Auth, bearer token (sends `Authorization: Bearer <token>`):

`xh -A bearer -a "$TOKEN" :4545/api/refresh-paywall`

- Auth, bearer as a plain header (same request; `Bearer=...` would be a JSON field):

`xh post {{url}} Authorization:"Bearer $TOKEN" iterasId={{12345}} subBrand={{hf}}`

- Auth, basic with user and password (basic is the default; xh base64-encodes `user:pass`):

`xh -a {{user}}:"$PASSWORD" {{url}}`

- Auth, basic with only the user (xh prompts for the password, so it never hits history):

`xh -a {{user}} {{url}}`

- Auth, API wanting `Basic <base64 of token>` with no user:pass:

`xh {{url}} Authorization:"Basic $(printf %s "$TOKEN" | base64)"`

- Auth, API key as a header (or `api_key=="$API_KEY"` as a query param):

`xh {{url}} Api-Token:"$API_TOKEN"`

- Send a JSON file as the body:

`xh post {{url}} < {{body.json}}`

- File upload (multipart):

`xh -f post {{url}} {{name}}={{john}} {{avatar}}@{{path/to/image.png}}`

- Full request and response:

`xh -v {{url}}`

- Only the response body (for piping into jq):

`xh -b {{url}} | jq`

- Print the equivalent curl command without sending:

`xh --curl {{url}}`

- In scripts (stdin not a terminal), stop xh reading stdin as the body:

`xh -I post {{url}} {{name}}={{john}}`
