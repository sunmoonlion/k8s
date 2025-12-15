<template>
  <div class="stage1-article">
    <article v-if="article">
      <ContentRenderer :value="article" />
    </article>
    <div v-else>
      <h1>Article not found</h1>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({
  layout: 'default'
})

const route = useRoute()
const slug = route.params.slug as string[]

// 获取所有 stage1 文章
const { data: allArticles } = await useAsyncData('all-stage1-articles', () =>
  queryContent('/stage1').find()
)

// 根据 URL slug 匹配文章
// 由于中文路径在 URL 中可能被编码，需要尝试多种匹配方式
const urlSlug = slug.join('/')

const { data: article } = await useAsyncData(`stage1-${urlSlug}`, () => {
  if (!allArticles.value) return null
  
  // 遍历所有文章，尝试匹配
  for (const item of allArticles.value) {
    const itemPath = item._path || ''
    
    // 提取文件名（去掉 /stage1/ 前缀和 .md 后缀）
    const fileName = itemPath.replace(/^\/stage1\//, '').replace(/\.md$/, '')
    
    // 方式1: 如果文章有 slug 字段，优先使用 slug 匹配
    if (item.slug && item.slug === urlSlug) {
      return item
    }
    
    // 方式2: 直接匹配文件名
    if (fileName === urlSlug) {
      return item
    }
    
    // 方式3: URL 解码后匹配（处理浏览器自动编码的情况）
    try {
      const decodedSlug = decodeURIComponent(urlSlug)
      const decodedFileName = decodeURIComponent(fileName)
      
      if (fileName === decodedSlug || decodedFileName === urlSlug) {
        return item
      }
    } catch (e) {
      // 忽略解码错误
    }
    
    // 方式4: 模糊匹配（包含关系）
    if (fileName.includes(urlSlug) || urlSlug.includes(fileName)) {
      return item
    }
  }
  
  return null
})

// 如果找不到，返回 404
if (!article.value) {
  throw createError({
    statusCode: 404,
    statusMessage: `Article not found: ${urlSlug}`
  })
}
</script>

<style scoped>
.stage1-article {
  padding: 2rem;
  max-width: 800px;
  margin: 0 auto;
}

/* 标题样式 - 确保标题和正文之间有两个空行的间距 */
.stage1-article :deep(h1) {
  font-size: 2rem;
  margin-bottom: 3rem !important; /* 标题和正文之间两个空行的间距 */
}

/* 针对包含标题的 div 也设置间距 */
.stage1-article :deep(div[style*="text-align: center"]) {
  margin-bottom: 3rem !important;
}

/* 段落首行缩进 2 个字符 - 符合中文排版惯例 */
.stage1-article :deep(p) {
  margin-bottom: 1rem;
  line-height: 1.6;
  text-indent: 2em; /* 2 个字符的缩进 */
}

/* 确保第一个段落（正文开始）有足够的上边距 */
.stage1-article :deep(article > p:first-of-type),
.stage1-article :deep(article > div + p) {
  margin-top: 0;
}

/* 排除居中的标题段落不缩进 */
.stage1-article :deep(p[style*="text-align: center"]) {
  text-indent: 0;
}

/* 排除称呼类短句（包含"工会："等称呼的段落）不缩进 */
.stage1-article :deep(p:has(> span.no-indent)),
.stage1-article :deep(p.no-indent) {
  text-indent: 0;
}

/* 列表项也保持首行缩进 */
.stage1-article :deep(li) {
  text-indent: 2em;
}
</style>
