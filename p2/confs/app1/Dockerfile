FROM nginx
COPY ./index.html /usr/share/nginx/html/index.html

# Create a custom nginx configuration
RUN echo 'server { \n\
    listen 80 default_server; \n\
    listen [::]:80 default_server; \n\
    root /usr/share/nginx/html; \n\
    index index.html; \n\
    server_name _; \n\
    location / { \n\
        try_files $uri $uri/ /index.html =404; \n\
    } \n\
}' > /etc/nginx/conf.d/default.conf

RUN chown -R nginx:nginx /usr/share/nginx/html \
    && chmod -R 755 /usr/share/nginx/html
