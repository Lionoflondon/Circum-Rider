FROM nginx:1.27-alpine

COPY build/web /usr/share/nginx/html
COPY cloudrun/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
