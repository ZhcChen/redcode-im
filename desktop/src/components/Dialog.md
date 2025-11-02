# Dialog 组件

一个功能完整的弹窗组件，支持自定义标题、内容和交互行为。

## 特性

- ✅ 全屏黑灰透明蒙版
- ✅ 居中显示的弹窗
- ✅ 渐变背景色（#E7FFF7 到 #FFFFFF）
- ✅ 16px 圆角，内边距上下 20px 左右 24px
- ✅ 标题和关闭按钮
- ✅ 平滑的显示/隐藏动画
- ✅ 可配置是否点击蒙版关闭
- ✅ 响应式设计
- ✅ TypeScript 支持

## 基础用法

```vue
<template>
  <div>
    <button @click="showDialog = true">打开弹窗</button>
    
    <Dialog v-model="showDialog" title="我的弹窗">
      <p>这里是弹窗内容</p>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import Dialog from '@/components/Dialog.vue'

const showDialog = ref(false)
</script>
```

## Props

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `modelValue` | `boolean` | - | 是否显示弹窗（必需，支持 v-model） |
| `title` | `string` | `'提示'` | 弹窗标题 |
| `closeOnOverlay` | `boolean` | `true` | 是否可以通过点击蒙版关闭弹窗 |

## Events

| 事件名 | 参数 | 说明 |
|--------|------|------|
| `update:modelValue` | `(value: boolean)` | 弹窗显示状态改变时触发 |
| `close` | - | 弹窗关闭时触发 |

## Slots

| 插槽名 | 说明 |
|--------|------|
| `default` | 弹窗内容区域 |

## 方法

通过 ref 可以调用以下方法：

| 方法名 | 参数 | 说明 |
|--------|------|------|
| `close` | - | 关闭弹窗 |

```vue
<template>
  <Dialog ref="dialogRef" v-model="showDialog" title="我的弹窗">
    <button @click="closeDialog">关闭弹窗</button>
  </Dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import Dialog from '@/components/Dialog.vue'

const dialogRef = ref()
const showDialog = ref(false)

const closeDialog = () => {
  dialogRef.value?.close()
}
</script>
```

## 高级用法

### 禁止点击蒙版关闭

```vue
<Dialog 
  v-model="showDialog" 
  title="重要提示"
  :close-on-overlay="false"
>
  <p>此弹窗只能通过关闭按钮关闭</p>
</Dialog>
```

### 监听关闭事件

```vue
<Dialog 
  v-model="showDialog" 
  title="我的弹窗"
  @close="onDialogClose"
>
  <p>弹窗内容</p>
</Dialog>

<script setup lang="ts">
const onDialogClose = () => {
  console.log('弹窗已关闭')
  // 执行清理操作
}
</script>
```

### 复杂内容

```vue
<Dialog v-model="showDialog" title="用户设置">
  <form @submit.prevent="handleSubmit">
    <div class="form-group">
      <label>用户名：</label>
      <input v-model="username" type="text" />
    </div>
    
    <div class="form-actions">
      <button type="button" @click="showDialog = false">取消</button>
      <button type="submit">保存</button>
    </div>
  </form>
</Dialog>
```

## 样式自定义

组件使用了项目的全局样式变量，如需自定义样式，可以通过以下方式：

```scss
// 自定义弹窗样式
:deep(.dialog-container) {
  max-width: 600px;
  // 其他自定义样式
}

// 自定义标题样式
:deep(.dialog-title) {
  color: #333;
  font-size: 20px;
}
```

## 注意事项

1. 组件使用 `Teleport` 将弹窗渲染到 `body` 元素下，确保正确的层级关系
2. 弹窗具有最高的 z-index (9999)，确保显示在其他内容之上
3. 支持键盘 ESC 键关闭（可通过监听 keydown 事件实现）
4. 在移动端会自动适配，提供更好的用户体验

## 示例

完整的使用示例请查看 `src/examples/DialogExample.vue` 文件。
