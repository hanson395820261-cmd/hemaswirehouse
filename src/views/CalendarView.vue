<template>
  <div class="calendar-view">
    <!-- 顶部标题栏 -->
    <header class="header">
      <div class="header-content">
        <button @click="router.push('/')" class="back-btn">
          返回
        </button>
        <h1 class="page-title">日历浏览</h1>
      </div>
    </header>

    <!-- 主内容区 -->
    <main class="main-content">
      <!-- 日历导航 -->
      <div class="calendar-nav">
        <button @click="prevMonth" class="nav-btn">&lsaquo;</button>
        <h2 class="month-title">{{ currentYear }}年{{ currentMonth + 1 }}月</h2>
        <button @click="nextMonth" class="nav-btn">&rsaquo;</button>
      </div>

      <!-- 日历网格 -->
      <div class="calendar-grid card">
        <div class="weekday-header">
          <div v-for="day in weekdays" :key="day" class="weekday">{{ day }}</div>
        </div>
        <div class="days-grid">
          <div 
            v-for="(day, index) in calendarDays" 
            :key="index"
            :class="['calendar-day', { 
              'other-month': !day.currentMonth,
              'has-records': day.recordsCount > 0,
              'selected': day.date === selectedDate
            }]"
            @click="selectDate(day)"
          >
            <span class="day-number">{{ day.day }}</span>
            <span v-if="day.recordsCount > 0" class="records-indicator">
              {{ day.recordsCount }}
            </span>
          </div>
        </div>
      </div>

      <!-- 选中日期的记录 -->
      <div v-if="selectedDate" class="day-records">
        <h3 class="section-title">{{ formatDateDisplay(selectedDate) }} 的记录</h3>
        
        <div v-if="dayRecords.length === 0" class="empty-state">
          <p>这一天没有记录</p>
        </div>
        
        <div 
          v-for="record in dayRecords" 
          :key="record.id"
          class="record-card card"
        >
          <div class="record-content">{{ record.content }}</div>
          <div class="record-meta">
            <span class="record-time">{{ formatTime(record.created_at) }}</span>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const router = useRouter()
const currentDate = ref(new Date())
const selectedDate = ref('')
const dayRecords = ref([])
const recordsMap = ref({})
const userId = ref(localStorage.getItem('userId') || '')

const currentYear = computed(() => currentDate.value.getFullYear())
const currentMonth = computed(() => currentDate.value.getMonth())

const weekdays = ['日', '一', '二', '三', '四', '五', '六']

const calendarDays = computed(() => {
  const year = currentYear.value
  const month = currentMonth.value
  const firstDay = new Date(year, month, 1).getDay()
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const daysInPrevMonth = new Date(year, month, 0).getDate()
  
  const days = []
  
  // 上个月的日期
  for (let i = firstDay - 1; i >= 0; i--) {
    const day = daysInPrevMonth - i
    const date = new Date(year, month - 1, day)
    days.push({
      day,
      date: formatDate(date),
      currentMonth: false,
      recordsCount: recordsMap.value[formatDate(date)] || 0
    })
  }
  
  // 当前月的日期
  for (let day = 1; day <= daysInMonth; day++) {
    const date = new Date(year, month, day)
    days.push({
      day,
      date: formatDate(date),
      currentMonth: true,
      recordsCount: recordsMap.value[formatDate(date)] || 0
    })
  }
  
  // 下个月的日期
  const remaining = 42 - days.length
  for (let day = 1; day <= remaining; day++) {
    const date = new Date(year, month + 1, day)
    days.push({
      day,
      date: formatDate(date),
      currentMonth: false,
      recordsCount: recordsMap.value[formatDate(date)] || 0
    })
  }
  
  return days
})

const prevMonth = () => {
  currentDate.value = new Date(currentYear.value, currentMonth.value - 1, 1)
  loadMonthRecords()
}

const nextMonth = () => {
  currentDate.value = new Date(currentYear.value, currentMonth.value + 1, 1)
  loadMonthRecords()
}

const selectDate = async (day) => {
  if (!day.currentMonth) return
  
  selectedDate.value = day.date
  loadDayRecords()
}

const loadMonthRecords = async () => {
  const startDate = formatDate(new Date(currentYear.value, currentMonth.value, 1))
  const endDate = formatDate(new Date(currentYear.value, currentMonth.value + 1, 0))
  
  const { data, error } = await supabase
    .from('records')
    .select('record_date')
    .eq('user_id', userId.value)
    .gte('record_date', startDate)
    .lte('record_date', endDate)
  
  if (error) {
    console.error('加载记录失败:', error)
  } else {
    // 统计每天的记录数
    const map = {}
    data.forEach(record => {
      map[record.record_date] = (map[record.record_date] || 0) + 1
    })
    recordsMap.value = map
  }
}

const loadDayRecords = async () => {
  const { data, error } = await supabase
    .from('records')
    .select('*')
    .eq('user_id', userId.value)
    .eq('record_date', selectedDate.value)
    .order('created_at', { ascending: true })
  
  if (error) {
    console.error('加载记录失败:', error)
  } else {
    dayRecords.value = data
  }
}

const formatDate = (date) => {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const formatDateDisplay = (dateStr) => {
  const date = new Date(dateStr)
  const today = new Date()
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)
  
  if (dateStr === today.toISOString().split('T')[0]) {
    return '今天'
  } else if (dateStr === yesterday.toISOString().split('T')[0]) {
    return '昨天'
  } else {
    return dateStr
  }
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
  
  loadMonthRecords()
  selectedDate.value = formatDate(new Date())
  loadDayRecords()
})
</script>

<style scoped>
.calendar-view {
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

/* 日历导航 */
.calendar-nav {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 24px;
  margin-bottom: 24px;
}

.nav-btn {
  width: 36px;
  height: 36px;
  border: 1px solid var(--border-color);
  background: var(--bg-card);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 20px;
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.nav-btn:hover {
  border-color: var(--accent-color);
  color: var(--accent-color);
}

.month-title {
  font-size: 20px;
  font-weight: 600;
  color: var(--text-primary);
  min-width: 160px;
  text-align: center;
}

/* 日历网格 */
.calendar-grid {
  background: var(--bg-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-color);
  padding: 20px;
  margin-bottom: 32px;
}

.weekday-header {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 8px;
  margin-bottom: 12px;
}

.weekday {
  text-align: center;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  padding: 8px 0;
}

.days-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
}

.calendar-day {
  aspect-ratio: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: var(--radius-sm);
  transition: all 0.2s;
  position: relative;
  gap: 4px;
}

.calendar-day:hover:not(.other-month) {
  background: var(--bg-input);
}

.calendar-day.selected {
  background: var(--accent-light);
  color: var(--accent-color);
}

.calendar-day.has-records .day-number {
  font-weight: 600;
  color: var(--accent-color);
}

.calendar-day.other-month {
  opacity: 0.3;
  cursor: default;
}

.day-number {
  font-size: 15px;
  color: var(--text-primary);
}

.records-indicator {
  font-size: 11px;
  font-weight: 600;
  color: white;
  background: var(--accent-color);
  width: 20px;
  height: 20px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* 记录列表 */
.day-records {
  margin-top: 8px;
}

.section-title {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 20px;
}

.empty-state {
  text-align: center;
  padding: 40px 20px;
  background: var(--bg-card);
  border-radius: var(--radius-md);
  border: 1px solid var(--border-color);
}

.empty-state p {
  color: var(--text-secondary);
  font-size: 15px;
}

/* 记录卡片 */
.record-card {
  background: var(--bg-card);
  padding: 20px;
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-color);
  margin-bottom: 12px;
  transition: all 0.2s;
}

.record-card:hover {
  box-shadow: var(--shadow-md);
}

.record-content {
  font-size: 15px;
  line-height: 1.6;
  color: var(--text-primary);
  margin-bottom: 12px;
}

.record-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.record-time {
  font-size: 13px;
  color: var(--text-muted);
}

/* 响应式 */
@media (max-width: 768px) {
  .header-content {
    padding: 16px;
  }
  
  .main-content {
    padding: 20px 16px;
  }
  
  .calendar-grid {
    padding: 12px;
  }
  
  .day-number {
    font-size: 13px;
  }
  
  .records-indicator {
    width: 16px;
    height: 16px;
    font-size: 10px;
  }
}
</style>
