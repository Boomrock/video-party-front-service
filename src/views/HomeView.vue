<template>
  <main>
    <div class="main-container"> 
      <h1 class="title">
        Привет, это сайт для просмотра совместных видео!
      </h1>
      <button class="room-button" @click="getRoomCode()">
        Сгенерировать комнату
      </button>
      <div v-if="roomCode">
        <h1>
          Ваша ссылка на комнату
        </h1>
        <h1>
          <a :href="`/room/${roomCode}`">Клик</a> 
        </h1>
      </div>
    </div>
  </main>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const roomCode = ref('');

async function getRoomCode() {
  try {
    const response = await fetch(`http://${import.meta.env.VITE_BASE_URL_ROOM_SERVICE}/room/create`);
    if (response.ok) {
      const answer = await response.json();
      roomCode.value = answer.room.key;
    } else {
      console.error('Ошибка при создании комнаты:', response.status);
    }
  } catch (error) {
    console.error('Ошибка сети:', error);
  }
}
</script>

<style scoped>


.main-container {
  align-items: center;
  display: flex;
  flex-direction: column;
  gap: 40px;
  padding: 40px 20px;
}

.title {
  font-size: 5vh;
  text-align: center;
  max-width: 800px;
}
</style>