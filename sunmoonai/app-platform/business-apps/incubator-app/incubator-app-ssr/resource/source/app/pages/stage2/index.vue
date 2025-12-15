<template>
  <div class="stage2-list">
    <h1>Stage2 Articles</h1>
    <ul>
      <li v-for="article in articles" :key="article._path">
        <NuxtLink :to="getArticleLink(article)">
          {{ article.title || article._path?.split('/').pop()?.replace('.md', '') || 'Untitled' }}
        </NuxtLink>
        <span v-if="isDev" style="color: #999; font-size: 0.8rem; margin-left: 10px;">
          ({{ article._path }})
        </span>
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
definePageMeta({
  layout: 'default'
})

// 获取所有 stage2 文章
const { data: articles } = await useAsyncData('stage2-list', () =>
  queryContent('/stage2')
    .sort({ publishedAt: -1 })
    .find()
)

// 检查是否为开发环境
const isDev = process.dev

// 生成文章链接（处理中文文件名）
// 优先使用 slug，如果没有则使用文件名
const getArticleLink = (article: any) => {
  // 如果文章有 slug 字段，使用 slug
  if (article.slug) {
    return `/stage2/${article.slug}`
  }
  
  const path = article._path || ''
  // 提取文件名（去掉 /stage2/ 前缀和 .md 后缀）
  const fileName = path.replace(/^\/stage2\//, '').replace(/\.md$/, '')
  return `/stage2/${fileName}`
}
</script>

<style scoped>
.stage2-list {
  padding: 2rem;
}

.stage2-list ul {
  list-style: none;
  padding: 0;
}

.stage2-list li {
  margin: 1rem 0;
}

.stage2-list a {
  color: #333;
  text-decoration: none;
  font-size: 1.2rem;
}

.stage2-list a:hover {
  text-decoration: underline;
}
</style>
