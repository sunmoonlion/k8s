<template>
    <div :class="['flex',{'flex-col':align==='vertical'}]" >
        <router-link to="/" class="item">产品</router-link>
        <a  class="item" href="https://www.imooc.com" target="_blank">社区</a>
        <router-link to="/study" class="item">学习</router-link>
        <router-link to="/about" class="item">关于</router-link>
    </div>
</template>

<script setup lang="ts">
defineProps({
    align:{
        type:String as PropType<'horizontal' | 'vertical'>,
        default:'horizontal'
    }
})

</script>

<style scoped lang="scss">
.item {
    @apply relative text-black text-2xl px-8 py-2 font-300 cursor-pointer lt-sm:self-start;
    &:hover {
        @apply font-500;
        &:after {
            content: '';            
            @apply  absolute bg-gray-100 h-[1px] w-8 bottom-0 left-[calc(50%-1rem)];
            // left:calc(50% - 1rem);
        }
        
    }
}

</style>