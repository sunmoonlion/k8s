export function useAudioPlayer(lists) {
  const current = ref(0)
  const mode = ref(0)
  const oldIndex = ref([] as number[])

  const rand = (current, length) => {
    let num
    do {
      num = Math.floor(Math.random() * length)
    } while (num === current)
    return num
  }

  const handleNext = () => {
    // 普通列表模式
    if (mode.value === 0) {
      current.value = current.value + 1 >= lists.length ? lists.length - 1 : current.value + 1
    }
    // 列表循环模式
    if (mode.value === 1) {
      current.value = (current.value + 1) % lists.length
    }
    // 随机循环模式
    if (mode.value === 3) {
      if (oldIndex.value.length === 0) {
        oldIndex.value.push(current.value)
      }
      current.value = rand(current.value, lists.length)
      oldIndex.value.push(current.value)
    }
  }
  const handlePrev = () => {
    if (mode.value === 0) {
      current.value = current.value - 1 < 0 ? 0 : current.value - 1
    }
    // 列表循环模式
    if (mode.value === 1) {
      current.value = current.value - 1 < 0 ? lists.length - 1 : current.value - 1
    }
    // 随机循环模式
    if (mode.value === 3) {
      if (oldIndex.value.length) {
        // 拿到刚刚的current
        const tmp = oldIndex.value.pop() as number
        if (tmp === current.value) {
          if (oldIndex.value.length) {
            current.value = oldIndex.value.pop() as number
          } else {
            current.value = rand(tmp, lists.length)
          }
        } else {
          current.value = tmp
        }
      } else {
        current.value = rand(current.value, lists.length)
        // oldIndex.value.push(current.value)
      }
    }
  }
  const handleMode = (index: number) => {
    mode.value = index
    // 随机模式
    if (mode.value === 3) {
      oldIndex.value.push(current.value)
    } else {
      oldIndex.value = []
    }
  }

  return {
    current,
    mode,
    handlePrev,
    handleNext,
    handleMode
  }
}
