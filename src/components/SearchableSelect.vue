<!-- SearchableSelect.vue -->
<template>
  <div class="searchable-select">
    <input
      v-model="searchQuery"
      type="text"
      :placeholder="placeholder"
      class="search-input"
    />

    <div class="item-list">
      <div
        v-for="option in filteredOptions"
        :key="option.Name"
      >
      <FolderComponent
        :Folder="option" 
        :modelValue="option.Items"
        @update:modelValue="$emit('update:modelValue', $event)"
        @delete="$emit('delete', $event)"
      />
      </div>
      <div v-if="filteredOptions.length === 0" class="no-results">
        <button @click="$emit('add-video')"> 
            Нет твоего видео? 
            <br/>
            Добавь
        </button>

      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, computed, defineEmits, withDefaults } from 'vue'
import type { Folder, Item } from './FolderTypes';
import FolderComponent from "@/components/FolderComponent.vue"
defineEmits<{
  (e: 'add-video'): void,
  (e: 'update:modelValue', value: Item | null): void,
  (e: 'delete', value: Item | null): void,
}>()
// Пропсы
const props = withDefaults(
  defineProps<{
    options: Folder[]
    modelValue?: Item | null // для v-model
    placeholder?: string
  }>(),
  {
    modelValue: null,
    placeholder: 'Выберите или введите...',
  }
)

// Локальное состояние
const searchQuery = ref('')


// Фильтруем опции по поиску
const filteredOptions = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()
  if (!query) return props.options
  return props.options.filter((opt) =>
    opt.Items.label.toLowerCase().includes(query)
  )
})


// Закрытие при клике вне

</script>

<style scoped>
/* стили те же */
.searchable-select {
  width: auto;
}

.search-input {
  width: 100%;
  padding: 10px;
  font-size: 16px;
  border: none;
  border-radius: 15px 15px 0px 0px;
  outline: none;
}

.search-input:focus {
  border-color: #42b983;
}

.item-list {
  height: auto;
  border-radius: 0px 0px 15px 15px;
  background: white;
  overflow: hidden;

}
.no-results {
  padding: 10px;
  color: #999;
  text-align: center;
  font-style: italic;
}

.overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 999;
}
</style>