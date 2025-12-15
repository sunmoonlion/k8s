<template>
  <div class="flex justify-between w-full">
    <div class="flex justify-start items-center m-10">
      <div class="i-pepicons-pop:moon-circle text-blue-500 text-5xl lt-sm:mx-auto"></div>
      <!-- 分类 -->
      <ul class="flex text-blue-100">
        <li class="active item">欢迎欢迎！</li>
        <li class="item">日月同辉</li>
      </ul>
    </div>


    <div class="flex items-center">
      <!-- 搜索 -->
      <div class="relative bg-white rounded-6 pl-4 pr-2 h-full flex items-center mr-4">
        <input type="text" class="outline-none mr-2" placeholder="搜索课程" />
        <i class="i-ep:search"></i>
      </div>
      <!-- 登录 -->
      <div class="text-blue-200">
        <span class="mr-2 cursor-pointer hover:text-white">登录</span>|
        <span class="ml-2 cursor-pointer hover:text-white">注册</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">

</script>
