<template>
  <div class="report-view">
    <!-- 顶部标题栏 -->
    <header class="header">
      <div class="header-content">
        <button @click="router.push('/')" class="back-btn">
          返回
        </button>
        <h1 class="page-title">工作报告</h1>
      </div>
    </header>

    <!-- 主内容区 -->
    <main class="main-content">
      <!-- 时间范围选择 -->
      <div class="period-selector">
        <button 
          :class="['period-btn', { active: reportPeriod === 'week' }]"
          @click="reportPeriod = 'week'; loadReport()"
        >本周</button>
        <button 
          :class="['period-btn', { active: reportPeriod === 'month' }]"
          @click="reportPeriod = 'month'; loadReport()"
        >本月</button>
        <button 
          :class="['period-btn', { active: reportPeriod === 'year' }]"
          @click="reportPeriod = 'year'; loadReport()"
        >本年</button>
      </div>

      <!-- 时间显示 -->
      <div class="period-display">
        {{ periodDisplayText }}
      </div>

      <!-- 统计卡片 -->
      <div class="stats-grid" v-if="reportData.length > 0">
        <div class="stat-card card">
          <div class="stat-value">{{ reportData.length }}</div>
          <div class="stat-label">总记录数</div>
        </div>
        <div class="stat-card card">
          <div class="stat-value">{{ reportDays }}</div>
          <div class="stat-label">记录天数</div>
        </div>
        <div class="stat-card card">
          <div class="stat-value">{{ avgPerDay }}</div>
          <div class="stat-label">日均记录</div>
        </div>
      </div>

      <!-- 记录列表 -->
      <div class="report-content" v-if="reportData.length > 0">
        <div 
          v-for="(records, date) in groupedRecords" 
          :key="date"
          class="date-group"
        >
          <h3 class="date-header">{{ date }} ({{ records.length }} 条)</h3>
          <div 
            v-for="record in records" 
            :key="record.id"
            class="record-item"
          >
            <span class="record-time">{{ formatTime(record.created_at) }}</span>
            <span class="record-content">{{ record.content }}</span>
          </div>
        </div>
      </div>

      <div v-else class="empty-state">
        <p>该时间范围内暂无记录</p>
      </div>

      <!-- 导出按钮 -->
      <div class="export-actions" v-if="reportData.length > 0">
        <button @click="exportToMarkdown" class="btn-secondary">
          导出 Markdown
        </button>
        <button @click="exportToExcel" class="btn-primary">
          导出 Excel
        </button>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const router = useRouter()
const reportPeriod = ref('week')
const reportData = ref([])
const reportDays = ref(0)
const userId = ref(localStorage.getItem('userId') || '')

const periodDisplayText = computed(() => {
  const now = new Date()
  if (reportPeriod.value === 'week') {
    const weekNum = getWeekNumber(now)
    return `${now.getFullYear()} 年第 ${weekNum} 周`
  } else if (reportPeriod.value === 'month') {
    return `${now.getFullYear()} 年 ${now.getMonth() + 1} 月`
  } else {
    return `${now.getFullYear()} 年`
  }
})

const avgPerDay = computed(() => {
  if (reportDays.value === 0) return 0
  return (reportData.value.length / reportDays.value).toFixed(1)
})

const groupedRecords = computed(() => {
  const grouped = {}
  reportData.value.forEach(record => {
    if (!grouped[record.record_date]) {
      grouped[record.record_date] = []
    }
    grouped[record.record_date].push(record)
  })
  return grouped
})

const getWeekNumber = (date) => {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
  const dayNum = d.getUTCDay() || 7
  d.setUTCDate(d.getUTCDate() + 4 - dayNum)
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
  return Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
}

const getDateRange = () => {
  const now = new Date()
  let startDate, endDate
  
  if (reportPeriod.value === 'week') {
    const day = now.getDay() || 7
    startDate = new Date(now)
    startDate.setDate(now.getDate() - day + 1)
    endDate = new Date(startDate)
    endDate.setDate(startDate.getDate() + 6)
  } else if (reportPeriod.value === 'month') {
    startDate = new Date(now.getFullYear(), now.getMonth(), 1)
    endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0)
  } else {
    startDate = new Date(now.getFullYear(), 0, 1)
    endDate = new Date(now.getFullYear(), 11, 31)
  }
  
  return {
    start: formatDate(startDate),
    end: formatDate(endDate)
  }
}

const loadReport = async () => {
  const { start, end } = getDateRange()
  
  const { data, error } = await supabase
    .from('records')
    .select('*')
    .eq('user_id', userId.value)
    .gte('record_date', start)
    .lte('record_date', end)
    .order('record_date', { ascending: true })
    .order('created_at', { ascending: true })
  
  if (error) {
    console.error('加载报告数据失败:', error)
    alert('加载失败：' + error.message)
  } else {
    reportData.value = data
    
    // 统计天数
    const daysSet = new Set(data.map(r => r.record_date))
    reportDays.value = daysSet.size
  }
}

const exportToMarkdown = () => {
  if (reportData.value.length === 0) {
    alert('没有记录可导出')
    return
  }
  
  let markdown = `# 工作报告\n\n`
  markdown += `**时间范围：** ${periodDisplayText.value}\n`
  markdown += `**总记录数：** ${reportData.value.length}\n`
  markdown += `**记录天数：** ${reportDays.value}\n`
  markdown += `**日均记录：** ${avgPerDay.value}\n\n`
  markdown += `---\n\n`
  
  // 按日期分组
  Object.keys(groupedRecords.value).sort().forEach(date => {
    markdown += `## ${date}\n\n`
    groupedRecords.value[date].forEach(record => {
      const time = formatTime(record.created_at)
      markdown += `- **${time}** ${record.content}\n`
    })
    markdown += `\n`
  })
  
  // 下载
  const blob = new Blob([markdown], { type: 'text/markdown' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `工作报告_${periodDisplayText.value.replace(/\s/g, '_')}.md`
  a.click()
  URL.revokeObjectURL(url)
}

const exportToExcel = () => {
  if (reportData.value.length === 0) {
    alert('没有记录可导出')
    return
  }
  
  // 生成 CSV (Excel 可以直接打开)
  let csv = '\uFEFF' // BOM for Chinese encoding
  csv += '日期,时间,内容\n'
  
  reportData.value.forEach(record => {
    const time = formatTime(record.created_at)
    const content = record.content.replace(/"/g, '""') // Escape quotes
    csv += `${record.record_date},${time},"${content}"\n`
  })
  
  // 下载
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `工作报告_${periodDisplayText.value.replace(/\s/g, '_')}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

const formatDate = (date) => {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const formatTime = (datetime) => {
  return new Date(datetime).toLocaleTimeString('zh-CN', { 
    hour: '2-digit', 
    minute: '2-digit' 
  })
}

onMounted(() => {
  if (!userId.value) {
    router.push('/onboarding')
    return
  }
  
  loadReport()
})
</script>

<style scoped>
.report-view {
  min-height: 100vh;
  background: var(--bg-page);
}

/* 顶部标题栏 */
.header {
  background: var(--bg-card);
  border-bottom: 1px solid var(--border-color);
  position: sticky;
  top: 0;
  z-index: 100;
}

.header-content {
  max-width: 900px;
  margin: 0 auto;
  padding: 20px 24px;
  display: flex;
  align-items: center;
  gap: 20px;
}

.back-btn {
  padding: 8px 16px;
  background: transparent;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 14px;
  color: var(--text-secondary);
  transition: all 0.2s;
}

.back-btn:hover {
  border-color: var(--accent-color);
  color: var(--accent-color);
}

.page-title {
  font-size: 20px;
  font-weight: 600;
  color: var(--text-primary);
}

/* 主内容区 */
.main-content {
  max-width: 900px;
  margin: 0 auto;
  padding: 32px 24px;
}

/* 时间范围选择 */
.period-selector {
  display: flex;
  gap: 12px;
  margin-bottom: 24px;
}

.period-btn {
  flex: 1;
  padding: 10px 20px;
  border: 1px solid var(--border-color);
  background: var(--bg-card);
  color: var(--text-secondary);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 15px;
  font-weight: 500;
  transition: all 0.2s;
}

.period-btn:hover {
  border-color: var(--accent-color);
  color: var(--accent-color);
}

.period-btn.active {
  background: var(--accent-color);
  color: white;
  border-color: var(--accent-color);
}

/* 时间显示 */
.period-display {
  text-align: center;
  padding: 16px 20px;
  background: var(--bg-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-color);
  color: var(--text-primary);
  font-size: 16px;
  font-weight: 500;
  margin-bottom: 32px;
}

/* 统计卡片 */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin-bottom: 32px;
}

.stat-card {
  padding: 24px 20px;
  text-align: center;
  transition: all 0.2s;
}

.stat-card:hover {
  box-shadow: var(--shadow-md);
}

.stat-value {
  font-size: 36px;
  font-weight: 600;
  color: var(--accent-color);
  margin-bottom: 8px;
  line-height: 1;
}

.stat-label {
  font-size: 14px;
  color: var(--text-secondary);
  font-weight: 500;
}

/* 记录列表 */
.report-content {
  margin-bottom: 32px;
}

.date-group {
  margin-bottom: 28px;
}

.date-header {
  color: var(--text-primary);
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 16px;
  padding-bottom: 10px;
  border-bottom: 2px solid var(--border-color);
}

.record-item {
  display: flex;
  gap: 16px;
  padding: 14px 16px;
  border-left: 3px solid var(--accent-color);
  background: var(--bg-card);
  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  margin-bottom: 10px;
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-color);
  border-left: 3px solid var(--accent-color);
}

.record-time {
  color: var(--text-secondary);
  font-size: 14px;
  min-width: 50px;
  font-weight: 500;
}

.record-content {
  color: var(--text-primary);
  font-size: 15px;
  line-height: 1.5;
}

/* 空状态 */
.empty-state {
  text-align: center;
  padding: 60px 20px;
  background: var(--bg-card);
  border-radius: var(--radius-md);
  border: 1px solid var(--border-color);
  margin-bottom: 32px;
}

.empty-state p {
  color: var(--text-secondary);
  font-size: 16px;
}

/* 导出按钮 */
.export-actions {
  display: flex;
  gap: 12px;
  position: sticky;
  bottom: 20px;
  background: var(--bg-page);
  padding: 20px 0;
  border-top: 1px solid var(--border-color);
}

/* 按钮样式 */
.btn-primary {
  flex: 1;
  padding: 12px 24px;
  background: var(--accent-color);
  color: white;
  border: none;
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 15px;
  font-weight: 500;
  transition: all 0.2s;
}

.btn-primary:hover {
  background: var(--accent-hover);
}

.btn-secondary {
  flex: 1;
  padding: 12px 24px;
  background: transparent;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 15px;
  font-weight: 500;
  color: var(--text-secondary);
  transition: all 0.2s;
}

.btn-secondary:hover {
  border-color: var(--accent-color);
  color: var(--accent-color);
  background: var(--accent-light);
}

/* 卡片样式 */
.card {
  background: var(--bg-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-color);
}

/* 响应式 */
@media (max-width: 768px) {
  .header-content {
    padding: 16px;
  }
  
  .main-content {
    padding: 20px 16px;
  }
  
  .period-selector {
    gap: 8px;
  }
  
  .period-btn {
    padding: 8px 12px;
    font-size: 14px;
  }
  
  .stats-grid {
    grid-template-columns: 1fr;
    gap: 12px;
  }
  
  .export-actions {
    flex-direction: column;
  }
  
  .record-item {
    flex-direction: column;
    gap: 8px;
  }
}
</style>
