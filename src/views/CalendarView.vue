<template>
  <div class="calendar-view">
    <header>
      <h1>📅 日历浏览</h1>
      <button @click="router.push('/')" class="back-btn">← 返回</button>
    </header>

    <div class="calendar-nav">
      <button @click="prevMonth" class="nav-btn">‹</button>
      <h2>{{ currentYear }}年 {{ currentMonth + 1 }}月</h2>
      <button @click="nextMonth" class="nav-btn">›</button>
    </div>

    <div class="calendar-grid">
      <div class="weekday" v-for="day in weekdays" :key="day">{{ day }}</div>
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
        <span v-if="day.recordsCount > 0" class="records-badge">
          {{ day.recordsCount }}
        </span>
      </div>
    </div>

    <div class="day-records" v-if="selectedDate">
      <h3>{{ selectedDate }} 的记录</h3>
      <div v-if="dayRecords.length === 0" class="empty">
        这一天没有记录
      </div>
      <div 
        v-for="record in dayRecords" 
        :key="record.id"
        class="record-card"
      >
        <div class="record-content">{{ record.content }}</div>
        <div class="record-meta">
          <span class="user">{{ record.users?.name }}</span>
          <span class="time">{{ formatTime(record.created_at) }}</span>
        </div>
      </div>
    </div>
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
    .select('*, users(name)')
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

const formatTime = (datetime) => {
  return new Date(datetime).toLocaleTimeString('zh-CN', { 
    hour: '2-digit', 
    minute: '2-digit' 
  })
}

onMounted(() => {
  loadMonthRecords()
  selectedDate.value = formatDate(new Date())
  loadDayRecords()
})
</script>

<style scoped>
.calendar-view {
  max-width: 900px;
  margin: 0 auto;
  padding: 20px;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
}

header h1 {
  margin: 0;
  color: #333;
}

.back-btn {
  padding: 10px 20px;
  background: #f0f0f0;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 16px;
}

.back-btn:hover {
  background: #e0e0e0;
}

.calendar-nav {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 30px;
  margin-bottom: 30px;
}

.calendar-nav h2 {
  margin: 0;
  color: #333;
  min-width: 200px;
  text-align: center;
}

.nav-btn {
  width: 40px;
  height: 40px;
  border: 2px solid #e0e0e0;
  background: white;
  border-radius: 50%;
  font-size: 24px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

.nav-btn:hover {
  border-color: #667eea;
  color: #667eea;
}

.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 10px;
  margin-bottom: 40px;
}

.weekday {
  text-align: center;
  font-weight: 600;
  color: #666;
  padding: 10px;
}

.calendar-day {
  aspect-ratio: 1;
  border: 2px solid #f0f0f0;
  border-radius: 10px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.3s;
  position: relative;
}

.calendar-day:hover {
  border-color: #667eea;
  background: #f8f9ff;
}

.calendar-day.other-month {
  opacity: 0.3;
}

.calendar-day.selected {
  border-color: #667eea;
  background: #667eea;
  color: white;
}

.calendar-day.has-records {
  border-color: #667eea;
}

.day-number {
  font-size: 18px;
  font-weight: 600;
}

.records-badge {
  position: absolute;
  top: 5px;
  right: 5px;
  background: #667eea;
  color: white;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  font-size: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.calendar-day.selected .records-badge {
  background: white;
  color: #667eea;
}

.day-records {
  background: white;
  padding: 30px;
  border-radius: 15px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.day-records h3 {
  margin-top: 0;
  color: #333;
  margin-bottom: 20px;
}

.empty {
  text-align: center;
  color: #999;
  padding: 40px;
}

.record-card {
  padding: 20px;
  border-left: 4px solid #667eea;
  background: #f8f9ff;
  border-radius: 8px;
  margin-bottom: 15px;
}

.record-content {
  font-size: 16px;
  line-height: 1.6;
  color: #333;
  margin-bottom: 10px;
}

.record-meta {
  display: flex;
  justify-content: space-between;
  color: #999;
  font-size: 14px;
}
</style>
