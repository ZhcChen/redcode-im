<template>
  <a-spin :loading="loading" style="width: 100%">
    <a-card
      class="general-card"
      :header-style="{ paddingBottom: '0' }"
      :body-style="{ padding: '17px 20px 21px 20px' }"
    >
      <template #title>
        {{ $t('workplace.popularContent') }}
      </template>
      <template #extra>
        <a-link>{{ $t('workplace.viewMore') }}</a-link>
      </template>
      <a-space direction="vertical" :size="10" fill>
        <a-radio-group
          v-model:model-value="type"
          type="button"
          @change="typeChange as any"
        >
          <a-radio value="text">
            {{ $t('workplace.popularContent.text') }}
          </a-radio>
          <a-radio value="image">
            {{ $t('workplace.popularContent.image') }}
          </a-radio>
          <a-radio value="video">
            {{ $t('workplace.popularContent.video') }}
          </a-radio>
        </a-radio-group>
        <a-table
          :data="renderList"
          :pagination="false"
          :bordered="false"
          :scroll="{ x: '100%', y: '264px' }"
        >
          <template #columns>
            <a-table-column
              :title="t('workplace.popularContent.table.rank')"
              data-index="key"
            ></a-table-column>
            <a-table-column
              :title="t('workplace.popularContent.table.title')"
              data-index="title"
            >
              <template #cell="{ record }">
                <a-typography-paragraph
                  :ellipsis="{
                    rows: 1,
                  }"
                >
                  {{ record.title }}
                </a-typography-paragraph>
              </template>
            </a-table-column>
            <a-table-column
              :title="t('workplace.popularContent.table.clicks')"
              data-index="clickNumber"
            >
            </a-table-column>
            <a-table-column
              :title="t('workplace.popularContent.table.dailyGrowth')"
              data-index="increases"
              :sortable="{
                sortDirections: ['ascend', 'descend'],
              }"
            >
              <template #cell="{ record }">
                <div class="increases-cell">
                  <span>{{ record.increases }}%</span>
                  <icon-caret-up
                    v-if="record.increases !== 0"
                    style="color: #f53f3f; font-size: 8px"
                  />
                </div>
              </template>
            </a-table-column>
          </template>
        </a-table>
      </a-space>
    </a-card>
  </a-spin>
</template>

<script lang="ts" setup>
  import { onMounted, onUnmounted, ref } from 'vue';
  import { useI18n } from 'vue-i18n';
  import useLoading from '@/hooks/loading';
  import { getPopularContent } from '@/api/dashboard';

  interface PopularRecord {
    key: number;
    clickNumber: string;
    title: string;
    increases: number;
  }

  const { t } = useI18n();

  const queryPopularList = async (contentType: string = 'text') => {
    try {
      const response = await getPopularContent();
      const data =
        response.data[contentType as keyof typeof response.data] || [];
      const formattedData: PopularRecord[] = data.map((item, index) => ({
        key: index + 1,
        clickNumber: item.clickNumber,
        title: item.title,
        increases: item.increases,
      }));
      return { data: formattedData };
    } catch (error) {
      console.warn('failed to fetch popular content, using mock data', error);
      const data: PopularRecord[] = [
        {
          key: 1,
          clickNumber: '1234',
          title: t('workplace.popularContent.sample.1'),
          increases: 12,
        },
        {
          key: 2,
          clickNumber: '567',
          title: t('workplace.popularContent.sample.2'),
          increases: -5,
        },
        {
          key: 3,
          clickNumber: '890',
          title: t('workplace.popularContent.sample.3'),
          increases: 8,
        },
      ];
      return { data };
    }
  };

  const type = ref('text');
  const { loading, setLoading } = useLoading();
  const renderList = ref<PopularRecord[]>();
  let timer: number | null = null;

  const fetchData = async () => {
    try {
      setLoading(true);
      const { data } = await queryPopularList(type.value);
      renderList.value = data as any;
    } catch (err) {
      // you can report use errorHandler or other
    } finally {
      setLoading(false);
    }
  };

  const typeChange = (contentType: string) => {
    fetchData();
  };

  onMounted(() => {
    fetchData();
    timer = window.setInterval(fetchData, 3000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>

<style scoped lang="less">
  .general-card {
    min-height: 395px;
  }

  :deep(.arco-table-tr) {
    height: 44px;

    .arco-typography {
      margin-bottom: 0;
    }
  }

  .increases-cell {
    display: flex;
    align-items: center;

    span {
      margin-right: 4px;
    }
  }
</style>
