<template>
    <div :class="cardClass">
      <div 
        :class="imageClass" 
        :style="{ backgroundImage: `url(${image})` }" 
        v-if="image && image.trim() !== ''">
      </div>
      <div v-else :class="[icon, 'w-20 h-20']"></div>
      
      <div v-if="title || subTitle"  :class="titleClass">
        <p class="text-lg text-dark-300 text-bold pb-2">{{ title }}</p>
        <p class="text-sm text-dark-100 font-300">{{ subTitle }}</p>
      </div>
      
      <div>
        <slot :item="{ image, icon, title, subTitle, url }"></slot>
      </div>
    </div>
  </template>

<script setup lang="ts">

const props = defineProps({
    image:{
        type:String,
        default:''
    },
    imageType:{
        type:String as PropType<'default' | 'rounded' | 'avatar'>,
        default:'default'
    },
    icon:{
        type:String,
        default:''
    },
    title:{
        type:String,
        default:''
    },
    subTitle:{
        type:String,
        default:''
    },
    url:{
        type:String,
        default:''
    },
    border:{
        type:Boolean,
        default:false
        
    }
});
const cardClass=computed(()=>{
    let defaultClass='flex flex-col w-80'
    if (props.icon){
        defaultClass += ' items-start p-4'   
    }
    if (props.imageType === 'rounded'){
        defaultClass += ' rounded overflow-hidden'
    }else if (props.imageType === 'avatar'){
        defaultClass += ' relative mt-10'
    }
    if (props.border){
        defaultClass += ' border border-gray-300'
    }
    return defaultClass
})
const imageClass = computed(() => {    
    const defaultClass='bg-image';
    if (!props.title && !props.subTitle && props.imageType === 'rounded') {
        return defaultClass + ' h-60 rounded';
    }else if (props.imageType === 'avatar') {
        return defaultClass + ' h-20 w-20 rounded-1/2 self-center absolute top-0 translate-y--1/2';
    }
    else if (!props.title && !props.subTitle) {
        return defaultClass + ' h-40';
    }
    return defaultClass + ' h-40';   
});

const titleClass = computed(() => {
    const defaultClass = 'flex flex-col items-start p-4';
    if (props.imageType === 'avatar') {
            return defaultClass + ' pt-15';
        }
    return defaultClass;
    
    });
</script>

<style scoped>

</style>