<template>
  <div class="emoji-picker" v-if="show">
    <div class="emoji-grid">
      <div
        v-for="emoji in emojiList"
        :key="emoji.code"
        class="emoji-item"
        @click="selectEmoji(emoji)"
        :title="emoji.name"
      >
        {{ emoji.emoji }}
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, defineEmits, defineProps } from 'vue'

interface Emoji {
  emoji: string
  code: string
  name: string
}

// Props
const props = defineProps<{
  show: boolean
}>()

// Emits
const emit = defineEmits<{
  select: [emoji: string]
  close: []
}>()

// 常用表情列表
const emojiList = ref<Emoji[]>([
  { emoji: '😀', code: 'grinning', name: '开心' },
  { emoji: '😃', code: 'grinning_big', name: '大笑' },
  { emoji: '😄', code: 'grinning_squinting', name: '眯眼笑' },
  { emoji: '😁', code: 'beaming', name: '露齿笑' },
  { emoji: '😆', code: 'laughing', name: '哈哈' },
  { emoji: '😅', code: 'grinning_sweat', name: '苦笑' },
  { emoji: '🤣', code: 'rolling_laughing', name: '捧腹大笑' },
  { emoji: '😂', code: 'joy', name: '笑哭' },
  { emoji: '🙂', code: 'slightly_smiling', name: '微笑' },
  { emoji: '🙃', code: 'upside_down', name: '颠倒笑脸' },
  { emoji: '😉', code: 'winking', name: '眨眼' },
  { emoji: '😊', code: 'blush', name: '害羞' },
  { emoji: '😇', code: 'innocent', name: '天真' },
  { emoji: '🥰', code: 'smiling_hearts', name: '花痴' },
  { emoji: '😍', code: 'heart_eyes', name: '心形眼' },
  { emoji: '🤩', code: 'star_struck', name: '星星眼' },
  { emoji: '😘', code: 'kissing_heart', name: '飞吻' },
  { emoji: '😗', code: 'kissing', name: '亲吻' },
  { emoji: '☺️', code: 'relaxed', name: '满足' },
  { emoji: '😚', code: 'kissing_closed_eyes', name: '闭眼亲吻' },
  { emoji: '😙', code: 'kissing_smiling_eyes', name: '眯眼亲吻' },
  { emoji: '🥲', code: 'smiling_tear', name: '含泪微笑' },
  { emoji: '😋', code: 'yum', name: '美味' },
  { emoji: '😛', code: 'stuck_out_tongue', name: '吐舌' },
  { emoji: '😜', code: 'stuck_out_tongue_winking', name: '眨眼吐舌' },
  { emoji: '🤪', code: 'zany', name: '疯狂' },
  { emoji: '😝', code: 'stuck_out_tongue_closed_eyes', name: '闭眼吐舌' },
  { emoji: '🤑', code: 'money_mouth', name: '财迷' },
  { emoji: '🤗', code: 'hugs', name: '拥抱' },
  { emoji: '🤭', code: 'hand_over_mouth', name: '捂嘴' },
  { emoji: '🤫', code: 'shushing', name: '嘘' },
  { emoji: '🤔', code: 'thinking', name: '思考' },
  { emoji: '🤐', code: 'zipper_mouth', name: '闭嘴' },
  { emoji: '🤨', code: 'raised_eyebrow', name: '质疑' },
  { emoji: '😐', code: 'neutral', name: '面无表情' },
  { emoji: '😑', code: 'expressionless', name: '木然' },
  { emoji: '😶', code: 'no_mouth', name: '无言' },
  { emoji: '😏', code: 'smirk', name: '得意' },
  { emoji: '😒', code: 'unamused', name: '不悦' },
  { emoji: '🙄', code: 'eye_roll', name: '翻白眼' },
  { emoji: '😬', code: 'grimacing', name: '做鬼脸' },
  { emoji: '🤥', code: 'lying', name: '撒谎' },
  { emoji: '😔', code: 'pensive', name: '沉思' },
  { emoji: '😪', code: 'sleepy', name: '困倦' },
  { emoji: '🤤', code: 'drooling', name: '流口水' },
  { emoji: '😴', code: 'sleeping', name: '睡觉' },
  { emoji: '😷', code: 'mask', name: '口罩' },
  { emoji: '🤒', code: 'thermometer_face', name: '发烧' },
  { emoji: '🤕', code: 'head_bandage', name: '受伤' },
  { emoji: '🤢', code: 'nauseated', name: '恶心' },
  { emoji: '🤮', code: 'vomiting', name: '呕吐' },
  { emoji: '🤧', code: 'sneezing', name: '打喷嚏' },
  { emoji: '🥵', code: 'hot', name: '热' },
  { emoji: '🥶', code: 'cold', name: '冷' },
  { emoji: '🥴', code: 'woozy', name: '头晕' },
  { emoji: '😵', code: 'dizzy_face', name: '晕' },
  { emoji: '🤯', code: 'exploding_head', name: '震惊' },
  { emoji: '🤠', code: 'cowboy', name: '牛仔' },
  { emoji: '🥳', code: 'partying', name: '庆祝' },
  { emoji: '🥸', code: 'disguised', name: '伪装' },
  { emoji: '😎', code: 'sunglasses', name: '墨镜' },
  { emoji: '🤓', code: 'nerd', name: '书呆子' },
  { emoji: '🧐', code: 'monocle', name: '单片眼镜' },
  { emoji: '😕', code: 'confused', name: '困惑' },
  { emoji: '😟', code: 'worried', name: '担心' },
  { emoji: '🙁', code: 'frowning', name: '皱眉' },
  { emoji: '☹️', code: 'frowning2', name: '皱眉2' },
  { emoji: '😮', code: 'open_mouth', name: '张嘴' },
  { emoji: '😯', code: 'hushed', name: '惊讶' },
  { emoji: '😲', code: 'astonished', name: '震惊' },
  { emoji: '😳', code: 'flushed', name: '脸红' },
  { emoji: '🥺', code: 'pleading', name: '恳求' },
  { emoji: '😦', code: 'frowning_open_mouth', name: '皱眉张嘴' },
  { emoji: '😧', code: 'anguished', name: '痛苦' },
  { emoji: '😨', code: 'fearful', name: '恐惧' },
  { emoji: '😰', code: 'cold_sweat', name: '冷汗' },
  { emoji: '😥', code: 'disappointed_relieved', name: '失望但放心' },
  { emoji: '😢', code: 'cry', name: '哭泣' },
  { emoji: '😭', code: 'sob', name: '大哭' },
  { emoji: '😱', code: 'scream', name: '尖叫' },
  { emoji: '😖', code: 'confounded', name: '困扰' },
  { emoji: '😣', code: 'persevere', name: '坚持' },
  { emoji: '😞', code: 'disappointed', name: '失望' },
  { emoji: '😓', code: 'sweat', name: '汗' },
  { emoji: '😩', code: 'weary', name: '疲惫' },
  { emoji: '😫', code: 'tired_face', name: '累' },
  { emoji: '🥱', code: 'yawning', name: '打哈欠' },
  { emoji: '😤', code: 'triumph', name: '胜利' },
  { emoji: '😡', code: 'rage', name: '愤怒' },
  { emoji: '😠', code: 'angry', name: '生气' },
  { emoji: '🤬', code: 'swearing', name: '骂人' },
  { emoji: '👍', code: 'thumbs_up', name: '点赞' },
  { emoji: '👎', code: 'thumbs_down', name: '点踩' },
  { emoji: '👏', code: 'clap', name: '鼓掌' },
  { emoji: '🙏', code: 'pray', name: '祈祷' },
  { emoji: '❤️', code: 'heart', name: '红心' },
  { emoji: '💔', code: 'broken_heart', name: '心碎' },
  { emoji: '💕', code: 'two_hearts', name: '双心' },
  { emoji: '💖', code: 'sparkling_heart', name: '闪亮心' },
  { emoji: '💗', code: 'growing_heart', name: '成长心' },
  { emoji: '💘', code: 'cupid', name: '丘比特' },
  { emoji: '💙', code: 'blue_heart', name: '蓝心' },
  { emoji: '💚', code: 'green_heart', name: '绿心' },
  { emoji: '💛', code: 'yellow_heart', name: '黄心' },
  { emoji: '🧡', code: 'orange_heart', name: '橙心' },
  { emoji: '💜', code: 'purple_heart', name: '紫心' },
  { emoji: '🖤', code: 'black_heart', name: '黑心' },
  { emoji: '🤍', code: 'white_heart', name: '白心' },
  { emoji: '🤎', code: 'brown_heart', name: '棕心' },
  { emoji: '💯', code: 'hundred', name: '100' },
  { emoji: '💢', code: 'anger', name: '愤怒符号' },
  { emoji: '💥', code: 'boom', name: '爆炸' },
  { emoji: '💫', code: 'dizzy', name: '眩晕' },
  { emoji: '💦', code: 'sweat_drops', name: '汗滴' },
  { emoji: '💨', code: 'dash', name: '风' },
  { emoji: '🕳️', code: 'hole', name: '洞' },
  { emoji: '💤', code: 'zzz', name: 'ZZZ' },
  { emoji: '👋', code: 'wave', name: '挥手' },
  { emoji: '🤚', code: 'raised_back_of_hand', name: '手背' },
  { emoji: '🖐️', code: 'hand_splayed', name: '张开手' },
  { emoji: '✋', code: 'raised_hand', name: '举手' },
  { emoji: '🖖', code: 'vulcan', name: '瓦肯手势' },
  { emoji: '👌', code: 'ok_hand', name: 'OK' },
  { emoji: '🤌', code: 'pinched_fingers', name: '捏手指' },
  { emoji: '🤏', code: 'pinching_hand', name: '捏' },
  { emoji: '✌️', code: 'peace', name: '和平' },
  { emoji: '🤞', code: 'fingers_crossed', name: '交叉手指' },
  { emoji: '🤟', code: 'love_you', name: '爱你' },
  { emoji: '🤘', code: 'rock', name: '摇滚' },
  { emoji: '🤙', code: 'call_me', name: '打电话' },
  { emoji: '👈', code: 'point_left', name: '左指' },
  { emoji: '👉', code: 'point_right', name: '右指' },
  { emoji: '👆', code: 'point_up_2', name: '上指' },
  { emoji: '🖕', code: 'middle_finger', name: '中指' },
  { emoji: '👇', code: 'point_down', name: '下指' },
  { emoji: '☝️', code: 'point_up', name: '食指' },
  { emoji: '✊', code: 'fist', name: '拳头' },
  { emoji: '👊', code: 'punch', name: '出拳' },
  { emoji: '🤛', code: 'left_fist', name: '左拳' },
  { emoji: '🤜', code: 'right_fist', name: '右拳' }
])

// 选择表情
const selectEmoji = (emoji: Emoji) => {
  emit('select', emoji.emoji)
  emit('close')
}
</script>

<style lang="scss" scoped>
.emoji-picker {
  position: absolute;
  bottom: 100%;
  left: 0; // 改为左侧对齐，因为表情按钮在左边
  margin-bottom: 8px;
  width: 280px;
  max-height: 200px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  z-index: 1000;
  overflow: hidden;
}

.emoji-grid {
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  gap: 4px;
  padding: 12px;
  max-height: 200px;
  overflow-y: auto;

  // 滚动条样式
  &::-webkit-scrollbar {
    width: 4px;
  }

  &::-webkit-scrollbar-track {
    background: #f1f1f1;
  }

  &::-webkit-scrollbar-thumb {
    background: #c1c1c1;
    border-radius: 2px;
  }
}

.emoji-item {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 18px;
  transition: background-color 0.2s;

  &:hover {
    background-color: #f5f5f5;
  }

  &:active {
    background-color: #e0e0e0;
  }
}
</style>