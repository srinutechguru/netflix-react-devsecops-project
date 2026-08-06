# Stage 1: Build the React Application
FROM node:18-alpine AS builder
WORKDIR /app

# Copy the package files
COPY package*.json ./

# Use standard npm instead of yarn
RUN npm install

# Copy application source code
COPY . .

# Accept the API key from Jenkins as a build argument
ARG TMDB_V3_API_KEY
# Expose Vite environment variables so they are baked into the frontend
ENV VITE_APP_TMDB_V3_API_KEY=${TMDB_V3_API_KEY}
ENV VITE_APP_API_ENDPOINT_URL="https://api.themoviedb.org/3"

# Build the optimized production static files using npm
RUN npm run build

# Stage 2: Serve the app using Nginx
FROM nginx:stable-alpine
WORKDIR /usr/share/nginx/html

# Clean out default Nginx welcome page
RUN rm -rf ./*

# Copy the built assets from Stage 1 (Vite uses /dist)
COPY --from=builder /app/dist .

# Expose port 80 for the web server
EXPOSE 80

# Start Nginx
ENTRYPOINT ["nginx", "-g", "daemon off;"]
