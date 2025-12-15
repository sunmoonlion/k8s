<template>
    <div class="header-wrapper">
      <!-- Header 部分 -->
      <div class="header flex justify-between p-2 bg-gray-100 border-b border-gray-300">
        <div class="welcome text-base text-gray-800">欢迎来到美多商城!</div>
        <div class="user-section flex items-center">
          <!-- 如果用户已登录，显示欢迎信息与退出按钮 -->
          <div v-if="isLoggedIn" class="login-btn mr-5 flex items-center">
            欢迎您：<em>{{ username }}</em>
            <span class="mx-2">|</span>
            <a href="{{ url('users:logout') }}" class="quit text-red-500">退出</a>
          </div>
          <!-- 如果用户未登录，显示登录与注册链接 -->
          <div v-else class="login-btn mr-5 flex items-center">
            <a href="login.html" class="text-blue-500">登录</a>
            <span class="mx-2">|</span>
            <a href="register.html" class="text-blue-500">注册</a>
          </div>
  
          <!-- 用户链接 -->
          <div class="user-link flex items-center">
            <span class="mx-2">|</span>
            <a href="{{ url('users:info') }}" class="text-blue-500">用户中心</a>
            <span class="mx-2">|</span>
            <a href="{{ url('carts:info') }}" class="text-blue-500">我的购物车</a>
            <span class="mx-2">|</span>
            <a href="user_center_order.html" class="text-blue-500">我的订单</a>
          </div>
        </div>
      </div>
  
      <!-- 搜索条部分 -->
      <div class="search-bar flex items-center justify-between p-5">
        <a href="index.html" class="logo w-24">
          <!-- <img src="{{ static('images/logo.png') }}" alt="商城Logo" /> -->
        </a>
        <div class="search-wrap flex-1 flex justify-between">
          <form method="get" action="/search/" class="search-con flex items-center w-full">
            <input
              type="text"
              class="input-text w-4/5 p-2 border border-gray-300 rounded"
              name="q"
              placeholder="搜索商品"
            />
            <input type="submit" class="input-btn bg-blue-500 text-white p-2 rounded ml-2 cursor-pointer" value="搜索" />
          </form>
          <!-- 搜索建议 -->
          <ul class="search-suggest absolute bg-white border border-gray-300 w-full mt-1 p-2 hidden">
            <li><a href="#" class="block px-3 py-2 text-gray-800">索尼微单</a></li>
            <li><a href="#" class="block px-3 py-2 text-gray-800">优惠15元</a></li>
            <li><a href="#" class="block px-3 py-2 text-gray-800">美妆个护</a></li>
            <li><a href="#" class="block px-3 py-2 text-gray-800">买2免1</a></li>
          </ul>
        </div>
        <!-- 购物车部分 -->
        <div class="guest-cart relative">
          <a href="{{ url('carts:info') }}" class="cart-name text-blue-500">我的购物车</a>
          <div class="goods-count bg-red-500 text-white w-5 h-5 rounded-full absolute top-0 right-0 -mt-2 -mr-2 text-center leading-5">2</div>
          <ul class="cart-goods-show absolute top-full right-0 bg-white border border-gray-300 w-48 hidden">
            <li class="flex items-center p-2">
              <img src="../static/images/goods/goods001.jpg" alt="商品图片" class="w-10 h-10 mr-2" />
              <h4 class="text-sm">华为 HUAWEI P10 Plus 6GB+64GB 钻雕金</h4>
              <div class="text-xs">1</div>
            </li>
            <li class="flex items-center p-2">
              <img src="../static/images/goods/goods002.jpg" alt="商品图片" class="w-10 h-10 mr-2" />
              <h4 class="text-sm">Apple iPhoneX 64GB 深空灰色</h4>
              <div class="text-xs">1</div>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </template>
  
  <script setup lang="ts">
  import { ref } from "vue";
  
  // 模拟用户是否登录的状态
  const isLoggedIn = ref(false); // 可以通过 API 调用替换该值
  const username = ref("张三"); // 可以通过 API 获取用户名
  </script>
  
  <style scoped lang="scss">
  /* 搜索建议和购物车悬停效果 */
  .search-bar:hover .search-suggest {
    display: block;
  }
  .guest-cart:hover .cart-goods-show {
    display: block;
  }
  </style>
  