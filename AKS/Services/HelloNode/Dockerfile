FROM node:12-alpine
WORKDIR /app

# Install NPM packages
COPY Services/HelloNode/package*.json /app/
RUN npm set progress=true
RUN npm cache clean --force
RUN npm install

# Copy Angular source code to app folder
COPY Services/HelloNode /app/

EXPOSE 80
CMD [ "node", "server.js" ]