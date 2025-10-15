# Stage 1: Сборка Vue приложения
FROM node:22-alpine

WORKDIR /app

# Копируем package.json и устанавливаем зависимости
COPY package*.json ./
RUN npm install

# Копируем исходный код и собираем приложение
COPY . .
RUN npm run build
CMD ["npm", "run", "preview", "--", "--host", "--port", "8080"]