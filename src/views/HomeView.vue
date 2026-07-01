<template>
  <div class="home">
    <header>
      <h1>📝 随手记</h1>
      <div class="user-info">
        <span>{{ userName }} ({{ positionName }})</span>
        <button @click="handleLogout" class="logout-btn">切换用户</button>
      </div>
    </header>

    <nav class="nav-tabs">
      <button 
        :class="['tab', { active: currentTab === 'record' }]"
        @click="currentTab = 'record'"
      >
        ✍️ 记录
      </button>
      <button 
        :class="['tab', { active: currentTab === 'calendar' }]"
        @click="router.push('/calendar')"
      >
        📅 日历
      </button>
    </nav>

    <div class="content">
      <!-- 添加记录表单 -->
      <div class="record-form">
        <textarea 
          v-model="newRecord" 
          placeholder="记录一下现在在做什么..."
          rows="4"
          @keyup.ctrl.enter="addRecord"
        ></textarea>
        <div class="form-actions">
          <input type="date" v-model="recordDate" />
          <button @click="addRecord" :disabled="!newRecord.trim()">
            添加记录
          </button>
        </div>
      </div>

      <!-- 今日记录列表 -->
      <div class="records-list">
        <h2>{{ recordDate }} 的记录</h2>
        <div v-if="records.length === 0" class="empty">
          暂无记录，开始记录吧！
        </div>
        <div 
          v-for="record in records" 
          :key="record.id"
          class="record-card"
        >
          <div class="record-content">{{ record.content }}</div>
          <div class="record-meta">
            <span class="time">{{ formatTime(record.created_at) }}</span>
            <button @click="deleteRecord(record.id)" class="delete-btn">删除</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const router = useRouter()
const currentTab = ref('record')
const newRecord = ref('')
const recordDate = ref(new Date().toISOString().split('T')[0])
const records = ref([])
const userName = ref(localStorage.getItem('userName') || '')
const positionName = ref('')
const userId = ref(localStorage.getItem('userId') || '')

// 检查用户是否已登录
if (!userId.value) {
  router.push('/onboarding')
}

// 加载岗位名称
const loadPositionName = async () => {
  const positionId = localStorage.getItem('positionId')
  if (positionId) {
    const { data, error } = await supabase
      .from('positions')
      .select('name')
      .eq('id', positionId)
      .single()
    
    if (!error && data) {
      positionName.value = data.name
    }
  }
}

// 加载记录
const loadRecords = async () => {
  const { data, error } = await supabase
    .from('records')
    .select('*')
    .eq('user_id', userId.value)
    .eq('record_date', recordDate.value)
    .order('created_at', { ascending: false })
  
  if (error) {
    console.error('加载记录失败:', error)
  } else {
    records.value = data
  }
}

// 添加记录
const addRecord = async () => {
  if (!newRecord.value.trim()) return
  
  const { error } = await supabase
    .from('records')
    .insert([{
      user_id: userId.value,
      content: newRecord.value.trim(),
      record_date: recordDate.value
    }])
  
  if (error) {
    console.error('添加记录失败:', error)
  } else {
    newRecord.value = ''
    loadRecords()
  }
}

// 删除记录
const deleteRecord = async (id) => {
  if (!confirm('确定要删除这条记录吗？')) return
  
  const { error } = await supabase
    .from('records')
    .delete()
    .eq('id', id)
  
  if (error) {
    console.error('删除记录失败:', error)
  } else {
    loadRecords()
  }
}

// 格式化时间
const formatTime = (datetime) => {
  return new Date(datetime).toLocaleTimeString('zh-CN', { 
    hour: '2-digit', 
    minute: '2-digit' 
  })
}

// 退出登录
const handleLogout = () => {
  localStorage.clear()
  router.push('/onboarding')
}

// 监听日期变化
watch(recordDate, () => {
  loadRecords()
})

onMounted(() => {
  loadPositionName()
  loadRecords()
})
</script>

<style scoped>
.home {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

header h1 {
  margin: 0;
  color: #333;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 15px;
  color: #666;
}

.logout-btn {
  padding: 5px 15px;
  background: #f0f0f0;
  border: none;
  border-radius: 5px;
  cursor: pointer;
  font-size: 14px;
}

.logout-btn:hover {
  background: #e0e0e0;
}

.nav-tabs {
  display: flex;
  gap: 10px;
  margin-bottom: 30px;
  border-bottom: 2px solid #f0f0f0;
}

.tab {
  padding: 12px 24px;
  background: none;
  border: none;
  cursor: pointer;
  font-size: 16px;
  color: #666;
  border-bottom: 3px solid transparent;
  margin-bottom: -2px;
}

.tab.active {
  color: #667eea;
  border-bottom-color: #667eea;
  font-weight: 600;
}

.record-form {
  background: white;
  padding: 20px;
  border-radius: 10px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
  margin-bottom: 30px;
}

textarea {
  width: 100%;
  padding: 15px;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 16px;
  resize: vertical;
  box-sizing: border-box;
  font-family: inherit;
}

textarea:focus {
  outline: none;
  border-color: #667eea;
}

.form-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 15px;
  gap: 15px;
}

.form-actions input[type="date"] {
  padding: 10px;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 14px;
}

.form-actions button {
  padding: 12px 30px;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 16px;
  font-weight: 600;
}

.form-actions button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.records-list h2 {
  color: #333;
  margin-bottom: 20px;
}

.empty {
  text-align: center;
  color: #999;
  padding: 40px;
  background: #f9f9f9;
  border-radius: 10px;
}

.record-card {
  background: white;
  padding: 20px;
  border-radius: 10px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.05);
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
  align-items: center;
}

.time {
  color: #999;
  font-size: 14px;
}

.delete-btn {
  padding: 5px 15px;
  background: #ff6b6b;
  color: white;
  border: none;
  border-radius: 5px;
  cursor: pointer;
  font-size: 14px;
}

.delete-btn:hover {
  background: #ee5a5a;
}
</style>
