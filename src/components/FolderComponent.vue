<template>
  <div class="item" @click="clickHandler">
    <div @click="selectOption(Folder.Items)">
      {{ Folder.Items.label }}
    </div> 
    <img class="delete-button" src="@/assets/icons8-delete.svg" @click="$emit('delete', Folder.Items)">
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import type { Folder, Item } from '@/components/FolderTypes';

// Пропсы
interface Props {
  Folder: Folder;
  modelValue: Item | null;
  notFound?: string;
}

const props = withDefaults(defineProps<Props>(), {
  notFound: 'Тут ничего нет',
});

// Состояние
const isOpen = ref<boolean>(false);

// Обработчики
const clickHandler = () => {
  isOpen.value = !isOpen.value;
};
// События
const emit = defineEmits<{
  (e: 'update:modelValue', value: Item | null): void
  (e: 'delete', value: Item | null): void

}>()
const selectOption = (item: any) => {
  emit("update:modelValue", item)
};

// Пример фильтрации — если у тебя есть поиск, добавь input и v-model
// Здесь просто заглушка: если Items нет, то filteredOptions пуст
const filteredOptions = computed(() => props.Folder.Items || []);
</script>

<style scoped>
.item {
  padding: 8px;
  color: black;
  cursor: pointer;
  display: flex;
  justify-content: space-between;
}
.item:hover{

  background-color: rgb(188, 223, 188);
}
.no-results {
  color: #999;
  font-style: italic;
}
</style>