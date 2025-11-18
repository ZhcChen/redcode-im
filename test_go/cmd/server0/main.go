package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"sync"
	"time"
)

// 配置
const (
	BaseURL     = "http://localhost:8010"
	AdminPhone  = "15396582900"
	GroupName   = "测试群200"
	MaxWorkers  = 10 // 最大并发数
	DefaultPass = "123456"
)

// HTTP 客户端
var httpClient = &http.Client{
	Timeout: 30 * time.Second,
}

// API 响应结构
type LoginResponse struct {
	Token string `json:"token"`
	User  struct {
		ID       string `json:"id"`
		Username string `json:"username"`
		Nickname string `json:"nickname,omitempty"`
	} `json:"user"`
}

type RegisterResponse struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Nickname string `json:"nickname,omitempty"`
	Email    string `json:"email"`
}

type FriendRequestResponse struct {
	ID string `json:"id"`
}

type RoomResponse struct {
	Room struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"room"`
}

// API 客户端
type RedCodeAPI struct {
	baseURL string
	token   string
	client  *http.Client
}

// NewRedCodeAPI 创建API客户端
func NewRedCodeAPI(baseURL string) *RedCodeAPI {
	return &RedCodeAPI{
		baseURL: baseURL,
		client:  httpClient,
	}
}

// SetToken 设置认证令牌
func (api *RedCodeAPI) SetToken(token string) {
	api.token = token
}

// doRequest 执行HTTP请求
func (api *RedCodeAPI) doRequest(method, endpoint string, data interface{}) (*http.Response, error) {
	var body io.Reader
	if data != nil {
		jsonData, err := json.Marshal(data)
		if err != nil {
			return nil, fmt.Errorf("JSON编码失败: %v", err)
		}
		body = bytes.NewBuffer(jsonData)
	}

	url := api.baseURL + endpoint
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "RedCode-Test-Go/1.0")

	if api.token != "" {
		req.Header.Set("Authorization", "Bearer "+api.token)
	}

	resp, err := api.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("请求失败: %v", err)
	}

	return resp, nil
}

// Register 注册账号
func (api *RedCodeAPI) Register(phone, password string) (*RegisterResponse, error) {
	data := map[string]interface{}{
		"username": phone,
		"password": password,
		"email":    phone + "@example.com",
		"nickname": "测试用户" + phone,
	}

	resp, err := api.doRequest("POST", "/auth/register", data)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("注册失败 [%d]: %s", resp.StatusCode, string(body))
	}

	var result RegisterResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %v", err)
	}

	return &result, nil
}

// Login 登录账号
func (api *RedCodeAPI) Login(phone, password string) (*LoginResponse, error) {
	data := map[string]string{
		"username": phone,
		"password": password,
	}

	resp, err := api.doRequest("POST", "/auth/login", data)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("登录失败 [%d]: %s", resp.StatusCode, string(body))
	}

	var result LoginResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %v", err)
	}

	api.SetToken(result.Token)
	return &result, nil
}

// AddFriend 发送好友请求
func (api *RedCodeAPI) AddFriend(targetUserID string) (*FriendRequestResponse, error) {
	data := map[string]interface{}{
		"target_user_id": targetUserID,
		"message":        "你好，我想添加你为好友",
	}

	resp, err := api.doRequest("POST", "/friends/requests", data)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("发送好友请求失败 [%d]: %s", resp.StatusCode, string(body))
	}

	var result FriendRequestResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %v", err)
	}

	return &result, nil
}

// RespondFriendRequest 响应好友请求
func (api *RedCodeAPI) RespondFriendRequest(requestID, action string) error {
	data := map[string]string{
		"action": action, // "accept" 或 "decline"
	}

	resp, err := api.doRequest("POST", "/friends/requests/"+requestID+"/respond", data)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("响应好友请求失败 [%d]: %s", resp.StatusCode, string(body))
	}

	return nil
}

// GetIncomingFriendRequests 获取收到的好友请求
func (api *RedCodeAPI) GetIncomingFriendRequests() ([]map[string]interface{}, error) {
	resp, err := api.doRequest("GET", "/friends/requests?direction=incoming&status=pending", nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("获取好友请求失败 [%d]: %s", resp.StatusCode, string(body))
	}

	var result []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %v", err)
	}

	return result, nil
}

// CreateGroup 创建群聊
func (api *RedCodeAPI) CreateGroup(name string, memberIDs []string, description string) (*RoomResponse, error) {
	data := map[string]interface{}{
		"name":        name,
		"description": description,
		"room_type":   "group",
		"member_ids":  memberIDs,
	}

	resp, err := api.doRequest("POST", "/rooms", data)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("创建群聊失败 [%d]: %s", resp.StatusCode, string(body))
	}

	var result RoomResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %v", err)
	}

	return &result, nil
}

// 账号信息结构
type AccountInfo struct {
	Phone   string
	UserID  string
	UserInfo map[string]interface{}
}

// 生成连续手机号
func generatePhoneNumbers(start, count int) []string {
	phones := make([]string, count)
	for i := 0; i < count; i++ {
		phones[i] = strconv.Itoa(start + i)
	}
	return phones
}

// 注册或登录账号
func registerOrLoginAccount(phone string) (*AccountInfo, string, error) {
	api := NewRedCodeAPI(BaseURL)

	// 先尝试登录
	loginResp, err := api.Login(phone, DefaultPass)
	if err == nil {
		return &AccountInfo{
			Phone:   phone,
			UserID:  loginResp.User.ID,
			UserInfo: map[string]interface{}{
				"id":       loginResp.User.ID,
				"username": loginResp.User.Username,
				"nickname": loginResp.User.Nickname,
			},
		}, "logged_in", nil
	}

	// 登录失败，尝试注册
	regResp, err := api.Register(phone, DefaultPass)
	if err != nil {
		return nil, "", fmt.Errorf("处理账号 %s 失败: %v", phone, err)
	}

	return &AccountInfo{
		Phone:  phone,
		UserID: regResp.ID,
		UserInfo: map[string]interface{}{
			"id":       regResp.ID,
			"username": regResp.Username,
			"nickname": regResp.Nickname,
			"email":    regResp.Email,
		},
	}, "registered", nil
}

// 发送好友请求
func sendFriendRequest(phone, adminUserID string) (*FriendRequestResponse, error) {
	api := NewRedCodeAPI(BaseURL)

	// 登录账号
	_, err := api.Login(phone, DefaultPass)
	if err != nil {
		return nil, fmt.Errorf("登录账号 %s 失败: %v", phone, err)
	}

	// 发送好友请求
	resp, err := api.AddFriend(adminUserID)
	if err != nil {
		return nil, fmt.Errorf("账号 %s 发送好友请求失败: %v", phone, err)
	}

	return resp, nil
}

// 主函数
func main() {
	fmt.Printf("将处理 200 个账号: 15396582100 到 15396582299\n")

	// 生成手机号
	phones := generatePhoneNumbers(15396582100, 200)

	// 存储注册成功的账号
	var registeredAccounts []*AccountInfo
	userIDMap := make(map[string]string)

	fmt.Println("\n=== 步骤1: 并发注册/登录200个账号 ===")

	// 并发注册账号
	var wg sync.WaitGroup
	var mu sync.Mutex
	var registeredCount, loggedInCount int

	semaphore := make(chan struct{}, MaxWorkers)

	for _, phone := range phones {
		wg.Add(1)
		go func(phone string) {
			defer wg.Done()
			semaphore <- struct{}{} // 获取信号量
			defer func() { <-semaphore }() // 释放信号量

			account, status, err := registerOrLoginAccount(phone)
			if err != nil {
				log.Printf("处理账号 %s 失败: %v", phone, err)
				return
			}

			mu.Lock()
			registeredAccounts = append(registeredAccounts, account)
			userIDMap[phone] = account.UserID

			if status == "registered" {
				registeredCount++
				fmt.Printf("  ✓ 注册成功 %s，User ID: %s\n", phone, account.UserID)
			} else {
				loggedInCount++
				fmt.Printf("  ✓ 已登录 %s，User ID: %s\n", phone, account.UserID)
			}
			mu.Unlock()
		}(phone)
	}

	wg.Wait()

	if len(registeredAccounts) == 0 {
		log.Fatal("没有账号处理成功，退出")
	}

	fmt.Printf("\n注册/登录完成:\n")
	fmt.Printf("- 新注册账号: %d\n", registeredCount)
	fmt.Printf("- 已登录账号: %d\n", loggedInCount)
	fmt.Printf("- 总处理账号: %d\n", len(registeredAccounts))

	// 确保管理员账号存在
	fmt.Println("\n=== 步骤2: 确保管理员账号存在 ===")
	adminAPI := NewRedCodeAPI(BaseURL)

	_, err := adminAPI.Register(AdminPhone, DefaultPass)
	if err != nil {
		fmt.Printf("管理员账号可能已存在: %v\n", err)
	}

	// 获取管理员的user_id
	adminLoginResp, err := adminAPI.Login(AdminPhone, DefaultPass)
	if err != nil {
		log.Fatalf("管理员账号登录失败: %v", err)
	}

	adminUserID := adminLoginResp.User.ID
	fmt.Printf("管理员账号登录成功，User ID: %s\n", adminUserID)

	// 并发发送好友请求
	fmt.Println("\n=== 步骤3: 并发发送好友请求 ===")

	var friendRequests []map[string]interface{}
	var friendMu sync.Mutex
	var requestWg sync.WaitGroup
	requestSemaphore := make(chan struct{}, MaxWorkers)

	for _, account := range registeredAccounts {
		requestWg.Add(1)
		go func(account *AccountInfo) {
			defer requestWg.Done()
			requestSemaphore <- struct{}{}
			defer func() { <-requestSemaphore }()

			request, err := sendFriendRequest(account.Phone, adminUserID)
			if err != nil {
				log.Printf("账号 %s 发送好友请求失败: %v", account.Phone, err)
				return
			}

			friendMu.Lock()
			friendRequests = append(friendRequests, map[string]interface{}{
				"requester_phone": account.Phone,
				"request_id":      request.ID,
				"requester_id":    account.UserID,
			})
			fmt.Printf("  ✓ %s 好友请求发送成功，Request ID: %s\n", account.Phone, request.ID)
			friendMu.Unlock()
		}(account)
	}

	requestWg.Wait()
	fmt.Printf("\n共发送 %d 个好友请求\n", len(friendRequests))

	// 管理员通过所有好友请求
	fmt.Println("\n=== 步骤4: 管理员通过所有好友请求 ===")

	incomingRequests, err := adminAPI.GetIncomingFriendRequests()
	if err != nil {
		log.Printf("获取好友请求失败: %v", err)
	}

	fmt.Printf("发现 %d 个待处理好友请求\n", len(incomingRequests))

	acceptedCount := 0
	for _, request := range incomingRequests {
		requestID, ok := request["id"].(string)
		if !ok {
			continue
		}

		requester, ok := request["requester"].(map[string]interface{})
		if !ok {
			continue
		}

		requesterPhone, ok := requester["username"].(string)
		if !ok {
			continue
		}

		// 只有我们的测试账号才通过
		isTestAccount := false
		for _, account := range registeredAccounts {
			if account.Phone == requesterPhone {
				isTestAccount = true
				break
			}
		}

		if isTestAccount {
			err := adminAPI.RespondFriendRequest(requestID, "accept")
			if err != nil {
				log.Printf("通过好友请求失败: %v", err)
				continue
			}
			fmt.Printf("  ✓ 通过好友请求: %s\n", requesterPhone)
			acceptedCount++
		} else {
			fmt.Printf("  - 跳过非测试账号: %s\n", requesterPhone)
		}
	}

	fmt.Printf("管理员通过了 %d 个好友请求\n", acceptedCount)

	// 创建群聊
	fmt.Println("\n=== 步骤5: 创建群聊并拉入所有账号 ===")

	memberIDs := make([]string, len(registeredAccounts))
	for i, account := range registeredAccounts {
		memberIDs[i] = account.UserID
	}

	group, err := adminAPI.CreateGroup(GroupName, memberIDs, fmt.Sprintf("批量测试群，包含%d个测试账号", len(memberIDs)))
	if err != nil {
		log.Printf("创建群聊失败: %v", err)
	} else {
		fmt.Println("✓ 群聊创建成功")
		fmt.Printf("  群名: %s\n", group.Room.Name)
		fmt.Printf("  群ID: %s\n", group.Room.ID)
		fmt.Printf("  成员数: %d\n", len(memberIDs))
	}

	fmt.Println("\n=== 测试完成 ===")
	fmt.Printf("总结:\n")
	fmt.Printf("- 注册账号: %d\n", registeredCount)
	fmt.Printf("- 发送好友请求: %d\n", len(friendRequests))
	fmt.Printf("- 创建群聊: %s\n", GroupName)
}
