ARG NODE_IMAGE=node:20-alpine
ARG NGINX_IMAGE=nginx:1.28.3-alpine

# Build Angular separately so Node.js and node_modules stay out of the runtime image.
FROM ${NODE_IMAGE} AS builder

ARG API_URL
ENV API_URL=${API_URL}

# husky runs via the prepare script and fails in the container without .git
ENV HUSKY=0

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# angular reads the api url from this file, so overwrite it before the build
RUN echo "export const environment = { apiUrl: '${API_URL}' };" > src/environments/environment.ts

RUN npm run build

# Serve only the compiled frontend from the smaller Nginx runtime image.
FROM ${NGINX_IMAGE} AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist/angular-conduit /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
