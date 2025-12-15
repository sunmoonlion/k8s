<template>
  <div class="flex flex-col min-h-50vh">
    <header>
      <DefaultHeader></DefaultHeader>
    </header>
    <NuxtPage></NuxtPage>
    <footer>
      <div class="desktop-content">
        <DefaultFooter icp="鄂ICP备19018123号-1"></DefaultFooter>
      </div>
      <div class="mobile-content">
        <MobileFooter></MobileFooter>
      </div>

    </footer>
  </div>

</template>

<script setup lang="ts">

</script>


<style scoped lang="scss">

</style>
