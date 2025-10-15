<template>
  <div class="video-section">
    <!-- Выбор видео -->
    <div>

    <SearchableSelect 
      :options="videoList"
      v-model="videoURL"
      placeholder="Начните вводить название видео..."
      not-found-text="Видео не найдено"
      @add-video="onAddVideo"
      @update:model-value="onVideoSelected"
      @delete="onDeleteVideo"
      :loading="isLoading"
    />
    <VideoUploader v-model="showModal" />

    </div>

    <!-- Видеоплеер -->
    <div class="video-container" v-if="videoSrc">
      <video 
        ref="video"
        :key="videoSrc"
        class="video-player"
        controls
        preload="auto"
        muted="true"
        @loadedmetadata="onVideoLoaded"
        @error="onVideoError"
        @play="onPlay"
        @pause="onPause"
        @timeupdate="onTimeUpdate"
        
      >
        Ваш браузер не поддерживает видео тег.
      </video>
    </div>
    <div class="placeholder" v-else>
      <p>Введите название видео для воспроизведения</p>
    </div>


  </div>
  <!-- Лог действий -->
  <div class="log">
    <h4>События:</h4>
    <ul>
      <li v-for="(entry, index) in log" :key="index">
        [{{ formatTime(entry.timestamp) }}] {{ entry.message }}
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
import type { Folder, Item } from '@/components/FolderTypes';
import SearchableSelect from '@/components/SearchableSelect.vue';
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import VideoUploader from './VideoUploader.vue';
import Hls from 'hls.js';


const route = useRoute();

// Состояние
const videoURL = ref<Item | null>(null);
const videoList = ref<Folder[]>([]);
const isLoading = ref(true);
const log = ref<{ message: string; timestamp: number }[]>([]);

// Видео
const video = ref<HTMLVideoElement | null>(null);
const currentTime = ref(0);
const duration = ref(0);
const showModal = ref<boolean>(false)

// Экземпляр Hls
let hls: Hls | null = null;

// WebSocket
let ws: WebSocket | null = null;
let timeOut : boolean = false;
const timeOutTime: number = 30;

// *** videoSrc остается таким же ***
const videoSrc = computed<string>(() => {
  const selected = videoURL.value;
  if (!selected || !selected.key?.trim()) return '';

  const safeFileName = encodeURIComponent(selected.key.trim());
  return `/api/video/hls/${safeFileName}/480p.m3u8`;
});




const addLog = (text: string) => {
  console.log(`[LOG] ${text}`);
  log.value.unshift({ message: text, timestamp: Date.now() });
  if (log.value.length > 50) log.value.pop();
};

const formatTime = (time: number): string => {
  const seconds = Math.floor(time % 60);
  const minutes = Math.floor(time / 60);
  return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
};

const onAddVideo = () => {
  showModal.value =true;
}

const onVideoSelected = async (event:any) => {
  sendMessage('change-video', video.value?.currentTime, event.key)
  addLog(event);
  const response = await fetch(`/api/room/setVideo?key=${route.params.roomCode as string}&file_name=${event.key}`);
    if (response.ok) {
      const data = response.body;
      addLog(`Видео для комнаты успешно изменено ${data}`)
    }
}

const onDeleteVideo = async (event:Item | null) => {
  if(event == null) return;

  const response = await fetch(`/api/video/delete?file_name=${event.key}`);
  if (response.ok) {
    const data = response.body;
    addLog(`Видео для комнаты успешно изменено ${data}`)
    videoList.value = videoList.value.filter(item => item.Items != event)
  }
}

const connect = () => {
  const roomCode = route.params.roomCode as string;
  if (!roomCode) {
    addLog('❌ Код комнаты не указан');
    return;
  }

  const wsUrl = `ws://${import.meta.env.VITE_BASE_URL_ROOM_SERVICE}/room/ws?key=${roomCode}`;
  ws = new WebSocket(wsUrl);

  ws.onopen = () => {
    addLog('✅ Подключено к серверу');
  };

  ws.onmessage = (event) => {
    try {
      const message = JSON.parse(event.data);
      handleWSMessage(message);
    } catch (e) {
      addLog('⚠️ Ошибка парсинга JSON');
      console.error(e);
    }
  };

  ws.onclose = () => {
    addLog('🔌 Соединение закрыто');
    setTimeout(connect, 3000); // авто-переподключение
  };

  ws.onerror = (err) => {
    addLog('❌ Ошибка WebSocket');
    console.error(err);
  };
};

const setInputTimeOut = ():boolean => {
  if(timeOut) return timeOut;
  timeOut = true;
  setTimeout(()=> timeOut = false, timeOutTime)
  return false;
}

const handleWSMessage = (message: any): void => {
  if (!video.value) return;
  if (setInputTimeOut()) return;

  addLog("recieve " +message.type)
  switch (message.type) {
    case 'play':
      if (video.value.currentTime !== message.time) {
        video.value.currentTime = message.time;
      }
      video.value.play().catch(e => {
        addLog(`🔇 Не удалось воспроизвести: ${e.message}`);
      });
      addLog(`▶️ Play на ${formatTime(message.time)}`);
      break;

    case 'pause':
      if (video.value.currentTime !== message.time) {
        video.value.currentTime = message.time;
      }
      video.value.pause();
      addLog(`⏸️ Pause на ${formatTime(message.time)}`);
      break;

    case 'seek':
      video.value.currentTime = message.time;
      addLog(`⏭️ Перемотка на ${formatTime(message.time)}`);
      break;
    case 'change-video':
      videoURL.value = {key: message.payload, label: "auto-generate"};
      addLog(`Кто-то поставил новое виде -_- ${message.payload}`)
      break;
    default:
      addLog(`📩 Неизвестная команда: ${message.type}`);
  }
};

const sendMessage = (type: 'play' | 'pause' | 'seek' | 'change-video', time?: number, payload?:string) => {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  addLog("send " +type)

  if (setInputTimeOut()) return;
  addLog("TimeOut " +type)

  const msg = {
    type,
    time: time ?? video.value?.currentTime ?? 0,
    timestamp: new Date().toISOString(),
    payload: payload
  };
  ws.send(JSON.stringify(msg));
};

const isHlsInitializing = ref(false);

const cleanupHls = () => {
  if (hls) {
    hls.destroy();
    hls = null;
    addLog('🧹 HLS очищен');
  }
};

const cleanupVideo = () => {
  if (video.value) {
    video.value.pause();
    video.value.src = '';
    video.value.removeAttribute('src');
    video.value.load();
    addLog('🧹 Видео очищено');
  }
};

const initHls = async () => {
  // Защита от повторной инициализации
  if (isHlsInitializing.value) {
    addLog('⚠️ HLS уже инициализируется, пропускаем');
    return;
  }

  addLog(`initHls вызвана. videoURL: ${videoURL.value?.key}, videoSrc: ${videoSrc.value}`);
  

  if (!videoURL.value ) {
    addLog('⚠️ Отсутствует URL видео');
    return;
  }

  isHlsInitializing.value = true;
  
  try {
    // Очищаем предыдущие ресурсы
    cleanupHls();
    cleanupVideo();

    // Даем время на очистку DOM
    await new Promise(resolve => setTimeout(resolve, 100));

    if (Hls.isSupported()) {
      addLog(`✨ Инициализация HLS для: ${videoSrc.value}`);
      
      hls = new Hls({
        enableWorker: true,

      });

      hls.loadSource(videoSrc.value);
      hls.attachMedia(video.value);

      hls.on(Hls.Events.MEDIA_ATTACHED, () => {
        addLog('✅ HLS: Медиаэлемент прикреплен');
      });

      hls.on(Hls.Events.MANIFEST_PARSED, (event: any, data: any) => {
        addLog(`🚀 HLS манифест загружен, ${data.levels.length} качеств`);
        duration.value = video.value?.duration || 0;
        
        // Автовоспроизведение после загрузки
        video.value?.play().catch(e => {
          addLog(`🔇 Автовоспроизведение отклонено: ${e.message}`);
        });
      });

      hls.on(Hls.Events.ERROR, (event: any, data: any) => {
        addLog(`❌ HLS ошибка: ${data.type} - ${data.details}`);
        console.error('HLS Error:', data);
        
        if (data.fatal) {
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              addLog("🔄 Восстановление после сетевой ошибки...");
              hls?.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              addLog("🔄 Восстановление после медиа ошибки...");
              hls?.recoverMediaError();
              break;
            default:
              addLog("💀 Фатальная ошибка HLS, пересоздание...");
              cleanupHls();
              break;
          }
        }
      });

    } 
    // else if (videoSrc.value) {
    //   // Для не-HLS видео
    //   addLog(`📹 Загрузка обычного видео: ${videoSrc.value}`);
    //   video.value.src = videoSrc.value;
    //   video.value.load();
    // }

  } catch (error) {
    addLog(`💥 Ошибка инициализации HLS: ${error}`);
    console.error('HLS Init Error:', error);
  } finally {
    isHlsInitializing.value = false;
  }
};

const onVideoLoaded = (event: Event): void => {
  const vid = event.target as HTMLVideoElement;
  duration.value = vid.duration;
  addLog(`📹 Видео загружено (${formatTime(vid.duration)})`);
  if (!hls && video.value?.src) {
    duration.value = video.value.duration;
  }
};

const onVideoError = (event: Event): void => {
  addLog('❌ Ошибка загрузки видео');
  console.error('Ошибка видео:', event);
};

const onPlay = () => {
  sendMessage('play');
};

const onPause = () => {
  sendMessage('pause');
};

const onTimeUpdate = () => {
  currentTime.value = video.value?.currentTime || 0;
};

onMounted(async () => {
  isLoading.value = true;

  connect();
  try {
    const response = await fetch(`/api/room?key=${route.params.roomCode}`);
    if (response.ok) {
      const room = await response.json();
      if(room.video.Valid && room.video.String != ""){
        videoURL.value = { key: room.video.String, label: "some label"}
      }

    } else {
      addLog(`⚠️ Ошибка получения данных о комнате: ${response.status}`);
    }
  } catch (error) {
    addLog('⚠️ Ошибка получения данных о комнате');
    console.error(error);
  }

  try {
    const response = await fetch(`/api/video/all`);
    if (response.ok) {
      const data = await response.json();
      videoList.value = data.map((video: any) => ({
        Name: "Some Name",
        Items:{
          key: video.FileName,
          label: video.VideoName || 'Без названия',
        },

      }));
    } else {
      addLog(`⚠️ Ошибка загрузки видео: ${response.status}`);
    }
  } catch (error) {
    addLog('⚠️ Сетевая ошибка при загрузке видео');
    console.error(error);
  } finally {
    isLoading.value = false;
  }

  if (videoURL.value) {
    console.log("asdasd", videoURL.value)
    initHls();
  }
});

watch(videoURL, async (newValue, oldValue) => {
  if (newValue && newValue.key !== oldValue?.key) {
    addLog(`🔄 Переключение видео с ${oldValue?.key} на ${newValue.key}`);
    
    // Небольшая задержка для гарантии обновления computed свойств
    await initHls();
  }
}, { immediate: false });

onUnmounted(() => {
  if (ws) {
    ws.close();
  }
  cleanupHls();
  cleanupVideo();
});
</script>

<style scoped>
.video-section {
  display: flex;
  width: 100%;
  gap: 20px;
  font-family: Arial, sans-serif;
}

.video-container {
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.video-player {
  width: 100%;
  height: auto;
  background: #000;
  border-radius: 8px;
}

.placeholder {
  margin: 40px 0;
  padding: 40px;
  text-align: center;
  color: #999;
  border: 2px dashed #ddd;
  border-radius: 8px;
  background-color: #f9f9f9;
}

.log {
  max-height: 150px;
  overflow-y: auto;
  border: 1px solid #eee;
  padding: 10px;
  font-size: 12px;
  color: #555;
  background: #f8f8f8;
  border-radius: 4px;
}
</style>