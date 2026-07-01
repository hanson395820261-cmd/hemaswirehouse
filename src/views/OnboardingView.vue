<template>
  <div class="onboarding">
    <div class="container">
      <h1>荷马随手记</h1>
      
      <!-- 已存在的用户列表 -->
      <div v-if="existingUsers.length > 0" class="form-group">
        <label>选择角色</label>
        <div class="user-list">
          <div 
            v-for="user in existingUsers" 
            :key="user.id"
            class="user-item"
          >
            <button 
              class="user-btn"
              @click="loginAsUser(user)"
            >
              <span class="user-name">{{ user.name }}</span>
              <span class="user-position">{{ user.position_name }}</span>
            </button>
            <button 
              class="delete-user-btn"
              @click="confirmDeleteUser(user)"
              title="删除此角色"
            >
              ×
            </button>
          </div>
        </div>
        <div class="divider">
          <span>或者创建新角色</span>
        </div>
      </div>

      <!-- 创建新用户表单 -->
      <div class="form-group">
        <label>岗位</label>
        <div class="position-list">
          <button 
            v-for="position in positions" 
            :key="position.id"
            :class="['position-btn', { active: selectedPosition === position.id }]"
            @click="selectedPosition = position.id"
          >
            {{ position.name }}
          </button>
        </div>
        <div class="add-position">
          <input 
            v-model="newPosition" 
            placeholder="或输入新岗位"
            class="form-input"
            @keyup.enter="addPosition"
          />
          <button @click="addPosition" class="form-btn" :disabled="!newPosition">添加</button>
        </div>
      </div>

      <div class="form-group">
        <label>名字</label>
        <input 
          v-model="userName" 
          placeholder="请输入你的名字"
          class="form-input"
          @keyup.enter="handleSubmit"
        />
      </div>

      <button 
        class="submit-btn" 
        @click="handleSubmit"
        :disabled="!selectedPosition || !userName"
      >
        创建角色 →
      </button>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="showDeleteModal" class="modal-overlay" @click="closeDeleteModal">
      <div class="modal-content" @click.stop>
        <h3>删除角色</h3>
        <p>确定要删除角色 <strong>{{ userToDelete?.name }}</strong> 吗？</p>
        <p class="modal-hint">请输入密码以确认删除</p>
        <input 
          v-model="deletePassword"
          type="password"
          placeholder="请输入密码"
          class="form-input"
          @keyup.enter="executeDeleteUser"
        />
        <div class="modal-actions">
          <button @click="closeDeleteModal" class="form-btn">取消</button>
          <button @click="executeDeleteUser" class="modal-delete-btn">删除</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const router = useRouter()
const positions = ref([])
const selectedPosition = ref(null)
const userName = ref('')
const newPosition = ref('')
const existingUsers = ref([])

// 删除相关
const showDeleteModal = ref(false)
const userToDelete = ref(null)
const deletePassword = ref('')

// 加载岗位列表
const loadPositions = async () => {
  const { data, error } = await supabase
    .from('positions')
    .select('*')
    .order('name')
  
  if (error) {
    console.error('加载岗位失败:', error)
  } else {
    positions.value = data
  }
}

// 加载已存在的用户
const loadExistingUsers = async () => {
  const { data, error } = await supabase
    .from('users')
    .select(`
      *,
      positions(name)
    `)
    .order('created_at', { ascending: false })
  
  if (error) {
    console.error('加载用户失败:', error)
  } else {
    existingUsers.value = data.map(user => ({
      ...user,
      position_name: user.positions?.name || '未设置'
    }))
  }
}

// 直接登录已有用户
const loginAsUser = (user) => {
  localStorage.setItem('userId', user.id)
  localStorage.setItem('userName', user.name)
  localStorage.setItem('positionId', user.position_id)
  router.push('/')
}

// 确认删除用户
const confirmDeleteUser = (user) => {
  userToDelete.value = user
  deletePassword.value = ''
  showDeleteModal.value = true
}

// 关闭删除弹窗
const closeDeleteModal = () => {
  showDeleteModal.value = false
  userToDelete.value = null
  deletePassword.value = ''
}

// 执行删除用户
const executeDeleteUser = async () => {
  if (deletePassword.value !== 'hema') {
    alert('密码错误！')
    return
  }
  
  if (!userToDelete.value) return
  
  // 先删除该用户的所有记录
  const { error: recordsError } = await supabase
    .from('records')
    .delete()
    .eq('user_id', userToDelete.value.id)
  
  if (recordsError) {
    console.error('删除记录失败:', recordsError)
    alert('删除失败：' + recordsError.message)
    return
  }
  
  // 再删除用户
  const { error: userError } = await supabase
    .from('users')
    .delete()
    .eq('id', userToDelete.value.id)
  
  if (userError) {
    console.error('删除用户失败:', userError)
    alert('删除失败：' + userError.message)
  } else {
    alert('删除成功！')
    showDeleteModal.value = false
    loadExistingUsers() // 重新加载用户列表
  }
}

// 添加新岗位
const addPosition = async () => {
  if (!newPosition.value.trim()) return
  
  const { data, error } = await supabase
    .from('positions')
    .insert([{ name: newPosition.value.trim() }])
    .select()
  
  if (error) {
    console.error('添加岗位失败:', error)
    alert('添加岗位失败：' + error.message)
  } else {
    positions.value.push(data[0])
    selectedPosition.value = data[0].id
    newPosition.value = ''
  }
}

// 提交表单
const handleSubmit = async () => {
  if (!selectedPosition.value || !userName.value.trim()) return
  
  // 检查用户是否已存在
  const { data: existingUsers, error: searchError } = await supabase
    .from('users')
    .select('*')
    .eq('name', userName.value.trim())
    .eq('position_id', selectedPosition.value)
  
  if (searchError) {
    console.error('查找用户失败:', searchError)
    return
  }
  
  if (existingUsers && existingUsers.length > 0) {
    // 用户已存在，直接登录
    localStorage.setItem('userId', existingUsers[0].id)
    localStorage.setItem('userName', existingUsers[0].name)
    localStorage.setItem('positionId', selectedPosition.value)
  } else {
    // 创建新用户
    const { data, error } = await supabase
      .from('users')
      .insert([{ 
        name: userName.value.trim(), 
        position_id: selectedPosition.value 
      }])
      .select()
    
    if (error) {
      console.error('创建用户失败:', error)
      alert('创建用户失败：' + error.message)
      return
    } else {
      localStorage.setItem('userId', data[0].id)
      localStorage.setItem('userName', data[0].name)
      localStorage.setItem('positionId', selectedPosition.value)
    }
  }
  
  router.push('/')
}

onMounted(() => {
  loadPositions()
  loadExistingUsers()
})
</script>

<style scoped>
.onboarding {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-page);
  padding: 20px;
}

.container {
  max-width: 400px;
  width: 100%;
  padding: 40px 32px;
  background: var(--bg-card);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
  border: 1px solid var(--border-color);
}

h1 {
  text-align: center;
  color: var(--text-primary);
  margin-bottom: 40px;
  font-size: 28px;
  font-weight: 600;
  letter-spacing: -0.5px;
}

.form-group {
  margin-bottom: 28px;
}

label {
  display: block;
  margin-bottom: 12px;
  color: var(--text-secondary);
  font-weight: 500;
  font-size: 14px;
}

/* 已存在用户列表 */
.user-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 20px;
}

.user-item {
  display: flex;
  gap: 8px;
  align-items: center;
}

.user-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  border: none;
  border-radius: 8px;
  background: #f1f5f9;
  cursor: pointer;
  transition: all 0.2s;
  text-align: left;
  width: 100%;
  height: 48px;
}

.user-btn:hover {
  background: #e2e8f0;
}

.user-name {
  font-size: 15px;
  font-weight: 500;
  color: var(--text-primary);
}

.user-position {
  font-size: 13px;
  color: #2563eb;
  background: #eff6ff;
  padding: 4px 12px;
  border-radius: 20px;
  font-weight: 500;
}

.delete-user-btn {
  width: 48px;
  height: 48px;
  border: none;
  border-radius: 8px;
  background: #f1f5f9;
  color: var(--text-muted);
  font-size: 20px;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.delete-user-btn:hover {
  background: #fee2e2;
  color: #dc2626;
}

.divider {
  text-align: center;
  margin: 24px 0;
  position: relative;
}

.divider::before {
  content: '';
  position: absolute;
  left: 0;
  top: 50%;
  width: 100%;
  height: 1px;
  background: var(--border-color);
}

.divider span {
  position: relative;
  background: var(--bg-card);
  padding: 0 16px;
  color: var(--text-muted);
  font-size: 13px;
}

/* 岗位选择 */
.position-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 12px;
}

.position-btn {
  height: 48px;
  padding: 0 16px;
  border: none;
  border-radius: 8px;
  background: #f1f5f9;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 14px;
  color: var(--text-secondary);
  font-weight: 500;
}

.position-btn:hover {
  background: #e2e8f0;
}

.position-btn.active {
  background: #eff6ff;
  color: #2563eb;
  border: 1px solid #2563eb;
}

/* 添加岗位 */
.add-position {
  display: flex;
  gap: 8px;
}

/* 通用表单样式 */
.form-input {
  flex: 1;
  height: 48px;
  padding: 0 16px;
  border: none;
  border-radius: 8px;
  background: #f1f5f9;
  color: var(--text-primary);
  font-size: 15px;
  outline: none;
  transition: all 0.2s;
  box-sizing: border-box;
}

.form-input:hover {
  background: #e2e8f0;
}

.form-input:focus {
  background: #eff6ff;
  border: 1px solid #2563eb;
  box-shadow: none;
}

.form-input::placeholder {
  color: var(--text-muted);
}

.form-btn {
  height: 48px;
  padding: 0 20px;
  border: none;
  border-radius: 8px;
  background: #f1f5f9;
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.form-btn:hover:not(:disabled) {
  background: #e2e8f0;
  color: var(--text-primary);
}

.form-btn:disabled {
  color: var(--text-muted);
  cursor: not-allowed;
  opacity: 0.6;
}

/* 提交按钮 */
.submit-btn {
  width: 100%;
  height: 48px;
  padding: 0 24px;
  background: #1e40af;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 15px;
  font-weight: 500;
  transition: all 0.2s;
  margin-top: 8px;
}

.submit-btn:hover:not(:disabled) {
  background: #1d4ed8;
}

.submit-btn:disabled {
  background: var(--text-muted);
  cursor: not-allowed;
  opacity: 0.6;
}

/* 模态框 */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: var(--bg-card);
  border-radius: var(--radius-lg);
  padding: 32px;
  max-width: 400px;
  width: 90%;
  box-shadow: var(--shadow-lg);
}

.modal-content h3 {
  font-size: 20px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 16px;
}

.modal-content p {
  font-size: 15px;
  color: var(--text-secondary);
  margin-bottom: 12px;
}

.modal-hint {
  font-size: 13px;
  color: var(--text-muted);
}

.modal-content .form-input {
  width: 100%;
  margin-bottom: 20px;
}

.modal-actions {
  display: flex;
  gap: 12px;
}

.modal-actions .form-btn {
  flex: 1;
}

.modal-delete-btn {
  flex: 1;
  height: 48px;
  padding: 0 24px;
  background: #dc2626;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 15px;
  font-weight: 500;
  transition: all 0.2s;
}

.modal-delete-btn:hover {
  background: #b91c1c;
}

/* 响应式 */
@media (max-width: 768px) {
  .container {
    padding: 32px 24px;
  }
  
  h1 {
    font-size: 24px;
  }
}
</style>
