FROM nginx:1.27-alpine

# Placeholder image until frontend source is added.
RUN mkdir -p /usr/share/nginx/html
RUN printf '%s\n' '<!doctype html><html><body><h1>frontend scaffold</h1></body></html>' > /usr/share/nginx/html/index.html

EXPOSE 8080

CMD ["sh", "-c", "sed -i 's/listen       80;/listen       8080;/' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
