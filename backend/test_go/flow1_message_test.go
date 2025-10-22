package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"syscall"
	"testing"
	"time"
)

// 流程 1 自动化测试：
// 1. 使用通用验证码 666666 通过短信登录接口完成两名用户的登录（若用户不存在则自动注册后重试）。
// 2. 由发起方调用好友私聊接口确保存在双方专属房间，并获取房间 ID。
// 3. 发起方发送一条文本消息。
// 4. 分别以发起方和接收方身份拉取消息列表，确认均能看到同一条消息。
// 5. 最后输出测试总结，给出消息发送与接收是否正常的结论。
func TestFlowMessageSendReceive(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	baseURL := apiBaseURL()
	client := &http.Client{Timeout: 10 * time.Second}

	// 在执行主流程前，先确认后端服务可用；若当前环境未启动后端，则直接跳过测试。
	if err := ensureBackendAlive(ctx, client, baseURL); err != nil {
		t.Skipf("跳过流程 1：后端服务不可达（%v）。请先在本地启动 Axum 服务后再运行测试。", err)
		return
	}

	// 准备两名测试用户，手机号使用时间戳生成，避免与已有数据冲突。
	now := time.Now().UnixNano()
	senderPhone := fmt.Sprintf("199%08d", now%1_0000_0000)
	receiverPhone := fmt.Sprintf("188%08d", (now/3)%1_0000_0000)

	sender, err := ensureLoginViaSms(ctx, client, baseURL, senderPhone)
	if err != nil {
		t.Fatalf("发送方登录失败: %v", err)
	}
	receiver, err := ensureLoginViaSms(ctx, client, baseURL, receiverPhone)
	if err != nil {
		t.Fatalf("接收方登录失败: %v", err)
	}

	// 由发送方确保与接收方之间存在私聊房间。
	roomID, err := ensurePrivateChatRoom(ctx, client, baseURL, sender, receiver.UserID)
	if err != nil {
		t.Fatalf("确保私聊房间失败: %v", err)
	}

	// 构造一条具备唯一标记的文本消息，便于后续断言。
	messageContent := fmt.Sprintf("流程1自动化消息-%d", time.Now().UnixNano())
	messageID, err := sendRoomMessage(ctx, client, baseURL, sender, roomID, messageContent)
	if err != nil {
		t.Fatalf("发送消息失败: %v", err)
	}

	// 核验发送方是否能在历史记录中看到刚发送的消息。
	if err := assertMessageVisible(ctx, client, baseURL, sender, roomID, messageID, messageContent); err != nil {
		t.Fatalf("发送方校验消息失败: %v", err)
	}

	// 核验接收方是否能在历史记录中看到同一条消息。
	if err := assertMessageVisible(ctx, client, baseURL, receiver, roomID, messageID, messageContent); err != nil {
		t.Fatalf("接收方校验消息失败: %v", err)
	}

	t.Logf("流程 1 总结：发送方 %s 与接收方 %s 均成功收发消息（room=%s, message=%s）。",
		senderPhone, receiverPhone, roomID, messageID)
}

// apiBaseURL 返回测试使用的后端根地址，优先读取 TEST_GO_API_BASE 环境变量。
func apiBaseURL() string {
	if v := strings.TrimSpace(os.Getenv("TEST_GO_API_BASE")); v != "" {
		return strings.TrimRight(v, "/")
	}
	return "http://localhost:8010"
}

// ensureBackendAlive 向 /healthz 发起请求，确认后端服务已就绪。
func ensureBackendAlive(ctx context.Context, client *http.Client, baseURL string) error {
	healthURL := baseURL + "/healthz"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, healthURL, nil)
	if err != nil {
		return err
	}

	var lastErr error
	for i := 0; i < 3; i++ {
		resp, err := client.Do(req)
		if err == nil {
			_ = resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return nil
			}
			lastErr = fmt.Errorf("健康检查返回状态码 %d", resp.StatusCode)
		} else {
			lastErr = err
			if isConnRefused(err) {
				time.Sleep(500 * time.Millisecond)
				continue
			}
		}
	}
	return lastErr
}

// isConnRefused 判断错误是否为连接被拒绝（常见于服务未启动）。
func isConnRefused(err error) bool {
	var opErr *net.OpError
	if errors.As(err, &opErr) {
		if sysErr, ok := opErr.Err.(*os.SyscallError); ok {
			return sysErr.Err == syscall.ECONNREFUSED
		}
	}
	return false
}

// userSession 保存通过登录接口获得的访问令牌与基本信息。
type userSession struct {
	Token  string
	UserID string
}

const universalCaptcha = "666666"

// ensureLoginViaSms 使用短信验证码登录用户；若用户不存在，则自动注册后重试。
func ensureLoginViaSms(ctx context.Context, client *http.Client, baseURL, phone string) (userSession, error) {
	session, err := loginWithSms(ctx, client, baseURL, phone)
	if err == nil {
		return session, nil
	}

	// 如果报错不是“用户不存在”，直接返回。
	if !strings.Contains(err.Error(), "用户不存在") {
		return userSession{}, err
	}

	if regErr := registerUser(ctx, client, baseURL, phone); regErr != nil {
		return userSession{}, fmt.Errorf("注册用户失败: %w", regErr)
	}

	session, err = loginWithSms(ctx, client, baseURL, phone)
	if err != nil {
		return userSession{}, fmt.Errorf("注册后登录仍失败: %w", err)
	}
	return session, nil
}

// loginWithSms 调用 /auth/login/sms 完成登录，并返回 token 与用户 ID。
func loginWithSms(ctx context.Context, client *http.Client, baseURL, phone string) (userSession, error) {
	payload := map[string]string{
		"phone": phone,
		"code":  universalCaptcha,
	}
	buf, err := json.Marshal(payload)
	if err != nil {
		return userSession{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/auth/login/sms", bytes.NewReader(buf))
	if err != nil {
		return userSession{}, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return userSession{}, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return userSession{}, err
	}

	if resp.StatusCode != http.StatusOK {
		return userSession{}, fmt.Errorf("登录失败: %s", extractErrorMessage(body))
	}

	var success struct {
		Token string `json:"token"`
		User  struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	if err := json.Unmarshal(body, &success); err != nil {
		return userSession{}, fmt.Errorf("解析登录响应失败: %w", err)
	}
	if success.Token == "" || success.User.ID == "" {
		return userSession{}, fmt.Errorf("登录响应缺少 token 或 user.id")
	}
	return userSession{
		Token:  success.Token,
		UserID: success.User.ID,
	}, nil
}

// registerUser 调用 /auth/register 为手机号创建基础帐号，便于后续短信登录。
func registerUser(ctx context.Context, client *http.Client, baseURL, phone string) error {
	payload := map[string]any{
		"username": phone,
		"email":    fmt.Sprintf("%s@flow.test", phone),
		"password": fmt.Sprintf("Pwd%s!", phone[len(phone)-4:]),
		"nickname": fmt.Sprintf("用户%s", phone[len(phone)-4:]),
	}
	buf, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/auth/register", bytes.NewReader(buf))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		return nil
	}

	body, _ := io.ReadAll(resp.Body)
	return fmt.Errorf("注册接口返回状态 %d: %s", resp.StatusCode, extractErrorMessage(body))
}

// ensurePrivateChatRoom 调用 /friends/{friend_id}/chat 确保私聊房间存在。
func ensurePrivateChatRoom(ctx context.Context, client *http.Client, baseURL string, session userSession, friendUserID string) (string, error) {
	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		fmt.Sprintf("%s/friends/%s/chat", baseURL, friendUserID),
		bytes.NewBufferString("{}"),
	)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+session.Token)

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("确保私聊房间失败: %s", extractErrorMessage(body))
	}

	var data struct {
		RoomID string `json:"room_id"`
	}
	if err := json.Unmarshal(body, &data); err != nil {
		return "", fmt.Errorf("解析私聊房间响应失败: %w", err)
	}
	if data.RoomID == "" {
		return "", fmt.Errorf("私聊房间响应缺少 room_id")
	}
	return data.RoomID, nil
}

// sendRoomMessage 调用 /rooms/{room_id}/messages 发送文本消息，返回消息 ID。
func sendRoomMessage(ctx context.Context, client *http.Client, baseURL string, session userSession, roomID, content string) (string, error) {
	payload := map[string]string{"content": content}
	buf, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		fmt.Sprintf("%s/rooms/%s/messages", baseURL, roomID),
		bytes.NewReader(buf),
	)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+session.Token)

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("发送消息失败: %s", extractErrorMessage(body))
	}

	var result struct {
		Message struct {
			ID      string `json:"id"`
			Content string `json:"content"`
		} `json:"message"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("解析发送消息响应失败: %w", err)
	}
	if result.Message.ID == "" {
		return "", fmt.Errorf("发送消息响应缺少 message.id")
	}
	if result.Message.Content != content {
		return "", fmt.Errorf("发送内容与响应不一致: 期望 %q, 实际 %q", content, result.Message.Content)
	}
	return result.Message.ID, nil
}

// assertMessageVisible 检查指定用户能在消息列表中看到目标消息。
func assertMessageVisible(ctx context.Context, client *http.Client, baseURL string, session userSession, roomID, messageID, content string) error {
	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodGet,
		fmt.Sprintf("%s/rooms/%s/messages?limit=20", baseURL, roomID),
		nil,
	)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+session.Token)

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("读取消息失败: %s", extractErrorMessage(body))
	}

	var messages []struct {
		ID      string `json:"id"`
		Content string `json:"content"`
	}
	if err := json.Unmarshal(body, &messages); err != nil {
		return fmt.Errorf("解析消息列表失败: %w", err)
	}
	for _, msg := range messages {
		if msg.ID == messageID {
			if msg.Content != content {
				return fmt.Errorf("消息内容不匹配: 期望 %q, 实际 %q", content, msg.Content)
			}
			return nil
		}
	}
	return fmt.Errorf("未在消息列表中找到消息 %s", messageID)
}

// extractErrorMessage 解码后端统一错误响应，若解析失败则返回原始字符串。
func extractErrorMessage(body []byte) string {
	if len(body) == 0 {
		return "无响应正文"
	}
	var errResp struct {
		Message string `json:"message"`
		Details string `json:"details"`
	}
	if json.Unmarshal(body, &errResp) == nil {
		if errResp.Details != "" {
			return fmt.Sprintf("%s (%s)", errResp.Message, errResp.Details)
		}
		if errResp.Message != "" {
			return errResp.Message
		}
	}
	return string(body)
}
