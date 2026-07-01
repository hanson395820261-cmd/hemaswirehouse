<template>
  <div class="home">
    <!-- 顶部标题栏 -->
    <header class="header">
      <div class="header-content">
        <h1 class="app-title">荷马随手记</h1>
        <div class="user-info">
          <span class="user-name">{{ userName }}</span>
          <span class="user-position">{{ positionName }}</span>
          <button @click="handleLogout" class="logout-btn">切换用户</button>
        </div>
      </div>
    </header>

    <!-- 内容区 -->
    <main class="main-content">
      <!-- 标签导航 -->
      <nav class="nav-tabs">
        <button 
          :class="['tab', { active: currentTab === 'record' }]"
          @click="currentTab = 'record'"
        >
          记录
        </button>
        <button 
          :class="['tab', { active: currentTab === 'calendar' }]"
          @click="router.push('/calendar')"
        >
          日历
        </button>
        <button 
          :class="['tab', { active: currentTab === 'report' }]"
          @click="router.push('/report')"
        >
          报告
        </button>
      </nav>

      <!-- 记录表单 -->
      <div class="record-form card">
        <textarea 
          v-model="newRecord" 
          placeholder="记录一下现在在做什么..."
          rows="4"
          @keyup.ctrl.enter="addRecord"
        ></textarea>
        <div class="form-actions">
          <input type="date" v-model="recordDate" class="date-input" />
          <button @click="addRecord" class="btn-primary" :disabled="!newRecord.trim()">
            添加记录
          </button>
        </div>
      </div>

      <!-- 导入导出 -->
      <div class="import-export">
        <button @click="exportRecords" class="btn-secondary">
          导出记录
        </button>
        <button @click="triggerImport" class="btn-secondary">
          导入记录
        </button>
        <input 
          ref="fileInput" 
          type="file" 
          accept=".json" 
          style="display: none"
          @change="importRecords"
        />
      </div>

      <!-- 记录列表 -->
      <div class="records-section">
        <h2 class="section-title">{{ formatDateDisplay(recordDate) }} 的记录</h2>
        
        <div v-if="records.length === 0" class="empty-state">
          <p>暂无记录</p>
          <p class="empty-hint">开始记录吧！</p>
        </div>
        
        <div 
          v-for="record in records" 
          :key="record.id"
          class="record-card card"
        >
          <div class="record-content">{{ record.content }}</div>
          <div class="record-meta">
            <span class="record-time">{{ formatTime(record.created_at) }}</span>
            <button @click="deleteRecord(record.id)" class="btn-danger">
              删除
            </button>
          </div>
        </div>
      </div>
    </main>
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
const fileInput = ref(null)

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
    alert('添加失败：' + error.message)
  } else {
    newRecord.value = ''
    loadRecords()
  }
}

// 删除记录
const deleteRecord = async (id) => {
  if (!window.confirm('确定要删除这条记录吗？')) return
  
  console.log('正在删除记录:', id) // 调试日志
  
  const { error } = await supabase
    .from('records')
    .delete()
    .eq('id', id)
  
  if (error) {
    console.error('删除记录失败:', error)
    window.alert('删除失败：' + error.message)
  } else {
    console.log('删除成功')
    loadRecords()
  }
}

// 导出记录
const exportRecords = async () => {
  const { data, error } = await supabase
    .from('records')
    .select('*, users(name, positions(name))')
    .eq('user_id', userId.value)
    .order('record_date', { ascending: true })
  
  if (error) {
    console.error('导出失败:', error)
    alert('导出失败：' + error.message)
    return
  }
  
  const exportData = {
    version: '1.0',
    exportDate: new Date().toISOString(),
    user: userName.value,
    records: data
  }
  
  const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `随手记_${userName.value}_${new Date().toISOString().split('T')[0]}.json`
  a.click()
  URL.revokeObjectURL(url)
}

// 触发导入
const triggerImport = () => {
  fileInput.value.click()
}

// 导入记录
const importRecords = async (event) => {
  const file = event.target.files[0]
  if (!file) return
  
  const reader = new FileReader()
  reader.onload = async (e) => {
    try {
      const importData = JSON.parse(e.target.result)
      
      if (!importData.records || !Array.isArray(importData.records)) {
        alert('文件格式不正确')
        return
      }
      
      // 导入记录
      const recordsToImport = importData.records.map(record => ({
        user_id: userId.value,
        content: record.content,
        record_date: record.record_date,
        created_at: record.created_at
      }))
      
      const { error } = await supabase
        .from('records')
        .insert(recordsToImport)
      
      if (error) {
        console.error('导入失败:', error)
        alert('导入失败：' + error.message)
      } else {
        alert(`成功导入 ${recordsToImport.length} 条记录`)
        loadRecords()
      }
    } catch (err) {
      console.error('解析文件失败:', err)
      alert('解析文件失败，请确保文件格式正确')
    }
  }
  
  reader.readAsText(file)
  event.target.value = '' // 清空input，允许重复选择同一个文件
}

// 格式化时间
const formatTime = (datetime) => {
  return new Date(datetime).toLocaleTimeString('zh-CN', { 
    hour: '2-digit', 
    minute: '2-digit' 
  })
}

// 格式化日期显示
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
  justify-content: space-between;
  align-items: center;
}

.app-title {
  font-size: 24px;
  font-weight: 600;
  color: var(--text-primary);
  letter-spacing: -0.5px;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 14px;
  color: var(--text-secondary);
}

.user-name {
  font-weight: 500;
  color: var(--text-primary);
}

.user-position {
  padding: 4px 12px;
  background: var(--accent-light);
  color: var(--accent-color);
  border-radius: 20px;
  font-size: 13px;
  font-weight: 500;
}

.logout-btn {
  padding: 6px 16px;
  background: transparent;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 14px;
  color: var(--text-secondary);
  transition: all 0.2s;
}

.logout-btn:hover {
  border-color: var(--text-secondary);
  color: var(--text-primary);
}

/* 主内容区 */
.main-content {
  max-width: 900px;
  margin: 0 auto;
  padding: 32px 24px;
}

/* 标签导航 */
.nav-tabs {
  display: flex;
  gap: 32px;
  margin-bottom: 32px;
  border-bottom: 1px solid var(--border-color);
}

.tab {
  padding: 12px 4px;
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  font-size: 15px;
  font-weight: 500;
  color: var(--text-secondary);
  transition: all 0.2s;
  margin-bottom: -1px;
}

.tab:hover {
  color: var(--text-primary);
}

.tab.active {
  color: var(--accent-color);
  border-bottom-color: var(--accent-color);
}

/* 卡片样式 */
.card {
  background: var(--bg-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-color);
}

/* 记录表单 */
.record-form {
  padding: 24px;
  margin-bottom: 20px;
}

.record-form textarea {
  width: 100%;
  padding: 16px;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-sm);
  font-size: 15px;
  line-height: 1.6;
  resize: vertical;
  font-family: inherit;
  background: var(--bg-input);
  color: var(--text-primary);
  transition: all 0.2s;
}

.record-form textarea:focus {
  outline: none;
  border-color: var(--border-focus);
  box-shadow: 0 0 0 3px rgba(30, 64, 175, 0.1);
}

.form-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 16px;
  gap: 16px;
}

.date-input {
  padding: 10px 14px;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-sm);
  font-size: 14px;
  background: var(--bg-input);
  color: var(--text-primary);
  transition: all 0.2s;
}

.date-input:focus {
  outline: none;
  border-color: var(--border-focus);
  box-shadow: 0 0 0 3px rgba(30, 64, 175, 0.1);
}

/* 按钮样式 */
.btn-primary {
  padding: 10px 24px;
  background: var(--accent-color);
  color: white;
  border: none;
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 15px;
  font-weight: 500;
  transition: all 0.2s;
}

.btn-primary:hover:not(:disabled) {
  background: var(--accent-hover);
}

.btn-primary:disabled {
  background: var(--text-muted);
  cursor: not-allowed;
}

.btn-secondary {
  padding: 8px 20px;
  background: transparent;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
  transition: all 0.2s;
}

.btn-secondary:hover {
  border-color: var(--accent-color);
  color: var(--accent-color);
  background: var(--accent-light);
}

.btn-danger {
  padding: 6px 16px;
  background: transparent;
  border: 1px solid var(--danger-color);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 14px;
  color: var(--danger-color);
  transition: all 0.2s;
}

.btn-danger:hover {
  background: var(--danger-color);
  color: white;
}

/* 导入导出 */
.import-export {
  display: flex;
  gap: 12px;
  margin-bottom: 32px;
}

/* 记录列表 */
.records-section {
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
  padding: 60px 20px;
  background: var(--bg-card);
  border-radius: var(--radius-md);
  border: 1px solid var(--border-color);
}

.empty-state p {
  color: var(--text-secondary);
  font-size: 16px;
}

.empty-hint {
  margin-top: 8px;
  font-size: 14px !important;
  color: var(--text-muted) !important;
}

/* 记录卡片 */
.record-card {
  padding: 20px;
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
  
  .app-title {
    font-size: 20px;
  }
  
  .user-info {
    gap: 8px;
    font-size: 13px;
  }
  
  .user-position {
    display: none;
  }
  
  .main-content {
    padding: 20px 16px;
  }
  
  .nav-tabs {
    gap: 20px;
  }
  
  .form-actions {
    flex-direction: column;
    align-items: stretch;
  }
  
  .import-export {
    flex-direction: column;
  }
}
</style>
