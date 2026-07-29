# syntax=docker/dockerfile:1

ARG NODE_IMAGE=node:20-alpine
ARG NGINX_IMAGE=nginx:1.28.3-alpine

# Build Angular separately so Node.js and node_modules stay out of the runtime image.
FROM ${NODE_IMAGE} AS builder

# Angular embeds the API URL into the browser bundle during the build.
ARG API_URL
ENV API_URL=${API_URL} \
    HUSKY=0

WORKDIR /app

# Copy package manifests first so Docker can reuse the dependency layer.
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .

# Generate the environment file from the build argument before compiling Angular.
RUN node -e "const fs=require('fs'); const value=JSON.stringify(process.env.API_URL); if (!process.env.API_URL) throw new Error('API_URL is required'); fs.writeFileSync('src/environments/environment.ts', '// Generated during the container build.\\nexport const environment = { apiUrl: ' + value + ' };\\n');" \
    && npm run build

# Serve only the compiled frontend from the smaller Nginx runtime image.
FROM ${NGINX_IMAGE} AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist/angular-conduit /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
