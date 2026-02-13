FROM node:20-slim
WORKDIR /app

COPY package.json .
# In Docker builds, the SDK tarball is used instead of file: reference
COPY constellation-engine-provider-sdk-*.tgz ./
RUN npm install

COPY tsconfig.json .
COPY src/ src/
RUN npx tsc

EXPOSE 50051

CMD ["node", "dist/index.js"]
