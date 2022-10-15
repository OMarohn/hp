FROM nginx:alpine

WORKDIR /app

COPY ./public ./static

COPY ./nginx.conf /etc/nginx/nginx.conf