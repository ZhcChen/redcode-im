package session

import (
	"sync"

	"desktop-el-core/internal/state"
)

type Service struct {
	mu           sync.RWMutex
	accessToken  string
	refreshToken string
	currentUser  *state.UserSnapshot
}

func New() *Service {
	return &Service{}
}

func (s *Service) Set(accessToken, refreshToken string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.accessToken = accessToken
	s.refreshToken = refreshToken
}

func (s *Service) SetCurrentUser(user state.UserSnapshot) {
	s.mu.Lock()
	defer s.mu.Unlock()

	userCopy := user
	s.currentUser = &userCopy
}

func (s *Service) Clear() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.accessToken = ""
	s.refreshToken = ""
	s.currentUser = nil
}

func (s *Service) AccessToken() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.accessToken
}

func (s *Service) RefreshToken() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.refreshToken
}

func (s *Service) CurrentUser() *state.UserSnapshot {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.currentUser == nil {
		return nil
	}

	userCopy := *s.currentUser
	return &userCopy
}
