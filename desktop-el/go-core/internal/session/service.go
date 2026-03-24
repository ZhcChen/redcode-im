package session

import "sync"

type Service struct {
	mu           sync.RWMutex
	accessToken  string
	refreshToken string
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

func (s *Service) Clear() {
	s.Set("", "")
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
