<template>
  <div class="api-test-container">
    <a-form
      :model="testForm"
      label-align="left"
      :label-col-props="{ span: 6 }"
      :wrapper-col-props="{ span: 18 }"
      class="settings-form"
      @submit="handleTestSubmit"
    >
      <a-form-item
        field="ip_address"
        label="IP地址"
        :rules="[
          { required: true, message: '请输入IP地址' },
          {
            validator: (value: any) => {
              const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;
              if (!ipRegex.test(value)) {
                return '请输入有效的IP地址格式';
              }
              return '';
            }
          }
        ]"
      >
        <a-input
          v-model="testForm.ip_address"
          placeholder="请输入要测试的IP地址，如：8.8.8.8"
          :max-length="15"
        />
        <template #help>
          输入要测试地理位置查询的IP地址，系统将调用ipinfo.io API进行测试。
        </template>
      </a-form-item>

      <a-form-item>
        <a-space>
          <a-button type="primary" html-type="submit" :loading="loading">
            测试API
          </a-button>
          <a-button @click="handleClear"> 清空 </a-button>
        </a-space>
      </a-form-item>
    </a-form>

    <!-- 测试结果显示区域 -->
    <a-card
      v-if="testResult"
      title="测试结果"
      :bordered="false"
      class="result-card"
    >
      <a-descriptions :data="resultData" bordered :column="1" />
    </a-card>

    <!-- 错误信息显示 -->
    <a-alert
      v-if="errorMessage"
      type="error"
      :message="errorMessage"
      class="error-alert"
      closable
      @close="errorMessage = ''"
    />
  </div>
</template>

<script lang="ts" setup>
  import { reactive, ref, computed } from 'vue';
  import useLoading from '@/hooks/loading';
  import { Message } from '@arco-design/web-vue';

  const { loading, setLoading } = useLoading(false);

  const testForm = reactive({
    ip_address: '',
  });

  const testResult = ref<any>(null);
  const errorMessage = ref('');

  const resultData = computed(() => {
    if (!testResult.value) return [];

    return [
      { label: 'IP地址', value: testResult.value.ip || '-' },
      { label: '主机名', value: testResult.value.hostname || '-' },
      { label: '城市', value: testResult.value.city || '-' },
      { label: '地区', value: testResult.value.region || '-' },
      { label: '国家', value: testResult.value.country || '-' },
      { label: '经纬度', value: testResult.value.loc || '-' },
      { label: '组织', value: testResult.value.org || '-' },
      { label: '邮编', value: testResult.value.postal || '-' },
      { label: '时区', value: testResult.value.timezone || '-' },
    ];
  });

  const handleTestSubmit = async () => {
    if (!testForm.ip_address.trim()) {
      Message.warning('请输入IP地址');
      return;
    }

    // 验证IP地址格式
    const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;
    if (!ipRegex.test(testForm.ip_address.trim())) {
      Message.warning('请输入有效的IP地址格式');
      return;
    }

    try {
      setLoading(true);
      errorMessage.value = '';
      testResult.value = null;

      // 调用后端API测试接口
      const response = await fetch('/api/admin/test-geolocation-api', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ip_address: testForm.ip_address.trim(),
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || 'API测试失败');
      }

      if (data.success) {
        testResult.value = data.data;
        Message.success('API测试成功');
      } else {
        throw new Error(data.message || 'API返回错误');
      }
    } catch (error: any) {
      errorMessage.value = error.message || '测试失败，请重试';
      Message.error(errorMessage.value);
    } finally {
      setLoading(false);
    }
  };

  const handleClear = () => {
    testForm.ip_address = '';
    testResult.value = null;
    errorMessage.value = '';
  };
</script>

<style lang="less" scoped>
  .api-test-container {
    padding: 20px 0;
  }

  .settings-form {
    max-width: 800px;
  }

  .result-card {
    max-width: 800px;
    margin-top: 20px;
  }

  .error-alert {
    max-width: 800px;
    margin-top: 20px;
  }
</style>
