<template>
  <BModal
    :visible="visible"
    title="添加账号"
    :width="520"
    @close="handleClose"
  >
    <Login
      v-if="visible"
      mode="modal"
      @login-success="handleSuccess"
    />
  </BModal>
</template>

<script setup lang="ts">
import BModal from "./BModal.vue";
import Login from "@/views/Login.vue";
import toast from "@/utils/toast";

const props = defineProps<{ visible: boolean }>();

const emit = defineEmits<{
  (e: "close"): void;
}>();

function handleClose() {
  emit("close");
}

function handleSuccess(payload: { accountId: string; nickname: string }) {
  toast.success(`账号 ${payload.nickname} 已添加`);
  emit("close");
}
</script>
