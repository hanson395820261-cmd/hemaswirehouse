<template>
  <div class="onboarding">
    <div class="container">
      <h1>荷马随手记</h1>
      
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
            @keyup.enter="addPosition"
          />
          <button @click="addPosition" :disabled="!newPosition">添加</button>
        </div>
      </div>

      <div class="form-group">
        <label>名字</label>
        <input 
          v-model="userName" 
          placeholder="请输入你的名字"
          @keyup.enter="handleSubmit"
        />
      </div>

      <button 
        class="submit-btn" 
        @click="handleSubmit"
        :disabled="!selectedPosition || !userName"
      >
        进入 →
      </button>
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

// 添加新岗位
const addPosition = async () => {
  if (!newPosition.value.trim()) return
  
  const { data, error } = await supabase
    .from('positions')
    .insert([{ name: newPosition.value.trim() }])
    .select()
  
  if (error) {
    console.error('添加岗位失败:', error)
  } else {
    positions.value.push(data[0])
    selectedPosition.value = data[0].id
    newPosition.value = ''
  }
}

// 提交表单
const handleSubmit = async () => {
  if (!selectedPosition.value || !userName.value.trim()) return
  
  // 创建用户
  const { data, error } = await supabase
    .from('users')
    .insert([{ 
      name: userName.value.trim(), 
      position_id: selectedPosition.value 
    }])
    .select()
  
  if (error) {
    console.error('创建用户失败:', error)
  } else {
    // 保存用户信息到 localStorage
    localStorage.setItem('userId', data[0].id)
    localStorage.setItem('userName', data[0].name)
    localStorage.setItem('positionId', selectedPosition.value)
    
    // 跳转到主页
    router.push('/')
  }
}

onMounted(() => {
  loadPositions()
})
</script>

<style scoped>
.onboarding {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #ffffff;
  padding: 20px;
}

.container {
  max-width: 400px;
  width: 100%;
  padding: 20px;
}

h1 {
  text-align: center;
  color: #1a1a1a;
  margin-bottom: 40px;
  font-size: 32px;
  font-weight: 300;
  letter-spacing: 2px;
}

.form-group {
  margin-bottom: 30px;
}

label {
  display: block;
  margin-bottom: 12px;
  color: #666;
  font-weight: 400;
  font-size: 14px;
  text-transform: uppercase;
  letter-spacing: 1px;
}

.position-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 12px;
}

.position-btn {
  padding: 8px 16px;
  border: 1px solid #e0e0e0;
  border-radius: 0;
  background: white;
  cursor: pointer;
  transition: all 0.3s;
  font-size: 14px;
  color: #666;
}

.position-btn:hover {
  border-color: #1a1a1a;
  color: #1a1a1a;
}

.position-btn.active {
  background: #1a1a1a;
  color: white;
  border-color: #1a1a1a;
}

.add-position {
  display: flex;
  gap: 8px;
}

.add-position input {
  flex: 1;
  padding: 8px 0;
  border: none;
  border-bottom: 1px solid #e0e0e0;
  font-size: 14px;
  outline: none;
  transition: border-color 0.3s;
}

.add-position input:focus {
  border-bottom-color: #1a1a1a;
}

.add-position button {
  padding: 8px 16px;
  background: none;
  color: #666;
  border: 1px solid #e0e0e0;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.3s;
}

.add-position button:hover:not(:disabled) {
  border-color: #1a1a1a;
  color: #1a1a1a;
}

.add-position button:disabled {
  color: #ccc;
  border-color: #f0f0f0;
  cursor: not-allowed;
}

input[type="text"] {
  width: 100%;
  padding: 8px 0;
  border: none;
  border-bottom: 1px solid #e0e0e0;
  font-size: 16px;
  outline: none;
  transition: border-color 0.3s;
  box-sizing: border-box;
}

input[type="text"]:focus {
  border-bottom-color: #1a1a1a;
}

.submit-btn {
  width: 100%;
  padding: 12px;
  background: none;
  color: #1a1a1a;
  border: 1px solid #1a1a1a;
  cursor: pointer;
  font-size: 14px;
  font-weight: 400;
  letter-spacing: 2px;
  transition: all 0.3s;
  margin-top: 20px;
}

.submit-btn:hover:not(:disabled) {
  background: #1a1a1a;
  color: white;
}

.submit-btn:disabled {
  color: #ccc;
  border-color: #e0e0e0;
  cursor: not-allowed;
}
</style>
