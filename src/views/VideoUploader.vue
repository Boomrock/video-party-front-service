<template>
  <!-- Телепортируем модалку в body, чтобы не было проблем с z-index -->
  <Teleport to="body">
    <div v-if="modelValue" class="modal-overlay" @click.self="closeModal">
      <div class="modal-container">
        <!-- Заголовок с кнопкой закрытия -->
        <div class="modal-header">
          <h2>Загрузка видео</h2>
          <button class="close-btn" @click="closeModal">&times;</button>
        </div>

        <!-- Основное содержимое -->
        <div class="modal-body">
          <div class="upload-box">
            <!-- Выбор файла -->
            <input
              type="file"
              accept="video/*"
              @change="onFileSelected"
              class="file-input"
            />

            <!-- Информация о выбранном файле -->
            <p v-if="selectedFile" class="selected-file">
              Выбрано: {{ selectedFile.name }} ({{ formatFileSize(selectedFile.size) }})
            </p>

            <!-- Кнопка загрузки -->
            <button
              @click="uploadVideo"
              :disabled="!selectedFile || isUploading"
              class="upload-btn"
            >
              {{ isUploading ? 'Загрузка...' : 'Загрузить видео' }}
            </button>

            <!-- Статус -->
            <p v-if="uploadStatus" class="status" :class="uploadStatus.type">
              {{ uploadStatus.message }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { ref } from 'vue';

// Определяем пропсы и emit
interface UploadStatus {
  type: 'success' | 'error';
  message: string;
}

const props = defineProps<{
  modelValue: boolean; // v-model поддержка
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

// Реактивные переменные
const selectedFile = ref<File | null>(null);
const isUploading = ref<boolean>(false);
const uploadStatus = ref<UploadStatus | null>(null);

// Обработчик выбора файла
const onFileSelected = (event: Event): void => {
  const input = event.target as HTMLInputElement;
  const files = input.files;

  if (!files || files.length === 0) return;

  const file = files[0];

  if (file && file.type.startsWith('video/')) {
    selectedFile.value = file;
    uploadStatus.value = null;
  } else {
    uploadStatus.value = {
      type: 'error',
      message: 'Пожалуйста, выберите видеофайл.',
    };
    selectedFile.value = null;
  }
};

// Форматирование размера файла
const formatFileSize = (bytes: number): string => {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

// Загрузка видео
const uploadVideo = async (): Promise<void> => {
  if (!selectedFile.value) return;

  isUploading.value = true;
  uploadStatus.value = null;

  const formData = new FormData();
  formData.append('video', selectedFile.value);

  try {
    const response = await fetch(`/api/video/upload`, {
      method: 'POST',
      body: formData,
    });

    if (response.ok) {

      uploadStatus.value = {
        type: 'success',
        message: 'Видео успешно загружено!',
      };
      // Можно автоматически закрыть после успеха?
      // setTimeout(() => closeModal(), 1500);
    } else {
      const error = await response.text();
      uploadStatus.value = {
        type: 'error',
        message: `Ошибка: ${response.status} - ${error}`,
      };
    }
  } catch (err: any) {
    console.error('Ошибка сети:', err);
    uploadStatus.value = {
      type: 'error',
      message: 'Ошибка подключения: ' + (err.message || 'Неизвестная ошибка'),
    };
  } finally {
    isUploading.value = false;
  }
};

// Закрытие модалки
const closeModal = () => {
  emit('update:modelValue', false);
  // Очистка состояния при закрытии (по желанию)
  selectedFile.value = null;
  uploadStatus.value = null;
};
</script>

<style scoped>
/* Overlay на весь экран */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

/* Основное модальное окно */
.modal-container {
  background: white;
  border-radius: 12px;
  width: 90%;
  max-width: 500px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
  overflow: hidden;
  animation: fadeIn 0.2s ease-out;
}

/* Шапка модалки */
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  background-color: #f5f5f5;
  border-bottom: 1px solid #ddd;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.5rem;
  color: #333;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.8rem;
  color: #aaa;
  cursor: pointer;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  transition: background-color 0.2s;
}

.close-btn:hover {
  background-color: #e0e0e0;
  color: #000;
}

/* Тело модалки */
.modal-body {
  padding: 20px;
}

.upload-box {
  background: #f9f9f9;
  border: 1px dashed #ccc;
  border-radius: 8px;
  padding: 30px;
  text-align: center;
}

.file-input {
  margin-bottom: 15px;
}

.selected-file {
  font-size: 14px;
  color: #555;
  margin: 10px 0;
}

.upload-btn {
  background-color: #007bff;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 5px;
  cursor: pointer;
  font-size: 16px;
  margin-top: 10px;
}

.upload-btn:disabled {
  background-color: #aaa;
  cursor: not-allowed;
}

.status {
  padding: 10px;
  margin-top: 10px;
  border-radius: 5px;
  font-size: 14px;
}

.status.success {
  background-color: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.status.error {
  background-color: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

/* Анимация появления */
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: scale(0.9);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}
</style>