<template>
  <div class="p-4 max-w-4xl mx-auto">
    <h1 class="text-2xl font-semibold mb-6 text-center">音频列表</h1>

    <ul class="space-y-6">
      <!-- 音频列表渲染 -->
      <li v-for="audio in audioList" :key="audio.id" class="flex items-center gap-6 bg-gray-50 p-4 rounded-lg shadow-md hover:shadow-xl transition-all">
        <!-- 音频标题 -->
        <span class="text-xl font-medium text-gray-800 flex-1">{{ audio.title }}</span>
        
        <!-- 音频播放器 -->
        <audio controls class="flex-1">
          <source :src="audio.url" type="audio/mp3">
          您的浏览器不支持音频播放。
        </audio>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';

// 音频列表数据
const audioList = ref([]);

// 获取音频文件列表
const loadAudioList = async () => {
  const response = await fetch('/api/audio/list');  // 从后端获取音频列表
  const data = await response.json();
  audioList.value = data.audio_list;
};

// 页面加载完成后调用获取音频列表的函数
onMounted(() => {
  loadAudioList();
});
</script>

<style scoped lang="scss">

</style>
