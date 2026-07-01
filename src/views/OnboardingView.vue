<template>
  <div class="onboarding">
    <div class="container">
      <h1>📝 欢迎使用随手记</h1>
      <p class="subtitle">请设置你的岗位和名字</p>
      
      <div class="form-group">
        <label>选择岗位</label>
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
            placeholder="或输入新岗位名称"
            @keyup.enter="addPosition"
          />
          <button @click="addPosition" :disabled="!newPosition">添加</button>
        </div>
      </div>

      <div class="form-group">
        <label>你的名字</label>
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
        开始使用 →
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
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 20px;
}

.container {
  background: white;
  border-radius: 20px;
  padding: 40px;
  max-width: 500px;
  width: 100%;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}

h1 {
  text-align: center;
  color: #333;
  margin-bottom: 10px;
}

.subtitle {
  text-align: center;
  color: #666;
  margin-bottom: 30px;
}

.form-group {
  margin-bottom: 25px;
}

label {
  display: block;
  margin-bottom: 10px;
  color: #333;
  font-weight: 600;
}

.position-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 15px;
}

.position-btn {
  padding: 10px 20px;
  border: 2px solid #e0e0e0;
  border-radius: 25px;
  background: white;
  cursor: pointer;
  transition: all 0.3s;
  font-size: 14px;
}

.position-btn:hover {
  border-color: #667eea;
  color: #667eea;
}

.position-btn.active {
  background: #667eea;
  color: white;
  border-color: #667eea;
}

.add-position {
  display: flex;
  gap: 10px;
}

.add-position input {
  flex: 1;
  padding: 10px;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 14px;
}

.add-position button {
  padding: 10px 20px;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
}

.add-position button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

input[type="text"] {
  width: 100%;
  padding: 12px;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 16px;
  box-sizing: border-box;
}

.submit-btn {
  width: 100%;
  padding: 15px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 10px;
  font-size: 18px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.2s;
}

.submit-btn:hover {
  transform: translateY(-2px);
}

.submit-btn:disabled {
  background: #ccc;
  cursor: not-allowed;
  transform: none;
}
</style>
